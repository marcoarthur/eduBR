# Fixtures dos microdados de gestor (imita clean.censo_gestor + censo_escolas).

fake_censo_gestor_tbl <- function(con, nome) {
  if (nome != "censo_gestor") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  tibble::tibble(
    nu_ano_censo = rep(2025L, 12L),
    co_entidade = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12),
    qt_gest_bas = c(2L, 1L, 2L, 1L, 2L, 1L, 2L, 1L, 3L, 1L, 1L, 1L),
    qt_gest_bas_fem = c(2L, 1L, 1L, 0L, 1L, 0L, 2L, 1L, 1L, 1L, 0L, 1L),
    qt_gest_bas_masc = c(0L, 0L, 1L, 1L, 1L, 1L, 0L, 0L, 2L, 0L, 1L, 0L),
    qt_gest_bas_nd = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L),
    qt_gest_bas_branca = c(2L, 1L, 1L, 0L, 1L, 0L, 0L, 1L, 2L, 0L, 1L, 0L),
    qt_gest_bas_preta = c(0L, 0L, 1L, 0L, 0L, 1L, 1L, 0L, 0L, 1L, 0L, 0L),
    qt_gest_bas_parda = c(0L, 0L, 0L, 1L, 0L, 0L, 1L, 0L, 1L, 0L, 0L, 0L),
    qt_gest_bas_amarela = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_indigena = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_esco_ef = c(0L, 0L, 0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_esco_em = c(0L, 0L, 1L, 0L, 1L, 0L, 0L, 0L, 0L, 0L, 1L, 0L),
    qt_gest_bas_esco_sup_grad = c(2L, 1L, 1L, 0L, 1L, 1L, 2L, 1L, 3L, 1L, 0L, 1L),
    qt_gest_bas_vinculo_concur = c(2L, 1L, 1L, 0L, 2L, 0L, 2L, 1L, 3L, 0L, 0L, 0L),
    qt_gest_bas_vinculo_contra = c(0L, 0L, 1L, 0L, 0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_vinculo_terceir = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_vinculo_clt = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, 1L),
    qt_gest_bas_diretor = c(2L, 1L, 2L, 1L, 2L, 1L, 2L, 1L, 3L, 1L, 1L, 1L),
    qt_gest_bas_outro = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_acesso_cargo_prop = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, 1L),
    qt_gest_bas_acesso_cargo_indic = c(0L, 1L, 1L, 1L, 0L, 0L, 2L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_acesso_cargo_sel = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_acesso_cargo_conca = c(2L, 0L, 1L, 0L, 2L, 0L, 0L, 1L, 3L, 0L, 0L, 0L),
    qt_gest_bas_acesso_cargo_eleic = c(0L, 0L, 0L, 0L, 0L, 1L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_acesso_cargo_p_sel = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 1L, 0L, 0L),
    qt_gest_bas_acesso_cargo_outro = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_pcd = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_espec_gestao = c(1L, 1L, 2L, 0L, 0L, 1L, 1L, 1L, 0L, 1L, 0L, 0L),
    qt_gest_bas_0_24 = c(0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L)
  )
}

fake_censo_escolas_tbl <- function(con, nome) {
  if (nome != "censo_escolas") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  tibble::tibble(
    nu_ano_censo = rep(2025L, 12L),
    co_entidade = c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12),
    tp_dependencia = c(3L, 3L, 2L, 3L, 3L, 2L, 1L, 3L, 2L, 3L, 4L, 4L),
    tp_categoria_escola_privada = c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, 1L, 4L),
    tp_localizacao = c(1L, 1L, 2L, 2L, 1L, 1L, 1L, 2L, 1L, 1L, 1L, 1L),
    sg_uf = c("SP", "SP", "BA", "BA", "RS", "RS", "SP", "MG", "PR", "PR", "SP", "SP"),
    co_uf = c(35L, 35L, 29L, 29L, 43L, 43L, 35L, 31L, 41L, 41L, 35L, 35L),
    no_municipio = c("Ubatuba", "Ubatuba", "Salvador", "Salvador",
                     "Porto Alegre", "Porto Alegre", "Ubatuba", "BH",
                     "Curitiba", "Curitiba", "SP", "SP"),
    co_municipio = c(3555406L, 3555406L, 2927408L, 2927408L, 4314902L,
                     4314902L, 3555406L, 3106200L, 4106902L, 4106902L,
                     3550308L, 3550308L)
  )
}

