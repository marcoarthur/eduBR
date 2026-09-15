# Fixture em memoria: duas regioes, uma etapa, tres anos, com tendencias
# crescentes distintas (Norte: +0.25/ano; Sudeste: +0.125/ano).
fake_ideb_regiao <- function(con, regiao = NULL, uf = NULL, etapa = NULL,
                             rede = NULL, ano = NULL) {
  new_eduBR(
    tibble::tibble(
      nome_regiao    = c(rep("Norte", 3), rep("Sudeste", 3)),
      sigla_regiao   = c(rep("N", 3), rep("SE", 3)),
      etapa          = rep("fundamental_i", 6),
      ano            = c(2005L, 2009L, 2013L, 2005L, 2009L, 2013L),
      ideb_observado = c(3.0, 4.0, 5.0, 5.0, 5.5, 6.0)
    ),
    "eduBR_ideb_regiao", con,
    list(descricao = "fixture ideb_regiao")
  )
}

test_that("tendencia_regiao() ajusta um modelo por regiao x etapa", {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("broom")
  skip_if_not_installed("tidyr")
  skip_if_not_installed("purrr")

  local_mocked_bindings(ideb_regiao = fake_ideb_regiao)

  x <- tendencia_regiao("fake_con")

  expect_s3_class(x, "eduBR_tendencia")
  expect_equal(nrow(x), 2L)
  expect_setequal(x$nome_regiao, c("Norte", "Sudeste"))
  expect_true(all(x$n_anos == 3L))

  coef <- tidyr::unnest(x, "coeficientes")
  inclinacao <- function(reg) {
    coef$estimate[coef$nome_regiao == reg & coef$term == "ano"]
  }
  expect_equal(inclinacao("Norte"), 0.25)
  expect_equal(inclinacao("Sudeste"), 0.125)

  pred <- tidyr::unnest(x, "predicoes")
  expect_true(".pred" %in% names(pred))
  expect_equal(nrow(pred), 6L)
})

test_that("print() de eduBR_tendencia resume inclinacao e R2", {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("broom")
  skip_if_not_installed("tidyr")
  skip_if_not_installed("purrr")

  local_mocked_bindings(ideb_regiao = fake_ideb_regiao)

  x <- tendencia_regiao("fake_con")
  expect_output(print(x), "eduBR_tendencia")
  expect_output(print(x), "Norte")
})
