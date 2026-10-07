test_that("catalogo() expoe as relacoes esperadas", {
  cat <- catalogo()

  expect_s3_class(cat, "data.frame")
  expect_named(cat, c("dominio", "schema", "tabela", "granularidade", "chave",
                     "tipo_chave", "coluna_ano", "anos"))
  expect_setequal(
    cat$dominio,
    c(
      "escolas", "municipios", "ibge", "populacao", "redes", "indicadores",
      "scores", "censo_escolas", "censo_docentes", "censo_matriculas",
      "censo_gestor",
      "ideb", "inse", "escola_features", "clusters", "similaridade"
    )
  )
})

test_that("catalogo() aponta para schema.tabela corretos", {
  cat <- catalogo()
  escolas <- cat[cat$dominio == "escolas", ]
  expect_equal(escolas$schema, "clean")
  expect_equal(escolas$tabela, "escolas")

  clusters <- cat[cat$dominio == "clusters", ]
  expect_equal(clusters$schema, "analytics")
  expect_equal(clusters$tabela, "clustering_metadata")
})

test_that("catalogo() informa chave, tipo e ano por dominio", {
  cat <- catalogo()
  expect_true(all(names(eduBR_catalogo()) %in% names(eduBR_catalogo_meta())))
  expect_false(anyNA(cat$chave))

  ideb <- cat[cat$dominio == "ideb", ]
  expect_equal(ideb$chave, "id_escola")
  expect_equal(ideb$tipo_chave, "bigint")
  expect_equal(ideb$coluna_ano, "ano")

  censo <- cat[cat$dominio == "censo_escolas", ]
  expect_equal(censo$coluna_ano, "nu_ano_censo")
  expect_equal(censo$anos, "2025")
})

test_that("catalogo() deixa NA nos metadados de relacao registrada", {
  withr::local_options(list(eduBR.catalogo.extra = list(
    minha = c("staging", "x"),
    ideb = c("staging", "ideb_teste")
  )))
  cat <- catalogo()
  expect_true(is.na(cat$chave[cat$dominio == "minha"]))
  expect_true(is.na(cat$chave[cat$dominio == "ideb"]))
})

test_that("eduBR_tbl() falha para relacao desconhecida", {
  expect_error(eduBR_tbl(NULL, "nao_existe"), "desconhecida")
})