fake_eduBR_tbl <- function(con, nome) {
  switch(
    nome,
    censo_gestor = fake_censo_gestor_tbl(con, nome),
    censo_escolas = fake_censo_escolas_tbl(con, nome),
    stop(sprintf("fixture inesperada: %s", nome))
  )
}

test_that("censo_gestor() devolve eduBR_censo e filtra", {
  local_mocked_bindings(eduBR_tbl = fake_censo_gestor_tbl)

  x <- censo_gestor("fake_con")
  expect_s3_class(x, "eduBR_censo")
  expect_s3_class(x, "eduBR")
  expect_equal(nrow(as_tibble(x)), 12L)

  expect_equal(nrow(as_tibble(censo_gestor("fake_con", escola_id = 3))), 1L)
  expect_equal(nrow(as_tibble(censo_gestor("fake_con", ano = 2026))), 0L)
})

test_that("gestores() cruza com as escolas e anexa rede, regiao e localizacao", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  x <- gestores("fake_con")
  expect_s3_class(x, "eduBR_gestores")

  d <- as_tibble(x)
  expect_equal(nrow(d), 12L)
  expect_true(all(c("rede", "nome_regiao", "sigla_regiao", "localizacao",
                    "categoria_privada", "tp_dependencia") %in% names(d)))
  expect_true("no_municipio" %in% names(d))
  expect_true("no_municipio" %in% names(d))

  expect_equal(unique(d$rede[d$tp_dependencia == 1]), "Federal")
  expect_equal(unique(d$rede[d$tp_dependencia == 4]), "Privada")
  expect_equal(unique(d$rede[d$tp_dependencia == 3]), "Municipal")
  expect_equal(unique(d$nome_regiao[d$sg_uf == "BA"]), "Nordeste")
  expect_equal(unique(d$categoria_privada[d$tp_dependencia == 4]), c("Particular", "Filantrópica"))
})

test_that("gestores() aplica os filtros de rede, uf, regiao e localizacao", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  apenas_publicas <- as_tibble(gestores("fake_con", rede = "publica"))
  expect_false(any(apenas_publicas$tp_dependencia == 4L))
  expect_equal(apenas_publicas$tp_dependencia |> unique() |> sort(), 1:3)

  privadas <- as_tibble(gestores("fake_con", rede = "Privada"))
  expect_true(all(privadas$tp_dependencia == 4L))

  sp <- as_tibble(gestores("fake_con", uf = "SP"))
  expect_true(all(sp$sg_uf == "SP"))

  nordeste <- as_tibble(gestores("fake_con", regiao = "Nordeste"))
  expect_setequal(unique(nordeste$sg_uf), "BA")

  rural <- as_tibble(gestores("fake_con", localizacao = "rural"))
  expect_true(all(rural$tp_localizacao == 2L))

  expect_error(gestores("fake_con", rede = "banana"), "rede inválida")
  expect_error(gestores("fake_con", localizacao = 3), "localizacao inválida")
})

test_that("gestores() alimenta perfil_gestor() ponta a ponta", {
  local_mocked_bindings(eduBR_tbl = fake_eduBR_tbl)

  p <- perfil_gestor(gestores("fake_con"), corte = "rede", dimensoes = "sexo")
  expect_s3_class(p, "eduBR_perfil_gestor")
  expect_setequal(p$n$corte, c("Federal", "Estadual", "Municipal", "Privada"))
  expect_equal(sum(p$n$n_gestores), 18)

  sexo <- dplyr::filter(p$modal, .data$dimensao == "Sexo")
  expect_true(all(c("Feminino", "Masculino") %in% sexo$categoria_modal))
})