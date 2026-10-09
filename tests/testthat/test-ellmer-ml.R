# Tools de ML na camada ellmer (chunk 5): contrato, validações antes do
# banco/ranger, SQL da amostra estratificada (hash determinístico, sem
# random()), fluxo classificar -> dividir -> treinar -> importância ->
# métricas sem objetos R no JSON, ausência de vazamento (nota nunca é
# preditora), pca_perfil com coluna redundante e filtro por persona. Sem
# banco: bases sintéticas em memória e amostragem mockada.

skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")
skip_if_not_installed("ranger")

tools_ml <- c("features_escola", "classificar_desempenho", "dividir_dados",
              "treinar_floresta", "importancia_floresta", "metricas_floresta",
              "pca_perfil")

chamar <- function(tool, ...) {
  json <- tool(...)
  expect_type(json, "character")
  expect_length(json, 1L)
  expect_true(jsonlite::validate(json))
  list(json = json, env = eduBR_envelope_de(json))
}

# Base escola × etapa sintética: cada escola em duas etapas; nota_media
# depende de x1 e x2 (sinal forte); infra_score = in_a + in_b (redundante);
# `constante` sem variância; duas escolas sem nota.
base_ml <- function(n = 400L) {
  i <- seq_len(n)
  x1 <- ((i * 37) %% 101) / 101
  x2 <- ((i * 53) %% 97) / 97
  ruido <- ((i * 71) %% 89) / 89
  in_a <- as.integer((i %% 3) == 0)
  in_b <- as.integer((i %% 5) < 2)
  nota <- 200 + 60 * x1 + 40 * x2 + 5 * ruido
  nota[intersect(c(5L, 10L), i)] <- NA
  tibble::tibble(
    co_entidade = sprintf("%08d", 11000000L + (i - 1L) %/% 2L),
    etapa = rep(c("fundamental_i", "fundamental_ii"), length.out = n),
    tp_dependencia = 3L,
    x1 = x1, x2 = x2, ruido = ruido, in_a = in_a, in_b = in_b,
    infra_score = in_a + in_b,
    constante = 1,
    media_inse = 4 + ((i * 13) %% 7) / 7,
    nota_media = nota
  )
}

nova_sessao <- function(limites = list(), dados = base_ml()) {
  tools <- ferramentas_edubr("fake_con", persona = "especialista-ml",
                             limites = limites)
  sessao <- attr(tools, "sessao")
  id <- eduBR_handle_guardar(sessao, "dados", dados, descricao = "base de teste")
  list(tools = tools, sessao = sessao, dados_id = id)
}

expect_sem_objetos_r <- function(json) {
  for (marca in c("ranger", "\"modelo\":", "\"forest\"", "\"fit\"",
                  "<environment", "\"call\"", "prcomp", "\"rotation\"",
                  "clean.", "analytics.", "escola_features")) {
    expect_false(grepl(marca, json, fixed = TRUE), info = marca)
  }
}

erro_tipo <- function(r, tipo = "parametro_invalido") {
  expect_false(is.null(r$env$erro))
  expect_equal(r$env$erro$tipo, tipo)
  invisible(r$env$erro$mensagem)
}

