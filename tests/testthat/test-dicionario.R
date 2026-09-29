# dicionario() é puro R (sem banco).

test_that("dicionario() devolve codigo -> rotulo das categoricas", {
  d <- dicionario()

  expect_s3_class(d, "tbl_df")
  expect_equal(names(d), c("variavel", "codigo", "rotulo"))
  expect_true(is.integer(d$codigo))

  rede <- d[d$variavel == "tp_dependencia", ]
  expect_equal(rede$rotulo[rede$codigo == 3L], "Municipal")
  expect_equal(nrow(rede), 4L)

  loc <- d[d$variavel == "tp_localizacao", ]
  expect_equal(loc$rotulo[loc$codigo == 2L], "Rural")

  # rótulos consistentes com as colunas derivadas no SQL
  expect_equal(
    sort(unique(d$rotulo[d$variavel == "tp_dependencia"])),
    sort(c("Federal", "Estadual", "Municipal", "Privada"))
  )
})
