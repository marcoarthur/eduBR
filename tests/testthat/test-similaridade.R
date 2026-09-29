# eduBR_vizinhos() é puro R; testa a matemática sem banco.

vizinhas <- tibble::tibble(
  co_entidade = c("1", "2", "3", "4"),
  etapa = rep("fundamental_i", 4L),
  tp_dependencia = c(3L, 3L, 3L, 3L),
  in_biblioteca = c(1, 1, 0, 0),
  in_internet = c(1, 0, 1, 0),
  qt_doc_bas = c(20, 21, 5, 6),
  nota_media = c(5.0, 5.1, 6.0, 4.0)
)

test_that("eduBR_vizinhos() ordena por distancia e exclui a referencia", {
  v <- eduBR_vizinhos(vizinhas, "1", n = 2L)

  expect_equal(nrow(v), 2L)
  expect_false("1" %in% v$co_entidade)
  expect_true(all(diff(v$distancia) >= 0))
  # escola 2 difere da 1 em 1 flag + 1 docente; 3 e 4 estão longe
  expect_equal(v$co_entidade[[1L]], "2")
})

test_that("eduBR_vizinhos() ignora desempenho e identificadores", {
  # nota_media não entra na distância: 3 (nota 6) vem antes de 4 (nota 4)
  v <- eduBR_vizinhos(vizinhas, "1", n = 3L)
  expect_equal(v$co_entidade, c("2", "3", "4"))
})

test_that("eduBR_vizinhos() compara dentro de cada etapa", {
  duas <- tibble::tibble(
    co_entidade = c("1", "2", "1", "3"),
    etapa = c("fundamental_i", "fundamental_i", "fundamental_ii", "fundamental_ii"),
    in_biblioteca = c(1, 1, 0, 0),
    qt_doc_bas = c(20, 21, 5, 6)
  )
  v <- eduBR_vizinhos(duas, "1", n = 2L)

  expect_equal(nrow(v), 2L)
  expect_setequal(v$etapa, c("fundamental_i", "fundamental_ii"))
  expect_equal(v$co_entidade[v$etapa == "fundamental_i"], "2")
  expect_equal(v$co_entidade[v$etapa == "fundamental_ii"], "3")
  expect_true(all(is.finite(v$distancia)))
})

test_that("eduBR_vizinhos() tolera Inf/NA nas features", {
  suja <- tibble::tibble(
    co_entidade = c("1", "2", "3"),
    etapa = rep("fundamental_i", 3L),
    x = c(1, 2, Inf),
    y = c(1, NA_real_, 3)
  )
  v <- eduBR_vizinhos(suja, "1", n = 2L)
  expect_true(all(is.finite(v$distancia)))
})

test_that("eduBR_vizinhos() erros em PT-BR", {
  expect_error(eduBR_vizinhos(vizinhas, "999"), "fora do recorte")
  expect_error(
    eduBR_vizinhos(vizinhas[0L, ], "1"),
    "sem dados"
  )
})

test_that("escolas_similares() valida n e usa features_escola()", {
  fake_features <- function(con, etapa = c("fundamental_i", "fundamental_ii"),
                            publica = TRUE) {
    new_eduBR(vizinhas, "eduBR_features", con, list())
  }
  local_mocked_bindings(features_escola = fake_features)

  v <- escolas_similares("fake_con", "1", n = 1L)
  expect_equal(v$co_entidade, "2")

  expect_error(escolas_similares("fake_con", "1", n = 0), "inteiro positivo")
})