test_that("contrato: 7 tools de ML com argumentos e descrições", {
  tools <- ferramentas_edubr("fake_con", persona = "especialista-ml")
  expect_true(all(tools_ml %in% names(tools)))
  for (nm in tools_ml) {
    expect_true(inherits(tools[[nm]], "ellmer::ToolDef"))
    expect_identical(tools[[nm]]@name, nm)
    expect_gt(nchar(tools[[nm]]@description), 300L)
  }
  args <- function(nm) names(formals(tools[[nm]]))
  expect_identical(args("features_escola"),
                   c("etapa", "publica", "n_por_etapa", "semente"))
  expect_identical(args("classificar_desempenho"),
                   c("dados_id", "nota", "grupo"))
  expect_identical(args("dividir_dados"), c("dados_id", "prop", "semente"))
  expect_identical(args("treinar_floresta"),
                   c("treino_id", "trees", "min_node_size", "semente",
                     "features"))
  expect_identical(args("importancia_floresta"), c("floresta_id", "n"))
  expect_identical(args("metricas_floresta"), c("floresta_id", "teste_id"))
  expect_identical(args("pca_perfil"),
                   c("dados_id", "redundantes", "n_componentes", "n_pesos"))

  props <- tools$features_escola@arguments@properties
  expect_true(inherits(props$etapa, "ellmer::TypeArray"))
  expect_setequal(props$etapa@items@values,
                  c("fundamental_i", "fundamental_ii", "ensino_medio"))
  expect_setequal(tools$pca_perfil@arguments@properties$redundantes@values,
                  c("remover", "manter"))
  expect_match(tools$metricas_floresta@description, "baseline", fixed = TRUE)
  expect_match(tools$treinar_floresta@description, "VAZAMENTO", fixed = TRUE)
})

test_that("filtro por persona: só a especialista-ml recebe as tools de ML", {
  expect_true(all(tools_ml %in% names(
    ferramentas_edubr("fake_con", persona = "especialista-ml")
  )))
  for (p in c("pesquisadora-educacional", "gestora-escolar")) {
    expect_false(any(tools_ml %in% names(ferramentas_edubr("fake_con", persona = p))))
  }
  expect_true(all(tools_ml %in% names(ferramentas_edubr("fake_con"))))
})

test_that("amostra: SQL com hash determinístico por etapa, sem random()", {
  lf <- dbplyr::lazy_frame(
    co_entidade = "1", etapa = "fundamental_i", nota_media = 1,
    con = dbplyr::simulate_postgres()
  )
  sql <- as.character(dbplyr::sql_render(eduBR_amostra_features(lf, 3000L, 2023L)))
  # o quoting de identificadores muda entre versões do dbplyr
  sql <- gsub("[`\"]", "", sql)
  expect_match(sql, "md5(CONCAT_WS('', co_entidade, ':', '2023'))", fixed = TRUE)
  expect_match(sql, "ROW_NUMBER() OVER (PARTITION BY etapa ORDER BY .ordem, co_entidade)",
               fixed = TRUE)
  expect_match(sql, "COUNT(*) OVER (PARTITION BY etapa)", fixed = TRUE)
  expect_match(sql, "<= 3000", fixed = TRUE)
  expect_false(grepl("random", sql, ignore.case = TRUE))
  expect_false(grepl("setseed", sql, ignore.case = TRUE))
  # outra semente muda só a chave
  sql2 <- as.character(dbplyr::sql_render(eduBR_amostra_features(lf, 3000L, 7L)))
  expect_match(sql2, "'7'", fixed = TRUE)
})

test_that("coleta da amostra: remove colunas auxiliares e guarda a população", {
  df <- base_ml(6L)
  df$.ordem <- "h"
  df$.pos <- 1L
  df$.n_etapa <- c(10, 20, 10, 20, 10, 20)
  out <- eduBR_coletar_amostra(df)
  expect_false(any(c(".ordem", ".pos", ".n_etapa") %in% names(out)))
  expect_equal(as.numeric(attr(out, "eduBR_populacao")[c("fundamental_i", "fundamental_ii")]),
               c(10, 20))
})

