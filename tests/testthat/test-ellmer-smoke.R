# Smoke da camada ellmer contra o banco real [edumaps] (tools de escola).
# Rode com EDUBR_SMOKE=1. Lento (perfil e similares levam ~10 s cada):
# mantenha o número de chamadas pequeno.

skip_if(
  Sys.getenv("EDUBR_SMOKE", "") == "",
  "Defina EDUBR_SMOKE=1 para rodar o smoke test"
)
skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")

# Confere envelope: JSON válido, dentro do cap, sem PII e sem schema.tabela.
smoke_checar <- function(json, cap = 1000L) {
  expect_type(json, "character")
  expect_true(jsonlite::validate(json))
  env <- eduBR_envelope_de(json)
  expect_lte(length(env$dados), cap)
  for (reg in env$dados) {
    expect_false(any(names(reg) %in% c(eduBR_colunas_pii(), "geometry", "geom")))
  }
  rel <- eduBR_relacoes_fisicas()
  for (i in seq_len(nrow(rel))) {
    expect_false(grepl(paste0(rel$schema[i], ".", rel$tabela[i]), json,
                       fixed = TRUE))
  }
  expect_false(grepl("clean.", json, fixed = TRUE))
  expect_false(grepl("analytics.", json, fixed = TRUE))
  env
}

test_that("tools de escola respondem no banco real (13078070, 26106582)", {
  con <- conecta(service = "edumaps")
  withr::defer(DBI::dbDisconnect(con))
  tools <- ferramentas_edubr(con, limites = list(timeout_s = 120))
  id <- "13078070"

  env <- smoke_checar(tools$perfil_escola(escola_id = id))
  expect_null(env$erro)
  expect_gt(length(env$dados), 0L)
  ctx <- env$metadados$contexto
  expect_equal(ctx$codigo_inep, id)
  expect_equal(ctx$uf, "AM")
  expect_false(is.null(ctx$nome))

  env <- smoke_checar(tools$resumo_escola(escola_id = id))
  expect_null(env$erro)
  expect_length(env$dados, 1L)

  env <- smoke_checar(tools$serie_ideb_escola(escola_id = id))
  expect_null(env$erro)
  expect_gt(length(env$dados), 0L)

  env <- smoke_checar(tools$escolas_similares(escola_id = id, n = 3L))
  expect_null(env$erro)
  expect_length(env$dados, 3L)
  nomes <- vapply(env$dados, function(r) r$escola %||% NA_character_,
                  character(1))
  expect_false(anyNA(nomes))
  expect_false(id %in% vapply(env$dados, `[[`, character(1), "co_entidade"))

  env <- smoke_checar(tools$scores_escola(escola_id = id))
  expect_null(env$erro)

  env <- smoke_checar(tools$indicadores_escola(escola_id = id))
  expect_equal(env$erro$tipo, "sem_dados")

  # Abreu e Lima/PE: IDEB de ensino médio, mas não oferta médio no Censo 2025
  env <- smoke_checar(tools$perfil_escola(escola_id = "26106582"))
  expect_null(env$erro)
  itens <- vapply(env$dados, `[[`, character(1), "item")
  medio <- env$dados[grepl("^IDEB m", itens)]
  expect_length(medio, 1L)
  expect_false(medio[[1]]$ofertada)

  led <- ledger(tools)
  expect_equal(nrow(led), 7L)
  message(paste(sprintf("%s: %.1f s", led$tool, led$duracao_ms / 1000),
                collapse = "; "))
})

