# R/ellmer_tools_ml.R
#
# Tools de ML da camada ellmer (plans/ellmer-tools.md, chunk 5; persona
# especialista-ml): features_escola, classificar_desempenho, dividir_dados,
# treinar_floresta, importancia_floresta, metricas_floresta e pca_perfil.
# Só envolvem as funções do pacote (desempenho.R, floresta.R, pca.R).
#
# Memória (D5): a única coleta é a de features_escola, uma amostra
# estratificada por etapa feita **no banco** e limitada a
# `limites$max_amostra`. A ordem da amostra é um hash determinístico
# md5(co_entidade || ':' || semente) com ROW_NUMBER() por etapa: mesma
# semente, mesmas escolas, sem depender do gerador aleatório do Postgres.
# O treino usa num.threads = 2 e no máximo 500 árvores.
#
# Vazamento: a nota que define a classe (e as demais notas SAEB) e o
# próprio `nivel` nunca entram como preditores; identificadores e rótulos
# espaciais também ficam de fora (as mesmas exclusões padrão de
# treinar_floresta()). As medidas de INSE (`media_inse`, `pc_nivel_*`) são
# contexto socioeconômico, não desempenho: continuam preditoras.

# ---------------------------------------------------------------------------
# Valores aceitos

eduBR_etapas_features <- function() c("fundamental_i", "fundamental_ii", "ensino_medio")

eduBR_semente_padrao <- function() 2023L

eduBR_max_arvores <- function() 500L

eduBR_threads_floresta <- function() 2L

# Medidas de desempenho (SAEB): nunca preditoras.
eduBR_colunas_desempenho <- function() {
  c("nota_media", "nota_matematica", "nota_portugues")
}

# Identificadores e rótulos espaciais (exclusões padrão de treinar_floresta()).
eduBR_colunas_identificacao <- function() {
  c("co_entidade", "id_escola", "etapa", "sg_uf", "uf", "sg_regiao", "regiao",
    "co_municipio", "co_uf", "no_municipio")
}

# ---------------------------------------------------------------------------
# Validação e acesso aos handles

eduBR_validar_semente <- function(semente) {
  eduBR_validar_inteiro(
    semente %||% eduBR_semente_padrao(), "semente", 0L, .Machine$integer.max
  )
}

# `etapa` do LLM (string ou array) -> vetor de etapas válidas, sem repetição.
eduBR_validar_etapas <- function(etapa) {
  if (is.null(etapa) || (is.list(etapa) && !length(etapa))) {
    return(c("fundamental_i", "fundamental_ii"))
  }
  etapa <- unlist(etapa, use.names = FALSE)
  validas <- eduBR_etapas_features()
  if (!is.character(etapa) || !length(etapa) || anyNA(etapa) ||
      any(!etapa %in% validas)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        "`etapa` inv\u00e1lida: %s. Use uma lista com valores entre: %s.",
        eduBR_valor_texto(etapa), paste(validas, collapse = ", ")
      )
    )
  }
  unique(etapa)
}

eduBR_ranger_disponivel <- function() {
  if (!requireNamespace("ranger", quietly = TRUE)) {
    eduBR_abortar(
      "parametro_invalido",
      "O pacote `ranger` n\u00e3o est\u00e1 instalado neste ambiente; a floresta n\u00e3o pode ser treinada."
    )
  }
  invisible(TRUE)
}

# Handle `dados_<k>` materializado (data frame) para as tools de ML.
eduBR_ml_dados <- function(sessao, dados_id) {
  obj <- eduBR_obter_dados_handle(sessao, dados_id)
  if (!is.data.frame(obj)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        paste0(
          "O handle %s guarda uma consulta n\u00e3o materializada (ex.: de ",
          "`covariaveis_escola`). As ferramentas de ML trabalham sobre a ",
          "amostra coletada por `features_escola`; use o handle dela."
        ),
        dados_id
      )
    )
  }
  obj
}

# Nota usada para definir a classe (ou NULL quando ainda não classificado).
eduBR_ml_nota <- function(df) attr(df, "eduBR_nota", exact = TRUE)

# Guarda um data frame de ML com seus atributos (nota da classe e cortes).
eduBR_ml_atributos <- function(df, nota = NULL, limites = NULL) {
  attr(df, "eduBR_nota") <- nota
  attr(df, "limites_desempenho") <- limites
  df
}

# Executa `expr` sem alterar o estado do gerador aleatório do usuário
# (dividir_dados() chama set.seed()).
eduBR_preservar_semente <- function(expr) {
  amb <- globalenv()
  tinha <- exists(".Random.seed", envir = amb, inherits = FALSE)
  if (tinha) {
    antiga <- get(".Random.seed", envir = amb, inherits = FALSE)
    on.exit(assign(".Random.seed", antiga, envir = amb), add = TRUE)
  } else {
    on.exit(
      if (exists(".Random.seed", envir = amb, inherits = FALSE)) {
        rm(".Random.seed", envir = amb)
      },
      add = TRUE
    )
  }
  force(expr)
}

# Data frame -> lista de registros JSON-serializáveis (para `contexto`).
eduBR_registros <- function(df) {
  eduBR_serializar(df)$dados
}

# ---------------------------------------------------------------------------
# Amostra estratificada no banco

