# Tools de escola da camada ellmer (chunk 2): contrato, validação antes do
# banco, perfil com contexto/ofertada, sem PII/geometria/schema.tabela e
# filtro por persona. Sem banco: funções do pacote mockadas com fixtures.

skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")

tools_escola <- c("perfil_escola", "resumo_escola", "serie_ideb_escola",
                  "escolas_similares", "scores_escola", "indicadores_escola")

# Executa uma tool e devolve list(json, env).
chamar_json <- function(tool, ...) {
  json <- tool(...)
  expect_type(json, "character")
  expect_length(json, 1L)
  expect_true(jsonlite::validate(json))
  list(json = json, env = eduBR_envelope_de(json))
}

# Nenhuma coluna PII/geometria nos registros e nenhum schema.tabela no JSON.
expect_sem_vazamento <- function(json, env) {
  for (reg in env$dados) {
    expect_false(any(names(reg) %in% c(eduBR_colunas_pii(), "geometry", "geom")))
  }
  expect_false(grepl("clean.", json, fixed = TRUE))
  expect_false(grepl("analytics.", json, fixed = TRUE))
  rel <- eduBR_relacoes_fisicas()
  for (i in seq_len(nrow(rel))) {
    expect_false(grepl(paste0(rel$schema[i], ".", rel$tabela[i]), json,
                       fixed = TRUE))
  }
}

# Fixtures do perfil: ESC A (11000011) oferta só fund. I no Censo 2025, mas
# tem IDEB de fund. II em 2023 (ofertada = FALSE nessa linha).
fx_escolas <- tibble::tibble(
  nu_ano_censo = rep(2025L, 3L),
  co_entidade = c(11000011, 11000012, 21000021),
  no_entidade = c("ESC A", "ESC B", "ESC D"),
  tp_dependencia = c(3L, 3L, 3L),
  tp_localizacao = c(1L, 2L, 1L),
  tp_situacao_funcionamento = c(1L, 1L, 1L),
  sg_uf = c("SP", "SP", "RJ"),
  no_municipio = c("Ubatuba", "Ubatuba", "Paraty"),
  co_municipio = c(1L, 1L, 2L),
  ds_endereco = c("RUA X, 1", "RUA Y, 2", "RUA Z, 3"),
  nu_telefone = c("1299999", "1288888", "2477777"),
  in_biblioteca = c(1L, 0L, 1L),
  in_internet = c(1L, 1L, 0L),
  in_comum_fund_ai = c(1L, 1L, 1L),
  in_comum_fund_af = c(0L, 1L, 0L)
)
fx_matriculas <- tibble::tibble(
  nu_ano_censo = 2025L, co_entidade = c(11000011, 11000012, 21000021),
  qt_mat_bas = c(400L, 300L, 150L)
)
fx_docentes <- tibble::tibble(
  nu_ano_censo = 2025L, co_entidade = c(11000011, 11000012, 21000021),
  qt_doc_bas = c(20L, 10L, 15L)
)
fx_ideb <- tibble::tibble(
  id_escola = c(11000011, 11000011, 11000011, 11000012, 21000021),
  co_municipio = c(1L, 1L, 1L, 1L, 2L),
  sg_uf = c("SP", "SP", "SP", "SP", "RJ"),
  rede = "Municipal",
  ano = c(2021L, 2023L, 2023L, 2023L, 2023L),
  etapa = c("fundamental_i", "fundamental_i", "fundamental_ii",
            "fundamental_ii", "fundamental_i"),
  ideb_observado = c(4.0, 5.0, 4.5, 3.5, 6.0),
  nota_media = c(5.1, 5.4, 4.9, 4.2, 6.1)
)
fx_tbl <- function(con, nome) {
  switch(
    nome,
    censo_escolas = fx_escolas,
    censo_docentes = fx_docentes,
    censo_matriculas = fx_matriculas,
    ideb = fx_ideb,
    stop(sprintf("fixture inesperada: %s", nome))
  )
}