test_that("tools da pesquisadora respondem no banco real (recorte AC)", {
  con <- conecta(service = "edumaps")
  withr::defer(DBI::dbDisconnect(con))
  tools <- ferramentas_edubr(con, limites = list(timeout_s = 120))
  sessao <- attr(tools, "sessao")

  env <- smoke_checar(tools$municipios(uf = "AC"))
  expect_null(env$erro)
  expect_length(env$dados, 22L)
  expect_type(env$dados[[1]]$codigo_ibge, "character")

  env <- smoke_checar(tools$redes_municipio(uf = "AC", rede = "Municipal",
                                            n = 5L))
  expect_null(env$erro)
  expect_length(env$dados, 5L)
  expect_true(all(vapply(env$dados, `[[`, character(1), "rede") == "Municipal"))
  expect_type(env$dados[[1]]$total_matriculas, "character")
  message("redes_municipio[1]: ", jsonlite::toJSON(
    env$dados[[1]][c("no_municipio", "rede", "total_escolas",
                     "total_matriculas", "total_docentes", "ideb_fund_i",
                     "ideb_fund_ii", "ideb_medio", "ano_ideb")],
    auto_unbox = TRUE, null = "null"
  ))

  env <- smoke_checar(tools$docentes_rede(
    nivel = "uf", uf = "AC",
    colunas = c("qt_doc_bas_esco_sup_grad", "qt_doc_bas_vinculo_concur")
  ))
  expect_null(env$erro)
  expect_gt(length(env$dados), 0L)
  expect_true(all(c("qt_doc_bas", "qt_doc_bas_vinculo_concur") %in%
                    names(env$dados[[1]])))

  env <- smoke_checar(tools$ideb(uf = "AC", ano = 2023L,
                                 etapa = "fundamental_i", n = 20L))
  expect_null(env$erro)
  expect_length(env$dados, 20L)
  expect_type(env$dados[[1]]$id_escola, "character")

  env <- smoke_checar(tools$tendencia_ideb_regiao(etapa = "fundamental_i",
                                                  rede = "Municipal"))
  expect_null(env$erro)
  expect_length(env$dados, 10L)

  env <- smoke_checar(tools$covariaveis_escola(uf = "AC", rede = "Municipal",
                                               n = 3L))
  expect_null(env$erro)
  expect_length(env$dados, 3L)
  h <- env$metadados$handle
  expect_match(h, "^dados_[0-9]+$")
  obj <- eduBR_handle_obter(sessao, h)
  expect_s3_class(obj, "eduBR")
  expect_true(eduBR_lazy(consulta(obj)))
  expect_gt(nrow(coletar(obj, n = 1000L)), 3L)
  message("covariaveis_escola: handle ", h, "; colunas ",
          paste(unlist(env$metadados$contexto$colunas), collapse = ","))

  env <- smoke_checar(tools$perfil_gestor(corte = "rede", uf = "AC"))
  expect_null(env$erro)
  expect_gt(length(env$dados), 0L)
  expect_gt(length(env$metadados$contexto$n_por_corte), 0L)
  message("perfil_gestor[1]: ",
          jsonlite::toJSON(env$dados[[1]], auto_unbox = TRUE))

  # Nacional, sem filtro: perfil_gestor coleta ~190 mil linhas.
  env <- smoke_checar(tools$perfil_gestor(corte = "regiao"))
  expect_null(env$erro)
  expect_length(env$metadados$contexto$n_por_corte, 5L)

  led <- ledger(tools)
  expect_equal(nrow(led), 8L)
  expect_true(all(is.na(led$erro)))
  message(paste(sprintf("%s: %.1f s", led$tool, led$duracao_ms / 1000),
                collapse = "; "))
})