# Consulta lazy da amostra: ordena cada etapa por md5(co_entidade || ':' ||
# semente) e mantém as `n_por_etapa` primeiras; `.n_etapa` é o tamanho da
# população da etapa (COUNT(*) OVER). Sem nomes físicos: parte da consulta
# de features_escola().
eduBR_amostra_features <- function(tb, n_por_etapa, semente) {
  chave <- rlang::call2(
    "md5",
    rlang::call2(
      "paste0", quote(.data$co_entidade), ":",
      format(semente, scientific = FALSE)
    )
  )
  tb <- dplyr::mutate(tb, .ordem = !!chave)
  tb <- dplyr::group_by(tb, .data$etapa)
  tb <- dbplyr::window_order(tb, .data$.ordem, .data$co_entidade)
  tb <- dplyr::mutate(tb, .pos = dplyr::row_number(), .n_etapa = dplyr::n())
  tb <- dplyr::ungroup(tb)
  tb <- dplyr::filter(tb, .data$.pos <= !!as.integer(n_por_etapa))
  dplyr::arrange(tb, .data$etapa, .data$co_entidade)
}

# Coleta a amostra; integer64 vira double (o cálculo de ML exige número).
eduBR_coletar_amostra <- function(tb) {
  df <- dplyr::collect(tb)
  populacao <- tapply(as.numeric(df$.n_etapa), df$etapa, max)
  df$.ordem <- NULL
  df$.pos <- NULL
  df$.n_etapa <- NULL
  df[] <- lapply(df, function(v) {
    if (inherits(v, "integer64")) as.numeric(v) else v
  })
  out <- tibble::as_tibble(df)
  attr(out, "eduBR_populacao") <- populacao
  out
}

# ---------------------------------------------------------------------------
# features_escola

eduBR_tool_features_escola <- function(sessao) {
  fun <- function(etapa = NULL, publica = TRUE, n_por_etapa = NULL,
                  semente = 2023L) {
    etapa <- eduBR_validar_etapas(etapa)
    publica <- eduBR_validar_logico(publica %||% TRUE, "publica")
    teto <- as.integer(floor(sessao$limites$max_amostra / length(etapa)))
    if (is.null(n_por_etapa)) {
      n_por_etapa <- teto
    } else if (is.numeric(n_por_etapa) && length(n_por_etapa) == 1L &&
               !is.na(n_por_etapa) && n_por_etapa > teto) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf(
          paste0(
            "`n_por_etapa` = %s passa do limite de %d escolas por etapa ",
            "(amostra m\u00e1xima da sess\u00e3o, %d, dividida entre %d etapa(s)). ",
            "Use um valor at\u00e9 %d ou menos etapas."
          ),
          format(n_por_etapa, scientific = FALSE), teto,
          sessao$limites$max_amostra, length(etapa), teto
        )
      )
    }
    n_por_etapa <- eduBR_validar_inteiro(n_por_etapa, "n_por_etapa", 1L, teto)
    semente <- eduBR_validar_semente(semente)

    tb <- consulta(features_escola(sessao$con, etapa = etapa, publica = publica))
    df <- eduBR_coletar_amostra(eduBR_amostra_features(tb, n_por_etapa, semente))
    if (!nrow(df)) {
      eduBR_abortar(
        "sem_dados",
        "Nenhuma escola com features para as etapas pedidas."
      )
    }
    populacao <- attr(df, "eduBR_populacao")
    attr(df, "eduBR_populacao") <- NULL

    id <- eduBR_handle_guardar(
      sessao, "dados", df,
      descricao = eduBR_handle_descrever(
        "features_escola",
        list(etapa = etapa, publica = publica, n_por_etapa = n_por_etapa,
             semente = semente, n = nrow(df))
      )
    )

    nota <- if ("nota_media" %in% names(df)) df$nota_media else NA_real_
    por_etapa <- split(seq_len(nrow(df)), df$etapa)
    resumo <- tibble::tibble(
      etapa = names(por_etapa),
      n_amostra = vapply(por_etapa, length, integer(1), USE.NAMES = FALSE),
      n_populacao = as.numeric(populacao[names(por_etapa)]),
      n_com_nota = vapply(por_etapa, function(ix) sum(!is.na(nota[ix])),
                          integer(1), USE.NAMES = FALSE)
    )
    desempenho <- intersect(eduBR_colunas_desempenho(), names(df))
    previa_cols <- utils::head(
      c("co_entidade", "etapa", desempenho,
        setdiff(names(df), c("co_entidade", "etapa", desempenho))),
      12L
    )
    eduBR_resultado(
      resumo,
      grao = "etapa (resumo da amostra escola \u00d7 etapa)",
      filtros = list(etapa = I(etapa), publica = publica,
                     n_por_etapa = n_por_etapa, semente = semente),
      handle = id,
      aviso = sprintf(
        paste0(
          "Amostra guardada em %s (%d linhas escola \u00d7 etapa, %d colunas); ",
          "a mesma semente devolve as mesmas escolas. Pr\u00f3ximo passo: ",
          "`classificar_desempenho(dados_id = \"%s\")`."
        ),
        id, nrow(df), ncol(df), id
      ),
      contexto = list(
        handle = id,
        semente = semente,
        n_linhas = nrow(df),
        n_colunas = ncol(df),
        colunas_desempenho = I(desempenho),
        colunas = I(names(df)),
        previa = eduBR_registros(utils::head(df[previa_cols], 3L))
      )
    )
  }
  eduBR_tool(
    sessao, "features_escola", fun,
    descricao = paste0(
      "Coleta uma AMOSTRA reprodut\u00edvel da base de features escolares para ",
      "modelagem de desempenho: uma linha por escola \u00d7 etapa, com ",
      "infraestrutura (`in_*`, scores `*_score`), matr\u00edculas (`qt_mat_*`, ",
      "propor\u00e7\u00f5es), docentes (`qt_doc_*`, forma\u00e7\u00e3o e v\u00ednculo), gest\u00e3o ",
      "(`gestor_*`), INSE (`media_inse`, `pc_nivel_*`), raz\u00f5es derivadas ",
      "(alunos por sala, docentes por aluno) e a nota SAEB `nota_media` ",
      "(m\u00e9dia de matem\u00e1tica e portugu\u00eas; \u00e9 o ALVO potencial, nunca preditor). ",
      "N\u00e3o h\u00e1 UF nem munic\u00edpio na base. A amostra \u00e9 estratificada por etapa e ",
      "feita no banco: em cada etapa as escolas s\u00e3o ordenadas por um hash ",
      "determin\u00edstico do c\u00f3digo com a `semente`, ent\u00e3o a mesma semente traz ",
      "as mesmas escolas. `n_por_etapa` tem padr\u00e3o e teto iguais ao limite da ",
      "sess\u00e3o (15.000 escolas) dividido entre as etapas pedidas. A base fica ",
      "guardada no handle \"dados_<k>\"; a resposta traz o n por etapa (amostra, ",
      "popula\u00e7\u00e3o, com nota), o n\u00famero de colunas, as colunas de desempenho e ",
      "uma pr\u00e9via de 3 linhas. Fluxo: features_escola -> ",
      "classificar_desempenho -> dividir_dados -> treinar_floresta -> ",
      "importancia_floresta / metricas_floresta; ou pca_perfil."
    ),
    arguments = list(
      etapa = ellmer::type_array(
        ellmer::type_enum(eduBR_etapas_features(), "Etapa de ensino."),
        paste0(
          "Etapas inclu\u00eddas (padr\u00e3o [\"fundamental_i\", \"fundamental_ii\"]); ",
          "cada etapa \u00e9 um estrato da amostra."
        ),
        required = FALSE
      ),
      publica = ellmer::type_boolean(
        "S\u00f3 escolas p\u00fablicas (federal, estadual, municipal)? Padr\u00e3o true.",
        required = FALSE
      ),
      n_por_etapa = ellmer::type_integer(
        paste0(
          "Escolas por etapa na amostra. Padr\u00e3o e m\u00e1ximo: 15.000 dividido ",
          "pelo n\u00famero de etapas (ex.: 7.500 com duas etapas)."
        ),
        required = FALSE
      ),
      semente = ellmer::type_integer(
        "Semente da amostra (padr\u00e3o 2023); repita-a para reproduzir.",
        required = FALSE
      )
    ),
    titulo = "Features escolares (amostra)"
  )
}

