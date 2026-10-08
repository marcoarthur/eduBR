# R/ellmer_tools.R
#
# Núcleo da camada ellmer (plans/ellmer-tools.md, chunk 1): sessão, limites,
# envelope (D2), serialização (D3), cap de linhas (D4), timeout (D6),
# classificação de erros (D9), anti-vazamento de schema.tabela (D10) e loja
# de handles (D1). A camada se adapta ao pacote: as tools só chamam as
# funções existentes e materializam sempre via coletar().
#
# Fronteira com o ellmer (0.5.0): o valor devolvido pela função de uma tool
# passa por normalize_tool_result(); listas são convertidas com
# jsonlite::toJSON(auto_unbox = TRUE) (sem `null = "null"`, NA vira "NA",
# NaN vira "NaN", 4 dígitos) e com aviso de depreciação. Por isso cada tool
# devolve uma **string JSON** já serializada por eduBR_envelope_json()
# (strings passam intactas e viram o `content` do tool_result).

# Personas aceitas pelo filtro de ferramentas_edubr().
eduBR_personas <- function() {
  c("gestora-escolar", "pesquisadora-educacional", "especialista-ml")
}

# Teto absoluto de linhas devolvidas ao LLM por chamada (D4).
eduBR_hard_cap <- function() 1000L

# Teto absoluto da amostra interna de treino (D5).
eduBR_teto_amostra <- function() 30000L

eduBR_limites_padrao <- function() {
  list(
    n_padrao = 100L,
    max_linhas = 1000L,
    max_chamadas = 50L,
    max_linhas_total = 10000,
    timeout_s = 30,
    max_amostra = 15000L,
    persistir = FALSE,
    ledger_arquivo = NULL
  )
}

# Valida e completa `limites` com os defaults.
eduBR_limites_normalizar <- function(limites) {
  if (is.null(limites)) {
    limites <- list()
  }
  if (!is.list(limites) || (length(limites) && is.null(names(limites))) ||
      any(!nzchar(names(limites)))) {
    stop("`limites` deve ser uma lista nomeada.", call. = FALSE)
  }
  padrao <- eduBR_limites_padrao()
  desconhecidas <- setdiff(names(limites), names(padrao))
  if (length(desconhecidas)) {
    stop(
      sprintf(
        "Chave(s) desconhecida(s) em `limites`: %s. V\u00e1lidas: %s.",
        paste(desconhecidas, collapse = ", "),
        paste(names(padrao), collapse = ", ")
      ),
      call. = FALSE
    )
  }

  positivo <- function(nm, inteiro = TRUE) {
    v <- limites[[nm]]
    ok <- is.numeric(v) && length(v) == 1L && !is.na(v) && is.finite(v) &&
      v > 0 && (!inteiro || v == round(v))
    if (!ok) {
      stop(
        sprintf(
          "`limites$%s` deve ser um n\u00famero %s.", nm,
          if (inteiro) "inteiro positivo" else "positivo"
        ),
        call. = FALSE
      )
    }
    v
  }

  out <- padrao
  for (nm in intersect(names(limites), c("n_padrao", "max_linhas",
                                         "max_chamadas", "max_amostra"))) {
    out[[nm]] <- as.integer(positivo(nm))
  }
  if ("max_linhas_total" %in% names(limites)) {
    out$max_linhas_total <- positivo("max_linhas_total")
  }
  if ("timeout_s" %in% names(limites)) {
    out$timeout_s <- positivo("timeout_s", inteiro = FALSE)
  }
  if ("persistir" %in% names(limites)) {
    v <- limites$persistir
    if (!is.logical(v) || length(v) != 1L || is.na(v)) {
      stop("`limites$persistir` deve ser TRUE ou FALSE.", call. = FALSE)
    }
    out$persistir <- v
  }
  if (!is.null(limites$ledger_arquivo)) {
    v <- limites$ledger_arquivo
    if (!is.character(v) || length(v) != 1L || is.na(v) || !nzchar(v)) {
      stop(
        "`limites$ledger_arquivo` deve ser um caminho (string n\u00e3o vazia).",
        call. = FALSE
      )
    }
    out["ledger_arquivo"] <- list(v)
  }

  if (out$max_linhas > eduBR_hard_cap()) {
    stop(
      sprintf(
        "`limites$max_linhas` n\u00e3o pode exceder %d (teto fixo de linhas devolvidas ao modelo).",
        eduBR_hard_cap()
      ),
      call. = FALSE
    )
  }
  if (out$max_amostra > eduBR_teto_amostra()) {
    stop(
      sprintf(
        "`limites$max_amostra` n\u00e3o pode exceder %d.", eduBR_teto_amostra()
      ),
      call. = FALSE
    )
  }
  out$n_padrao <- min(out$n_padrao, out$max_linhas)
  out
}

