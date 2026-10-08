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
  in_quadra_esportes = c(0L, 0L, 1L, 1L),
  in_comum_fund_ai = c(1L, 1L, 0L, 1L),
  in_comum_fund_af = c(1L, 0L, 1L, 0L)
)

fake_perfil_matriculas <- tibble::tibble(
  nu_ano_censo = rep(2025L, 4L),
  co_entidade = c(11L, 12L, 13L, 21L),
  qt_mat_bas = c(1200L, 300L, 800L, 150L)
)

fake_perfil_docentes <- tibble::tibble(
  nu_ano_censo = rep(2025L, 4L),
  co_entidade = c(11L, 12L, 13L, 21L),
  qt_doc_bas = c(20L, 10L, 30L, 15L)
)

# ESC A tem fund. I em 2021 e 2023; ESC C (Estadual) só entra na rede dela.
fake_perfil_ideb <- tibble::tibble(
  id_escola = c(11L, 11L, 11L, 12L, 12L, 13L, 21L),
  co_municipio = c(1L, 1L, 1L, 1L, 1L, 1L, 2L),
  sg_uf = c("SP", "SP", "SP", "SP", "SP", "SP", "RJ"),
  rede = c("Municipal", "Municipal", "Municipal", "Municipal", "Municipal",
           "Estadual", "Municipal"),
  ano = c(2023L, 2021L, 2023L, 2023L, 2021L, 2023L, 2023L),
  etapa = c("fundamental_i", "fundamental_i", "fundamental_ii",
            "fundamental_ii", "fundamental_i", "fundamental_i", "fundamental_i"),
  ideb_observado = c(5.0, 3.0, 6.0, 4.0, 9.0, 1.0, 7.0)
)