test_that("contrato: tools de escola registradas com argumentos", {
  tools <- ferramentas_edubr("fake_con")
  expect_true(all(tools_escola %in% names(tools)))
  for (nm in tools_escola) {
    expect_true(inherits(tools[[nm]], "ellmer::ToolDef"))
    expect_identical(tools[[nm]]@name, nm)
    expect_gt(nchar(tools[[nm]]@description), 200L)
  }
  args <- function(nm) names(formals(tools[[nm]]))
  expect_identical(args("perfil_escola"), c("escola_id", "ano_ideb"))
  expect_identical(args("resumo_escola"), c("escola_id", "ano_ideb"))
  expect_identical(args("serie_ideb_escola"), c("escola_id", "etapa"))
  expect_identical(args("escolas_similares"),
                   c("escola_id", "n", "etapa", "publica"))
  expect_identical(args("scores_escola"), "escola_id")
  expect_identical(args("indicadores_escola"), c("escola_id", "indicador"))
})

test_that("validação: parametro_invalido sem chegar ao pacote", {
  chamadas <- 0L
  conta <- function(...) {
    chamadas <<- chamadas + 1L
    stop("não deveria ser chamada")
  }
  local_mocked_bindings(
    perfil_escola = conta, escolas_similares = conta, ideb = conta,
    scores = conta, indicadores = conta
  )
  tools <- ferramentas_edubr("fake_con")

  casos <- list(
    list(tools$perfil_escola, list(escola_id = "123"), "8 dígitos"),
    list(tools$perfil_escola, list(escola_id = "1307807a"), "escola_id"),
    list(tools$perfil_escola, list(), "obrigatório"),
    list(tools$perfil_escola, list(escola_id = "13078070", ano_ideb = 2024L),
         "bienal"),
    list(tools$resumo_escola, list(escola_id = "13 078 070"), "escola_id"),
    list(tools$serie_ideb_escola, list(escola_id = "13078070", etapa = "medio"),
         "ensino_medio"),
    list(tools$escolas_similares, list(escola_id = "13078070", n = 50L), "20"),
    list(tools$escolas_similares, list(escola_id = "13078070", n = 0L), "`n`"),
    list(tools$escolas_similares,
         list(escola_id = "13078070", etapa = "infantil"), "etapa"),
    list(tools$escolas_similares,
         list(escola_id = "13078070", publica = "sim"), "publica"),
    list(tools$scores_escola, list(escola_id = 123), "escola_id"),
    list(tools$indicadores_escola,
         list(escola_id = "13078070", indicador = ""), "indicador")
  )
  for (cs in casos) {
    r <- chamar_json(function() do.call(cs[[1]], cs[[2]]))
    expect_equal(r$env$erro$tipo, "parametro_invalido")
    expect_match(r$env$erro$mensagem, cs[[3]], fixed = TRUE)
    expect_length(r$env$dados, 0L)
  }
  expect_equal(chamadas, 0L)
  expect_true(all(ledger(tools)$erro == "parametro_invalido"))
})

