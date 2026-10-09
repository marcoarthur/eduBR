# tools/taxa-sucesso-ellmer.R
#
# Taxa de sucesso da camada ellmer com chat real: roda os 3 cenarios de
# aceite (gestora, pesquisadora, especialista-ml) N vezes cada, sempre com
# chat e sessao novos, e grava a tabela persona x provedor. Rode NO
# CONTAINER, como rsuser (Ollama: tunel aberto, tools/tunnel-ollama.sh;
# Anthropic: ANTHROPIC_API_KEY no ~/.Renviron):
#
#   EDUBR_DEST=/home/rsuser/projetos/eduBR   # pacote (load_all)
#   PROVEDOR=ollama                          # ou anthropic
#   N=2                                      # repeticoes por cenario (max. 2)
#   CENARIOS=gestora,pesquisadora,ml         # subconjunto opcional
#   SAIDA=/tmp/taxa/ollama                   # prefixo: <SAIDA>.md e .csv
#
# Uma execucao conta como SUCESSO quando: (1) as tools esperadas aparecem no
# ledger na ordem certa; (2) nenhuma chamada deu erro; (3) a resposta final
# nao esta vazia; (4) o numero-chave devolvido pela tool aparece na
# resposta (virgula, ponto ou porcentagem).

dest <- Sys.getenv("EDUBR_DEST", "/home/rsuser/projetos/eduBR")
provedor <- Sys.getenv("PROVEDOR", "ollama")
n_rep <- as.integer(Sys.getenv("N", "2"))
# O Ollama roda no laptop do dono do repo: N=5 levou a temperatura a nivel
# critico (2026-10-09). Teto fixo de 2 repeticoes por cenario.
if (is.na(n_rep) || n_rep < 1L || n_rep > 2L) {
  stop("N deve ser 1 ou 2 (limite t\u00e9rmico do laptop que roda o Ollama).",
       call. = FALSE)
}
saida <- Sys.getenv("SAIDA", file.path(tempdir(), paste0("taxa-", provedor)))
escolhidos <- strsplit(Sys.getenv("CENARIOS", "gestora,pesquisadora,ml"), ",")[[1]]
suppressMessages(devtools::load_all(dest, quiet = TRUE))

prop <- function(x, p) tryCatch(S7::prop(x, p), error = function(e) NULL)

# Valores (JSON) devolvidos pelas tools nos turnos do chat, por nome.
resultados_tools <- function(chat) {
  out <- list()
  for (t in chat$get_turns()) {
    for (cn in prop(t, "contents")) {
      if (S7::S7_inherits(cn, ellmer::ContentToolResult)) {
        req <- prop(cn, "request")
        nome <- if (is.null(req)) "?" else prop(req, "name")
        v <- prop(cn, "value")
        if (is.character(v)) {
          out[[length(out) + 1L]] <- list(
            tool = nome,
            env = tryCatch(jsonlite::fromJSON(paste(v, collapse = ""),
                                              simplifyVector = FALSE),
                           error = function(e) NULL)
          )
        }
      }
    }
  }
  out
}

ultimo <- function(res, nome) {
  r <- Filter(function(x) identical(x$tool, nome) && !is.null(x$env), res)
  if (length(r)) r[[length(r)]]$env else NULL
}

# O numero aparece no texto? Aceita 1-3 casas, ponto ou virgula, e %.
aparece <- function(x, texto) {
  if (is.null(x) || !is.numeric(x) || is.na(x)) return(FALSE)
  cand <- c(sprintf("%.1f", x), sprintf("%.2f", x), sprintf("%.3f", x),
            sprintf("%.0f%%", 100 * x), sprintf("%.1f%%", 100 * x))
  cand <- unique(c(cand, gsub(".", ",", cand, fixed = TRUE)))
  cand <- c(cand, sub("^-", "−", cand))
  any(vapply(cand, grepl, logical(1), x = texto, fixed = TRUE))
}

subsequencia <- function(esperado, obtido) {
  i <- 1L
  for (o in obtido) {
    if (i <= length(esperado) && identical(o, esperado[[i]])) i <- i + 1L
  }
  i > length(esperado)
}

cenarios <- list(
  gestora = list(
    persona = "gestora-escolar", raciocinio = NULL,
    perguntas = c(
      "Como está a infraestrutura da escola 13078070 comparada ao município?",
      "Quais escolas são parecidas com a 13078070 para trocar experiência?"
    ),
    esperado = c("perfil_escola", "escolas_similares"),
    # fração municipal de um item de infraestrutura que a escola tem
    chave = function(res) {
      env <- ultimo(res, "perfil_escola")
      if (is.null(env)) return(NULL)
      it <- Filter(function(d) {
        identical(d$dimensao, "Infraestrutura") &&
          isTRUE(as.numeric(d$escola %||% NA) == 1)
      }, env$dados)
      if (length(it)) it[[1]]$municipio else NULL
    }
  ),
  pesquisadora = list(
    persona = "pesquisadora-educacional", raciocinio = NULL,
    perguntas = paste(
      "No Acre, rede municipal, o IDEB do fundamental I se associa a ter",
      "biblioteca e ao número de docentes? Separe por localização urbana/rural."
    ),
    # caminho em uma chamada (#81) ou passo a passo
    esperado = list(c("regressao_escolas"),
                    c("covariaveis_escola", "especificar_regressao",
                      "executar_regressao", "coeficientes")),
    chave = function(res) {
      env <- ultimo(res, "regressao_escolas") %||% ultimo(res, "coeficientes")
      if (is.null(env)) return(NULL)
      b <- Filter(function(d) identical(d$termo, "in_biblioteca") &&
                    identical(d$localizacao, "Urbana"), env$dados)
      if (length(b)) b[[1]]$estimativa else NULL
    }
  ),
  ml = list(
    persona = "especialista-ml", raciocinio = NULL,
    perguntas = paste(
      "Treine uma floresta aleatória para classificar o desempenho (terços",
      "da nota) das escolas públicas do fundamental II, com amostra",
      "reprodutível, e avalie contra o baseline."
    ),
    esperado = c("features_escola", "classificar_desempenho", "dividir_dados",
                 "treinar_floresta", "metricas_floresta"),
    chave = function(res) {
      env <- ultimo(res, "metricas_floresta")
      if (is.null(env) || !length(env$dados)) NULL else env$dados[[1]]$acuracia
    }
  )
)
cenarios <- cenarios[intersect(names(cenarios), escolhidos)]