test_that("features_escola: teto da amostra, semente e resumo por etapa", {
  pedidos <- list()
  local_mocked_bindings(
    features_escola = function(con, etapa, publica) {
      d <- base_ml(400L)
      new_eduBR(d[d$etapa %in% etapa, ], "eduBR_features")
    },
    eduBR_amostra_features = function(tb, n_por_etapa, semente) {
      pedidos[[length(pedidos) + 1L]] <<- list(n = n_por_etapa, semente = semente)
      tb <- tb[order(tb$etapa, tb$co_entidade), ]
      pop <- table(tb$etapa)
      tb$.n_etapa <- as.numeric(pop[tb$etapa])
      tb$.ordem <- "x"
      tb$.pos <- stats::ave(seq_len(nrow(tb)), tb$etapa, FUN = seq_along)
      tb[tb$.pos <= n_por_etapa, ]
    }
  )
  s <- nova_sessao(limites = list(max_amostra = 100L))

  # validações antes do banco
  r <- chamar(s$tools$features_escola, n_por_etapa = 60L)
  expect_match(erro_tipo(r), "50", fixed = TRUE)
  erro_tipo(chamar(s$tools$features_escola, etapa = "medio"))
  erro_tipo(chamar(s$tools$features_escola, semente = -1L))
  erro_tipo(chamar(s$tools$features_escola, publica = "sim"))
  expect_length(pedidos, 0L)

  r <- chamar(s$tools$features_escola)
  expect_null(r$env$erro)
  expect_equal(pedidos[[1]], list(n = 50L, semente = 2023L))
  id <- r$env$metadados$handle
  expect_match(id, "^dados_[0-9]+$")
  df <- eduBR_handle_obter(s$sessao, id)
  expect_true(is.data.frame(df))
  expect_lte(nrow(df), 100L)
  expect_false(any(c(".ordem", ".pos", ".n_etapa") %in% names(df)))
  linhas <- r$env$dados
  expect_length(linhas, 2L)
  expect_equal(vapply(linhas, `[[`, numeric(1), "n_amostra"), c(50, 50))
  expect_equal(vapply(linhas, `[[`, numeric(1), "n_populacao"), c(200, 200))
  ctx <- r$env$metadados$contexto
  expect_equal(unlist(ctx$colunas_desempenho), "nota_media")
  expect_equal(ctx$n_colunas, ncol(df))
  expect_length(ctx$previa, 3L)
  expect_equal(ctx$semente, 2023)
  expect_match(eduBR_handle_listar(s$sessao)$descricao[2], "semente=2023",
               fixed = TRUE)

  r <- chamar(s$tools$features_escola, etapa = list("fundamental_ii"),
              n_por_etapa = 80L, semente = 7L)
  expect_null(r$env$erro)
  expect_equal(pedidos[[2]], list(n = 80L, semente = 7L))
  expect_length(r$env$dados, 1L)
  expect_sem_objetos_r(r$json)
})

test_that("etapa como fator (array de enum convertido pelo ellmer) é aceita", {
  # ellmer converte `type_array(type_enum())` em fator; o aceite com chat
  # real recusava etapa = ["fundamental_ii"] por isso.
  expect_equal(eduBR_validar_etapas(factor("fundamental_ii",
                                           levels = eduBR_etapas_features())),
               "fundamental_ii")
  expect_equal(eduBR_validar_etapas(list(factor("ensino_medio"),
                                         "fundamental_i")),
               c("ensino_medio", "fundamental_i"))
  expect_error(eduBR_validar_etapas(factor("medio")), class = "eduBR_erro_tool")
})