fake_perfil_tbl <- function(con, nome) {
  switch(
    nome,
    censo_escolas = fake_perfil_escolas,
    censo_docentes = fake_perfil_docentes,
    censo_matriculas = fake_perfil_matriculas,
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

test_that("perfil_escola() compara IDEB na mesma edição e rede", {
  local_mocked_bindings(eduBR_tbl = fake_perfil_tbl)

  p <- perfil_escola("fake_con", 11L)
  esc <- p$perfil[p$perfil$nivel == "escola", , drop = FALSE]
  mun <- p$perfil[p$perfil$nivel == "municipio", , drop = FALSE]
  est <- p$perfil[p$perfil$nivel == "estado", , drop = FALSE]

  # Edição mais recente da escola (2023), sem média com 2021.
  expect_equal(p$ano_ideb[["fundamental_i"]], 2023L)
  expect_true(is.na(p$ano_ideb[["ensino_medio"]]))
  expect_equal(esc$ideb_fund_i[[1L]], 5.0)
  # Município/UF: só rede Municipal em 2023 (exclui ESC B 2021 e ESC C).
  expect_equal(mun$ideb_fund_i[[1L]], 5.0)
  expect_equal(est$ideb_fund_i[[1L]], 5.0)

  p21 <- perfil_escola("fake_con", 11L, ano_ideb = 2021L)
  mun21 <- p21$perfil[p21$perfil$nivel == "municipio", , drop = FALSE]
  expect_equal(p21$perfil$ideb_fund_i[[1L]], 3.0)
  expect_equal(mun21$ideb_fund_i[[1L]], 6.0)

  cmp <- comparar(p)
  expect_true("IDEB fund. I (2023)" %in% cmp$item)
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

test_that("perfil_escola() guarda etapas, porte e série do IDEB", {
  local_mocked_bindings(eduBR_tbl = fake_perfil_tbl)

  p <- perfil_escola("fake_con", 11L)

  expect_equal(p$escola$etapas, c("Fund. I", "Fund. II"))
  expect_equal(p$escola$matriculas, 1200)
  expect_equal(p$escola$localizacao, "Urbana")
  expect_equal(p$ideb_serie$ano[p$ideb_serie$etapa == "fundamental_i"],
               c(2021L, 2023L))

  out <- capture.output(print(p))
  expect_true(any(grepl("Fund. I, Fund. II", out, fixed = TRUE)))
  expect_true(any(grepl("1.200 matr", out, fixed = TRUE)))
  expect_true(any(grepl("em 2021: 3 (+2,0)", out, fixed = TRUE)))
})

test_that("resumo_escola() devolve uma linha com IDEB e variação", {
  local_mocked_bindings(eduBR_tbl = fake_perfil_tbl)

  r <- resumo_escola(perfil_escola("fake_con", 11L))

  expect_equal(nrow(r), 1L)
  expect_equal(r$escola, "ESC A")
  expect_equal(r$rede, "Municipal")
  expect_equal(r$etapas, "Fund. I, Fund. II")
  expect_equal(r$docentes, 20)
  expect_equal(r$ideb_fund_i, 5.0)
  expect_equal(r$ano_fund_i, 2023L)
  expect_equal(r$var_fund_i, 2.0)
  # fund. II só tem 2023: sem variação
  expect_equal(r$ideb_fund_ii, 6.0)
  expect_true(is.na(r$var_fund_ii))
  expect_true(is.na(r$ideb_medio))

  expect_error(resumo_escola(list()), "eduBR_perfil_escola")
})

test_that("perfil_escola() conta só escolas em atividade no município", {
  com_inativa <- function(con, nome) {
    d <- fake_perfil_tbl(con, nome)
    if (nome == "censo_escolas") {
      d$tp_situacao_funcionamento <- c(1L, 1L, 2L, 1L)
    }
    d
  }
  local_mocked_bindings(eduBR_tbl = com_inativa)

  mun <- perfil_escola("fake_con", 11L)$perfil
  mun <- mun[mun$nivel == "municipio", , drop = FALSE]
  expect_equal(mun$n_escolas[[1L]], 2L)
  expect_equal(mun$infra_in_biblioteca[[1L]], 1 / 2)
})

test_that("exportar() grava CSV em PT-BR (;, vírgula decimal, BOM)", {
  local_mocked_bindings(eduBR_tbl = fake_perfil_tbl)
  p <- perfil_escola("fake_con", 11L)
  arq <- withr::local_tempfile(fileext = ".csv")

  expect_equal(exportar(p, arq), arq)

  bytes <- readBin(arq, "raw", 3L)
  expect_equal(bytes, as.raw(c(0xef, 0xbb, 0xbf)))
  linhas <- readLines(arq, encoding = "UTF-8")
  expect_match(linhas[[1L]], "\"Escola\";", fixed = TRUE)
  expect_match(linhas[[1L]], "Munic\u00edpio", fixed = TRUE)
  lido <- utils::read.csv2(arq, fileEncoding = "UTF-8-BOM", check.names = FALSE)
  expect_equal(nrow(lido), nrow(comparar(p)))
  bib <- lido[lido$Item == "Biblioteca", , drop = FALSE]
  expect_equal(bib[["M\u00e9dia do munic\u00edpio"]], 0.667)
  expect_true(any(grepl("0,6", linhas, fixed = TRUE)))
})

test_that("exportar() grava xlsx com duas abas e valida entradas", {
  local_mocked_bindings(eduBR_tbl = fake_perfil_tbl)
  p <- perfil_escola("fake_con", 11L)

  expect_error(exportar(p, "x.txt"), ".csv ou .xlsx")
  expect_error(exportar(list(), "x.csv"), "eduBR_perfil_escola")

  skip_if_not_installed("writexl")
  arq <- withr::local_tempfile(fileext = ".xlsx")
  exportar(p, arq)
  expect_equal(readBin(arq, "raw", 2L), charToRaw("PK"))
  abas <- utils::unzip(arq, list = TRUE)$Name
  expect_equal(sum(grepl("^xl/worksheets/sheet", abas)), 2L)
})