con <- conecta(service = "edumaps")
execucoes <- list()
dir.create(dirname(saida), recursive = TRUE, showWarnings = FALSE)
csv <- paste0(saida, ".csv")
if (file.exists(csv)) file.remove(csv)
for (nome in names(cenarios)) {
  cen <- cenarios[[nome]]
  for (k in seq_len(n_rep)) {
    tools <- ferramentas_edubr(con, persona = cen$persona,
                               limites = list(timeout_s = 180))
    t0 <- Sys.time()
    falha <- NULL
    respostas <- character(0)
    chat <- tryCatch(
      chat_edubr(provedor, tools = tools, echo = "none",
                 raciocinio = cen$raciocinio),
      error = function(e) {
        falha <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(chat)) {
      for (p in cen$perguntas) {
        r <- tryCatch(as.character(chat$chat(p)), error = function(e) {
          falha <<- conditionMessage(e)
          ""
        })
        respostas <- c(respostas, r)
        if (!is.null(falha)) break
      }
    }
    dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    led <- ledger(tools)
    caminhos <- if (is.list(cen$esperado)) cen$esperado else list(cen$esperado)
    ok_tools <- any(vapply(caminhos, subsequencia, logical(1),
                           obtido = led$tool[is.na(led$erro)]))
    ok_erros <- !any(!is.na(led$erro))
    ok_texto <- length(respostas) == length(cen$perguntas) &&
      all(nzchar(trimws(respostas)))
    res <- if (is.null(chat)) list() else resultados_tools(chat)
    valor <- cen$chave(res)
    ok_numero <- aparece(as.numeric(valor %||% NA), paste(respostas, collapse = "\n"))
    tok <- if (is.null(chat)) NULL else tryCatch(chat$get_tokens(), error = function(e) NULL)
    pico <- if (is.null(tok) || !nrow(tok)) NA_real_ else
      max(tok$input + ifelse(is.na(tok$cached_input), 0, tok$cached_input) + tok$output)
    sucesso <- is.null(falha) && ok_tools && ok_erros && ok_texto && ok_numero
    execucoes[[length(execucoes) + 1L]] <- data.frame(
      cenario = nome, persona = cen$persona, provedor = provedor, rep = k,
      sucesso = sucesso, tools_ok = ok_tools, sem_erro = ok_erros,
      texto_ok = ok_texto, numero_ok = ok_numero,
      valor_chave = if (is.null(valor)) NA_real_ else as.numeric(valor),
      segundos = round(dt, 1), pico_tokens = pico,
      tools = paste(led$tool, collapse = " > "),
      falha = falha %||% NA_character_,
      resposta = substr(gsub("\\s+", " ", paste(respostas, collapse = " || ")),
                        1L, 600L),
      stringsAsFactors = FALSE
    )
    # Grava a cada execu\u00e7\u00e3o: uma interrup\u00e7\u00e3o n\u00e3o perde o que j\u00e1 rodou.
    utils::write.table(execucoes[[length(execucoes)]], csv, sep = ",",
                       row.names = FALSE, col.names = !file.exists(csv),
                       append = file.exists(csv))
    message(sprintf("%s #%d: %s (%.0f s; tools: %s)", nome, k,
                    if (sucesso) "SUCESSO" else "falha", dt,
                    paste(led$tool, collapse = " > ")))
  }
}

tab <- do.call(rbind, execucoes)

resumo <- do.call(rbind, lapply(split(tab, tab$cenario), function(d) {
  data.frame(
    cenario = d$cenario[1], persona = d$persona[1], provedor = d$provedor[1],
    taxa = sprintf("%d/%d", sum(d$sucesso), nrow(d)),
    tools_ok = sum(d$tools_ok), numero_ok = sum(d$numero_ok),
    segundos_mediana = stats::median(d$segundos),
    pico_tokens_max = suppressWarnings(max(d$pico_tokens, na.rm = TRUE))
  )
}))
linhas <- c(
  sprintf("# Taxa de sucesso da camada ellmer (%s)", provedor), "",
  sprintf("Gerado em %s com `tools/taxa-sucesso-ellmer.R` (N = %d por cenário).",
          format(Sys.time(), "%Y-%m-%d %H:%M"), n_rep), "",
  "| Cenário | Persona | Sucesso | Tools na ordem | Número conferido | Mediana (s) | Pico de tokens |",
  "|---|---|---|---|---|---|---|",
  sprintf("| %s | %s | %s | %d | %d | %.0f | %s |", resumo$cenario, resumo$persona,
          resumo$taxa, resumo$tools_ok, resumo$numero_ok,
          resumo$segundos_mediana, format(resumo$pico_tokens_max)),
  "",
  "Critério de sucesso: tools esperadas na ordem, sem erro nas chamadas,",
  "resposta não vazia e o número-chave da tool presente na resposta.",
  sprintf("Execuções detalhadas: `%s.csv`.", basename(saida))
)
writeLines(linhas, paste0(saida, ".md"))
cat(linhas, sep = "\n")
