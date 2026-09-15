# Fixtures em memoria: mocka a resolucao do catalogo para evitar banco.
fake_ideb_tbl <- function(con, nome) {
  if (nome != "ideb") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  tibble::tibble(
    id_escola      = 1:8,
    sg_uf          = c("SP", "SP", "BA", "RS", "AM", "DF", "SE", "ZZ"),
    no_municipio   = c(
      "Ubatuba", "Campinas", "Salvador", "Porto Alegre",
      "Manaus", "Brasilia", "Aracaju", "Nada"
    ),
    ano            = c(2005L, 2019L, 2005L, 2019L, 2005L, 2019L, 2005L, 2019L),
    etapa          = c(
      "fundamental_i", "fundamental_ii", rep("fundamental_i", 6)
    ),
    rede           = c(
      "Municipal", "Estadual", "Municipal", "Estadual",
      "Municipal", "Federal", "Municipal", "Municipal"
    ),
    ideb_observado = c(4.0, 5.0, 3.0, 4.5, 3.5, 6.0, 2.5, 7.0)
  )
}

test_that("ideb_regiao() anexa nome e sigla da macrorregiao", {
  local_mocked_bindings(eduBR_tbl = fake_ideb_tbl)

  x <- ideb_regiao("fake_con")

  expect_s3_class(x, "eduBR_ideb_regiao")
  expect_s3_class(x, "eduBR")

  d <- as_tibble(x)
  regiao_de <- function(uf) {
    unique(d$nome_regiao[d$sg_uf == uf])
  }
  expect_equal(regiao_de("SP"), "Sudeste")
  expect_equal(regiao_de("BA"), "Nordeste")
  expect_equal(regiao_de("RS"), "Sul")
  expect_equal(regiao_de("AM"), "Norte")
  expect_equal(regiao_de("DF"), "Centro-oeste")
  expect_true(is.na(regiao_de("ZZ")))

  sigla_de <- function(uf) unique(d$sigla_regiao[d$sg_uf == uf])
  expect_equal(sigla_de("SP"), "SE")
  expect_equal(sigla_de("BA"), "NE")
  expect_equal(sigla_de("AM"), "N")
})

test_that("ideb_regiao() filtra por regiao (nome ou sigla)", {
  local_mocked_bindings(eduBR_tbl = fake_ideb_tbl)

  por_nome <- as_tibble(ideb_regiao("fake_con", regiao = "Sudeste"))
  expect_equal(nrow(por_nome), 2L)
  expect_true(all(por_nome$sg_uf == "SP"))

  por_sigla <- as_tibble(ideb_regiao("fake_con", regiao = "NE"))
  expect_setequal(por_sigla$sg_uf, c("BA", "SE"))

  case_insensitive <- as_tibble(ideb_regiao("fake_con", regiao = "sudeste"))
  expect_equal(nrow(case_insensitive), 2L)
})

test_that("ideb_regiao() aplica os demais filtros", {
  local_mocked_bindings(eduBR_tbl = fake_ideb_tbl)

  expect_equal(nrow(as_tibble(ideb_regiao("fake_con", uf = "SP"))), 2L)
  expect_equal(
    nrow(as_tibble(ideb_regiao("fake_con", etapa = "fundamental_ii"))), 1L
  )
  expect_equal(nrow(as_tibble(ideb_regiao("fake_con", ano = 2005L))), 4L)

  fed <- as_tibble(ideb_regiao("fake_con", rede = "Federal"))
  expect_equal(nrow(fed), 1L)
  expect_equal(fed$sg_uf, "DF")
})

test_that("ideb() agora filtra por uf, etapa, rede e ano", {
  local_mocked_bindings(eduBR_tbl = fake_ideb_tbl)

  x <- as_tibble(
    ideb("fake_con", uf = "SP", etapa = "fundamental_i", ano = 2005L)
  )
  expect_equal(nrow(x), 1L)
  expect_equal(x$id_escola, 1L)
})