test_that("validações: trees, prop, features com nota -> parametro_invalido", {
  chamou <- 0L
  local_mocked_bindings(
    treinar_floresta = function(...) {
      chamou <<- chamou + 1L
      stop("não deveria treinar")
    },
    dividir_dados = function(...) {
      chamou <<- chamou + 1L
      stop("não deveria dividir")
    }
  )
  s <- nova_sessao()
  erro_tipo(chamar(s$tools$dividir_dados, dados_id = s$dados_id, prop = 0.99))
  erro_tipo(chamar(s$tools$dividir_dados, dados_id = s$dados_id, prop = 0.3))
  # base ainda sem `nivel`
  r <- chamar(s$tools$dividir_dados, dados_id = s$dados_id)
  expect_match(erro_tipo(r), "classificar_desempenho", fixed = TRUE)
  expect_equal(chamou, 0L)

  cl <- chamar(s$tools$classificar_desempenho, dados_id = s$dados_id)
  sessao <- s$sessao
  dados_cl <- cl$env$metadados$handle
  # treino fabricado à mão (sem dividir_dados, que está mockada)
  tr <- eduBR_handle_guardar(sessao, "treino",
                             list(dados = eduBR_handle_obter(sessao, dados_cl),
                                  par = "teste_1"))
  erro_tipo(chamar(s$tools$treinar_floresta, treino_id = tr, trees = 1000L))
  erro_tipo(chamar(s$tools$treinar_floresta, treino_id = tr, trees = 0L))
  erro_tipo(chamar(s$tools$treinar_floresta, treino_id = tr, min_node_size = 0L))
  r <- chamar(s$tools$treinar_floresta, treino_id = tr,
              features = c("x1", "nota_media"))
  msg <- erro_tipo(r)
  expect_match(msg, "nota_media", fixed = TRUE)
  expect_match(msg, "vazamento", fixed = TRUE)
  msg <- erro_tipo(chamar(s$tools$treinar_floresta, treino_id = tr,
                          features = c("x1", "co_entidade")))
  expect_match(msg, "co_entidade", fixed = TRUE)
  msg <- erro_tipo(chamar(s$tools$treinar_floresta, treino_id = tr,
                          features = c("x1", "nivel")))
  expect_match(msg, "alvo", fixed = TRUE)
  msg <- erro_tipo(chamar(s$tools$treinar_floresta, treino_id = tr,
                          features = c("x1", "nao_existe")))
  expect_match(msg, "nao_existe", fixed = TRUE)
  erro_tipo(chamar(s$tools$treinar_floresta, treino_id = "dados_1"))
  erro_tipo(chamar(s$tools$treinar_floresta, treino_id = "treino_99"))
  expect_equal(chamou, 0L)

  erro_tipo(chamar(s$tools$classificar_desempenho, dados_id = s$dados_id,
                   nota = "nao_existe"))
  erro_tipo(chamar(s$tools$classificar_desempenho, dados_id = s$dados_id,
                   grupo = "nao_existe"))
  erro_tipo(chamar(s$tools$pca_perfil, dados_id = s$dados_id,
                   redundantes = "talvez"))
  erro_tipo(chamar(s$tools$pca_perfil, dados_id = s$dados_id,
                   n_componentes = 0L))
})

test_that("handle lazy (covariaveis_escola) é recusado pelas tools de ML", {
  s <- nova_sessao()
  lf <- dbplyr::lazy_frame(co_entidade = "1", con = dbplyr::simulate_postgres())
  id <- eduBR_handle_guardar(s$sessao, "dados", new_eduBR(lf, "eduBR_cov"))
  msg <- erro_tipo(chamar(s$tools$classificar_desempenho, dados_id = id))
  expect_match(msg, "features_escola", fixed = TRUE)
  erro_tipo(chamar(s$tools$pca_perfil, dados_id = id))
})

