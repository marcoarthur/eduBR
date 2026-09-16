# Fixtures em memoria para o acesso ao INSE e o cruzamento com o IDEB.

fake_inse_tbl <- function(con, nome) {
  if (nome != "inse") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  tibble::tibble(
    nu_ano_saeb        = c(2023L, 2023L, 2023L),
    sg_uf              = c("SP", "BA", "RS"),
    no_municipio       = c("Ubatuba", "Salvador", "Porto Alegre"),
    id_escola          = c(1, 2, 3),
    media_inse         = c(5.0, 4.0, 6.0),
    inse_classificacao = c("Nivel V", "Nivel III", "Nivel VII"),
    qtd_alunos_inse    = c(10L, 20L, 30L),
    tp_tipo_rede       = c(3L, 2L, 3L),
    tp_localizacao     = c(1L, 1L, 2L)
  )
}

fake_ideb_inse_tbl <- function(con, nome) {
  switch(
    nome,
    ideb = tibble::tibble(
      id_escola      = c(1, 1, 2, 3, 4),
      sg_uf          = c("SP", "SP", "BA", "RS", "SP"),
      no_municipio   = c("Ubatuba", "Ubatuba", "Salvador", "POA", "Ubatuba"),
      ano            = rep(2023L, 5),
      etapa          = c(
        "fundamental_i", "fundamental_ii", "fundamental_i",
        "fundamental_i", "fundamental_i"
      ),
      rede           = c(
        "Municipal", "Municipal", "Estadual", "Municipal", "Federal"
      ),
      ideb_observado = c(4.0, 4.5, 3.0, 5.0, 6.0)
    ),
    inse = tibble::tibble(
      id_escola          = c(1, 2, 3),
      nu_ano_saeb        = c(2023L, 2023L, 2023L),
      media_inse         = c(5.0, 4.0, 6.0),
      inse_classificacao = c("Nivel V", "Nivel III", "Nivel VII"),
      qtd_alunos_inse    = c(10L, 20L, 30L),
      tp_tipo_rede       = c(3L, 2L, 3L),
      tp_localizacao     = c(1L, 1L, 2L)
    ),
    stop(sprintf("fixture inesperada: %s", nome))
  )
}

test_that("inse() devolve eduBR_inse e aplica os filtros", {
  local_mocked_bindings(eduBR_tbl = fake_inse_tbl)

  x <- inse("fake_con")
  expect_s3_class(x, "eduBR_inse")
  expect_s3_class(x, "eduBR")
  expect_equal(nrow(as_tibble(x)), 3L)

  expect_equal(nrow(as_tibble(inse("fake_con", uf = "SP"))), 1L)
  expect_equal(nrow(as_tibble(inse("fake_con", municipio = "Salvador"))), 1L)
  expect_equal(nrow(as_tibble(inse("fake_con", ano = 2023L))), 3L)
  expect_equal(nrow(as_tibble(inse("fake_con", rede = 2L))), 1L)
  expect_equal(
    nrow(as_tibble(inse("fake_con", classificacao = "Nivel V"))), 1L
  )
})

test_that("ideb_inse() cruza IDEB x INSE e anexa a regiao", {
  local_mocked_bindings(eduBR_tbl = fake_ideb_inse_tbl)

  x <- ideb_inse("fake_con")

  expect_s3_class(x, "eduBR_ideb_inse")
  expect_s3_class(x, "eduBR")

  d <- as_tibble(x)
  expect_equal(nrow(d), 4L)
  expect_true("media_inse" %in% names(d))
  expect_true("inse_classificacao" %in% names(d))

  expect_equal(unique(d$nome_regiao[d$sg_uf == "BA"]), "Nordeste")
  expect_equal(unique(d$sigla_regiao[d$sg_uf == "RS"]), "S")

  # escola sem INSE (id 4) fica de fora do inner join
  expect_false(4 %in% d$id_escola)
})

test_that("ideb_inse() filtra por regiao e etapa", {
  local_mocked_bindings(eduBR_tbl = fake_ideb_inse_tbl)

  sudeste <- as_tibble(ideb_inse("fake_con", regiao = "Sudeste"))
  expect_equal(nrow(sudeste), 2L)
  expect_true(all(sudeste$sg_uf == "SP"))

  fund_ii <- as_tibble(ideb_inse("fake_con", etapa = "fundamental_ii"))
  expect_equal(nrow(fund_ii), 1L)
  expect_equal(fund_ii$id_escola, 1)
})
