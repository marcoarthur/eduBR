# covariaveis_escola(): fixtures em memória (sem banco).

fake_cov_tbl <- function(con, nome) {
  switch(
    nome,
    censo_escolas = tibble::tibble(
      nu_ano_censo = c(2025L, 2025L, 2025L, 2024L),
      co_entidade = c(11, 12, 13, 11),
      sg_uf = c("SP", "SP", "RJ", "SP"),
      co_municipio = c(1L, 1L, 2L, 1L),
      tp_dependencia = c(3L, 2L, 3L, 3L),
      tp_localizacao = c(1L, 2L, 1L, 1L),
      tp_situacao_funcionamento = c(1L, 1L, 1L, 1L),
      in_biblioteca = c(1L, 0L, 1L, 0L),
      in_internet = c(1L, 1L, 0L, 0L),
      in_comum_fund_ai = c(1L, 0L, 1L, 1L)
    ),
    censo_docentes = tibble::tibble(
      nu_ano_censo = c(2025L, 2025L, 2025L),
      co_entidade = c(11, 12, 13),
      qt_doc_bas = c(20L, 10L, 30L)
    ),
    censo_matriculas = tibble::tibble(
      nu_ano_censo = c(2025L, 2025L),
      co_entidade = c(11, 13),
      qt_mat_bas = c(300L, 500L)
    ),
    ideb = tibble::tibble(
      id_escola = c(11, 11, 11, 12, 13),
      ano = c(2023L, 2021L, 2023L, 2023L, 2019L),
      etapa = c("fundamental_i", "fundamental_i", "fundamental_ii",
                "ensino_medio", "fundamental_i"),
      ideb_observado = c(5.0, 3.0, 6.0, 4.0, 7.0)
    ),
    stop(sprintf("fixture inesperada: %s", nome))
  )
}

test_that("covariaveis_escola() monta uma linha por escola", {
  local_mocked_bindings(eduBR_tbl = fake_cov_tbl)

  x <- covariaveis_escola("fake_con")
  expect_s3_class(x, c("eduBR_covariaveis", "eduBR"))

  d <- as_tibble(x)
  d <- d[order(d$co_entidade), , drop = FALSE]
  expect_equal(d$co_entidade, c(11, 12, 13))
  expect_true(all(c("rede", "localizacao", "in_biblioteca", "in_comum_fund_ai",
                    "docentes", "matriculas", "ideb_fund_i", "ideb_fund_ii",
                    "ideb_medio") %in% names(d)))
  expect_equal(d$rede, c("Municipal", "Estadual", "Municipal"))
  expect_equal(d$localizacao, c("Urbana", "Rural", "Urbana"))
  expect_equal(d$docentes, c(20L, 10L, 30L))
  expect_equal(d$matriculas, c(300L, NA, 500L))
  # IDEB 2023 apenas (2021 de ESC 11 e 2019 de ESC 13 ficam fora)
  expect_equal(d$ideb_fund_i, c(5.0, NA, NA))
  expect_equal(d$ideb_fund_ii, c(6.0, NA, NA))
  expect_equal(d$ideb_medio, c(NA, 4.0, NA))
})

test_that("covariaveis_escola() filtra UF, rede e edição do IDEB", {
  local_mocked_bindings(eduBR_tbl = fake_cov_tbl)

  sp_mun <- as_tibble(covariaveis_escola("fake_con", uf = "SP", rede = "Municipal"))
  expect_equal(sp_mun$co_entidade, 11)

  d19 <- as_tibble(covariaveis_escola("fake_con", ano_ideb = 2019L))
  expect_equal(d19$ideb_fund_i[d19$co_entidade == 13], 7.0)
  expect_true(is.na(d19$ideb_fund_i[d19$co_entidade == 11]))
})

test_that("covariaveis_escola() serve de dados para executar_regressao()", {
  skip_if_not_installed("parsnip")
  skip_if_not_installed("broom")
  local_mocked_bindings(eduBR_tbl = fake_cov_tbl)

  espec <- especificar_regressao("docentes", "in_biblioteca")
  x <- executar_regressao("fake_con", espec, dados = covariaveis_escola("fake_con"))
  expect_true("in_biblioteca" %in% coeficientes(x)$term)
})

test_that("covariaveis_escola() exclui escolas fora de atividade por padrão", {
  com_inativa <- function(con, nome) {
    d <- fake_cov_tbl(con, nome)
    if (nome == "censo_escolas") {
      d$tp_situacao_funcionamento[d$co_entidade == 13] <- 2L
    }
    d
  }
  local_mocked_bindings(eduBR_tbl = com_inativa)

  expect_equal(sort(as_tibble(covariaveis_escola("fake_con"))$co_entidade), c(11, 12))
  expect_equal(nrow(as_tibble(covariaveis_escola("fake_con", ativas = FALSE))), 3L)
})