test_that("regressão declarativa no banco real (aceite da pesquisadora)", {
  skip_if_not_installed("parsnip")
  con <- conecta(service = "edumaps")
  withr::defer(DBI::dbDisconnect(con))
  tools <- ferramentas_edubr(con, limites = list(timeout_s = 120))

  # (a) covariaveis_escola -> especificar -> executar -> coeficientes/metricas
  env <- smoke_checar(tools$covariaveis_escola(uf = "AC", rede = "Municipal",
                                               n = 2L))
  expect_null(env$erro)
  dados_id <- env$metadados$handle
  env <- smoke_checar(tools$especificar_regressao(
    outcome = "ideb_fund_i", predictors = c("in_biblioteca", "docentes"),
    cuts = "localizacao", dados_id = dados_id
  ))
  expect_null(env$erro)
  espec_id <- env$metadados$handle
  expect_match(espec_id, "^espec_[0-9]+$")
  env <- smoke_checar(tools$executar_regressao(espec_id = espec_id))
  expect_null(env$erro)
  reg_id <- env$metadados$handle
  expect_match(reg_id, "^regressao_[0-9]+$")
  expect_gt(length(env$dados), 0L)
  message("executar_regressao (a): ", jsonlite::toJSON(
    list(dados = env$dados, contexto = env$metadados$contexto,
         aviso = env$metadados$aviso),
    auto_unbox = TRUE, null = "null"
  ))
  env <- smoke_checar(tools$coeficientes(regressao_id = reg_id))
  expect_null(env$erro)
  expect_true(all(c("termo", "estimativa", "erro_padrao", "p_valor") %in%
                    names(env$dados[[1]])))
  message("coeficientes (a): ", jsonlite::toJSON(env$dados, auto_unbox = TRUE,
                                                 null = "null", digits = 4))
  env <- smoke_checar(tools$metricas(regressao_id = reg_id))
  expect_null(env$erro)
  expect_true("r2" %in% names(env$dados[[1]]))
  message("metricas (a): ", jsonlite::toJSON(
    lapply(env$dados, `[`, c("localizacao", "r2", "r2_ajustado", "nobs")),
    auto_unbox = TRUE, null = "null", digits = 4
  ))

  # (b) fonte do catálogo com filtro (ano 2023, AC)
  env <- smoke_checar(tools$especificar_regressao(
    outcome = "ideb_observado", predictors = "nota_media", cuts = "etapa",
    fonte = "ideb",
    filtro = data.frame(coluna = c("ano", "sg_uf"), valor = c("2023", "AC"))
  ))
  expect_null(env$erro)
  env <- smoke_checar(tools$executar_regressao(
    espec_id = env$metadados$handle
  ))
  expect_null(env$erro)
  expect_gt(length(env$dados), 0L)
  message("executar_regressao (b): ", jsonlite::toJSON(
    list(dados = env$dados, n_recorte = env$metadados$contexto$n_recorte),
    auto_unbox = TRUE, null = "null"
  ))
  env <- smoke_checar(tools$metricas(regressao_id = env$metadados$handle))
  expect_null(env$erro)

  # (c) recorte grande (Brasil, 2023): limite_excedido sem coletar
  chamou <- FALSE
  local_mocked_bindings(executar_regressao = function(...) {
    chamou <<- TRUE
    stop("não deveria executar")
  })
  env <- smoke_checar(tools$especificar_regressao(
    outcome = "ideb_observado", predictors = "nota_media", cuts = "etapa",
    fonte = "ideb", filtro = list(list(coluna = "ano", valor = "2023"))
  ))
  expect_null(env$erro)
  env <- smoke_checar(tools$executar_regressao(
    espec_id = env$metadados$handle
  ))
  expect_equal(env$erro$tipo, "limite_excedido")
  expect_false(chamou)
  message("executar_regressao (c): ", env$erro$mensagem)

  env <- smoke_checar(tools$listar_handles())
  expect_null(env$erro)
  message("listar_handles: ", jsonlite::toJSON(env$dados, auto_unbox = TRUE))

  led <- ledger(tools)
  expect_equal(sum(!is.na(led$erro)), 1L)
  message(paste(sprintf("%s: %.1f s", led$tool, led$duracao_ms / 1000),
                collapse = "; "))
})

# Pico de memória residente do processo R (inclui o C++ do ranger), em MB.
smoke_pico_mb <- function() {
  st <- tryCatch(readLines("/proc/self/status"), error = function(e) character(0))
  linha <- grep("^VmHWM:", st, value = TRUE)
  if (!length(linha)) {
    return(NA_real_)
  }
  as.numeric(gsub("[^0-9]", "", linha)) / 1024
}

