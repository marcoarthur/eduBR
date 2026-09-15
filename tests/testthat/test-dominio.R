# Fixtures em memoria: mocka a resolucao do catalogo para evitar banco.
fake_eduBR_tbl <- function(con, nome) {
  switch(
    nome,
    escolas = tibble::tibble(
      codigo_inep = c("1", "2", "3"),
      escola      = c("A", "B", "C"),
      municipio   = c("Ubatuba", "Ubatuba", "Campinas"),
      uf          = c("SP", "SP", "RJ")
    ),
    municipios = tibble::tibble(
      codigo_ibge  = c("3555406", "3509502"),
      sigla_estado = c("SP", "SP"),
      nome         = c("Ubatuba", "Campinas")
    ),
    indicadores = tibble::tibble(
      id_escola    = c("1", "2"),
      indicador_id = c("infraestrutura", "infraestrutura"),
      valor        = c(0.8, 0.4)
    ),
    scores = tibble::tibble(
      co_entidade = c("1", "2"),
      score_infraestrutura = c(0.7, 0.3)
    ),
    clusters = tibble::tibble(
      run_id     = c("r1", "r1", "r2"),
      cluster_id = c(1L, 2L, 1L)
    ),
    stop(sprintf("fixture inesperada: %s", nome))
  )
}

test_that("escolas() devolve eduBR_escola e filtra", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  x <- escolas("fake_con", uf = "SP")

  expect_s3_class(x, "eduBR_escola")
  expect_s3_class(x, "eduBR")
  expect_equal(nrow(as_tibble(x)), 2L)

  y <- escolas("fake_con", municipio = "Campinas")
  expect_equal(nrow(as_tibble(y)), 1L)
  expect_equal(as_tibble(y)$escola, "C")
})

test_that("escola() filtra por codigo INEP", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  x <- escola("fake_con", "2")

  expect_s3_class(x, "eduBR_escola")
  expect_equal(x$meta$codigo_inep, "2")
  expect_equal(as_tibble(x)$escola, "B")
})

test_that("municipios() filtra por UF", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  x <- municipios("fake_con", uf = "SP")
  expect_s3_class(x, "eduBR_municipio")
  expect_equal(nrow(as_tibble(x)), 2L)
})

test_that("indicadores() e scores() aplicam filtro por escola", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  i <- indicadores("fake_con", escola_id = "1", indicador = "infraestrutura")
  expect_s3_class(i, "eduBR_indicador")
  expect_equal(nrow(as_tibble(i)), 1L)

  s <- scores("fake_con", escola_id = "2")
  expect_s3_class(s, "eduBR_score")
  expect_equal(as_tibble(s)$co_entidade, "2")
})

test_that("clusters() filtra por run_id", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  x <- clusters("fake_con", run_id = "r1")
  expect_s3_class(x, "eduBR_cluster")
  expect_equal(nrow(as_tibble(x)), 2L)
})

test_that("acessores genericos funcionam", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  x <- escolas("fake_con")

  expect_equal(conexao(x), "fake_con")
  expect_s3_class(consulta(x), "tbl_df")
  expect_output(print(x), "eduBR_escola")
  expect_equal(summary(x)$linhas, 3L)
  expect_equal(summary(x)$colunas, 4L)
})