# ---------------------------------------------------------------------------
# classificar_desempenho

eduBR_tool_classificar_desempenho <- function(sessao) {
  fun <- function(dados_id, nota = "nota_media", grupo = "etapa") {
    nota <- eduBR_validar_texto(nota %||% "nota_media", "nota")
    grupo <- eduBR_validar_texto(grupo %||% "etapa", "grupo")
    df <- eduBR_ml_dados(sessao, dados_id)
    if (!nota %in% names(df) || !is.numeric(df[[nota]])) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf(
          paste0(
            "`nota` deve ser uma coluna num\u00e9rica de %s; recebido: %s. ",
            "Colunas de desempenho presentes: %s."
          ),
          dados_id, eduBR_valor_texto(nota),
          paste(intersect(eduBR_colunas_desempenho(), names(df)),
                collapse = ", ") %|vazio|% "nenhuma"
        )
      )
    }
    if (!grupo %in% names(df) || identical(grupo, nota)) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf(
          paste0(
            "`grupo` deve ser uma coluna de %s diferente da nota (padr\u00e3o ",
            "\"etapa\"); recebido: %s."
          ),
          dados_id, eduBR_valor_texto(grupo)
        )
      )
    }

    out <- classificar_desempenho(df, nota = nota, grupo = grupo)
    lim <- limites_desempenho(out)
    if (!is.list(lim)) {
      lim <- stats::setNames(list(lim), as.character(df[[grupo]][1]))
    }
    sem_nota <- sum(is.na(out$nivel))
    out <- out[!is.na(out$nivel), , drop = FALSE]
    if (!nrow(out)) {
      eduBR_abortar(
        "sem_dados",
        sprintf("Nenhuma escola de %s tem `%s`; nada a classificar.",
                dados_id, nota)
      )
    }
    out <- eduBR_ml_atributos(out, nota = nota, limites = lim)

    id <- eduBR_handle_guardar(
      sessao, "dados", out,
      descricao = eduBR_handle_descrever(
        "classificar_desempenho",
        list(de = dados_id, nota = nota, grupo = grupo, n = nrow(out))
      )
    )

    contagem <- as.data.frame(
      table(grupo = as.character(out[[grupo]]), nivel = out$nivel),
      stringsAsFactors = FALSE
    )
    names(contagem) <- c(grupo, "nivel", "n")
    contagem <- contagem[order(contagem[[grupo]], match(contagem$nivel,
                                                        levels(out$nivel))), ]
    limites_df <- tibble::tibble(
      grupo = names(lim),
      corte_baixo_medio = vapply(lim, `[`, numeric(1), 1L, USE.NAMES = FALSE),
      corte_medio_alto = vapply(lim, `[`, numeric(1), 2L, USE.NAMES = FALSE)
    )
    aviso <- sprintf(
      paste0(
        "Base classificada em %s (coluna `nivel`: baixo < corte_baixo_medio ",
        "<= medio < corte_medio_alto <= alto, ter\u00e7os dentro de `%s`). ",
        "Pr\u00f3ximo passo: `dividir_dados(dados_id = \"%s\")`."
      ),
      id, grupo, id
    )
    if (sem_nota > 0L) {
      aviso <- paste(aviso, sprintf(
        "%d escola(s) sem `%s` (null) ficaram fora da base classificada.",
        sem_nota, nota
      ))
    }
    eduBR_resultado(
      tibble::as_tibble(contagem),
      grao = paste0(grupo, " \u00d7 nivel"),
      filtros = list(dados_id = dados_id, nota = nota, grupo = grupo),
      handle = id,
      aviso = aviso,
      n_padrao = 1000L,
      contexto = list(
        handle = id,
        nota = nota,
        grupo = grupo,
        n_classificadas = nrow(out),
        n_sem_nota = sem_nota,
        limites = eduBR_registros(limites_df)
      )
    )
  }
  eduBR_tool(
    sessao, "classificar_desempenho", fun,
    descricao = paste0(
      "Cria o alvo de classifica\u00e7\u00e3o `nivel` (baixo/medio/alto) a partir de ",
      "uma nota (padr\u00e3o `nota_media`, m\u00e9dia SAEB) por TER\u00c7OS dentro de cada ",
      "grupo (padr\u00e3o `etapa`: os cortes de fundamental I e II s\u00e3o ",
      "diferentes). Recebe um handle \"dados_<k>\" de `features_escola` e ",
      "guarda a base classificada num NOVO handle \"dados_<k>\". Escolas sem ",
      "nota saem da base (a resposta diz quantas). Devolve a contagem por ",
      "grupo \u00d7 n\u00edvel e, em `metadados.contexto.limites`, os dois cortes ",
      "de cada grupo. Cuidado: a nota usada define a classe e por isso \u00e9 ",
      "exclu\u00edda automaticamente dos preditores em `treinar_floresta`."
    ),
    arguments = list(
      dados_id = ellmer::type_string(
        "Handle \"dados_<k>\" devolvido por `features_escola`."
      ),
      nota = ellmer::type_string(
        "Coluna num\u00e9rica que define a classe (padr\u00e3o \"nota_media\").",
        required = FALSE
      ),
      grupo = ellmer::type_string(
        "Coluna dentro da qual os ter\u00e7os s\u00e3o calculados (padr\u00e3o \"etapa\").",
        required = FALSE
      )
    ),
    titulo = "Classificar desempenho"
  )
}

