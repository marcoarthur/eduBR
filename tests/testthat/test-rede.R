# Fixtures em memoria para rede

fake_mv_rede_escolas_tbl <- function(con, nome) {
  if (nome != "redes") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  tibble::tibble(
    co_municipio = c("3555406", "3555406", "3509502", "3509502", "2927408", "2927408"),
    no_municipio = c("Ubatuba", "Ubatuba", "Campinas", "Campinas", "Salvador", "Salvador"),
    sg_uf = c("SP", "SP", "SP", "SP", "BA", "BA"),
    no_regiao = c("Sudeste", "Sudeste", "Sudeste", "Sudeste", "Nordeste", "Nordeste"),
    codigo_rede = c(2L, 3L, 2L, 3L, 2L, 3L),
    rede = c("Estadual", "Municipal", "Estadual", "Municipal", "Estadual", "Municipal"),
    total_escolas = c(10L, 15L, 50L, 80L, 30L, 40L),
    total_matriculas = c(5000L, 8000L, 25000L, 40000L, 15000L, 20000L),
    total_docentes = c(200L, 300L, 1000L, 1500L, 600L, 800L),
    ideb_fund_i = c(5.2, 5.8, 6.1, 6.3, 4.9, 5.1),
    ideb_fund_ii = c(4.8, 5.2, 5.5, 5.8, 4.5, 4.7)
  )
}

test_that("redes() devolve eduBR_rede e filtra por municipio", {
  local_mocked_bindings(eduBR_tbl = fake_mv_rede_escolas_tbl)

  x <- redes("fake_con", municipio = "3555406")

  expect_s3_class(x, "eduBR_rede")
  expect_s3_class(x, "eduBR")
  expect_equal(nrow(as_tibble(x)), 2L)
  expect_equal(unique(as_tibble(x)$no_municipio), "Ubatuba")
})

test_that("rede_municipio() filtra por UF", {
  local_mocked_bindings(eduBR_tbl = fake_mv_rede_escolas_tbl)

  x <- rede_municipio("fake_con", uf = "SP")
  d <- as_tibble(x)

  expect_s3_class(x, "eduBR_rede")
  expect_true(all(d$sg_uf == "SP"))
  expect_equal(nrow(d), 4L)
})

test_that("rede_municipio() filtra por regiao (nome e sigla)", {
  local_mocked_bindings(eduBR_tbl = fake_mv_rede_escolas_tbl)

  ne_nome <- as_tibble(rede_municipio("fake_con", regiao = "Nordeste"))
  ne_sigla <- as_tibble(rede_municipio("fake_con", regiao = "NE"))

  expect_true(all(ne_nome$no_regiao == "Nordeste"))
  expect_true(all(ne_sigla$no_regiao == "Nordeste"))
  expect_equal(nrow(ne_nome), 2L)
})

test_that("rede_municipio() filtra por rede (codigo e nome)", {
  local_mocked_bindings(eduBR_tbl = fake_mv_rede_escolas_tbl)

  m_cod <- as_tibble(rede_municipio("fake_con", rede = 3L))
  m_nome <- as_tibble(rede_municipio("fake_con", rede = "Municipal"))
  pub <- as_tibble(rede_municipio("fake_con", rede = "publica"))

  expect_true(all(m_cod$codigo_rede == 3L))
  expect_true(all(m_nome$rede == "Municipal"))
  expect_true(all(pub$codigo_rede %in% 1:3))
  expect_false(any(pub$codigo_rede == 4L))
})

test_that("rede_municipio() combina filtros", {
  local_mocked_bindings(eduBR_tbl = fake_mv_rede_escolas_tbl)

  x <- as_tibble(rede_municipio("fake_con", uf = "BA", rede = "Estadual"))
  expect_equal(nrow(x), 1L)
  expect_equal(x$no_municipio, "Salvador")
  expect_equal(x$rede, "Estadual")
})

test_that("rede_municipio() erro em rede invalida", {
  local_mocked_bindings(eduBR_tbl = fake_mv_rede_escolas_tbl)

  expect_error(
    rede_municipio("fake_con", rede = "banana"),
    "rede inválida"
  )
})