test_that("perfil_escola: comparação, contexto e ofertada", {
  local_mocked_bindings(eduBR_tbl = fx_tbl)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$perfil_escola, escola_id = "11000011")
  env <- r$env
  expect_null(env$erro)
  expect_sem_vazamento(r$json, env)
  expect_false(grepl("RUA X", r$json, fixed = TRUE))
  expect_false(grepl("1299999", r$json, fixed = TRUE))

  nomes <- names(env$dados[[1]])
  expect_identical(nomes, c("dimensao", "item", "escola", "municipio",
                            "estado", "dif_municipio", "ofertada"))
  itens <- vapply(env$dados, `[[`, character(1), "item")
  expect_true("Biblioteca" %in% itens)
  ideb_i <- env$dados[[which(itens == "IDEB fund. I (2023)")]]
  expect_equal(ideb_i$escola, 5.0)
  expect_true(ideb_i$ofertada)
  ideb_ii <- env$dados[[which(itens == "IDEB fund. II (2023)")]]
  expect_false(ideb_ii$ofertada)
  bib <- env$dados[[which(itens == "Biblioteca")]]
  expect_null(bib$ofertada)
  expect_equal(bib$municipio, 0.5)

  ctx <- env$metadados$contexto
  expect_equal(ctx$codigo_inep, "11000011")
  expect_equal(ctx$nome, "ESC A")
  expect_equal(ctx$rede, "Municipal")
  expect_equal(ctx$municipio, "Ubatuba")
  expect_equal(ctx$uf, "SP")
  expect_equal(ctx$localizacao, "Urbana")
  expect_equal(unlist(ctx$etapas_ofertadas), "Fund. I")
  expect_equal(ctx$matriculas, 400)
  expect_equal(ctx$ano_censo, 2025L)
  expect_equal(ctx$edicao_ideb$fundamental_i, 2023L)
  expect_equal(ctx$edicao_ideb$fundamental_ii, 2023L)
  expect_true("ensino_medio" %in% names(ctx$edicao_ideb))
  expect_null(ctx$edicao_ideb$ensino_medio)
  expect_false(ctx$ideb_etapa_ofertada$fundamental_ii)
  expect_equal(env$metadados$filtros$escola_id, "11000011")

  # edição fixa
  r21 <- chamar_json(tools$perfil_escola, escola_id = "11000011",
                     ano_ideb = 2021L)
  expect_equal(r21$env$metadados$contexto$edicao_ideb$fundamental_i, 2021L)

  # escola fora do Censo -> sem_dados
  r0 <- chamar_json(tools$perfil_escola, escola_id = "99999999")
  expect_equal(r0$env$erro$tipo, "sem_dados")
  expect_match(r0$env$erro$mensagem, "99999999", fixed = TRUE)
})

test_that("envelope sem contexto continua igual (retrocompatível)", {
  env <- eduBR_envelope(dados = list())
  expect_false("contexto" %in% names(env$metadados))
  env <- eduBR_envelope(dados = list(), contexto = list(nome = "X"))
  expect_equal(env$metadados$contexto$nome, "X")
  res <- eduBR_resultado(tibble::tibble(a = 1), contexto = list(nome = "X"))
  expect_equal(res$contexto$nome, "X")
})

test_that("resumo_escola: uma linha com variação do IDEB", {
  local_mocked_bindings(eduBR_tbl = fx_tbl)
  tools <- ferramentas_edubr("fake_con")
  r <- chamar_json(tools$resumo_escola, escola_id = "11000011")
  expect_null(r$env$erro)
  expect_sem_vazamento(r$json, r$env)
  expect_length(r$env$dados, 1L)
  reg <- r$env$dados[[1]]
  expect_equal(reg$codigo_inep, "11000011")
  expect_equal(reg$ideb_fund_i, 5.0)
  expect_equal(reg$var_fund_i, 1.0)
  expect_equal(reg$ano_fund_i, 2023L)
  expect_false(reg$oferta_fund_ii)
  expect_null(reg$ideb_medio)
})

test_that("serie_ideb_escola: colunas e ordem", {
  fake_ideb <- function(con, escola_id = NULL, etapa = NULL, ...) {
    d <- fx_ideb[as.character(fx_ideb$id_escola) == escola_id, , drop = FALSE]
    if (!is.null(etapa)) d <- d[d$etapa == etapa, , drop = FALSE]
    d <- d[rev(seq_len(nrow(d))), , drop = FALSE]
    new_eduBR(d, "eduBR_ideb", con, list())
  }
  local_mocked_bindings(ideb = fake_ideb)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$serie_ideb_escola, escola_id = "11000011")
  expect_null(r$env$erro)
  expect_sem_vazamento(r$json, r$env)
  expect_identical(names(r$env$dados[[1]]),
                   c("etapa", "ano", "ideb_observado", "nota_media"))
  et <- vapply(r$env$dados, `[[`, character(1), "etapa")
  an <- vapply(r$env$dados, `[[`, integer(1), "ano")
  expect_identical(et, c("fundamental_i", "fundamental_i", "fundamental_ii"))
  expect_identical(an, c(2021L, 2023L, 2023L))

  r <- chamar_json(tools$serie_ideb_escola, escola_id = "11000011",
                   etapa = "fundamental_ii")
  expect_length(r$env$dados, 1L)
  expect_equal(r$env$metadados$filtros$etapa, "fundamental_ii")
})