`%|vazio|%` <- function(x, y) if (!length(x) || !nzchar(x)) y else x

# ---------------------------------------------------------------------------
# dividir_dados

eduBR_tool_dividir_dados <- function(sessao) {
  fun <- function(dados_id, prop = 0.8, semente = 2023L) {
    prop <- prop %||% 0.8
    if (!is.numeric(prop) || length(prop) != 1L || is.na(prop) ||
        prop < 0.5 || prop > 0.9) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf(
          "`prop` inv\u00e1lida: %s. Use a fra\u00e7\u00e3o do treino entre 0.5 e 0.9 (padr\u00e3o 0.8).",
          eduBR_valor_texto(prop)
        )
      )
    }
    semente <- eduBR_validar_semente(semente)
    df <- eduBR_ml_dados(sessao, dados_id)
    if (!is.factor(df[["nivel", exact = TRUE]])) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf(
          paste0(
            "%s n\u00e3o tem o alvo `nivel`; rode `classificar_desempenho(dados_id ",
            "= \"%s\")` antes e use o handle que ela devolver."
          ),
          dados_id, dados_id
        )
      )
    }
    nota <- eduBR_ml_nota(df)
    partes <- eduBR_preservar_semente(
      dividir_dados(df, var = "nivel", prop = prop, semente = semente)
    )
    treino <- eduBR_ml_atributos(partes$treino, nota = nota)
    teste <- eduBR_ml_atributos(partes$teste, nota = nota)

    desc <- function(parte) {
      eduBR_handle_descrever(
        "dividir_dados",
        list(de = dados_id, parte = parte, prop = prop, semente = semente)
      )
    }
    treino_id <- eduBR_handle_guardar(
      sessao, "treino", list(dados = treino), descricao = desc("treino")
    )
    teste_id <- eduBR_handle_guardar(
      sessao, "teste", list(dados = teste), descricao = desc("teste")
    )
    assign(treino_id, list(dados = treino, origem = dados_id, par = teste_id),
           envir = sessao$handles$objetos)
    assign(teste_id, list(dados = teste, origem = dados_id, par = treino_id),
           envir = sessao$handles$objetos)

    dist <- function(d, parte) {
      tab <- table(d$nivel)
      tibble::tibble(
        parte = parte,
        nivel = names(tab),
        n = as.integer(tab),
        prop = as.numeric(tab) / sum(tab)
      )
    }
    eduBR_resultado(
      rbind(dist(treino, "treino"), dist(teste, "teste")),
      grao = "parte \u00d7 nivel",
      filtros = list(dados_id = dados_id, prop = prop, semente = semente),
      handle = treino_id,
      aviso = sprintf(
        paste0(
          "Treino em %s, teste em %s (estratificado por `nivel`). Treine com ",
          "`treinar_floresta(treino_id = \"%s\")` e avalie S\u00d3 no teste com ",
          "`metricas_floresta(teste_id = \"%s\")`."
        ),
        treino_id, teste_id, treino_id, teste_id
      ),
      contexto = list(
        treino_id = treino_id,
        teste_id = teste_id,
        n_treino = nrow(treino),
        n_teste = nrow(teste),
        prop = prop,
        semente = semente
      )
    )
  }
  eduBR_tool(
    sessao, "dividir_dados", fun,
    descricao = paste0(
      "Separa uma base classificada (handle \"dados_<k>\" de ",
      "`classificar_desempenho`, com a coluna `nivel`) em treino e teste, ",
      "estratificando por `nivel` para as duas partes terem a mesma ",
      "distribui\u00e7\u00e3o de classes. `prop` \u00e9 a fra\u00e7\u00e3o do treino (0.5 a 0.9, ",
      "padr\u00e3o 0.8); `semente` torna a divis\u00e3o reprodut\u00edvel. Guarda os handles ",
      "\"treino_<k>\" e \"teste_<k>\" (em `metadados.contexto`) e devolve o ",
      "tamanho e a distribui\u00e7\u00e3o de `nivel` em cada parte. O teste \u00e9 a ",
      "amostra fora do treino: use-o s\u00f3 para avaliar (holdout), nunca para ",
      "escolher features."
    ),
    arguments = list(
      dados_id = ellmer::type_string(
        "Handle \"dados_<k>\" devolvido por `classificar_desempenho`."
      ),
      prop = ellmer::type_number(
        "Fra\u00e7\u00e3o das escolas no treino, entre 0.5 e 0.9 (padr\u00e3o 0.8).",
        required = FALSE
      ),
      semente = ellmer::type_integer(
        "Semente da divis\u00e3o (padr\u00e3o 2023).", required = FALSE
      )
    ),
    titulo = "Dividir treino e teste"
  )
}