eduBR_validar_persona <- function(persona) {
  if (is.null(persona)) {
    return(NULL)
  }
  if (!is.character(persona) || length(persona) != 1L || is.na(persona) ||
      !persona %in% eduBR_personas()) {
    stop(
      sprintf(
        "`persona` deve ser NULL ou uma de: %s.",
        paste(eduBR_personas(), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  persona
}

# Host da conexão (para filtrar mensagens de erro); NULL se indisponível.
eduBR_host_conexao <- function(con) {
  if (!inherits(con, "PqConnection")) {
    return(NULL)
  }
  h <- tryCatch(DBI::dbGetInfo(con)$host, error = function(e) NULL)
  if (is.character(h) && length(h) == 1L && !is.na(h) && nzchar(h)) h else NULL
}

# Nova sessão: ambiente com conexão, limites, ledger e loja de handles.
eduBR_sessao_nova <- function(con, limites) {
  sessao <- new.env(parent = emptyenv())
  sessao$con <- con
  sessao$limites <- limites
  sessao$host <- eduBR_host_conexao(con)
  sessao$ledger <- eduBR_ledger_novo()
  handles <- new.env(parent = emptyenv())
  handles$objetos <- new.env(parent = emptyenv())
  handles$contadores <- list()
  sessao$handles <- handles
  sessao
}

# ---------------------------------------------------------------------------
# Erros (D9)

# Condição de erro classificada de uma tool.
eduBR_erro_tool <- function(tipo, mensagem) {
  structure(
    class = c(paste0("eduBR_", tipo), "eduBR_erro_tool", "error", "condition"),
    list(message = mensagem, call = NULL, tipo = tipo)
  )
}

eduBR_abortar <- function(tipo, mensagem) {
  stop(eduBR_erro_tool(tipo, mensagem))
}

eduBR_mensagem_conexao <- function() {
  paste0(
    "Falha ao consultar a base de dados (conex\u00e3o ou consulta). ",
    "Tente novamente ou simplifique o pedido; detalhes t\u00e9cnicos n\u00e3o ",
    "s\u00e3o expostos."
  )
}

# A mensagem traz SQL, texto do Postgres, schema ou host?
eduBR_mensagem_sensivel <- function(msg, sessao = NULL) {
  if (!length(msg) || is.na(msg)) {
    return(FALSE)
  }
  schemas <- unique(vapply(
    c(eduBR_catalogo(), eduBR_catalogo_extra()), `[[`, character(1), 1L
  ))
  fixos <- c("SELECT", "FROM", "ERROR:", "relation", "SQLSTATE", "libpq",
             paste0(schemas, "."))
  if (!is.null(sessao$host)) {
    fixos <- c(fixos, sessao$host)
  }
  any(vapply(fixos, grepl, logical(1), x = msg, fixed = TRUE)) ||
    grepl("postgres|\\b\\d{1,3}(\\.\\d{1,3}){3}\\b", msg,
          ignore.case = TRUE, perl = TRUE)
}

# Erro vindo do DBI/RPostgres/dbplyr?
eduBR_erro_de_banco <- function(e) {
  any(grepl("DBI|dbplyr|Rcpp|cpp11|Pq|Postgres", class(e))) ||
    grepl("dbplyr|RPostgres|DBI|dbGetQuery|dbSendQuery|dbExecute|dbFetch",
          paste(deparse(conditionCall(e)), collapse = " "))
}

# Classifica uma condição de erro em list(tipo, mensagem).
eduBR_classificar_erro <- function(e, sessao = NULL) {
  msg <- conditionMessage(e)
  if (inherits(e, "eduBR_erro_tool")) {
    tipo <- e$tipo
  } else if (grepl(paste0("statement timeout|canceling statement|",
                          "reached elapsed time limit|",
                          "reached CPU time limit"),
                   msg, ignore.case = TRUE)) {
    tipo <- "limite_excedido"
    msg <- sprintf(
      paste0(
        "A consulta excedeu o tempo limite de %s s e foi interrompida. ",
        "Filtre mais (UF, munic\u00edpio, ano, etapa) ou pe\u00e7a menos linhas."
      ),
      format(sessao$limites$timeout_s %||% NA)
    )
  } else if (eduBR_erro_de_banco(e)) {
    tipo <- "conexao"
  } else {
    tipo <- "parametro_invalido"
  }
  if (tipo != "limite_excedido" &&
      (tipo == "conexao" || eduBR_mensagem_sensivel(msg, sessao))) {
    tipo <- "conexao"
    msg <- eduBR_mensagem_conexao()
  }
  list(tipo = tipo, mensagem = msg)
}

`%||%` <- function(x, y) if (is.null(x)) y else x

# ---------------------------------------------------------------------------
# Serialização (D3)

# Colunas com dados institucionais identificáveis (endereço, telefone, CEP,
# CNPJ): ocultas por padrão em todo retorno de tool.
eduBR_colunas_pii <- function() {
  c("ds_endereco", "nu_endereco", "ds_complemento", "no_bairro", "co_cep",
    "nu_telefone", "nu_cnpj_escola_privada", "nu_cnpj_mantenedora",
    "endereco", "telefone")
}

eduBR_coluna_geometria <- function(x, nome) {
  inherits(x, c("pq_geometry", "sfc", "geometry")) ||
    nome %in% c("geometry", "geom")
}

# Converte uma coluna para tipos que o JSON representa sem perda.
eduBR_serializar_coluna <- function(x) {
  if (inherits(x, "integer64")) {
    rlang::check_installed("bit64")
    na <- is.na(x)
    out <- as.character(x)
    out[na] <- NA_character_
    return(out)
  }
  if (inherits(x, "POSIXlt")) {
    x <- as.POSIXct(x)
  }
  if (inherits(x, "POSIXct")) {
    return(format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  }
  if (inherits(x, "Date")) {
    return(format(x, "%Y-%m-%d"))
  }
  if (is.factor(x)) {
    return(as.character(x))
  }
  if (is.data.frame(x)) {
    return(lapply(seq_len(nrow(x)), function(i) {
      eduBR_serializar(x[i, , drop = FALSE])$dados[[1]]
    }))
  }
  if (is.list(x)) {
    return(lapply(x, function(el) {
      if (is.null(el)) {
        NULL
      } else if (is.data.frame(el)) {
        eduBR_serializar(el)$dados
      } else if (is.atomic(el)) {
        eduBR_serializar_coluna(el)
      } else {
        el
      }
    }))
  }
  if (is.double(x)) {
    x <- as.numeric(x)
    x[!is.finite(x)] <- NA_real_
    return(x)
  }
  if (is.logical(x) || is.integer(x) || is.character(x)) {
    return(as.vector(x))
  }
  as.character(x)
}

# Escalar NA vira NULL (null no JSON).
eduBR_valor_json <- function(v) {
  if (is.atomic(v) && length(v) == 1L && is.na(v)) NULL else v
}

# Data frame -> list(dados = <lista de registros>, omitidas = <colunas>).
# Remove geometria e PII institucional; integer64 -> string; datas ->
# ISO-8601; fator -> texto; NA/NaN/Inf -> NULL.
eduBR_serializar <- function(df) {
  if (inherits(df, "eduBR")) {
    df <- consulta(df)
  }
  if (!is.data.frame(df)) {
    stop("`df` deve ser um data frame.", call. = FALSE)
  }
  class(df) <- "data.frame"
  nomes <- names(df)
  geo <- vapply(seq_along(df), function(j) {
    eduBR_coluna_geometria(df[[j]], nomes[j])
  }, logical(1))
  pii <- nomes %in% eduBR_colunas_pii()
  omitidas <- nomes[geo | pii]
  df <- df[, !(geo | pii), drop = FALSE]

  cols <- lapply(df, eduBR_serializar_coluna)
  dados <- lapply(seq_len(nrow(df)), function(i) {
    lapply(cols, function(col) eduBR_valor_json(col[[i]]))
  })
  list(dados = dados, omitidas = omitidas)
}

# ---------------------------------------------------------------------------
# Anti-vazamento de schema.tabela (D10)

eduBR_regex_escapar <- function(x) {
  gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", x)
}

# Pares (domínio, schema, tabela) de todas as relações conhecidas.
eduBR_relacoes_fisicas <- function() {
  rel <- c(eduBR_catalogo(), eduBR_catalogo_extra())
  out <- data.frame(
    dominio = names(rel),
    schema = vapply(rel, `[[`, character(1), 1L),
    tabela = vapply(rel, `[[`, character(1), 2L),
    stringsAsFactors = FALSE
  )
  out[order(-nchar(out$schema) - nchar(out$tabela)), , drop = FALSE]
}

# Substitui qualquer `schema.tabela` (também na forma "schema"."tabela",
# escapada ou não) pelo nome de domínio. Recursivo em listas.
eduBR_anti_vazamento <- function(x) {
  if (is.list(x)) {
    out <- lapply(x, eduBR_anti_vazamento)
    attributes(out) <- attributes(x)
    return(out)
  }
  if (!is.character(x) || !length(x) ||
      !any(grepl(".", x, fixed = TRUE), na.rm = TRUE)) {
    return(x)
  }
  atributos <- attributes(x)
  rel <- eduBR_relacoes_fisicas()
  for (i in seq_len(nrow(rel))) {
    s <- eduBR_regex_escapar(rel$schema[i])
    t <- eduBR_regex_escapar(rel$tabela[i])
    q <- '\\\\?"'
    x <- gsub(
      sprintf("%s%s%s\\.%s%s%s", q, s, q, q, t, q), rel$dominio[i], x,
      perl = TRUE
    )
    x <- gsub(
      sprintf("(?<![A-Za-z0-9_])%s\\.%s(?![A-Za-z0-9_])", s, t),
      rel$dominio[i], x, perl = TRUE
    )
  }
  attributes(x) <- atributos
  x
}

# ---------------------------------------------------------------------------
# Envelope (D2)

eduBR_filtros_json <- function(filtros) {
  if (is.null(filtros) || !length(filtros)) {
    return(structure(list(), names = character(0)))
  }
  filtros
}

eduBR_envelope <- function(dados = list(), grao = NULL, filtros = NULL,
                           n = length(dados), n_total = NULL,
                           truncado = FALSE, aviso = NULL, handle = NULL,
                           colunas_omitidas = character(0), erro = NULL,
                           contexto = NULL) {
  metadados <- list(
    grao = grao,
    filtros = eduBR_filtros_json(filtros),
    n = as.integer(n),
    n_total = n_total,
    truncado = truncado,
    aviso = aviso,
    handle = handle,
    colunas_omitidas = I(as.character(colunas_omitidas))
  )
  # Campo opcional: identificação do objeto consultado (ex.: a escola).
  if (!is.null(contexto)) {
    metadados$contexto <- contexto
  }
  list(dados = dados, metadados = metadados, erro = erro)
}

eduBR_envelope_erro <- function(tipo, mensagem, grao = NULL, filtros = NULL) {
  eduBR_envelope(
    dados = list(), grao = grao, filtros = filtros, n = 0L,
    erro = list(tipo = tipo, mensagem = mensagem)
  )
}

# Resultado de uma função de tool, antes do envelope: `dados` é um objeto
# eduBR, tbl lazy, data frame ou NULL. `contexto` (opcional) é uma lista
# serializável que vai para `metadados$contexto`.
eduBR_resultado <- function(dados = NULL, grao = NULL, filtros = NULL,
                            handle = NULL, aviso = NULL, contexto = NULL) {
  structure(
    list(dados = dados, grao = grao, filtros = filtros, handle = handle,
         aviso = aviso, contexto = contexto),
    class = "eduBR_resultado_tool"
  )
}

# Envelope -> string JSON (o que vai para o ellmer).
eduBR_envelope_json <- function(env) {
  txt <- jsonlite::toJSON(
    env, auto_unbox = TRUE, null = "null", na = "null", digits = NA,
    force = TRUE
  )
  eduBR_anti_vazamento(as.character(txt))
}

# String JSON de uma tool -> envelope (lista R). Útil em testes.
eduBR_envelope_de <- function(json) {
  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

# ---------------------------------------------------------------------------
# Cap de linhas (D4)

eduBR_cap_n <- function(sessao, n = NULL) {
  lim <- sessao$limites
  if (is.null(n)) {
    n <- lim$n_padrao
  }
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1) {
    eduBR_abortar("parametro_invalido", "`n` deve ser um inteiro positivo.")
  }
  teto <- min(lim$max_linhas, eduBR_hard_cap())
  restante <- eduBR_orcamento_linhas_restantes(sessao)
  n_ef <- as.integer(max(1, min(floor(n), teto, restante)))
  aviso <- NULL
  if (n > teto) {
    aviso <- sprintf(
      "Pedido de %s linhas reduzido para %d (limite por chamada).",
      format(n, big.mark = ".", decimal.mark = ",", scientific = FALSE), n_ef
    )
  } else if (n_ef < n) {
    aviso <- sprintf(
      "Pedido de %s linhas reduzido para %d (or\u00e7amento restante da sess\u00e3o).",
      format(n, big.mark = ".", decimal.mark = ",", scientific = FALSE), n_ef
    )
  }
  list(n = n_ef, aviso = aviso)
}

# ---------------------------------------------------------------------------
# Timeout (D6)

eduBR_com_timeout <- function(sessao, expr) {
  con <- sessao$con
  tempo <- sessao$limites$timeout_s
  if (inherits(con, "PqConnection") &&
      isTRUE(tryCatch(DBI::dbIsValid(con), error = function(e) FALSE))) {
    anterior <- DBI::dbGetQuery(con, "SHOW statement_timeout")[[1]][1]
    DBI::dbExecute(
      con,
      sprintf("SET statement_timeout = %d", as.integer(ceiling(tempo * 1000)))
    )
    on.exit(
      try(
        DBI::dbExecute(
          con,
          paste0("SET statement_timeout = ", DBI::dbQuoteString(con, anterior))
        ),
        silent = TRUE
      ),
      add = TRUE
    )
  }
  setTimeLimit(elapsed = tempo, transient = TRUE)
  on.exit(
    setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE),
    add = TRUE, after = FALSE
  )
  force(expr)
}

# ---------------------------------------------------------------------------
# Execução de uma tool

# Materializa o resultado da função de uma tool e monta o envelope.
eduBR_montar_envelope <- function(sessao, res, n = NULL) {
  if (!inherits(res, "eduBR_resultado_tool")) {
    res <- eduBR_resultado(res)
  }
  x <- res$dados
  avisos <- character(0)
  if (is.null(x)) {
    return(eduBR_envelope(
      dados = list(), grao = res$grao, filtros = res$filtros, n = 0L,
      aviso = res$aviso, handle = res$handle, contexto = res$contexto
    ))
  }
  if (!(is.data.frame(x) || inherits(x, "eduBR") || eduBR_lazy(x))) {
    stop("Resultado de tool em formato n\u00e3o suportado.", call. = FALSE)
  }

  cap <- eduBR_cap_n(sessao, n)
  base <- if (inherits(x, "eduBR")) consulta(x) else x
  remoto <- eduBR_lazy(base)
  df <- coletar(x, n = cap$n + 1L)
  truncado <- nrow(df) > cap$n
  if (truncado) {
    df <- df[seq_len(cap$n), , drop = FALSE]
  }
  n_total <- if (!remoto) nrow(base) else if (!truncado) nrow(df) else NULL

  if (!is.null(cap$aviso)) {
    avisos <- c(avisos, cap$aviso)
  }
  if (truncado) {
    avisos <- c(avisos, sprintf(
      paste0(
        "H\u00e1 mais linhas do que as %d devolvidas; refine os filtros ",
        "para ver o restante."
      ),
      cap$n
    ))
  }
  if (!is.null(res$aviso)) {
    avisos <- c(avisos, res$aviso)
  }

  ser <- eduBR_serializar(df)
  if (length(ser$omitidas)) {
    avisos <- c(avisos, sprintf(
      "Colunas omitidas (geometria ou dados institucionais): %s.",
      paste(ser$omitidas, collapse = ", ")
    ))
  }
  aviso <- if (length(avisos)) paste(avisos, collapse = " ") else NULL

  if (!length(ser$dados)) {
    env <- eduBR_envelope(
      dados = list(), grao = res$grao, filtros = res$filtros, n = 0L,
      n_total = 0L, aviso = aviso, handle = res$handle,
      colunas_omitidas = ser$omitidas, contexto = res$contexto,
      erro = list(
        tipo = "sem_dados",
        mensagem = paste0(
          "A consulta n\u00e3o retornou linhas para os filtros informados. ",
          "Confira os par\u00e2metros (c\u00f3digos, ano, etapa, rede) ou ",
          "consulte a ferramenta `catalogo`."
        )
      )
    )
    return(env)
  }

  eduBR_envelope(
    dados = ser$dados, grao = res$grao, filtros = res$filtros,
    n = length(ser$dados), n_total = n_total, truncado = truncado,
    aviso = aviso, handle = res$handle, colunas_omitidas = ser$omitidas,
    contexto = res$contexto
  )
}

# Executa uma tool com orçamento, timeout, cap, classificação de erros,
# anti-vazamento e registro no ledger. Devolve o envelope (lista R).
eduBR_executar_tool <- function(sessao, nome, args, fun) {
  t0 <- proc.time()[["elapsed"]]
  duracao <- function() round((proc.time()[["elapsed"]] - t0) * 1000, 1)

  estouro <- eduBR_orcamento_estourado(sessao)
  if (!is.null(estouro)) {
    env <- eduBR_envelope_erro("limite_excedido", estouro)
    eduBR_ledger_registrar(
      sessao, nome, args, 0L, duracao(), "limite_excedido", contar = FALSE
    )
    return(eduBR_anti_vazamento(env))
  }

  env <- tryCatch(
    eduBR_com_timeout(sessao, {
      res <- do.call(fun, args)
      eduBR_montar_envelope(sessao, res, n = args[["n"]])
    }),
    error = function(e) {
      cl <- eduBR_classificar_erro(e, sessao)
      eduBR_envelope_erro(cl$tipo, cl$mensagem)
    }
  )
  env <- eduBR_anti_vazamento(env)
  eduBR_ledger_registrar(
    sessao, nome, args, length(env$dados), duracao(),
    if (is.null(env$erro)) NA_character_ else env$erro$tipo
  )
  env
}

# Função chamável pelo ellmer: mesmos formais de `fun`; repassa só os
# argumentos informados e devolve o envelope como string JSON.
eduBR_tool_wrapper <- function(sessao, nome, fun) {
  force(sessao)
  force(nome)
  force(fun)
  w <- function() {
    .amb <- environment()
    .args <- list()
    for (.nm in names(formals(fun))) {
      if (!do.call(missing, list(as.name(.nm)), envir = .amb)) {
        .args[.nm] <- list(get(.nm, envir = .amb))
      }
    }
    eduBR_envelope_json(eduBR_executar_tool(sessao, nome, .args, fun))
  }
  formals(w) <- formals(fun)
  w
}

# Cria um ToolDef do ellmer a partir de uma função de tool do eduBR.
eduBR_tool <- function(sessao, nome, fun, descricao, arguments = list(),
                       titulo = nome) {
  ellmer::tool(
    eduBR_tool_wrapper(sessao, nome, fun),
    description = descricao,
    arguments = arguments,
    name = nome,
    annotations = ellmer::tool_annotations(
      title = titulo, read_only_hint = TRUE, open_world_hint = FALSE
    )
  )
}

# ---------------------------------------------------------------------------
# Handles (D1)

eduBR_handle_guardar <- function(sessao, prefixo, obj) {
  if (!is.character(prefixo) || length(prefixo) != 1L || is.na(prefixo) ||
      !grepl("^[a-z][a-z0-9_]*$", prefixo)) {
    stop("`prefixo` deve ser um identificador em min\u00fasculas.", call. = FALSE)
  }
  h <- sessao$handles
  k <- (h$contadores[[prefixo]] %||% 0L) + 1L
  h$contadores[[prefixo]] <- k
  id <- paste0(prefixo, "_", k)
  assign(id, obj, envir = h$objetos)
  id
}

eduBR_handle_obter <- function(sessao, id) {
  if (!is.character(id) || length(id) != 1L || is.na(id) ||
      !exists(id, envir = sessao$handles$objetos, inherits = FALSE)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        "handle inexistente: %s. Use um id devolvido por outra ferramenta nesta sess\u00e3o.",
        if (is.character(id) && length(id) == 1L) id else "?"
      )
    )
  }
  get(id, envir = sessao$handles$objetos, inherits = FALSE)
}

# ---------------------------------------------------------------------------
# Tools

eduBR_tool_catalogo_fun <- function() {
  cat <- catalogo()
  cat$schema <- NULL
  cat$tabela <- NULL
  eduBR_resultado(cat, grao = "dominio")
}

eduBR_tool_catalogo <- function(sessao) {
  eduBR_tool(
    sessao, "catalogo", eduBR_tool_catalogo_fun,
    descricao = paste0(
      "Mapa dos dom\u00ednios de dados dispon\u00edveis no eduBR (Censo Escolar, ",
      "IDEB, INSE, IBGE, redes, scores). Consulte antes de escolher outra ",
      "ferramenta: para cada dom\u00ednio diz a granularidade (escola, ",
      "munic\u00edpio, escola \u00d7 etapa \u00d7 edi\u00e7\u00e3o...), a chave de jun\u00e7\u00e3o e ",
      "o seu tipo, a coluna de ano e os anos dispon\u00edveis. Use-o para saber ",
      "se um ano ou recorte existe antes de pedir dados. N\u00e3o recebe ",
      "argumentos."
    ),
    titulo = "Cat\u00e1logo de dom\u00ednios"
  )
}

# Registro interno: tool -> construtor e personas que a recebem.
eduBR_tools_registro <- function() {
  list(
    catalogo = list(
      criar = eduBR_tool_catalogo,
      personas = eduBR_personas()
    ),
    perfil_escola = list(
      criar = eduBR_tool_perfil_escola,
      personas = c("gestora-escolar", "pesquisadora-educacional")
    ),
    resumo_escola = list(
      criar = eduBR_tool_resumo_escola,
      personas = "gestora-escolar"
    ),
    serie_ideb_escola = list(
      criar = eduBR_tool_serie_ideb_escola,
      personas = "gestora-escolar"
    ),
    escolas_similares = list(
      criar = eduBR_tool_escolas_similares,
      personas = "gestora-escolar"
    ),
    scores_escola = list(
      criar = eduBR_tool_scores_escola,
      personas = c("gestora-escolar", "especialista-ml")
    ),
    indicadores_escola = list(
      criar = eduBR_tool_indicadores_escola,
      personas = "especialista-ml"
    )
  )
}

#' Ferramentas do eduBR para LLMs (ellmer)
#'
#' Cria uma lista de ferramentas (`ellmer::tool()`) que expõem o `eduBR` a
#' um modelo de linguagem via [ellmer](https://ellmer.tidyverse.org). Cada
#' ferramenta chama as funções do pacote e devolve ao modelo um **envelope
#' JSON** com três campos:
#'
#' - `dados`: lista de registros (linhas), sem geometria e sem dados
#'   institucionais identificáveis (endereço, telefone, CEP, CNPJ);
#'   `integer64` vira texto, datas viram ISO-8601 e `NA`/`NaN`/`Inf` viram
#'   `null`;
#' - `metadados`: `grao`, `filtros`, `n`, `n_total`, `truncado`, `aviso`,
#'   `handle`, `colunas_omitidas` e, em algumas ferramentas, `contexto`
#'   (identificação do objeto consultado, ex.: a escola em `perfil_escola`);
#' - `erro`: `null`, ou `{tipo, mensagem}` com `tipo` em
#'   `parametro_invalido`, `sem_dados`, `limite_excedido` ou `conexao`.
#'
#' Nenhum retorno expõe nomes físicos de `schema.tabela`, SQL ou mensagens
#' do Postgres. Cada chamada fica registrada no ledger da sessão (ver
#' [ledger()]).
#'
#' @section Ferramentas:
#' - `catalogo` (todas as personas): domínios, granularidade e anos;
#' - `perfil_escola` (gestora, pesquisadora): escola × município × estado
#'   ([perfil_escola()] + [comparar()]), com a identificação da escola em
#'   `metadados$contexto`;
#' - `resumo_escola` (gestora): a escola numa linha ([resumo_escola()]);
#' - `serie_ideb_escola` (gestora): série do IDEB da escola ([ideb()]);
#' - `escolas_similares` (gestora): benchmark sem usar a nota
#'   ([escolas_similares()], `n` até 20);
#' - `scores_escola` (gestora, especialista-ml): scores compostos
#'   ([scores()]);
#' - `indicadores_escola` (especialista-ml): ranking por indicador
#'   ([indicadores()]).
#'
#' Os argumentos (código INEP de 8 dígitos, etapa, edição bienal do IDEB,
#' `n`) são validados antes de consultar o banco; valores inválidos
#' devolvem `parametro_invalido` com a correção esperada.
#'
#' @section Limites:
#' `limites` é uma lista nomeada; chaves omitidas usam o padrão:
#'
#' - `n_padrao` (100): linhas devolvidas quando a ferramenta não recebe `n`;
#' - `max_linhas` (1000): linhas por chamada; nunca acima de 1000;
#' - `max_chamadas` (50) e `max_linhas_total` (10000): orçamento da sessão;
#'   estourado, a ferramenta responde `limite_excedido` sem executar;
#' - `timeout_s` (30): tempo máximo por chamada (aplicado também como
#'   `statement_timeout` no Postgres e restaurado ao fim);
#' - `max_amostra` (15000, máx. 30000): teto das amostras internas de
#'   treino (nunca devolvidas ao modelo);
#' - `persistir` (`FALSE`) e `ledger_arquivo` (`NULL`): gravação do ledger
#'   em CSV (por padrão em `tools::R_user_dir("eduBR", "data")/ledger/`).
#'
#' @param con Conexão criada por [conecta()].
#' @param persona `NULL` (todas as ferramentas) ou uma de
#'   `"gestora-escolar"`, `"pesquisadora-educacional"`,
#'   `"especialista-ml"`, que restringe a lista às ferramentas da persona.
#' @param limites Lista nomeada de limites (ver seção *Limites*).
#'
#' @return Uma lista nomeada de `ellmer::ToolDef`, com os atributos
#'   `ledger` (ambiente lido por [ledger()]) e `sessao`. Registre-a num chat
#'   com `chat$register_tools(tools)`.
#'
#' @examples
#' \dontrun{
#' con <- conecta(service = "edumaps")
#' tools <- ferramentas_edubr(con, persona = "pesquisadora-educacional")
#' chat <- ellmer::chat_anthropic()
#' chat$register_tools(tools)
#' chat$chat("Quais anos de IDEB existem na base?")
#' ledger(tools)
#' }
#'
#' @export
ferramentas_edubr <- function(con, persona = NULL, limites = list()) {
  rlang::check_installed(
    c("ellmer", "jsonlite"),
    reason = "para expor o eduBR como ferramentas de LLM."
  )
  persona <- eduBR_validar_persona(persona)
  sessao <- eduBR_sessao_nova(con, eduBR_limites_normalizar(limites))

  registro <- eduBR_tools_registro()
  if (!is.null(persona)) {
    manter <- vapply(registro, function(r) persona %in% r$personas, logical(1))
    registro <- registro[manter]
  }
  tools <- lapply(registro, function(r) r$criar(sessao))
  names(tools) <- names(registro)

  attr(tools, "ledger") <- sessao$ledger
  attr(tools, "sessao") <- sessao
  tools
}