test_that("fluxo completo: classificar -> dividir -> treinar -> importância -> métricas", {
  s <- nova_sessao()
  t <- s$tools

  r <- chamar(t$classificar_desempenho, dados_id = s$dados_id)
  expect_null(r$env$erro)
  cl <- r$env$metadados$handle
  expect_match(cl, "^dados_[0-9]+$")
  expect_false(identical(cl, s$dados_id))
  ctx <- r$env$metadados$contexto
  expect_equal(ctx$n_sem_nota, 2)
  expect_equal(ctx$n_classificadas, 398)
  expect_match(r$env$metadados$aviso, "2 escola(s) sem `nota_media`", fixed = TRUE)
  expect_length(ctx$limites, 2L)
  expect_setequal(vapply(ctx$limites, `[[`, character(1), "grupo"),
                  c("fundamental_i", "fundamental_ii"))
  lim1 <- ctx$limites[[1]]
  expect_lt(lim1$corte_baixo_medio, lim1$corte_medio_alto)
  expect_length(r$env$dados, 6L)
  expect_setequal(names(r$env$dados[[1]]), c("etapa", "nivel", "n"))
  expect_equal(sum(vapply(r$env$dados, `[[`, numeric(1), "n")), 398)
  expect_sem_objetos_r(r$json)

  r <- chamar(t$dividir_dados, dados_id = cl, prop = 0.75, semente = 11L)
  expect_null(r$env$erro)
  ctx <- r$env$metadados$contexto
  expect_match(ctx$treino_id, "^treino_[0-9]+$")
  expect_match(ctx$teste_id, "^teste_[0-9]+$")
  expect_equal(ctx$n_treino + ctx$n_teste, 398)
  expect_setequal(unique(vapply(r$env$dados, `[[`, character(1), "parte")),
                  c("treino", "teste"))
  expect_sem_objetos_r(r$json)
  # reprodutível e sem mexer no RNG do usuário
  set.seed(1)
  antes <- .Random.seed
  r2 <- chamar(t$dividir_dados, dados_id = cl, prop = 0.75, semente = 11L)
  expect_identical(.Random.seed, antes)
  tr1 <- eduBR_handle_obter(s$sessao, ctx$treino_id)$dados
  tr2 <- eduBR_handle_obter(s$sessao, r2$env$metadados$contexto$treino_id)$dados
  expect_identical(tr1$co_entidade, tr2$co_entidade)

  r <- chamar(t$treinar_floresta, treino_id = ctx$treino_id, trees = 60L)
  expect_null(r$env$erro)
  fl <- r$env$metadados$handle
  expect_match(fl, "^floresta_[0-9]+$")
  feats <- unlist(r$env$metadados$contexto$features)
  expect_false("nota_media" %in% feats)
  expect_false(any(c("nivel", "co_entidade", "etapa") %in% feats))
  expect_true(all(c("x1", "x2", "media_inse") %in% feats))
  excl <- r$env$metadados$contexto$excluidas
  motivos <- stats::setNames(vapply(excl, `[[`, character(1), "motivo"),
                             vapply(excl, `[[`, character(1), "coluna"))
  expect_equal(motivos[["nota_media"]], "desempenho (vazamento)")
  expect_equal(motivos[["nivel"]], "alvo")
  expect_match(r$env$metadados$aviso, "nota_media", fixed = TRUE)
  d <- r$env$dados[[1]]
  expect_equal(d$n_arvores, 60)
  expect_equal(d$n_features, length(feats))
  expect_true(is.numeric(d$erro_oob_brier))
  expect_true(is.numeric(d$tempo_s))
  expect_sem_objetos_r(r$json)
  modelo <- eduBR_handle_obter(s$sessao, fl)$modelo
  expect_false("nota_media" %in% modelo$features)
  expect_false("nota_media" %in% names(modelo$modelo$variable.importance))

  r <- chamar(t$importancia_floresta, floresta_id = fl, n = 3L)
  expect_null(r$env$erro)
  expect_length(r$env$dados, 3L)
  top <- vapply(r$env$dados, `[[`, character(1), "variavel")
  expect_true("x1" %in% top)
  expect_false("nota_media" %in% top)
  expect_sem_objetos_r(r$json)

  r <- chamar(t$metricas_floresta, floresta_id = fl, teste_id = ctx$teste_id)
  expect_null(r$env$erro)
  m <- r$env$dados[[1]]
  expect_true(all(c("acuracia", "baseline_acerto", "ganho_sobre_baseline",
                    "f1_macro", "auc_macro", "n_teste") %in% names(m)))
  expect_gt(m$acuracia, m$baseline_acerto)
  conf <- r$env$metadados$contexto$confusao
  expect_length(conf, 9L)
  expect_setequal(names(conf[[1]]), c("real", "predito", "n"))
  expect_equal(sum(vapply(conf, `[[`, numeric(1), "n")), m$n_teste)
  expect_sem_objetos_r(r$json)

  # teste com escolas do treino -> recusado (vazamento)
  vaz <- eduBR_handle_guardar(s$sessao, "teste", list(dados = tr1, par = "x"))
  msg <- erro_tipo(chamar(t$metricas_floresta, floresta_id = fl, teste_id = vaz))
  expect_match(msg, "vazamento", fixed = TRUE)

  r <- chamar(t$listar_handles)
  tipos <- vapply(r$env$dados, `[[`, character(1), "tipo")
  expect_true(all(c("dados", "treino", "teste", "floresta") %in% tipos))
})

