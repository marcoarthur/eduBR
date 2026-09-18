skip_sem_floresta <- function() {
  skip_if_not_installed("ranger")
}

# Fixture: tres classes bem separadas no plano (x1, x2) + ruido puro (x3).
fixture_floresta <- function(n = 300L, semente = 42) {
  set.seed(semente)
  centros <- list(
    baixo = c(0, 0),
    medio = c(5, 5),
    alto  = c(10, 10)
  )
  pedaco <- lapply(names(centros), function(cl) {
    tibble::tibble(
      x1 = stats::rnorm(n, centros[[cl]][1], 0.5),
      x2 = stats::rnorm(n, centros[[cl]][2], 0.5),
      x3 = stats::rnorm(n),                    # ruido
      nivel = factor(cl, levels = c("baixo", "medio", "alto"))
    )
  })
  dados <- do.call(rbind, pedaco)
  dados$co_entidade <- as.character(seq_len(nrow(dados)))
  dados$etapa     <- "fundamental_ii"
  dados$nota_media <- stats::runif(nrow(dados), 3, 8)
  dados[, c("co_entidade", "etapa", "nota_media", "x1", "x2", "x3", "nivel")]
}

test_that("dividir_dados() preserva a estratificacao", {
  d <- fixture_floresta()
  partes <- dividir_dados(d, prop = 0.75, semente = 1)

  expect_setequal(names(partes), c("treino", "teste"))
  expect_equal(nrow(partes$treino) + nrow(partes$teste), nrow(d))
  expect_false(any(partes$treino$co_entidade %in% partes$teste$co_entidade))

  for (cl in c("baixo", "medio", "alto")) {
    n_treino <- sum(partes$treino$nivel == cl)
    n_total  <- sum(d$nivel == cl)
    expect_equal(n_treino, ceiling(0.75 * n_total))
  }
})

test_that("treinar_floresta() ajusta o modelo com metadados", {
  skip_sem_floresta()
  d <- fixture_floresta()
  rf <- treinar_floresta(d, trees = 50, semente = 1)

  expect_s3_class(rf, "eduBR_floresta")
  expect_s3_class(rf$modelo, "ranger")
  expect_identical(rf$classes, c("baixo", "medio", "alto"))
  expect_identical(rf$alvo, "nivel")
  # exclusoes padrao: identificadores e a nota nao viram features
  expect_false(any(c("co_entidade", "etapa", "nota_media") %in% rf$features))
  # importancia por permutacao disponivel
  expect_false(is.null(rf$modelo$variable.importance))
})

test_that("treinar_floresta() exclui identificadores espaciais das features", {
  skip_sem_floresta()
  d <- fixture_floresta()
  d$sg_uf        <- sample(c("SP", "RJ", "MG"), nrow(d), replace = TRUE)
  d$co_municipio <- as.character(seq_len(nrow(d)))
  rf <- treinar_floresta(d, trees = 50, semente = 1)
  expect_false(any(c("sg_uf", "co_municipio") %in% rf$features))
})

test_that("treinar_floresta() aceita features explicitas", {
  skip_sem_floresta()
  d <- fixture_floresta()
  rf <- treinar_floresta(d, features = c("x1", "x2"), trees = 30, semente = 2)
  expect_identical(rf$features, c("x1", "x2"))
})

test_that("treinar_floresta() valida entradas", {
  skip_sem_floresta()
  d <- fixture_floresta()
  d$nivel_char <- as.character(d$nivel)

  expect_error(treinar_floresta(d, alvo = "nivel_char"), "fator")
  expect_error(
    treinar_floresta(d, features = c("x1", "nao_existe")), "inexistentes"
  )
  expect_error(
    treinar_floresta(d, alvo = "co_entidade"), "fator"
  )
})

test_that("importancia_floresta() ordena e valida", {
  skip_sem_floresta()
  d <- fixture_floresta()
  rf <- treinar_floresta(d, trees = 50, semente = 3)

  imp <- importancia_floresta(rf)
  expect_identical(names(imp), c("var", "importancia"))
  # ordenacao decrescente da importancia
  expect_true(all(diff(imp$importancia) <= 0 + 1e-12))
  # o ruido puro (x3) e o menos relevante
  expect_identical(imp$var[[3]], "x3")

  expect_error(importancia_floresta(list()), "treinar_floresta")
})

test_that("predizer_floresta() devolve classe e probabilidades", {
  skip_sem_floresta()
  d <- fixture_floresta()
  partes <- dividir_dados(d, prop = 0.7, semente = 4)
  rf <- treinar_floresta(partes$treino, trees = 50, semente = 5)

  pred <- predizer_floresta(rf, partes$teste)
  expect_equal(nrow(pred), nrow(partes$teste))
  expect_true(all(c("nivel_pred", "p_baixo", "p_medio", "p_alto") %in% names(pred)))
  expect_s3_class(pred$nivel_pred, "factor")
  expect_identical(levels(pred$nivel_pred), c("baixo", "medio", "alto"))
  probs <- pred[, c("p_baixo", "p_medio", "p_alto")]
  expect_true(all(abs(rowSums(probs) - 1) < 1e-9))
})

test_that("metricas_floresta() avalia fora da amostra", {
  skip_sem_floresta()
  d <- fixture_floresta()
  partes <- dividir_dados(d, prop = 0.7, semente = 6)
  rf <- treinar_floresta(partes$treino, trees = 50, semente = 7)

  m <- metricas_floresta(rf, partes$teste)

  # classes bem separadas -> desempenho alto e muito acima do baseline
  expect_gt(m$acuracia, 0.9)
  expect_gt(m$f1_macro, 0.9)
  expect_true(is.finite(m$auc_macro) && m$auc_macro >= 0.5 && m$auc_macro <= 1)
  expect_gt(m$auc_macro, 0.9)
  expect_gt(m$acuracia, m$baseline_acerto)

  expect_true(is.matrix(attr(m, "confusao")))
  expect_length(attr(m, "f1_classe"), 3L)
  expect_named(attr(m, "auc_classe"), c("baixo", "medio", "alto"))
})

test_that("metricas_floresta() e predizer_floresta() validam entradas", {
  skip_sem_floresta()
  d <- fixture_floresta()
  partes <- dividir_dados(d, prop = 0.7, semente = 8)
  rf <- treinar_floresta(partes$treino, trees = 30, semente = 9)

  expect_error(metricas_floresta(list(), partes$teste), "treinar_floresta")
  expect_error(
    metricas_floresta(rf, partes$teste, rotulo = "nao_existe"), "nao_existe"
  )
  expect_error(
    predizer_floresta(rf, dplyr::select(partes$teste, -x1)), "x1"
  )
})

test_that("print.eduBR_floresta() resume o modelo", {
  skip_sem_floresta()
  rf <- treinar_floresta(fixture_floresta(), trees = 20, semente = 10)
  expect_output(print(rf), "eduBR_floresta")
  expect_output(print(rf), "importancia")
})