# ---------------------------------------------------------------------------
# treinar_floresta

# Colunas fora dos preditores e o motivo (data frame coluna/motivo).
eduBR_exclusoes_floresta <- function(colunas, nota) {
  vazamento <- unique(c(eduBR_colunas_desempenho(), nota))
  motivo <- ifelse(
    colunas == "nivel", "alvo",
    ifelse(colunas %in% vazamento, "desempenho (vazamento)",
           ifelse(colunas %in% eduBR_colunas_identificacao(),
                  "identifica\u00e7\u00e3o", NA_character_))
  )
  out <- data.frame(coluna = colunas, motivo = motivo, stringsAsFactors = FALSE)
  out[!is.na(out$motivo), , drop = FALSE]
}

eduBR_erro_tempo_floresta <- function(e, decorrido, limite) {
  msg <- conditionMessage(e)
  grepl("elapsed time limit", msg) ||
    (grepl("User interrupt", msg) && decorrido >= 0.9 * limite)
}

eduBR_mensagem_tempo_floresta <- function(sessao, trees, n) {
  sprintf(
    paste0(
      "O treino (%d \u00e1rvores, %d linhas) passou do tempo limite de %s s por ",
      "chamada e foi interrompido. Reduza `trees` (ex.: 100), passe menos ",
      "`features` ou use uma amostra menor (`features_escola(n_por_etapa = ",
      "3000)`); o limite da sess\u00e3o \u00e9 `limites$timeout_s`."
    ),
    as.integer(trees), as.integer(n), format(sessao$limites$timeout_s)
  )
}

