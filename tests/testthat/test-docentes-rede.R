# Fixtures para censo_docentes + censo_escolas

fake_censo_docentes_tbl <- function(con, nome) {
  if (nome != "censo_docentes") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  # 12 escolas, 2025, com variação em formação, vínculo, disciplina, demografia
  tibble::tibble(
    nu_ano_censo = rep(2025L, 12L),
    co_entidade = 1:12,
    qt_doc_bas = c(20L, 15L, 25L, 18L, 30L, 22L, 12L, 10L, 28L, 16L, 24L, 20L),
    qt_doc_bas_esco_ef = c(2L, 1L, 3L, 2L, 4L, 2L, 1L, 1L, 3L, 2L, 2L, 1L),
    qt_doc_bas_esco_em = c(5L, 4L, 6L, 4L, 8L, 5L, 3L, 2L, 7L, 4L, 5L, 4L),
    qt_doc_bas_esco_sup_grad = c(10L, 7L, 12L, 9L, 14L, 11L, 6L, 5L, 13L, 8L, 12L, 10L),
    qt_doc_bas_esco_sup_grad_licen = c(8L, 6L, 10L, 7L, 11L, 9L, 5L, 4L, 10L, 6L, 9L, 8L),
    qt_doc_bas_esco_sup_grad_slicen = c(2L, 1L, 2L, 2L, 3L, 2L, 1L, 1L, 3L, 2L, 3L, 2L),
    qt_doc_bas_esco_sup_pos_espec = c(4L, 3L, 5L, 4L, 6L, 4L, 2L, 2L, 5L, 3L, 4L, 4L),
    qt_doc_bas_esco_sup_pos_mestra = c(2L, 1L, 3L, 2L, 3L, 2L, 1L, 0L, 2L, 1L, 2L, 1L),
    qt_doc_bas_esco_sup_pos_douto = c(0L, 0L, 1L, 0L, 1L, 0L, 0L, 0L, 1L, 0L, 0L, 0L),
    qt_doc_bas_esco_sup_pos_nenhum = c(4L, 3L, 4L, 3L, 5L, 5L, 3L, 3L, 6L, 4L, 6L, 5L),
    qt_doc_bas_vinculo_concur = c(12L, 8L, 15L, 10L, 18L, 13L, 7L, 5L, 16L, 9L, 14L, 11L),
    qt_doc_bas_vinculo_contra = c(5L, 4L, 6L, 5L, 7L, 5L, 3L, 3L, 7L, 4L, 5L, 5L),
    qt_doc_bas_vinculo_terceir = c(2L, 2L, 2L, 2L, 3L, 2L, 1L, 1L, 3L, 2L, 3L, 2L),
    qt_doc_bas_vinculo_clt = c(1L, 1L, 2L, 1L, 2L, 2L, 1L, 1L, 2L, 1L, 2L, 2L),
    qt_doc_bas_disc_matematica = c(3L, 2L, 4L, 3L, 5L, 3L, 2L, 1L, 4L, 2L, 3L, 3L),
    qt_doc_bas_disc_lingua_port = c(3L, 2L, 4L, 3L, 5L, 3L, 2L, 1L, 4L, 2L, 3L, 3L),
    qt_doc_bas_disc_ciencias = c(2L, 1L, 3L, 2L, 3L, 2L, 1L, 1L, 3L, 2L, 2L, 2L),
    qt_doc_bas_fem = c(12L, 9L, 15L, 11L, 18L, 13L, 7L, 6L, 16L, 10L, 14L, 12L),
    qt_doc_bas_masc = c(8L, 6L, 10L, 7L, 12L, 9L, 5L, 4L, 12L, 6L, 10L, 8L),
    qt_doc_bas_branca = c(8L, 6L, 10L, 7L, 12L, 8L, 4L, 3L, 10L, 5L, 8L, 7L),
    qt_doc_bas_preta = c(3L, 2L, 4L, 3L, 5L, 4L, 2L, 2L, 5L, 3L, 4L, 4L),
    qt_doc_bas_parda = c(8L, 6L, 9L, 7L, 10L, 8L, 5L, 4L, 10L, 6L, 10L, 7L),
    qt_doc_bas_amarela = c(0L, 0L, 1L, 0L, 1L, 1L, 0L, 0L, 1L, 0L, 0L, 0L),
    qt_doc_bas_indigena = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_doc_bas_0_24 = c(1L, 1L, 2L, 1L, 2L, 2L, 1L, 0L, 2L, 1L, 2L, 1L),
    qt_doc_bas_25_29 = c(4L, 3L, 5L, 4L, 6L, 4L, 2L, 2L, 5L, 3L, 4L, 4L),
    qt_doc_bas_30_39 = c(7L, 5L, 9L, 6L, 10L, 7L, 4L, 3L, 9L, 5L, 8L, 6L),
    qt_doc_bas_40_49 = c(5L, 4L, 6L, 5L, 7L, 5L, 3L, 3L, 7L, 4L, 6L, 5L),
    qt_doc_bas_50_54 = c(2L, 1L, 2L, 1L, 3L, 2L, 1L, 1L, 2L, 2L, 2L, 2L),
    qt_doc_bas_55_59 = c(1L, 1L, 1L, 1L, 2L, 1L, 1L, 1L, 2L, 1L, 1L, 1L),
    qt_doc_bas_60_mais = c(0L, 0L, 0L, 0L, 0L, 1L, 0L, 0L, 0L, 0L, 1L, 1L),
    qt_doc_bas_pcd = c(0L, 0L, 1L, 0L, 1L, 0L, 0L, 0L, 1L, 0L, 0L, 0L)
  )
}

