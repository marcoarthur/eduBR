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

test_that("rotular() adiciona rede/localizacao sem remover códigos", {
  df <- tibble::tibble(
    co_entidade = c(1L, 2L),
    tp_dependencia = c(3L, 4L),
    tp_localizacao = c(1L, 2L)
  )

  r <- rotular(df)

  expect_equal(r$rede, c("Municipal", "Privada"))
  expect_equal(r$localizacao, c("Urbana", "Rural"))
  expect_equal(r$tp_dependencia, c(3L, 4L))
  # código desconhecido vira NA; coluna de rótulo existente é preservada
  expect_equal(rotular(tibble::tibble(tp_dependencia = 9L))$rede, NA_character_)
  com_rede <- tibble::tibble(tp_dependencia = 1L, rede = "X")
  expect_equal(rotular(com_rede)$rede, "X")

  expect_error(rotular("nao-df"), "data.frame")
})