eduBR_tool_treinar_floresta <- function(sessao) {
  fun <- function(treino_id, trees = 250L, min_node_size = 5L,
                  semente = 2023L, features = NULL) {
    trees <- eduBR_validar_inteiro(trees %||% 250L, "trees", 1L,
                                   eduBR_max_arvores())
    min_node_size <- eduBR_validar_inteiro(min_node_size %||% 5L,
                                           "min_node_size", 1L, 500L)
    semente <- eduBR_validar_semente(semente)
    features <- eduBR_validar_nomes(features, "features", obrigatorio = FALSE)
    tr <- eduBR_obter_handle_tipo(
      sessao, treino_id, "treino", "treino_id", "dividir_dados"
    )
    df <- tr$dados
    if (nrow(df) > sessao$limites$max_amostra) {
      eduBR_abortar(
        "limite_excedido",
        sprintf("O treino tem %d linhas, acima do limite de %d da sess\u00e3o.",
                nrow(df), sessao$limites$max_amostra)
      )
    }
    excluidas <- eduBR_exclusoes_floresta(names(df), eduBR_ml_nota(df))

    proibidas <- eduBR_exclusoes_floresta(features %||% character(0),
                                          eduBR_ml_nota(df))
    if (nrow(proibidas)) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf(
          paste0(
            "`features` n\u00e3o pode conter %s. A nota que define a classe e as ",
            "demais notas seriam vazamento (o modelo veria a resposta); ",
            "identificadores n\u00e3o s\u00e3o caracter\u00edsticas da escola."
          ),
          paste(sprintf("%s (%s)", proibidas$coluna, proibidas$motivo),
                collapse = ", ")
        )
      )
    }
    if (is.null(features)) {
      features <- setdiff(names(df), excluidas$coluna)
    } else {
      eduBR_validar_colunas_fonte(
        features, setdiff(names(df), excluidas$coluna), "`features`"
      )
    }
    vazias <- features[vapply(df[features], function(v) all(is.na(v)),
                              logical(1))]
    if (length(vazias)) {
      excluidas <- rbind(excluidas, data.frame(
        coluna = vazias, motivo = "sem dados", stringsAsFactors = FALSE
      ))
      features <- setdiff(features, vazias)
    }
    if (!length(features)) {
      eduBR_abortar("parametro_invalido", "Nenhuma feature utiliz\u00e1vel no treino.")
    }
    # Garantia final: nada de desempenho/alvo entre os preditores.
    stopifnot(!any(features %in% c("nivel", eduBR_colunas_desempenho(),
                                   eduBR_ml_nota(df))))
    eduBR_ranger_disponivel()

    t0 <- proc.time()[["elapsed"]]
    rf <- tryCatch(
      treinar_floresta(
        df, alvo = "nivel", features = features, semente = semente,
        trees = trees, min_node_size = min_node_size,
        num.threads = eduBR_threads_floresta(), verbose = FALSE
      ),
      error = function(e) {
        # O ranger troca o "reached elapsed time limit" do setTimeLimit()
        # por "User interrupt or internal error.".
        decorrido <- proc.time()[["elapsed"]] - t0
        if (eduBR_erro_tempo_floresta(e, decorrido, sessao$limites$timeout_s)) {
          eduBR_abortar(
            "limite_excedido",
            eduBR_mensagem_tempo_floresta(sessao, trees, nrow(df))
          )
        }
        stop(e)
      }
    )
    tempo <- round(proc.time()[["elapsed"]] - t0, 2)

    id <- eduBR_handle_guardar(
      sessao, "floresta",
      list(modelo = rf, treino_id = treino_id, teste_id = tr$par),
      descricao = eduBR_handle_descrever(
        "treinar_floresta",
        list(treino = treino_id, trees = trees, features = length(features),
             semente = semente)
      )
    )
    oob <- rf$modelo$prediction.error
    resumo <- tibble::tibble(
      n_arvores = trees,
      n_features = length(features),
      n_treino = nrow(df),
      min_node_size = min_node_size,
      erro_oob_brier = if (is.numeric(oob)) oob else NA_real_,
      tempo_s = tempo
    )
    vazou <- excluidas$coluna[excluidas$motivo == "desempenho (vazamento)"]
    eduBR_resultado(
      resumo,
      grao = "modelo",
      filtros = list(treino_id = treino_id, trees = trees, semente = semente),
      handle = id,
      aviso = paste0(
        sprintf("Floresta guardada em %s. ", id),
        if (length(vazou)) {
          sprintf(
            "Fora dos preditores por vazamento (definem ou medem o desempenho): %s. ",
            paste(vazou, collapse = ", ")
          )
        } else "",
        sprintf(
          "Avalie com `metricas_floresta(floresta_id = \"%s\", teste_id = \"%s\")`.",
          id, tr$par %||% "teste_<k>"
        )
      ),
      contexto = list(
        handle = id,
        features = I(features),
        excluidas = eduBR_registros(excluidas),
        num_threads = eduBR_threads_floresta()
      )
    )
  }
  eduBR_tool(
    sessao, "treinar_floresta", fun,
    descricao = paste0(
      "Treina uma Random Forest de classifica\u00e7\u00e3o com probabilidade (ranger, ",
      "2 threads) para o alvo `nivel` no handle \"treino_<k>\" de ",
      "`dividir_dados`, com import\u00e2ncia por permuta\u00e7\u00e3o. `trees` de 1 a 500 ",
      "(padr\u00e3o 250; 100 j\u00e1 basta para explorar), `min_node_size` (padr\u00e3o 5), ",
      "`semente` (padr\u00e3o 2023). `features` (opcional) restringe os ",
      "preditores (ex.: as mais importantes de uma floresta anterior, para ",
      "redu\u00e7\u00e3o de dimens\u00e3o); por padr\u00e3o usa todas as colunas, menos o alvo, ",
      "as notas SAEB (a nota que define a classe seria VAZAMENTO e \u00e9 ",
      "recusada em `features`) e os identificadores (`co_entidade`, ",
      "`etapa`, UF/munic\u00edpio). INSE (`media_inse`, `pc_nivel_*`) \u00e9 contexto ",
      "socioecon\u00f4mico e fica entre os preditores. Devolve n\u00ba de \u00e1rvores, n\u00ba ",
      "de features, tamanho do treino, erro OOB (Brier das probabilidades; ",
      "menor \u00e9 melhor) e o tempo; `metadados.contexto` lista as features ",
      "usadas e as exclu\u00eddas com o motivo. Guarda o handle \"floresta_<k>\". ",
      "Tempo: cresce com \u00e1rvores \u00d7 linhas (3.000 linhas com 100 \u00e1rvores ",
      "levam poucos segundos; 12.000 com 250 passam de 30 s); acima do tempo ",
      "limite por chamada a resposta \u00e9 `limite_excedido`: reduza `trees`, ",
      "`features` ou a amostra."
    ),
    arguments = list(
      treino_id = ellmer::type_string(
        "Handle \"treino_<k>\" devolvido por `dividir_dados`."
      ),
      trees = ellmer::type_integer(
        "N\u00famero de \u00e1rvores, de 1 a 500 (padr\u00e3o 250).", required = FALSE
      ),
      min_node_size = ellmer::type_integer(
        "Tamanho m\u00ednimo do n\u00f3 folha (padr\u00e3o 5).", required = FALSE
      ),
      semente = ellmer::type_integer(
        "Semente do ranger (padr\u00e3o 2023).", required = FALSE
      ),
      features = ellmer::type_array(
        ellmer::type_string("Nome exato de uma coluna do treino."),
        "Preditores a usar; omita para todos os permitidos.",
        required = FALSE
      )
    ),
    titulo = "Treinar floresta aleat\u00f3ria"
  )
}

# ---------------------------------------------------------------------------
# importancia_floresta