test_that("tools de ML: aceite da especialista-ml no banco real", {
  skip_if_not_installed("ranger")
  con <- conecta(service = "edumaps")
  withr::defer(DBI::dbDisconnect(con))
  tools <- ferramentas_edubr(con, persona = "especialista-ml",
                             limites = list(timeout_s = 300))
  sessao <- attr(tools, "sessao")
  t0 <- proc.time()[["elapsed"]]
  mem0 <- smoke_pico_mb()

  env <- smoke_checar(tools$features_escola(etapa = "fundamental_ii",
                                            n_por_etapa = 3000L))
  expect_null(env$erro)
  d1 <- env$metadados$handle
  df1 <- eduBR_handle_obter(sessao, d1)
  expect_lte(nrow(df1), 3000L)
  expect_lte(nrow(df1), sessao$limites$max_amostra)
  expect_equal(unique(df1$etapa), "fundamental_ii")
  expect_false(anyDuplicated(df1$co_entidade) > 0L)
  message("features_escola: ", jsonlite::toJSON(
    list(dados = env$dados, n_colunas = env$metadados$contexto$n_colunas,
         desempenho = env$metadados$contexto$colunas_desempenho),
    auto_unbox = TRUE, null = "null"
  ))

  # reprodutível: mesma semente, mesmas escolas; outra semente, outra amostra
  env <- smoke_checar(tools$features_escola(etapa = "fundamental_ii",
                                            n_por_etapa = 3000L))
  df2 <- eduBR_handle_obter(sessao, env$metadados$handle)
  expect_identical(df1$co_entidade, df2$co_entidade)
  env <- smoke_checar(tools$features_escola(etapa = "fundamental_ii",
                                            n_por_etapa = 3000L, semente = 7L))
  df3 <- eduBR_handle_obter(sessao, env$metadados$handle)
  expect_gt(length(setdiff(df3$co_entidade, df1$co_entidade)), 0L)
  message(sprintf(
    "reprodutibilidade: semente 2023 x2 identicas = %s; semente 7 troca %d de %d",
    identical(df1$co_entidade, df2$co_entidade),
    length(setdiff(df3$co_entidade, df1$co_entidade)), nrow(df3)
  ))

  env <- smoke_checar(tools$classificar_desempenho(dados_id = d1))
  expect_null(env$erro)
  cl <- env$metadados$handle
  message("classificar_desempenho: ", jsonlite::toJSON(
    list(dados = env$dados, limites = env$metadados$contexto$limites,
         aviso = env$metadados$aviso),
    auto_unbox = TRUE, null = "null", digits = 4
  ))

  env <- smoke_checar(tools$dividir_dados(dados_id = cl))
  expect_null(env$erro)
  dv <- env$metadados$contexto

  env <- smoke_checar(tools$treinar_floresta(treino_id = dv$treino_id,
                                             trees = 100L))
  expect_null(env$erro)
  fl <- env$metadados$handle
  feats <- unlist(env$metadados$contexto$features)
  expect_false("nota_media" %in% feats)
  message("treinar_floresta: ", jsonlite::toJSON(
    list(dados = env$dados, aviso = env$metadados$aviso),
    auto_unbox = TRUE, null = "null", digits = 4
  ))

  env <- smoke_checar(tools$importancia_floresta(floresta_id = fl, n = 5L))
  expect_null(env$erro)
  expect_length(env$dados, 5L)
  message("importancia_floresta (top 5): ", jsonlite::toJSON(
    env$dados, auto_unbox = TRUE, null = "null", digits = 4
  ))

  env <- smoke_checar(tools$metricas_floresta(floresta_id = fl,
                                              teste_id = dv$teste_id))
  expect_null(env$erro)
  m <- env$dados[[1]]
  expect_gt(m$acuracia, m$baseline_acerto)
  message("metricas_floresta: ", jsonlite::toJSON(
    list(dados = env$dados, confusao = env$metadados$contexto$confusao),
    auto_unbox = TRUE, null = "null", digits = 4
  ))

  env <- smoke_checar(tools$pca_perfil(dados_id = d1))
  expect_null(env$erro)
  expect_gt(length(env$dados), 0L)
  message("pca_perfil: ", jsonlite::toJSON(
    list(dados = env$dados, aviso = env$metadados$aviso,
         n_escolas = env$metadados$contexto$n_escolas),
    auto_unbox = TRUE, null = "null", digits = 3
  ))

  led <- ledger(tools)
  expect_true(all(is.na(led$erro)))
  message(paste(sprintf("%s: %.1f s", led$tool, led$duracao_ms / 1000),
                collapse = "; "))
  message(sprintf(
    "ML smoke: %.1f s no total; pico de memória residente do R %.0f MB (início %.0f MB)",
    proc.time()[["elapsed"]] - t0, smoke_pico_mb(), mem0
  ))
})
