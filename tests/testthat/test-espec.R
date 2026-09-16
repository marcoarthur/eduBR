test_that("especificar_regressao() cria e valida a especificacao", {
  e <- especificar_regressao(
    "y", c("x1", "x2"),
    cuts = "uf", fonte = "ideb", id = "a"
  )

  expect_s3_class(e, "eduBR_espec")
  expect_equal(e$outcome, "y")
  expect_equal(e$predictors, c("x1", "x2"))
  expect_equal(e$cuts, "uf")
  expect_equal(e$modelo, "linear")
  expect_equal(e$fonte, "ideb")
  expect_equal(e$id, "a")
  expect_output(print(e), "eduBR_espec")
})

test_that("especificar_regressao() rejeita entradas invalidas", {
  expect_error(especificar_regressao("", "x"), "outcome")
  expect_error(especificar_regressao("y", character(0)), "predictors")
  expect_error(especificar_regressao("y", "x", cuts = 1), "cuts")
  expect_error(especificar_regressao("y", "x", filtro = list(1, 2)), "filtro")
  expect_error(especificar_regressao("y", "x", modelo = "nope"),
               "should be one of")
})

test_that("ler_espec() le um YAML e devolve eduBR_espec", {
  skip_if_not_installed("yaml")

  caminho <- withr::local_tempfile(fileext = ".yaml")
  writeLines(c(
    "id: teste",
    "outcome: ideb_observado",
    "predictors:",
    "  - nota_media",
    "  - sg_uf",
    "cuts:",
    "  - ano",
    "modelo: linear",
    "fonte: ideb"
  ), caminho)

  e <- ler_espec(caminho)
  expect_s3_class(e, "eduBR_espec")
  expect_equal(e$id, "teste")
  expect_equal(e$outcome, "ideb_observado")
  expect_equal(e$predictors, c("nota_media", "sg_uf"))
  expect_equal(e$cuts, "ano")
  expect_equal(e$fonte, "ideb")
  expect_equal(e$modelo, "linear")
})

test_that("ler_espec() falha com caminho inexistente", {
  expect_error(ler_espec("/nao/existe.yaml"), "caminho")
})