test_that("treinar: nota usada na classe sai dos preditores e o ranger usa 2 threads", {
  capturado <- NULL
  local_mocked_bindings(treinar_floresta = function(dados, alvo, features, ...) {
    capturado <<- list(features = features, extra = list(...))
    structure(list(modelo = list(prediction.error = 0.1), features = features),
              class = "eduBR_floresta")
  })
  s <- nova_sessao()
  # classe definida por media_inse: ela passa a ser vazamento
  cl <- chamar(s$tools$classificar_desempenho, dados_id = s$dados_id,
               nota = "media_inse")$env$metadados$handle
  dv <- chamar(s$tools$dividir_dados, dados_id = cl)$env$metadados$contexto
  r <- chamar(s$tools$treinar_floresta, treino_id = dv$treino_id, trees = 500L)
  expect_null(r$env$erro)
  expect_false(any(c("media_inse", "nota_media", "nivel") %in% capturado$features))
  expect_equal(capturado$extra$num.threads, 2L)
  expect_equal(capturado$extra$trees, 500L)
  msg <- erro_tipo(chamar(s$tools$treinar_floresta, treino_id = dv$treino_id,
                          features = "media_inse"))
  expect_match(msg, "media_inse", fixed = TRUE)
})

test_that("pca_perfil: coluna redundante e constante removidas e avisadas", {
  s <- nova_sessao()
  r <- chamar(s$tools$pca_perfil, dados_id = s$dados_id, n_componentes = 3L,
              n_pesos = 2L)
  expect_null(r$env$erro)
  aviso <- r$env$metadados$aviso
  expect_match(aviso, "constante", fixed = TRUE)
  expect_match(aviso, "redundantes", fixed = TRUE)
  ctx <- r$env$metadados$contexto
  removidas <- unlist(ctx$removidas)
  expect_true("constante" %in% removidas)
  expect_true(any(c("infra_score", "in_a", "in_b") %in% removidas))
  expect_length(r$env$dados, 3L)
  expect_true(all(c("pc", "prop", "acumulada", "principais") %in%
                    names(r$env$dados[[1]])))
  expect_lte(length(ctx$pesos), 6L)
  vars <- vapply(ctx$pesos, `[[`, character(1), "variavel")
  expect_false(any(c("nota_media", "media_inse", "co_entidade") %in% vars))
  # escolas repetidas entre etapas: id composto escola|etapa
  expect_equal(ctx$n_escolas, 400)
  expect_sem_objetos_r(r$json)

  r <- chamar(s$tools$pca_perfil, dados_id = s$dados_id, redundantes = "manter")
  expect_null(r$env$erro)
  expect_match(r$env$metadados$aviso, "variância nula", fixed = TRUE)
})

test_that("treinar: estouro de tempo vira limite_excedido com orientação", {
  local_mocked_bindings(treinar_floresta = function(...) {
    stop("reached elapsed time limit")
  })
  s <- nova_sessao()
  cl <- chamar(s$tools$classificar_desempenho,
               dados_id = s$dados_id)$env$metadados$handle
  dv <- chamar(s$tools$dividir_dados, dados_id = cl)$env$metadados$contexto
  r <- chamar(s$tools$treinar_floresta, treino_id = dv$treino_id)
  msg <- erro_tipo(r, "limite_excedido")
  expect_match(msg, "trees", fixed = TRUE)
  expect_match(msg, "n_por_etapa", fixed = TRUE)
  expect_false(eduBR_erro_tempo_floresta(
    simpleError("User interrupt or internal error."), 1, 30
  ))
  expect_true(eduBR_erro_tempo_floresta(
    simpleError("User interrupt or internal error."), 29, 30
  ))
})