eduBR_tool_importancia_floresta <- function(sessao) {
  fun <- function(floresta_id, n = 15L) {
    eduBR_validar_n(n)
    fl <- eduBR_obter_handle_tipo(
      sessao, floresta_id, "floresta", "floresta_id", "treinar_floresta"
    )
    imp <- importancia_floresta(fl$modelo)
    imp <- tibble::tibble(
      posicao = seq_len(nrow(imp)), variavel = imp$var,
      importancia = imp$importancia
    )
    eduBR_resultado(
      imp,
      grao = "feature (import\u00e2ncia por permuta\u00e7\u00e3o)",
      filtros = list(floresta_id = floresta_id),
      n_padrao = 15L,
      contexto = list(floresta_id = floresta_id, n_features = nrow(imp))
    )
  }
  eduBR_tool(
    sessao, "importancia_floresta", fun,
    descricao = paste0(
      "Ranking das features de uma floresta (`floresta_id`) pela ",
      "import\u00e2ncia por permuta\u00e7\u00e3o: quanto a qualidade da previs\u00e3o cai ",
      "quando a coluna \u00e9 embaralhada (maior = mais informativa; valores ",
      "perto de zero ou negativos = irrelevante). Devolve as `n` primeiras ",
      "(padr\u00e3o 15). Use para redu\u00e7\u00e3o de dimens\u00e3o: treine de novo com ",
      "`features` = as mais importantes e compare as m\u00e9tricas. Cuidados: ",
      "import\u00e2ncia n\u00e3o \u00e9 efeito causal nem tem sinal; features ",
      "correlacionadas dividem a import\u00e2ncia entre si."
    ),
    arguments = list(
      floresta_id = ellmer::type_string(
        "Handle \"floresta_<k>\" devolvido por `treinar_floresta`."
      ),
      n = ellmer::type_integer(
        "Quantas features devolver (padr\u00e3o 15).", required = FALSE
      )
    ),
    titulo = "Import\u00e2ncia das features"
  )
}

# ---------------------------------------------------------------------------
# metricas_floresta

# Chave escola × etapa (para checar sobreposição treino/teste).
eduBR_chave_linhas <- function(df) {
  cols <- intersect(c("co_entidade", "etapa"), names(df))
  if (!length(cols)) {
    return(NULL)
  }
  do.call(paste, c(unname(as.list(df[cols])), sep = "|"))
}

eduBR_tool_metricas_floresta <- function(sessao) {
  fun <- function(floresta_id, teste_id) {
    fl <- eduBR_obter_handle_tipo(
      sessao, floresta_id, "floresta", "floresta_id", "treinar_floresta"
    )
    te <- eduBR_obter_handle_tipo(
      sessao, teste_id, "teste", "teste_id", "dividir_dados"
    )
    teste <- te$dados
    treino <- tryCatch(
      eduBR_handle_obter(sessao, fl$treino_id)$dados,
      error = function(e) NULL
    )
    if (!is.null(treino)) {
      comuns <- intersect(eduBR_chave_linhas(treino), eduBR_chave_linhas(teste))
      if (length(comuns)) {
        eduBR_abortar(
          "parametro_invalido",
          sprintf(
            paste0(
              "%s tem %d escola(s) usadas no treino de %s (vazamento). Use o ",
              "teste da mesma divis\u00e3o: %s."
            ),
            teste_id, length(comuns), floresta_id,
            fl$teste_id %||% "o teste_<k> de dividir_dados"
          )
        )
      }
    }

    m <- metricas_floresta(fl$modelo, teste)
    conf <- as.data.frame(attr(m, "confusao"), stringsAsFactors = FALSE)
    names(conf) <- c("real", "predito", "n")
    conf$real <- as.character(conf$real)
    conf$predito <- as.character(conf$predito)
    conf$n <- as.integer(conf$n)

    resumo <- tibble::tibble(
      acuracia = m$acuracia,
      baseline_acerto = m$baseline_acerto,
      ganho_sobre_baseline = m$acuracia - m$baseline_acerto,
      f1_macro = m$f1_macro,
      auc_macro = m$auc_macro,
      n_teste = nrow(teste)
    )
    aviso <- NULL
    if (!identical(fl$teste_id, teste_id)) {
      aviso <- sprintf(
        "%s n\u00e3o \u00e9 o teste da divis\u00e3o usada no treino (%s); sem sobreposi\u00e7\u00e3o de escolas, mas confira a origem.",
        teste_id, fl$teste_id %||% "?"
      )
    }
    if (m$acuracia <= m$baseline_acerto) {
      aviso <- c(aviso, paste0(
        "A acur\u00e1cia n\u00e3o supera o baseline (sempre a classe dominante): ",
        "o modelo n\u00e3o aprendeu nada \u00fatil."
      ))
    }
    auc_classe <- attr(m, "auc_classe")
    eduBR_resultado(
      resumo,
      grao = "modelo avaliado no teste",
      filtros = list(floresta_id = floresta_id, teste_id = teste_id),
      aviso = if (length(aviso)) paste(aviso, collapse = " ") else NULL,
      contexto = list(
        floresta_id = floresta_id,
        teste_id = teste_id,
        confusao = eduBR_registros(conf),
        f1_classe = as.list(attr(m, "f1_classe")),
        auc_classe = if (is.null(auc_classe)) NULL else as.list(auc_classe)
      )
    )
  }
  eduBR_tool(
    sessao, "metricas_floresta", fun,
    descricao = paste0(
      "Avalia uma floresta (`floresta_id`) no teste (`teste_id`, o ",
      "\"teste_<k>\" da MESMA divis\u00e3o; um teste com escolas do treino \u00e9 ",
      "recusado por vazamento). Devolve `acuracia`, `baseline_acerto` ",
      "(acerto de prever sempre a classe dominante), `ganho_sobre_baseline`, ",
      "`f1_macro` (m\u00e9dia do F1 das 3 classes), `auc_macro` (m\u00e9dia ",
      "one-vs-rest; 0,5 = acaso) e `n_teste`; em `metadados.contexto`, a ",
      "matriz de confus\u00e3o em formato longo (`real`, `predito`, `n`) e F1/AUC ",
      "por classe. Compare SEMPRE com o baseline: com ter\u00e7os, ele fica perto ",
      "de 0,33; acur\u00e1cia s\u00f3 tem valor acima dele. Erros entre baixo e alto ",
      "s\u00e3o mais graves que entre classes vizinhas."
    ),
    arguments = list(
      floresta_id = ellmer::type_string(
        "Handle \"floresta_<k>\" devolvido por `treinar_floresta`."
      ),
      teste_id = ellmer::type_string(
        "Handle \"teste_<k>\" devolvido por `dividir_dados`."
      )
    ),
    titulo = "M\u00e9tricas da floresta"
  )
}

