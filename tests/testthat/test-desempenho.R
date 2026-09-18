# Fixture: features em nivel de escola (imita analytics.escola_features).
fixture_features_escola <- function(con, nome) {
  if (nome != "escola_features") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  tibble::tibble(
    co_entidade    = as.character(1:8),
    tp_dependencia = c(1L, 2L, 3L, 4L, 2L, 2L, 3L, 3L),
    tp_localizacao = c(1L, 1L, 2L, 1L, 2L, 2L, 1L, 2L),
    qt_mat_bas     = c(10L, 20L, 30L, 40L, 50L, 60L, 70L, 80L),
    nota_media     = c(5.1, 5.4, 6.0, 6.5, 4.0, 4.5, 5.8, 7.0),
    etapa          = rep(c("fundamental_i", "fundamental_ii"), each = 4L)
  )
}

test_that("features_escola() filtra rede publica e etapas", {
  local_mocked_bindings(eduBR_tbl = fixture_features_escola)

  pub <- coletar(features_escola("fake_con"))
  expect_false(any(pub$tp_dependencia == 4L))
  expect_equal(nrow(pub), 7L)  # a unica privada (linha 4) sai

  todas <- coletar(features_escola("fake_con", publica = FALSE))
  expect_equal(nrow(todas), 8L)
  expect_true(any(todas$tp_dependencia == 4L))

  so_fii <- coletar(features_escola("fake_con", etapa = "fundamental_ii"))
  expect_setequal(so_fii$etapa, "fundamental_ii")
  expect_equal(nrow(so_fii), 4L)
})

test_that("features_escola() valida argumentos", {
  expect_error(features_escola("con", etapa = c("fundamental_i", "ensino_medio_x")),
    "etapa")
})

test_that("classificar_desempenho() usa tercis por etapa", {
  d <- tibble::tibble(
    nota_media = c(1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6),
    etapa      = rep(c("fundamental_i", "fundamental_ii"), each = 6L)
  )
  res <- classificar_desempenho(d)

  expect_s3_class(res$nivel, "factor")
  expect_identical(levels(res$nivel), c("baixo", "medio", "alto"))
  esperado <- rep(c("baixo", "baixo", "medio", "medio", "alto", "alto"), 2)
  expect_identical(as.character(res$nivel), esperado)

  lim <- limites_desempenho(res)
  expect_named(lim, c("fundamental_i", "fundamental_ii"))
  tercis <- unname(stats::quantile(1:6, probs = c(1 / 3, 2 / 3)))
  expect_equal(lim[["fundamental_i"]], tercis)
  expect_equal(lim[["fundamental_ii"]], tercis)
})

test_that("classificar_desempenho() aceita cortes fixos", {
  d <- tibble::tibble(nota_media = 1:6)
  res <- classificar_desempenho(d, grupo = NULL, cortes = c(2, 4))

  # <2 baixo; [2,4) medio; >=4 alto
  expect_identical(
    as.character(res$nivel),
    c("baixo", "medio", "medio", "alto", "alto", "alto")
  )
  expect_equal(limites_desempenho(res), c(2, 4))

  por_grupo <- classificar_desempenho(
    tibble::tibble(nota_media = 1:6, etapa = rep(c("fi", "fii"), each = 3L)),
    cortes = list(fi = c(2, 4), fii = c(1, 3))
  )
  expect_named(limites_desempenho(por_grupo), c("fi", "fii"))
})

test_that("classificar_desempenho() valida entradas", {
  expect_error(classificar_desempenho(data.frame(x = 1)), "nota_media")
  expect_error(
    classificar_desempenho(tibble::tibble(nota_media = 1:6), cortes = c(1)),
    "cortes"
  )
  expect_error(
    classificar_desempenho(
      tibble::tibble(nota_media = 1:6), rotulos = c("baixo", "baixo", "alto")
    ),
    "rotulos"
  )
})