test_that("escolas_similares: repassa argumentos e esconde PII", {
  recebido <- NULL
  fake_sim <- function(con, codigo_inep, n = 5L, etapa = NULL, publica = TRUE) {
    recebido <<- list(codigo_inep = codigo_inep, n = n, etapa = etapa,
                      publica = publica)
    tibble::tibble(
      co_entidade = sprintf("2100%04d", seq_len(n)),
      escola = paste("ESC", seq_len(n)),
      municipio = "Paraty", uf = "RJ", rede = "Municipal",
      etapa = "fundamental_i", distancia = seq_len(n) / 10,
      nu_telefone = "2477777"
    )
  }
  local_mocked_bindings(escolas_similares = fake_sim)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$escolas_similares, escola_id = "11000011")
  expect_null(r$env$erro)
  expect_sem_vazamento(r$json, r$env)
  expect_equal(recebido, list(codigo_inep = "11000011", n = 5L, etapa = NULL,
                              publica = TRUE))
  expect_length(r$env$dados, 5L)
  expect_identical(names(r$env$dados[[1]]),
                   c("co_entidade", "escola", "municipio", "uf", "rede",
                     "etapa", "distancia"))
  expect_false(grepl("2477777", r$json, fixed = TRUE))

  r <- chamar_json(tools$escolas_similares, escola_id = "11000011", n = 20,
                   etapa = "fundamental_i", publica = FALSE)
  expect_null(r$env$erro)
  expect_equal(recebido$n, 20L)
  expect_equal(recebido$etapa, "fundamental_i")
  expect_false(recebido$publica)
  expect_length(r$env$dados, 20L)
})

test_that("scores_escola e indicadores_escola", {
  fake_scores <- function(con, escola_id = NULL) {
    new_eduBR(
      tibble::tibble(
        nu_ano_censo = 2025L, co_entidade = as.numeric(escola_id),
        score_infraestrutura = 6.5, score_capacidade_gestora = 4.2,
        data_atualizacao = as.POSIXct("2026-01-02 03:04:05", tz = "UTC")
      ),
      "eduBR_score", con, list()
    )
  }
  fake_ind <- function(con, escola_id = NULL, indicador = NULL) {
    new_eduBR(
      tibble::tibble(indicador_id = character(0), id_escola = numeric(0),
                     valor = numeric(0)),
      "eduBR_indicador", con, list()
    )
  }
  local_mocked_bindings(scores = fake_scores, indicadores = fake_ind)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$scores_escola, escola_id = "11000011")
  expect_null(r$env$erro)
  expect_sem_vazamento(r$json, r$env)
  expect_equal(r$env$dados[[1]]$score_infraestrutura, 6.5)
  expect_equal(r$env$dados[[1]]$data_atualizacao, "2026-01-02T03:04:05Z")

  r <- chamar_json(tools$indicadores_escola, escola_id = "11000011",
                   indicador = "infraestrutura")
  expect_equal(r$env$erro$tipo, "sem_dados")
  expect_equal(r$env$metadados$filtros$indicador, "infraestrutura")
})

test_that("filtro por persona das tools de escola", {
  nomes <- function(p) names(ferramentas_edubr("fake_con", persona = p))

  gestora <- nomes("gestora-escolar")
  expect_setequal(gestora, c("catalogo", "perfil_escola", "resumo_escola",
                             "serie_ideb_escola", "escolas_similares",
                             "scores_escola"))
  expect_false("indicadores_escola" %in% gestora)

  pesq <- nomes("pesquisadora-educacional")
  expect_true("perfil_escola" %in% pesq)
  expect_false(any(c("resumo_escola", "escolas_similares", "scores_escola",
                     "indicadores_escola") %in% pesq))

  ml <- nomes("especialista-ml")
  expect_true(all(c("scores_escola", "indicadores_escola") %in% ml))
  expect_false(any(c("perfil_escola", "resumo_escola",
                     "escolas_similares") %in% ml))

  expect_true(all(tools_escola %in% nomes(NULL)))
})