# ---------------------------------------------------------------------------
# pca_perfil

eduBR_tool_pca_perfil <- function(sessao) {
  fun <- function(dados_id, redundantes = "remover", n_componentes = 5L,
                  n_pesos = 8L) {
    redundantes <- eduBR_validar_enum(
      redundantes %||% "remover", "redundantes", c("remover", "manter")
    )
    n_componentes <- eduBR_validar_inteiro(n_componentes %||% 5L,
                                           "n_componentes", 1L, 30L)
    n_pesos <- eduBR_validar_inteiro(n_pesos %||% 8L, "n_pesos", 1L, 30L)
    df <- eduBR_ml_dados(sessao, dados_id)
    if (!"co_entidade" %in% names(df)) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf("%s n\u00e3o tem `co_entidade`; use uma base de `features_escola`.",
                dados_id)
      )
    }
    id_col <- "co_entidade"
    if (anyDuplicated(df$co_entidade) && "etapa" %in% names(df)) {
      df$.id_pca <- paste(df$co_entidade, df$etapa, sep = "|")
      id_col <- ".id_pca"
    }

    avisos <- character(0)
    pca <- withCallingHandlers(
      pca_perfil(df, id = id_col, redundantes = redundantes),
      warning = function(w) {
        avisos <<- c(avisos, conditionMessage(w))
        invokeRestart("muffleWarning")
      },
      message = function(m) {
        avisos <<- c(avisos, trimws(conditionMessage(m)))
        invokeRestart("muffleMessage")
      }
    )
    n_inc <- attr(pca, "n_incompletas")
    if (isTRUE(n_inc > 0)) {
      avisos <- c(avisos, sprintf(
        "%d linha(s) com dados incompletos ficaram fora da PCA.", n_inc
      ))
    }

    var <- utils::head(pca$variancia, n_componentes)
    pesos <- pca$loadings[pca$loadings$pc %in% var$pc, , drop = FALSE]
    pesos <- pesos[order(match(pesos$pc, var$pc), -abs(pesos$peso)), ]
    pesos <- do.call(rbind, lapply(split(pesos, pesos$pc), utils::head,
                                   n_pesos))
    pesos <- pesos[order(match(pesos$pc, var$pc), -abs(pesos$peso)), ]
    var$principais <- vapply(var$pc, function(p) {
      s <- pesos[pesos$pc == p, , drop = FALSE]
      paste(sprintf("%s (%+.2f)", s$variavel, s$peso), collapse = "; ")
    }, character(1))

    eduBR_resultado(
      var,
      grao = "componente principal",
      filtros = list(dados_id = dados_id, redundantes = redundantes),
      aviso = if (length(avisos)) paste(avisos, collapse = " ") else NULL,
      n_padrao = 30L,
      contexto = list(
        dados_id = dados_id,
        n_escolas = nrow(pca$scores),
        n_variaveis = nrow(pca$fit$rotation),
        n_componentes_total = nrow(pca$variancia),
        removidas = I(as.character(attr(pca, "removidas"))),
        pesos = eduBR_registros(tibble::as_tibble(pesos))
      )
    )
  }
  eduBR_tool(
    sessao, "pca_perfil", fun,
    descricao = paste0(
      "PCA (centrada e escalada) do perfil escolar sobre as colunas ",
      "num\u00e9ricas de um handle \"dados_<k>\" de `features_escola` (ou da base ",
      "classificada). Ficam fora: identificadores, c\u00f3digos `tp_*`, nota e ",
      "INSE (desempenho/contexto), o alvo `nivel`, colunas constantes ou sem ",
      "dados e, com `redundantes = \"remover\"` (padr\u00e3o), colunas que s\u00e3o ",
      "combina\u00e7\u00e3o linear exata de outras (ex.: os `*_score`, somas dos ",
      "`in_*`); as removidas aparecem em `metadados.aviso`. Devolve, para os ",
      "`n_componentes` primeiros (padr\u00e3o 5), a vari\u00e2ncia explicada (`prop`, ",
      "`acumulada`) e em `principais` os maiores pesos (em m\u00f3dulo, com sinal); ",
      "a lista longa de pesos (`pc`, `variavel`, `peso`, at\u00e9 `n_pesos` por ",
      "componente, padr\u00e3o 8) vai em `metadados.contexto.pesos`. Leitura: o ",
      "sinal de cada componente \u00e9 fixado (maior peso positivo); componentes ",
      "descrevem perfis, n\u00e3o desempenho."
    ),
    arguments = list(
      dados_id = ellmer::type_string(
        "Handle \"dados_<k>\" de `features_escola` ou `classificar_desempenho`."
      ),
      redundantes = ellmer::type_enum(
        c("remover", "manter"),
        "Colunas redundantes (combina\u00e7\u00e3o linear de outras): \"remover\" (padr\u00e3o) ou \"manter\".",
        required = FALSE
      ),
      n_componentes = ellmer::type_integer(
        "Componentes devolvidos (padr\u00e3o 5).", required = FALSE
      ),
      n_pesos = ellmer::type_integer(
        "Maiores pesos por componente (padr\u00e3o 8).", required = FALSE
      )
    ),
    titulo = "PCA do perfil escolar"
  )
}
