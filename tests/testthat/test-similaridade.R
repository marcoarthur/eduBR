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
  fake_censo <- function(con, nome) {
    tibble::tibble(
      nu_ano_censo = c(2024L, 2025L, 2025L),
      co_entidade = c(2, 2, 3),
      no_entidade = c("ESC B ANTIGA", "ESC B", "ESC C"),
      no_municipio = c("Ubatuba", "Ubatuba", "Paraty"),
      sg_uf = c("SP", "SP", "RJ"),
      tp_dependencia = c(3L, 3L, 2L)
    )
  }
  local_mocked_bindings(features_escola = fake_features, eduBR_tbl = fake_censo)

  v <- escolas_similares("fake_con", "1", n = 1L)
  expect_equal(v$co_entidade, "2")
  expect_named(v, c("co_entidade", "escola", "municipio", "uf", "rede",
                    "etapa", "distancia"))
  expect_equal(v$escola, "ESC B")
  expect_equal(v$rede, "Municipal")

  v2 <- escolas_similares("fake_con", "1", n = 3L)
  expect_equal(nrow(v2), 3L)
  expect_true(is.na(v2$escola[v2$co_entidade == "4"]))

  expect_error(escolas_similares("fake_con", "1", n = 0), "inteiro positivo")
})

test_that("eduBR_vizinhos() trata integer64 como número", {
  testthat::skip_if_not_installed("bit64")
  v64 <- vizinhas
  v64$score <- bit64::as.integer64(c(10, 10, 1, 1))
  vnum <- vizinhas
  vnum$score <- c(10, 10, 1, 1)

  expect_equal(
    eduBR_vizinhos(v64, "1", n = 3L),
    eduBR_vizinhos(vnum, "1", n = 3L)
  )
})

test_that("eduBR_vizinhos_query() roda o k-NN no SQL", {
  testthat::skip_if_not_installed("dbplyr")
  lf <- dbplyr::lazy_frame(
    co_entidade = "1", etapa = "fundamental_i", in_internet = 1L,
    qt_doc_bas = 2L, con = dbplyr::simulate_postgres()
  )
  sql <- as.character(dbplyr::sql_render(
    eduBR_vizinhos_query(lf, "1", 3L, c("in_internet", "qt_doc_bas"),
                         "fundamental_i")
  ))

  expect_match(sql, "STDDEV_SAMP", fixed = TRUE)
  expect_match(sql, "GROUP BY", fixed = TRUE)
  expect_match(sql, "DOUBLE PRECISION", fixed = TRUE)
  expect_match(sql, "LIMIT 3", fixed = TRUE)
  expect_match(sql, "ORDER BY", fixed = TRUE)
  expect_no_match(sql, "OVER", fixed = TRUE)
})

test_that("escolas_similares() usa as etapas da escola por padrão", {
  feats <- tibble::tibble(
    co_entidade = c("1", "2", "3", "4", "5", "6", "7"),
    etapa = c(rep("fundamental_i", 3L), rep("ensino_medio", 3L), "ensino_medio"),
    tp_dependencia = c(3L, 3L, 3L, 2L, 2L, 2L, 4L),
    in_internet = c(1, 1, 0, 1, 0, 0, 1),
    qt_doc_bas = c(20, 21, 5, 40, 41, 10, 40)
  )
  fake_features <- function(con, etapa = NULL, publica = TRUE) {
    d <- feats
    if (!is.null(etapa)) d <- d[d$etapa %in% etapa, , drop = FALSE]
    if (publica) d <- d[d$tp_dependencia %in% 1:3, , drop = FALSE]
    new_eduBR(d, "eduBR_features", con, list())
  }
  fake_censo <- function(con, nome) {
    tibble::tibble(
      nu_ano_censo = 2025L, co_entidade = c(1, 2, 3, 4, 5, 6, 7),
      no_entidade = paste("ESC", 1:7), no_municipio = "X", sg_uf = "SP",
      tp_dependencia = c(3L, 3L, 3L, 2L, 2L, 2L, 4L)
    )
  }
  local_mocked_bindings(features_escola = fake_features, eduBR_tbl = fake_censo)

  # escola só de ensino médio: sem `etapa =`
  v <- escolas_similares("fake_con", "4", n = 1L)
  expect_equal(v$co_entidade, "5")
  expect_equal(v$etapa, "ensino_medio")

  # escola de fund. I: resultado como antes
  expect_equal(escolas_similares("fake_con", "1", n = 1L)$co_entidade, "2")

  expect_error(
    escolas_similares("fake_con", "4", etapa = "fundamental_i"),
    "disponível em: ensino_medio"
  )
  expect_error(escolas_similares("fake_con", "7"), "publica = FALSE")
  expect_error(escolas_similares("fake_con", "999"), "sem features")
})
