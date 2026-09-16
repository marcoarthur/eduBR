# Fixture: duas UFs com retas exatas de inclinacoes distintas
# (SP: +1/ano em x; BA: +2/ano em x).
fixture_regressao <- function(con, nome) {
  if (nome != "dados") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  tibble::tibble(
    uf  = c(rep("SP", 4), rep("BA", 4)),
    ano = rep(c(2005L, 2009L, 2013L, 2017L), 2),
    y   = c(1, 2, 3, 4, 2, 4, 6, 8),
    x   = c(1, 2, 3, 4, 1, 2, 3, 4)
  )
}

skip_sem_parsnip <- function() {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("broom")
  skip_if_not_installed("tidyr")
  skip_if_not_installed("purrr")
}

test_that("executar_regressao() ajusta um modelo por corte", {
  skip_sem_parsnip()
  local_mocked_bindings(eduBR_tbl = fixture_regressao)

  espec <- especificar_regressao("y", "x", cuts = "uf", fonte = "dados")
  x <- suppressWarnings(executar_regressao("fake_con", espec))

  expect_s3_class(x, "eduBR_regressoes")
  expect_equal(nrow(x), 2L)
  expect_setequal(x$uf, c("SP", "BA"))
  expect_true(all(x$n == 4L))

  co <- coeficientes(x)
  inclinacao <- function(uf) co$estimate[co$uf == uf & co$term == "x"]
  expect_equal(inclinacao("SP"), 1)
  expect_equal(inclinacao("BA"), 2)

  met <- metricas(x)
  expect_true("r.squared" %in% names(met))
  expect_output(print(x), "eduBR_regressoes")
})

test_that("executar_regressao() aceita dados diretos e sem cortes", {
  skip_sem_parsnip()

  d <- tibble::tibble(y = c(1, 2, 3, 4, 5), x = c(2, 4, 6, 8, 10))
  espec <- especificar_regressao("y", "x")
  x <- suppressWarnings(executar_regressao("fake_con", espec, dados = d))

  expect_equal(nrow(x), 1L)
  expect_equal(x$n, 5L)

  co <- coeficientes(x)
  expect_equal(co$estimate[co$term == "x"], 0.5)
})

test_that("executar_regressao() aplica o filtro da especificacao", {
  skip_sem_parsnip()
  local_mocked_bindings(eduBR_tbl = fixture_regressao)

  espec <- especificar_regressao(
    "y", "x", fonte = "dados", filtro = list(uf = "SP")
  )
  x <- suppressWarnings(executar_regressao("fake_con", espec))

  expect_equal(nrow(x), 1L)
  expect_equal(x$n, 4L)  # apenas as linhas de SP
})

test_that("executar_regressao() ajusta modelo logistico", {
  skip_sem_parsnip()

  d <- tibble::tibble(
    y = c(0, 0, 0, 1, 1, 0, 1, 1, 0, 1),
    x = c(1, 2, 2, 3, 4, 3, 5, 4, 2, 5)
  )
  espec <- especificar_regressao("y", "x", modelo = "logistico")
  x <- suppressWarnings(executar_regressao("fake_con", espec, dados = d))

  expect_s3_class(x, "eduBR_regressoes")
  co <- coeficientes(x)
  expect_true("x" %in% co$term)
})

test_that("coeficientes()/metricas() rejeitam objetos estranhos", {
  expect_error(coeficientes(list()), "executar_regressao")
  expect_error(metricas(data.frame()), "executar_regressao")
})

test_that("executar_regressao() exige fonte ou dados", {
  espec <- especificar_regressao("y", "x")
  expect_error(executar_regressao("fake_con", espec), "fonte")
  expect_error(executar_regressao("fake_con", list()), "espec")
})
