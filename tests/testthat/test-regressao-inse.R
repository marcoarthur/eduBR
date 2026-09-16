# Fixture em memoria: duas regioes, uma etapa, INSE crescente, com
# gradientes distintos (Norte: +1 IDEB/INSE; Sudeste: +0.5 IDEB/INSE).
fake_ideb_inse <- function(con, regiao = NULL, uf = NULL, etapa = NULL,
                           rede = NULL) {
  new_eduBR(
    tibble::tibble(
      nome_regiao    = c(rep("Norte", 4), rep("Sudeste", 4)),
      sigla_regiao   = c(rep("N", 4), rep("SE", 4)),
      etapa          = rep("fundamental_i", 8),
      media_inse     = c(3, 4, 5, 6, 3, 4, 5, 6),
      ideb_observado = c(3, 4, 5, 6, 4.5, 5, 5.5, 6)
    ),
    "eduBR_ideb_inse", con,
    list(descricao = "fixture ideb_inse")
  )
}

test_that("regressao_inse() ajusta ideb ~ media_inse por regiao x etapa", {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("broom")
  skip_if_not_installed("tidyr")
  skip_if_not_installed("purrr")

  local_mocked_bindings(ideb_inse = fake_ideb_inse)

  x <- suppressWarnings(regressao_inse("fake_con"))

  expect_s3_class(x, "eduBR_regressao_inse")
  expect_equal(nrow(x), 2L)
  expect_setequal(x$nome_regiao, c("Norte", "Sudeste"))
  expect_true(all(x$n_escolas == 4L))

  co <- tidyr::unnest(x, "coeficientes")
  inclinacao <- function(reg) {
    co$estimate[co$nome_regiao == reg & co$term == "media_inse"]
  }
  expect_equal(inclinacao("Norte"), 1)
  expect_equal(inclinacao("Sudeste"), 0.5)

  pred <- tidyr::unnest(x, "predicoes")
  expect_true(".pred" %in% names(pred))
  expect_equal(nrow(pred), 8L)
})

test_that("print() de eduBR_regressao_inse resume inclinacao e R2", {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("broom")
  skip_if_not_installed("tidyr")
  skip_if_not_installed("purrr")

  local_mocked_bindings(ideb_inse = fake_ideb_inse)

  x <- suppressWarnings(regressao_inse("fake_con"))
  expect_output(print(x), "eduBR_regressao_inse")
  expect_output(print(x), "Norte")
})
