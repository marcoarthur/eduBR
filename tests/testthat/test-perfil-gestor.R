# Motor de perfil de gestores (perfil_gestor()).

# Fixture pequena (7 escolas) com contagens por dimensão.
fake_perfil <- function() {
  tibble::tibble(
    co_entidade = 1:7,
    nu_ano_censo = 2025L,
    tp_dependencia = c(3L, 3L, 2L, 2L, 1L, 4L, 4L),
    tp_categoria_escola_privada = c(NA, NA, NA, NA, NA, 1L, 4L),
    sg_uf = c("SP", "SP", "BA", "BA", "RS", "SP", "SP"),
    qt_gest_bas = c(2L, 1L, 2L, 1L, 1L, 1L, 2L),
    qt_gest_bas_fem = c(2L, 1L, 1L, 0L, 1L, 1L, 1L),
    qt_gest_bas_masc = c(0L, 0L, 1L, 1L, 0L, 0L, 1L),
    qt_gest_bas_nd = c(0L, 0L, 0L, 0L, 0L, 0L, 1L),
    qt_gest_bas_branca = c(2L, 0L, 1L, 0L, 1L, 1L, 0L),
    qt_gest_bas_preta = c(0L, 1L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_parda = c(0L, 0L, 1L, 1L, 0L, 0L, 1L),
    qt_gest_bas_amarela = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_indigena = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_esco_ef = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_esco_em = c(0L, 0L, 1L, 1L, 0L, 0L, 0L),
    qt_gest_bas_esco_sup_grad = c(2L, 1L, 1L, 0L, 1L, 1L, 2L),
    qt_gest_bas_esco_sup_pos_espec = c(1L, 1L, 1L, 0L, 1L, 0L, 1L),
    qt_gest_bas_esco_sup_pos_mestra = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_esco_sup_pos_douto = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_esco_sup_pos_nenhum = c(1L, 0L, 0L, 0L, 0L, 1L, 1L),
    qt_gest_bas_vinculo_concur = c(2L, 1L, 1L, 0L, 1L, 0L, 0L),
    qt_gest_bas_vinculo_contra = c(0L, 0L, 1L, 1L, 0L, 0L, 0L),
    qt_gest_bas_vinculo_terceir = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_vinculo_clt = c(0L, 0L, 0L, 0L, 0L, 1L, 0L),
    qt_gest_bas_acesso_cargo_prop = c(0L, 0L, 0L, 0L, 0L, 1L, 2L),
    qt_gest_bas_acesso_cargo_indic = c(0L, 1L, 2L, 0L, 0L, 0L, 0L),
    qt_gest_bas_acesso_cargo_sel = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_acesso_cargo_conca = c(2L, 0L, 0L, 0L, 1L, 0L, 0L),
    qt_gest_bas_acesso_cargo_eleic = c(0L, 0L, 0L, 1L, 0L, 0L, 0L),
    qt_gest_bas_acesso_cargo_p_sel = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_acesso_cargo_outro = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_pcd = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_espec_gestao = c(1L, 1L, 0L, 0L, 1L, 1L, 0L),
    qt_gest_bas_0_24 = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_25_29 = c(0L, 1L, 0L, 0L, 0L, 0L, 1L),
    qt_gest_bas_30_39 = c(1L, 0L, 1L, 1L, 1L, 0L, 0L),
    qt_gest_bas_40_49 = c(1L, 0L, 1L, 0L, 0L, 1L, 0L),
    qt_gest_bas_50_54 = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_55_59 = c(0L, 0L, 0L, 0L, 0L, 0L, 0L),
    qt_gest_bas_60_mais = c(0L, 0L, 0L, 0L, 0L, 0L, 0L)
  )
}

test_that("perfil_gestor() deriva o corte e agrega por gestor", {
  p <- perfil_gestor(fake_perfil(), corte = "rede", unidade = "gestor")

  expect_s3_class(p, "eduBR_perfil_gestor")
  expect_equal(p$corte, "rede")
  expect_equal(p$unidade, "gestor")
  expect_named(
    p$proporcoes,
    c("corte", "dimensao", "categoria", "n", "denom", "prop", "composicao")
  )

  modal <- p$modal

  municipal <- dplyr::filter(modal, .data$corte == "Municipal")
  expect_equal(
    municipal$categoria_modal[municipal$dimensao == "Sexo"], "Feminino"
  )
  expect_equal(
    municipal$prop_modal[municipal$dimensao == "Sexo"], 1, tolerance = 1e-9
  )
  expect_equal(
    municipal$categoria_modal[municipal$dimensao == "Escolaridade (maior concluída)"],
    "Superior (graduação)"
  )
  expect_equal(
    municipal$categoria_modal[municipal$dimensao == "Vínculo (escolas públicas)"],
    "Concursado/efetivo/estável"
  )

  estadual <- dplyr::filter(modal, .data$corte == "Estadual")
  expect_equal(
    estadual$categoria_modal[estadual$dimensao == "Forma de acesso ao cargo"],
    "Indicação/escolha da gestão"
  )
  expect_equal(
    estadual$prop_modal[estadual$dimensao == "Escolaridade (maior concluída)"],
    2 / 3, tolerance = 1e-9
  )

  privada <- dplyr::filter(modal, .data$corte == "Privada")
  expect_equal(
    privada$categoria_modal[privada$dimensao == "Forma de acesso ao cargo"],
    "Proprietário/sócio"
  )
  expect_equal(
    privada$prop_modal[privada$dimensao == "Forma de acesso ao cargo"],
    1, tolerance = 1e-9
  )
})

test_that("complemento (formação em gestão) fecha a dimensão no total", {
  p <- perfil_gestor(fake_perfil(), corte = "rede", dimensoes = "formacao_gestao")
  cols <- dplyr::filter(
    p$proporcoes,
    .data$corte == "Municipal" & .data$dimensao == "Formação continuada em gestão (≥80h)"
  )

  expect_equal(sum(cols$n), 3)  # total de gestores municipais
  expect_setequal(cols$categoria, c("Com formação em gestão", "Sem formação em gestão"))
  expect_equal(cols$prop[cols$categoria == "Com formação em gestão"], 2 / 3, tolerance = 1e-9)

  # Estadual: ninguém com formação em gestão → modal "Sem formação em gestão".
  est <- p$modal[p$modal$corte == "Estadual", ]
  expect_equal(est$categoria_modal, "Sem formação em gestão")
})

test_that("não declarada sai da composição e vínculo das privadas é ignorado", {
  p <- perfil_gestor(fake_perfil(), corte = "rede")

  cor <- dplyr::filter(
    p$proporcoes,
    .data$corte == "Privada" & .data$dimensao == "Cor/Raça"
  )
  comp <- dplyr::filter(cor, .data$composicao)
  nd <- dplyr::filter(cor, !.data$composicao)

  expect_true(all(nd$categoria == "Não declarada"))
  expect_equal(sum(comp$prop), 1, tolerance = 1e-9)
  expect_equal(comp$denom[1], 2)       # branca + parda
  expect_equal(nd$n[1], 1)             # uma gestora não declarou cor/raça

  vinculo_priv <- dplyr::filter(
    p$proporcoes,
    .data$corte == "Privada" & .data$dimensao == "Vínculo (escolas públicas)"
  )
  expect_equal(nrow(vinculo_priv), 0L)  # só se aplica a públicas

  modal_priv <- p$modal[p$modal$corte == "Privada", ]
  expect_false("Vínculo (escolas públicas)" %in% modal_priv$dimensao)
})

test_that("unidade escola pesa cada escola uma vez", {
  p <- perfil_gestor(fake_perfil(), corte = "rede", unidade = "escola")

  sexo <- dplyr::filter(
    p$proporcoes, .data$dimensao == "Sexo" & .data$corte == "Municipal"
  )
  expect_equal(sum(sexo$n), 2)  # duas escolas municipais
  expect_equal(sexo$prop[sexo$categoria == "Feminino"], 1, tolerance = 1e-9)

  est <- p$modal[p$modal$corte == "Estadual" & p$modal$dimensao == "Sexo", ]
  expect_equal(est$categoria_modal, "Feminino")  # desempate pela primeira
  expect_equal(est$prop_modal, 0.5, tolerance = 1e-9)

  # Concentração (Herfindahl) com duas categorias a 0.5.
  expect_equal(est$concentracao, 0.5, tolerance = 1e-9)
})

test_that("corte brasil e categoria_privada", {
  p <- perfil_gestor(fake_perfil(), corte = "brasil")
  expect_equal(p$n$corte, "Brasil")
  expect_equal(p$n$n_gestores, 10)
  expect_equal(p$n$n_escolas, 7)

  pc <- perfil_gestor(fake_perfil(), corte = "categoria_privada")
  expect_setequal(pc$n$corte, c("Particular", "Filantrópica"))
  expect_equal(sum(pc$n$n_escolas), 2L)
})

test_that("perfil_gestor() valida entradas", {
  expect_error(
    perfil_gestor(dplyr::select(fake_perfil(), -sg_uf), corte = "uf"),
    "sg_uf"
  )
  expect_error(perfil_gestor(fake_perfil(), corte = "estado"), "corte")
  expect_error(
    perfil_gestor(fake_perfil(), dimensoes = "idade"),
    "dimensões desconhecidas"
  )
})

test_that("print.eduBR_perfil_gestor() é compacto", {
  p <- perfil_gestor(fake_perfil())
  expect_output(print(p), "eduBR_perfil_gestor")
  expect_output(print(p), "Sexo")
})