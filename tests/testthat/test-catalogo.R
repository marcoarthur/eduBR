test_that("catalogo() expoe as relacoes esperadas", {
  cat <- catalogo()

  expect_s3_class(cat, "data.frame")
  expect_named(cat, c("dominio", "schema", "tabela"))
  expect_setequal(
    cat$dominio,
    c(
      "escolas", "municipios", "ibge", "populacao", "redes", "indicadores",
      "scores", "censo_escolas", "censo_docentes", "censo_matriculas",
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

test_that("eduBR_tbl() falha para relacao desconhecida", {
  expect_error(eduBR_tbl(NULL, "nao_existe"), "desconhecida")
})
