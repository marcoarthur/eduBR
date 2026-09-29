# Fixtures: 3 escolas no municipio 1 (SP) + 1 no municipio 2 (RJ).

fake_perfil_escolas <- tibble::tibble(
  nu_ano_censo = rep(2025L, 4L),
  co_entidade = c(11L, 12L, 13L, 21L),
  no_entidade = c("ESC A", "ESC B", "ESC C", "ESC D"),
  tp_dependencia = c(3L, 3L, 2L, 3L),
  tp_localizacao = c(1L, 1L, 2L, 1L),
  sg_uf = c("SP", "SP", "SP", "RJ"),
  no_municipio = c("Ubatuba", "Ubatuba", "Ubatuba", "Paraty"),
  co_municipio = c(1L, 1L, 1L, 2L),
  in_biblioteca = c(1L, 0L, 1L, 1L),
  in_internet = c(1L, 1L, 0L, 0L),
  in_quadra_esportes = c(0L, 0L, 1L, 1L)
)

fake_perfil_docentes <- tibble::tibble(
  nu_ano_censo = rep(2025L, 4L),
  co_entidade = c(11L, 12L, 13L, 21L),
  qt_doc_bas = c(20L, 10L, 30L, 15L)
)

fake_perfil_ideb <- tibble::tibble(
  id_escola = c(11L, 11L, 12L, 21L),
  co_municipio = c(1L, 1L, 1L, 2L),
  sg_uf = c("SP", "SP", "SP", "RJ"),
  etapa = c("fundamental_i", "fundamental_ii", "fundamental_ii", "fundamental_i"),
  ideb_observado = c(5.0, 6.0, 4.0, 7.0)
)

fake_perfil_tbl <- function(con, nome) {
  switch(
    nome,
    censo_escolas = fake_perfil_escolas,
    censo_docentes = fake_perfil_docentes,
    ideb = fake_perfil_ideb,
    stop(sprintf("fixture inesperada: %s", nome))
  )
}

test_that("perfil_escola() monta escola x municipio x estado", {
  local_mocked_bindings(eduBR_tbl = fake_perfil_tbl)

  p <- perfil_escola("fake_con", 11L)

  expect_s3_class(p, "eduBR_perfil_escola")
  expect_equal(p$perfil$nivel, c("escola", "municipio", "estado"))
  expect_equal(p$escola$nome, "ESC A")
  expect_equal(p$escola$rede, "Municipal")

  mun <- p$perfil[p$perfil$nivel == "municipio", , drop = FALSE]
  expect_equal(mun$n_escolas[[1L]], 3L)
  # 2 de 3 com biblioteca; média de docentes (20+10+30)/3
  expect_equal(mun$infra_in_biblioteca[[1L]], 2 / 3)
  expect_equal(mun$docentes[[1L]], 20)
  # IDEB fund II do município: só ESC A (6.0) e ESC B (4.0)
  expect_equal(mun$ideb_fund_ii[[1L]], 5.0)
  expect_true(is.na(mun$ideb_medio[[1L]]))
})

test_that("perfil_escola() erro em escola inexistente", {
  local_mocked_bindings(eduBR_tbl = fake_perfil_tbl)

  expect_error(perfil_escola("fake_con", 999L), "escola inexistente")
})

test_that("comparar() achata em tidy com diferenca", {
  local_mocked_bindings(eduBR_tbl = fake_perfil_tbl)

  cmp <- comparar(perfil_escola("fake_con", 11L))

  expect_s3_class(cmp, "tbl_df")
  expect_true(all(c("dimensao", "item", "escola", "municipio", "estado",
                    "dif_municipio") %in% names(cmp)))
  bib <- cmp[cmp$item == "Biblioteca", , drop = FALSE]
  expect_equal(bib$escola[[1L]], 1)
  expect_equal(bib$municipio[[1L]], 2 / 3)
  expect_equal(bib$dif_municipio[[1L]], 1 - 2 / 3)

  expect_error(comparar(data.frame()), "eduBR_perfil_escola")
})

test_that("print.eduBR_perfil_escola resume em PT-BR", {
  local_mocked_bindings(eduBR_tbl = fake_perfil_tbl)

  expect_output(print(perfil_escola("fake_con", 11L)), "ESC A")
  expect_output(print(perfil_escola("fake_con", 11L)), "Rede Municipal")
  expect_output(print(perfil_escola("fake_con", 11L)), "Biblioteca")
})