fake_censo_escolas_tbl <- function(con, nome) {
  if (nome != "censo_escolas") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  tibble::tibble(
    nu_ano_censo = rep(2025L, 12L),
    co_entidade = 1:12,
    tp_dependencia = c(3L, 3L, 2L, 3L, 2L, 1L, 3L, 3L, 2L, 3L, 4L, 4L),
    tp_localizacao = c(1L, 2L, 1L, 2L, 1L, 1L, 2L, 1L, 1L, 2L, 1L, 1L),
    sg_uf = c("SP", "SP", "BA", "BA", "RJ", "SP", "MG", "RS", "PR", "SC", "SP", "SP"),
    co_uf = c(35L, 35L, 29L, 29L, 33L, 35L, 31L, 43L, 41L, 42L, 35L, 35L),
    no_municipio = c("Ubatuba", "Ubatuba", "Salvador", "Salvador", "Rio de Janeiro",
                     "Campinas", "Belo Horizonte", "Porto Alegre", "Curitiba",
                     "Florianopolis", "São Paulo", "São Paulo"),
    co_municipio = c(3555406L, 3555406L, 2927408L, 2927408L, 3304557L,
                     3509502L, 3106200L, 4314902L, 4106902L, 4205407L,
                     3550308L, 3550308L)
  )
}

fake_eduBR_tbl <- function(con, nome) {
  switch(
    nome,
    censo_docentes = fake_censo_docentes_tbl(con, nome),
    censo_escolas = fake_censo_escolas_tbl(con, nome),
    stop(sprintf("fixture inesperada: %s", nome))
  )
}

test_that("docentes_rede() devolve eduBR_docentes_rede e agrega por municipio", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  x <- docentes_rede("fake_con", nivel = "municipio")

  expect_s3_class(x, "eduBR_docentes_rede")
  expect_s3_class(x, "eduBR")

  d <- as_tibble(x)
  expect_true(all(c("rede", "sg_uf", "co_municipio", "no_municipio",
                    "nome_regiao", "sigla_regiao", "localizacao") %in% names(d)))
  expect_true("qt_doc_bas" %in% names(d))
  expect_true("qt_doc_bas_esco_sup_grad" %in% names(d))
})

test_that("docentes_rede() agrega por diferentes niveis", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  mun <- as_tibble(docentes_rede("fake_con", nivel = "municipio"))
  uf <- as_tibble(docentes_rede("fake_con", nivel = "uf"))
  reg <- as_tibble(docentes_rede("fake_con", nivel = "regiao"))
  br <- as_tibble(docentes_rede("fake_con", nivel = "brasil"))

  expect_true("co_municipio" %in% names(mun))
  expect_false("co_municipio" %in% names(uf))
  expect_false("co_municipio" %in% names(reg))
  expect_false("co_municipio" %in% names(br))
  expect_true("rede" %in% names(br))
})

test_that("docentes_rede() filtra por rede", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  pub <- as_tibble(docentes_rede("fake_con", rede = "publica"))
  priv <- as_tibble(docentes_rede("fake_con", rede = "Privada"))
  cod <- as_tibble(docentes_rede("fake_con", rede = 2L))

  expect_false(any(pub$rede == "Privada"))
  expect_true(all(priv$rede == "Privada"))
  expect_true(all(cod$rede == "Estadual"))
})

test_that("docentes_rede() filtra por UF e regiao", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  sp <- as_tibble(docentes_rede("fake_con", uf = "SP"))
  ne <- as_tibble(docentes_rede("fake_con", regiao = "Nordeste"))

  expect_true(all(sp$sg_uf == "SP"))
  expect_true(all(ne$nome_regiao == "Nordeste"))
})

test_that("docentes_rede() filtra por localizacao", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  urb <- as_tibble(docentes_rede("fake_con", localizacao = "urbana"))
  rur <- as_tibble(docentes_rede("fake_con", localizacao = 2L))

  expect_true(all(urb$localizacao == "Urbana"))
  expect_true(all(rur$localizacao == "Rural"))
})

test_that("docentes_rede() projeta apenas colunas solicitadas", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  x <- docentes_rede("fake_con",
                     colunas = c("qt_doc_bas", "qt_doc_bas_esco_sup_grad",
                                 "qt_doc_bas_vinculo_concur"))
  d <- as_tibble(x)

  expect_true(all(c("qt_doc_bas", "qt_doc_bas_esco_sup_grad",
                    "qt_doc_bas_vinculo_concur") %in% names(d)))
  expect_false("qt_doc_bas_disc_matematica" %in% names(d))
})

test_that("docentes_rede() erro em rede invalida", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  expect_error(
    docentes_rede("fake_con", rede = "banana"),
    "rede inválida"
  )
})

test_that("docentes_rede() erro em localizacao invalida", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  expect_error(
    docentes_rede("fake_con", localizacao = 3),
    "localizacao inválida"
  )
})