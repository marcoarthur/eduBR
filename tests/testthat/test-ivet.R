test_that("catálogo registra os componentes territoriais", {
  cat <- catalogo()
  linha <- cat[cat$dominio == "ivet_entorno", , drop = FALSE]
  expect_equal(nrow(linha), 1L)
  expect_equal(linha$granularidade, "escola × ano escolar × raio")
  expect_equal(linha$coluna_ano, "nu_ano_censo")
})

test_that("raios IVET são limitados aos valores suportados", {
  expect_equal(eduBR_validar_raio_ivet(1000), 1000L)
  expect_error(eduBR_validar_raio_ivet(750), "500, 1000 ou 2000")
  expect_error(ivet_socioeconomico("fake", "123", raio_m = 750),
               "código INEP")
  expect_error(ivet_socioeconomico("fake", "13078070", raio_m = 750),
               "500, 1000 ou 2000")
})

test_that("base IVET de regressão declara raio único e colunas por escola", {
  expect_type(eduBR_ivet_componentes(), "character")
  expect_true(all(c("pct_analfabeto", "renda_resp_media",
                    "pct_agua_sem_rede", "pct_esgoto_inadequado",
                    "pct_lixo_inadequado", "pct_sem_banheiro") %in%
                    eduBR_ivet_componentes()))
})

test_that("IVET consultado no banco preserva proveniência e ausências", {
  skip_if(Sys.getenv("EDUBR_SMOKE", "") == "",
          "Defina EDUBR_SMOKE=1 para rodar o smoke test")
  con <- conecta(service = "edumaps_container")
  withr::defer(DBI::dbDisconnect(con))

  escola <- coletar(ivet_socioeconomico(con, "13078070", raio_m = 1000L), n = 1L)
  expect_equal(nrow(escola), 1L)
  expect_equal(escola$raio_m, 1000L)
  expect_equal(escola$nu_ano_censo, 2025L)
  expect_equal(escola$versao, "ivet-v1.1")
  expect_true(is.na(escola$renda_resp_media))

  contexto <- coletar(ivet_contexto_socioeconomico(
    con, co_municipio = "3555406", rede = "Municipal", raio_m = 1000L
  ), n = 1L)
  expect_equal(nrow(contexto), 1L)
  expect_gt(contexto$n_escolas, 0L)
  expect_true(contexto$n_pct_analfabeto <= contexto$n_escolas)

  base <- covariaveis_ivet_escola(con, uf = "RR", rede = "Municipal",
                                  raio_m = 1000L)
  ids <- dplyr::collect(dplyr::select(consulta(base), "co_entidade"))
  expect_equal(anyDuplicated(ids$co_entidade), 0L)

  sessao <- eduBR_sessao_nova(con, eduBR_limites_normalizar(list()))
  regressao <- eduBR_tool_funcao(sessao, eduBR_tool_regressao_ivet)(
    outcome = "ideb_fund_i", predictors = "pct_analfabeto",
    co_municipio = "3555406", rede = "Municipal", raio_m = 1000L
  )
  expect_s3_class(regressao, "eduBR_resultado_tool")
  expect_true(is.data.frame(regressao$dados))
  expect_true(regressao$contexto$n_usado > 2L)

  expect_error(
    eduBR_tool_funcao(sessao, eduBR_tool_regressao_ivet)(
      outcome = "ideb_fund_i", predictors = "renda_resp_media",
      co_municipio = "3555406", rede = "Municipal", raio_m = 1000L
    ),
    "casos completos"
  )
})
