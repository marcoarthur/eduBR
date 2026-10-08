# print.eduBR: prévia legível, sem SQL/conexão. Fixtures em memória.

fake_print_tbl <- tibble::tibble(
  co_entidade = c(1L, 2L, 3L),
  no_entidade = c("ESC A", "ESC B", "ESC C"),
  tp_dependencia = c(3L, 2L, 4L),
  tp_localizacao = c(1L, 2L, 1L)
)

test_that("print mostra domínio, descrição e prévia com rótulos", {
  x <- new_eduBR(fake_print_tbl, "eduBR_escola",
                 meta = list(descricao = "Escolas de teste"))

  out <- capture.output(print(x))

  expect_match(out[[1L]], "<eduBR_escola> Escolas de teste", fixed = TRUE)
  expect_true(any(grepl("4 colunas", out, fixed = TRUE)))
  expect_true(any(grepl("Municipal", out, fixed = TRUE)))
  expect_true(any(grepl("Rural", out, fixed = TRUE)))
  expect_false(any(grepl("tp_dependencia", out, fixed = TRUE)))
  expect_false(any(grepl("Dados ainda no banco", out, fixed = TRUE)))
})

test_that("print respeita n e omite a prévia com n = 0", {
  x <- new_eduBR(fake_print_tbl, "eduBR_escola")

  out2 <- capture.output(print(x, n = 2))
  expect_true(any(grepl("(2 linhas)", out2, fixed = TRUE)))
  expect_false(any(grepl("ESC C", out2, fixed = TRUE)))

  out0 <- capture.output(print(x, n = 0))
  expect_false(any(grepl("ESC A", out0, fixed = TRUE)))
})

test_that("print de consulta lazy não expõe SQL nem conexão", {
  testthat::skip_if_not_installed("dbplyr")
  lf <- dbplyr::lazy_frame(co_entidade = 1L, con = dbplyr::simulate_postgres())
  x <- new_eduBR(lf, "eduBR_escola")

  out <- capture.output(print(x))

  expect_false(any(grepl("SELECT|Database|@", out)))
  expect_true(any(grepl("indispon", out, fixed = TRUE)))
  expect_true(any(grepl("coletar(x, n = ...)", out, fixed = TRUE)))
})

test_that("print com zero linhas avisa", {
  x <- new_eduBR(fake_print_tbl[0, ], "eduBR_escola")
  expect_output(print(x), "Nenhuma linha encontrada")
})

test_that("print usa singular com uma linha", {
  x <- new_eduBR(fake_print_tbl[1, ], "eduBR_escola")
  expect_output(print(x), "(1 linha)", fixed = TRUE)
})

test_that("prévia sem tipos técnicos, sem geometria e com integer64 legível", {
  df <- fake_print_tbl
  df$geometry <- c("0101", "0101", NA)
  if (requireNamespace("bit64", quietly = TRUE)) {
    df$co_entidade <- bit64::as.integer64(c(13078070, 2, 3))
  }
  x <- new_eduBR(df, "eduBR_escola")

  out <- capture.output(print(x))

  expect_false(any(grepl("<chr>|<int>|<int64>|<dbl>|pq_gmtry", out)))
  expect_false(any(grepl("0101", out, fixed = TRUE)))
  expect_true(any(grepl("geometria omitida", out, fixed = TRUE)))
  if (requireNamespace("bit64", quietly = TRUE)) {
    expect_true(any(grepl("13078070", out, fixed = TRUE)))
  }
})

test_that("prévia lista as colunas que não cabem e trunca textos", {
  largo <- as.data.frame(
    stats::setNames(as.list(rep("valor", 30L)), sprintf("coluna_%02d", 1:30))
  )
  largo$texto <- strrep("x", 80L)
  x <- new_eduBR(tibble::as_tibble(largo), "eduBR_escola")

  out <- withr::with_options(list(width = 60L), capture.output(print(x)))

  expect_true(any(grepl("e mais \\d+ colunas: ", out)))
  resto <- out[grepl("e mais", out) | startsWith(out, "  ")]
  expect_true(all(nchar(resto) <= 60L))
  expect_false(any(grepl(strrep("x", 40L), out, fixed = TRUE)))
})
