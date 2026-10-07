# Smoke test opcional contra o banco real [edumaps].
# Rode com EDUBR_SMOKE=1 (ex.: EDUBR_SMOKE=1 Rscript -e 'devtools::test()').

test_that("conecta() no [edumaps] real e monta um objeto de dominio", {
  skip_if(
    Sys.getenv("EDUBR_SMOKE", "") == "",
    "Defina EDUBR_SMOKE=1 para rodar o smoke test"
  )

  con <- conecta(service = "edumaps")
  withr::defer(DBI::dbDisconnect(con))

  expect_s4_class(con, "DBIConnection")

  x <- escolas(con)
  expect_s3_class(x, "eduBR_escola")
  expect_s3_class(consulta(x), "tbl_sql")

  m <- municipios(con, uf = "SP")
  expect_gt(nrow(as_tibble(m)), 0L)
})

test_that("escolas_similares() no banco: k-NN no SQL, identificado", {
  skip_if(
    Sys.getenv("EDUBR_SMOKE", "") == "",
    "Defina EDUBR_SMOKE=1 para rodar o smoke test"
  )

  con <- conecta(service = "edumaps")
  withr::defer(DBI::dbDisconnect(con))

  v <- expect_no_warning(escolas_similares(con, "13078070", n = 3L))
  expect_equal(nrow(v), 3L)
  expect_false(anyNA(v$escola))
  expect_false("13078070" %in% v$co_entidade)
  expect_true(all(diff(v$distancia) >= 0))
})
