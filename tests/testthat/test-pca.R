# pca_perfil() é pura R: fixtures sintéticas com estrutura conhecida.

set.seed(42L)
bloco1 <- matrix(rnorm(60L), ncol = 2L)
df_pca <- tibble::tibble(
  co_entidade = as.character(1:30),
  etapa = rep("fundamental_ii", 30L),
  x1 = bloco1[, 1L] * 3,
  x2 = bloco1[, 1L] * 3 + rnorm(30L, sd = 0.1),
  x3 = rnorm(30L),
  nota_media = rnorm(30L, mean = 5),
  constante = 1,
  so_na = NA_real_
)

test_that("pca_perfil() ordena variância e exclui desempenho/constantes", {
  p <- suppressWarnings(pca_perfil(df_pca))

  expect_s3_class(p, "eduBR_pca")
  # x1/x2 correlacionadas dominam PC1
  expect_gt(p$variancia$prop[[1L]], 0.5)
  expect_equal(sum(p$variancia$prop), 1, tolerance = 1e-8)
  expect_true(all(c("PC1", "PC2", "PC3") %in% p$variancia$pc))
  # nota_media, constante e so_na fora
  expect_false("nota_media" %in% p$loadings$variavel)
  expect_false("constante" %in% p$loadings$variavel)
  expect_equal(
    sort(attr(p, "removidas")),
    sort(c("constante", "so_na"))
  )
  expect_equal(nrow(p$scores), 30L)
  expect_equal(p$scores$id, as.character(1:30))
  expect_output(print(p), "eduBR_pca")
})

test_that("pca_perfil() descarta incompletas e valida entradas", {
  df <- df_pca
  df$x3[1L:2L] <- NA_real_
  p <- suppressWarnings(pca_perfil(df))
  expect_equal(nrow(p$scores), 28L)
  expect_equal(attr(p, "n_incompletas"), 2L)

  expect_error(pca_perfil("nao-df"), "data.frame")
  expect_error(pca_perfil(df_pca, id = "inexistente"), "identificadora")
  expect_error(
    pca_perfil(tibble::tibble(co_entidade = "1", etapa = "a")),
    "sem colunas numéricas"
  )
  dup <- df_pca
  dup$co_entidade[[2L]] <- "1"
  expect_error(suppressWarnings(pca_perfil(dup)), "duplicados")
})

test_that("pca_perfil() trata integer64 como número", {
  testthat::skip_if_not_installed("bit64")
  base <- df_pca[c("co_entidade", "x1", "x3")]
  base$score <- round(df_pca$x2 * 10)
  b64 <- base
  b64$score <- bit64::as.integer64(base$score)

  p_num <- pca_perfil(base)
  p_64 <- pca_perfil(b64)
  expect_equal(p_64$variancia, p_num$variancia)
})

test_that("pca_perfil() deixa códigos categóricos do Censo fora", {
  d <- df_pca
  d$tp_dependencia <- rep(c(2L, 3L), 15L)
  d$tp_localizacao <- rep(c(1L, 2L), each = 15L)

  p <- suppressWarnings(pca_perfil(d))
  expect_false(any(c("tp_dependencia", "tp_localizacao") %in% p$loadings$variavel))
})

test_that("pca_perfil() fixa o sinal: maior peso de cada PC é positivo", {
  p <- suppressWarnings(pca_perfil(df_pca))
  maior <- tapply(p$loadings$peso, p$loadings$pc, function(v) v[which.max(abs(v))])
  expect_true(all(maior > 0))

  inv <- df_pca
  inv[c("x1", "x2", "x3")] <- -inv[c("x1", "x2", "x3")]
  p_inv <- suppressWarnings(pca_perfil(inv))
  expect_equal(abs(p_inv$scores$PC1), abs(p$scores$PC1))
  expect_true(all(
    tapply(p_inv$loadings$peso, p_inv$loadings$pc, function(v) v[which.max(abs(v))]) > 0
  ))
})

test_that("pca_perfil() descarta componentes de variância nula com aviso", {
  d <- df_pca[c("co_entidade", "x1", "x2", "x3")]
  d$soma <- d$x1 + d$x3

  expect_warning(p <- pca_perfil(d), "vari\u00e2ncia nula.*soma")
  expect_equal(nrow(p$variancia), 3L)
  expect_equal(ncol(p$scores), 4L)
  expect_true(all(p$variancia$prop > 1e-10))
  expect_equal(sum(p$variancia$prop), 1, tolerance = 1e-8)

  expect_no_warning(pca_perfil(df_pca[c("co_entidade", "x1", "x2", "x3")]))
})
