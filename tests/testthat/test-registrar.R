# Registro em opção de sessão; restaura ao fim de cada teste.

com_opcao_limpa <- function(code) {
  antiga <- getOption("eduBR.catalogo.extra", list())
  on.exit(options(eduBR.catalogo.extra = antiga), add = TRUE)
  options(eduBR.catalogo.extra = list())
  code
}

test_that("registrar_relacao() expõe o domínio em catalogo()", {
  com_opcao_limpa({
    registrar_relacao("minha_base", "staging", "experimento_1")

    cat <- catalogo()
    linha <- cat[cat$dominio == "minha_base", , drop = FALSE]
    expect_equal(nrow(linha), 1L)
    expect_equal(linha$schema, "staging")
    expect_equal(linha$tabela, "experimento_1")
  })
})

test_that("customizado tem precedência e desregistrar restaura", {
  com_opcao_limpa({
    registrar_relacao("redes", "staging", "outra_rede")
    linha <- catalogo()
    linha <- linha[linha$dominio == "redes", , drop = FALSE]
    expect_equal(linha$schema, "staging")

    desregistrar_relacao("redes")
    base <- catalogo()
    base <- base[base$dominio == "redes", , drop = FALSE]
    expect_equal(base$schema, "analytics")
  })
})

test_that("eduBR_tbl() resolve o customizado antes do embutido", {
  com_opcao_limpa({
    registrar_relacao("minha_base", "staging", "experimento_1")
    expect_equal(
      eduBR_catalogo_extra()[["minha_base"]],
      c("staging", "experimento_1")
    )
    # desconhecido segue erro PT-BR
    expect_error(eduBR_tbl(NULL, "nao_existe"), "desconhecida")
  })
})

test_that("registrar_relacao() valida argumentos em PT-BR", {
  expect_error(registrar_relacao("", "staging", "t"), "nao vazia")
  expect_error(registrar_relacao("d", "", "t"), "nao vazia")
  expect_error(registrar_relacao("com espaco", "s", "t"), "espacos")
  expect_error(registrar_relacao(c("a", "b"), "s", "t"), "nao vazia")
})
