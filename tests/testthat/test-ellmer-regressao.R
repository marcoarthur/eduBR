# Tools de regressão declarativa na camada ellmer (chunk 4): contrato,
# validação de nomes sem executar, filtro, contagem do recorte contra
# max_amostra, fluxo especificar -> executar -> coeficientes/metricas,
# listar_handles e filtro por persona. Sem banco: handle de dados em memória
# e eduBR_tbl() mockado para `fonte`.

skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")
skip_if_not_installed("parsnip")
skip_if_not_installed("broom")
skip_if_not_installed("tidyr")
skip_if_not_installed("purrr")

tools_regressao <- c("especificar_regressao", "executar_regressao",
                     "coeficientes", "metricas", "listar_handles")

chamar <- function(tool, ...) {
  json <- tool(...)
  expect_type(json, "character")
  expect_length(json, 1L)
  expect_true(jsonlite::validate(json))
  list(json = json, env = eduBR_envelope_de(json))
}

# Base escola × covariáveis em memória (determinística).
base_teste <- function(n = 60L) {
  i <- seq_len(n)
  tibble::tibble(
    co_entidade = 12000000 + i,
    sg_uf = "AC",
    localizacao = rep(c("Urbana", "Rural"), length.out = n),
    in_biblioteca = rep(c(0L, 1L, 1L), length.out = n),
    docentes = (i %% 17) + 3,
    ideb_fund_i = 4 + 0.3 * rep(c(0L, 1L, 1L), length.out = n) +
      0.02 * ((i %% 17) + 3) + ((i * 7) %% 11) / 20,
    aprovado = as.integer(((i * 5) %% 7) > 2),
    ano = rep(c(2021, 2023), length.out = n)
  )
}

nova_sessao <- function(limites = list(), dados = base_teste()) {
  tools <- ferramentas_edubr("fake_con", limites = limites)
  sessao <- attr(tools, "sessao")
  id <- eduBR_handle_guardar(
    sessao, "dados", new_eduBR(dados, "eduBR_teste"),
    descricao = "base de teste"
  )
  list(tools = tools, sessao = sessao, dados_id = id)
}

expect_sem_objetos_r <- function(json) {
  for (marca in c("\"modelo\":{", "\"modelo\":[", "\"predicoes\"", "\"coeficientes\":",
                  "\"metricas\":", "model_fit", "lm(", "glm(", "<environment",
                  "\"call\"", "clean.", "analytics.")) {
    expect_false(grepl(marca, json, fixed = TRUE), info = marca)
  }
}

test_that("contrato: tools de regressão registradas com argumentos", {
  tools <- ferramentas_edubr("fake_con")
  expect_true(all(tools_regressao %in% names(tools)))
  for (nm in tools_regressao) {
    expect_true(inherits(tools[[nm]], "ellmer::ToolDef"))
    expect_identical(tools[[nm]]@name, nm)
    expect_gt(nchar(tools[[nm]]@description), 300L)
  }
  args <- function(nm) names(formals(tools[[nm]]))
  expect_identical(args("especificar_regressao"),
                   c("outcome", "predictors", "cuts", "modelo", "fonte",
                     "dados_id", "filtro"))
  expect_identical(args("executar_regressao"), "espec_id")
  expect_identical(args("coeficientes"), c("regressao_id", "n"))
  expect_identical(args("metricas"), c("regressao_id", "n"))
  expect_length(args("listar_handles"), 0L)

  props <- tools$especificar_regressao@arguments@properties
  expect_setequal(props$modelo@values, c("linear", "logistico"))
  expect_setequal(props$fonte@values, eduBR_fontes_regressao())
  expect_false(any(c("clusters", "similaridade") %in% props$fonte@values))
  expect_true(all(c("ideb", "censo_escolas") %in% props$fonte@values))
  expect_false(props$fonte@required)
  expect_false(props$dados_id@required)
  expect_true(inherits(props$filtro, "ellmer::TypeArray"))
  expect_setequal(names(props$filtro@items@properties), c("coluna", "valor"))
})

test_that("filtro por persona: pesquisadora e ML recebem; gestora não", {
  for (p in c("pesquisadora-educacional", "especialista-ml")) {
    expect_true(all(tools_regressao %in% names(ferramentas_edubr("fake_con", persona = p))))
  }
  gestora <- names(ferramentas_edubr("fake_con", persona = "gestora-escolar"))
  expect_false(any(tools_regressao %in% gestora))
})

test_that("especificar: fonte e dados_id juntos ou nenhum -> parametro_invalido", {
  s <- nova_sessao()
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes")
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  expect_match(r$env$erro$mensagem, "exatamente um", fixed = TRUE)
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", fonte = "ideb", dados_id = s$dados_id)
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", fonte = "clusters")
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  expect_match(r$env$erro$mensagem, "`fonte`", fixed = TRUE)
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", dados_id = "espec_1")
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  expect_match(r$env$erro$mensagem, "dados_<k>", fixed = TRUE)
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", dados_id = "dados_9")
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  expect_match(r$env$erro$mensagem, "handle inexistente", fixed = TRUE)
})

test_that("especificar: colunas inexistentes e papéis conflitantes", {
  chamadas <- 0L
  local_mocked_bindings(
    executar_regressao = function(...) {
      chamadas <<- chamadas + 1L
      stop("não deveria ser chamada")
    },
    especificar_regressao = function(...) {
      chamadas <<- chamadas + 1L
      stop("não deveria ser chamada")
    }
  )
  s <- nova_sessao()
  esp <- s$tools$especificar_regressao
  casos <- list(
    list(list(outcome = "nao_existe", predictors = "docentes"), "nao_existe"),
    list(list(outcome = "ideb_fund_i", predictors = c("docentes", "xyz")),
         "xyz"),
    list(list(outcome = "ideb_fund_i", predictors = "docentes",
              cuts = "regiao_x"), "regiao_x"),
    list(list(outcome = "ideb_fund_i", predictors = "docentes",
              filtro = list(list(coluna = "uf_x", valor = "AC"))), "uf_x"),
    list(list(outcome = "ideb_fund_i",
              predictors = c("docentes", "ideb_fund_i")), "desfecho"),
    list(list(outcome = "ideb_fund_i", predictors = "docentes",
              cuts = "ideb_fund_i"), "desfecho"),
    list(list(outcome = "ideb_fund_i", predictors = "docentes",
              cuts = "docentes"), "ao mesmo tempo"),
    list(list(outcome = c("a", "b"), predictors = "docentes"), "UMA"),
    list(list(outcome = "ideb_fund_i", predictors = character(0)),
         "`predictors`"),
    list(list(outcome = "ideb_fund_i", predictors = "docentes",
              modelo = "poisson"), "`modelo`"),
    list(list(outcome = "ideb_fund_i", predictors = "docentes",
              filtro = list(list(coluna = "ano", valor = "dois mil"))),
         "numérica"),
    list(list(outcome = "ideb_fund_i", predictors = "docentes",
              filtro = list(list(coluna = "ano", valor = "2023"),
                            list(coluna = "ano", valor = "2021"))),
         "repete"),
    list(list(outcome = "ideb_fund_i", predictors = "docentes",
              filtro = list(list(col = "ano"))), "{\"coluna\"")
  )
  for (cs in casos) {
    args <- c(cs[[1]], list(dados_id = s$dados_id))
    r <- chamar(function() do.call(esp, args))
    expect_equal(r$env$erro$tipo, "parametro_invalido", info = cs[[2]])
    expect_match(r$env$erro$mensagem, cs[[2]], fixed = TRUE)
  }
  # Mensagem de coluna inexistente lista as disponíveis.
  r <- chamar(esp, outcome = "nao_existe", predictors = "docentes",
              dados_id = s$dados_id)
  expect_match(r$env$erro$mensagem, "in_biblioteca", fixed = TRUE)
  expect_equal(chamadas, 0L)
  expect_equal(nrow(eduBR_handle_listar(s$sessao)), 1L)
})

test_that("especificar: filtro vira lista nomeada com números convertidos", {
  s <- nova_sessao()
  # O ellmer pode entregar o array de objetos como data frame.
  filtro_df <- data.frame(coluna = c("ano", "sg_uf"), valor = c("2023", "AC"))
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = c("in_biblioteca", "docentes"),
              cuts = "localizacao", dados_id = s$dados_id, filtro = filtro_df)
  expect_null(r$env$erro)
  expect_equal(r$env$metadados$handle, "espec_1")
  expect_equal(r$env$dados[[1]]$formula, "ideb_fund_i ~ in_biblioteca + docentes")
  expect_equal(r$env$dados[[1]]$cortes, "localizacao")
  expect_equal(r$env$dados[[1]]$filtro, "ano == 2023 E sg_uf == \"AC\"")
  g <- eduBR_handle_obter(s$sessao, "espec_1")
  expect_s3_class(g$espec, "eduBR_espec")
  expect_identical(g$espec$filtro, list(ano = 2023, sg_uf = "AC"))
  expect_equal(g$espec$id, "espec_1")
  expect_null(g$espec$fonte)
  expect_equal(g$dados_id, s$dados_id)

  # Lista de listas, valor numérico e coluna de texto com dígitos.
  base <- base_teste()
  base$co_municipio <- "1200401"
  s2 <- nova_sessao(dados = base)
  r <- chamar(s2$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", dados_id = s2$dados_id,
              filtro = list(list(coluna = "ano", valor = 2021),
                            list(coluna = "co_municipio", valor = "1200401")))
  expect_null(r$env$erro)
  g <- eduBR_handle_obter(s2$sessao, "espec_1")
  expect_identical(g$espec$filtro, list(ano = 2021, co_municipio = "1200401"))
})

test_that("fluxo linear: especificar -> executar -> coeficientes/metricas", {
  s <- nova_sessao()
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = c("in_biblioteca", "docentes"),
              cuts = "localizacao", dados_id = s$dados_id,
              filtro = list(list(coluna = "sg_uf", valor = "AC")))
  espec_id <- r$env$metadados$handle

  r <- chamar(s$tools$executar_regressao, espec_id = espec_id)
  env <- r$env
  expect_null(env$erro)
  expect_sem_objetos_r(r$json)
  expect_equal(env$metadados$handle, "regressao_1")
  expect_length(env$dados, 2L)
  expect_setequal(vapply(env$dados, `[[`, character(1), "localizacao"),
                  c("Rural", "Urbana"))
  expect_true(all(vapply(env$dados, `[[`, logical(1), "ajustado")))
  expect_equal(sum(vapply(env$dados, `[[`, numeric(1), "n")), 60)
  expect_equal(env$metadados$contexto$n_recorte, 60)
  expect_equal(env$metadados$contexto$n_ajustados, 2L)
  expect_equal(env$metadados$contexto$n_usado, 60L)
  expect_null(env$metadados$aviso)
  reg <- eduBR_handle_obter(s$sessao, "regressao_1")
  expect_s3_class(reg, "eduBR_regressoes")

  r <- chamar(s$tools$coeficientes, regressao_id = "regressao_1")
  expect_null(r$env$erro)
  expect_sem_objetos_r(r$json)
  expect_length(r$env$dados, 6L)
  expect_setequal(names(r$env$dados[[1]]),
                  c("localizacao", "termo", "estimativa", "erro_padrao",
                    "estatistica", "p_valor"))
  r <- chamar(s$tools$coeficientes, regressao_id = "regressao_1", n = 2L)
  expect_length(r$env$dados, 2L)
  expect_true(r$env$metadados$truncado)

  r <- chamar(s$tools$metricas, regressao_id = "regressao_1")
  expect_null(r$env$erro)
  expect_sem_objetos_r(r$json)
  expect_length(r$env$dados, 2L)
  expect_true(all(c("localizacao", "r2", "r2_ajustado", "sigma", "AIC", "BIC",
                    "nobs") %in% names(r$env$dados[[1]])))
})

test_that("executar: linhas com null no desfecho são avisadas", {
  base <- base_teste()
  base$ideb_fund_i[1:10] <- NA
  s <- nova_sessao(dados = base)
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", dados_id = s$dados_id)
  r <- chamar(s$tools$executar_regressao, espec_id = r$env$metadados$handle)
  expect_null(r$env$erro)
  expect_equal(r$env$dados[[1]]$n, 50L)
  expect_match(r$env$metadados$aviso, "10 de 60 linhas", fixed = TRUE)
})

test_that("fluxo logístico: auc e mcfadden nas métricas", {
  s <- nova_sessao()
  r <- chamar(s$tools$especificar_regressao, outcome = "aprovado",
              predictors = c("docentes", "in_biblioteca"),
              modelo = "logistico", dados_id = s$dados_id)
  expect_null(r$env$erro)
  r <- chamar(s$tools$executar_regressao, espec_id = r$env$metadados$handle)
  expect_null(r$env$erro)
  expect_length(r$env$dados, 1L)
  expect_true(r$env$dados[[1]]$ajustado)
  h <- r$env$metadados$handle
  r <- chamar(s$tools$metricas, regressao_id = h)
  expect_null(r$env$erro)
  expect_true(all(c("auc", "mcfadden", "deviance", "deviance_nula", "nobs") %in%
                    names(r$env$dados[[1]])))
  expect_sem_objetos_r(r$json)
  r <- chamar(s$tools$coeficientes, regressao_id = h)
  expect_length(r$env$dados, 3L)
})

test_that("logístico com desfecho não binário é recusado antes de executar", {
  s <- nova_sessao()
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", modelo = "logistico",
              dados_id = s$dados_id)
  expect_null(r$env$erro)
  chamou <- FALSE
  local_mocked_bindings(
    executar_regressao = function(...) {
      chamou <<- TRUE
      stop("n\u00e3o deveria executar")
    }
  )
  r <- chamar(s$tools$executar_regressao, espec_id = r$env$metadados$handle)
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  expect_match(r$env$erro$mensagem, "desfecho bin", fixed = TRUE)
  expect_false(chamou)
})

test_that("executar: corte pequeno fica sem modelo e é avisado", {
  base <- base_teste()
  base$localizacao[1:2] <- "Ilha"
  s <- nova_sessao(dados = base)
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = c("in_biblioteca", "docentes"),
              cuts = "localizacao", dados_id = s$dados_id)
  r <- chamar(s$tools$executar_regressao, espec_id = r$env$metadados$handle)
  expect_null(r$env$erro)
  aj <- vapply(r$env$dados, `[[`, logical(1), "ajustado")
  loc <- vapply(r$env$dados, `[[`, character(1), "localizacao")
  expect_false(aj[loc == "Ilha"])
  expect_match(r$env$metadados$aviso, "1 corte(s) sem modelo", fixed = TRUE)
  expect_null(r$env$erro)
  r <- chamar(s$tools$coeficientes, regressao_id = r$env$metadados$handle)
  expect_false("Ilha" %in% vapply(r$env$dados, `[[`, character(1),
                                  "localizacao"))
})

test_that("executar: recorte acima de max_amostra -> limite_excedido sem executar", {
  chamadas <- 0L
  local_mocked_bindings(executar_regressao = function(...) {
    chamadas <<- chamadas + 1L
    stop("não deveria ser chamada")
  })
  s <- nova_sessao(limites = list(max_amostra = 50L))
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", dados_id = s$dados_id)
  r <- chamar(s$tools$executar_regressao, espec_id = r$env$metadados$handle)
  expect_equal(r$env$erro$tipo, "limite_excedido")
  expect_match(r$env$erro$mensagem, "60 linhas", fixed = TRUE)
  expect_match(r$env$erro$mensagem, "filtro", fixed = TRUE)
  expect_equal(chamadas, 0L)
  expect_equal(nrow(eduBR_handle_listar(s$sessao)), 2L)
})

test_that("executar: filtro reduz o recorte abaixo do limite", {
  s <- nova_sessao(limites = list(max_amostra = 50L))
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", dados_id = s$dados_id,
              filtro = list(list(coluna = "ano", valor = "2023")))
  r <- chamar(s$tools$executar_regressao, espec_id = r$env$metadados$handle)
  expect_null(r$env$erro)
  expect_equal(r$env$metadados$contexto$n_recorte, 30)
  expect_equal(r$env$dados[[1]]$n, 30L)
})

test_that("handles inexistentes ou de outro tipo -> parametro_invalido", {
  s <- nova_sessao()
  r <- chamar(s$tools$executar_regressao, espec_id = "espec_7")
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  expect_match(r$env$erro$mensagem, "handle inexistente", fixed = TRUE)
  r <- chamar(s$tools$executar_regressao, espec_id = s$dados_id)
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  expect_match(r$env$erro$mensagem, "espec_<k>", fixed = TRUE)
  r <- chamar(s$tools$coeficientes, regressao_id = "regressao_3")
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  r <- chamar(s$tools$metricas, regressao_id = "espec_1")
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  r <- chamar(s$tools$coeficientes, regressao_id = "regressao_1", n = 0L)
  expect_equal(r$env$erro$tipo, "parametro_invalido")
})

test_that("fonte do catálogo: eduBR_tbl mockado, filtro aplicado", {
  pedido <- NULL
  ideb_fake <- tibble::tibble(
    sg_uf = rep(c("AC", "AM"), each = 40),
    ano = rep(c(2021L, 2023L), 40),
    etapa = rep(c("fundamental_i", "fundamental_ii"), each = 2, length.out = 80),
    nota_media = 4 + (seq_len(80) %% 9) / 5,
    ideb_observado = 3 + (seq_len(80) %% 9) / 4 + (seq_len(80) %% 3) / 10
  )
  local_mocked_bindings(eduBR_tbl = function(con, nome) {
    pedido <<- c(pedido, nome)
    ideb_fake
  })
  tools <- ferramentas_edubr("fake_con")
  r <- chamar(tools$especificar_regressao, outcome = "ideb_observado",
              predictors = "nota_media", cuts = "etapa", fonte = "ideb",
              filtro = list(list(coluna = "ano", valor = "2023"),
                            list(coluna = "sg_uf", valor = "AC")))
  expect_null(r$env$erro)
  expect_equal(r$env$dados[[1]]$fonte, "ideb")
  g <- eduBR_handle_obter(attr(tools, "sessao"), "espec_1")
  expect_identical(g$espec$filtro, list(ano = 2023, sg_uf = "AC"))
  expect_equal(g$espec$fonte, "ideb")
  expect_null(g$dados)

  r <- chamar(tools$executar_regressao, espec_id = "espec_1")
  expect_null(r$env$erro)
  expect_equal(r$env$metadados$contexto$n_recorte, 20)
  expect_length(r$env$dados, 2L)
  expect_true(all(pedido == "ideb"))
  expect_sem_objetos_r(r$json)
})

test_that("listar_handles: vazio, depois tipos e descrições", {
  tools <- ferramentas_edubr("fake_con")
  r <- chamar(tools$listar_handles)
  expect_null(r$env$erro)
  expect_length(r$env$dados, 0L)
  expect_match(r$env$metadados$aviso, "Nenhum handle", fixed = TRUE)

  s <- nova_sessao()
  r <- chamar(s$tools$especificar_regressao, outcome = "ideb_fund_i",
              predictors = "docentes", cuts = "localizacao",
              dados_id = s$dados_id)
  chamar(s$tools$executar_regressao, espec_id = "espec_1")
  r <- chamar(s$tools$listar_handles)
  expect_null(r$env$erro)
  ids <- vapply(r$env$dados, `[[`, character(1), "id")
  tipos <- vapply(r$env$dados, `[[`, character(1), "tipo")
  desc <- vapply(r$env$dados, `[[`, character(1), "descricao")
  expect_identical(ids, c("dados_1", "espec_1", "regressao_1"))
  expect_identical(tipos, c("dados", "espec", "regressao"))
  expect_equal(desc[1], "base de teste")
  expect_match(desc[2], "linear ideb_fund_i ~ docentes por localizacao em dados_1",
               fixed = TRUE)
  expect_match(desc[3], "espec_1: 2 modelo(s)", fixed = TRUE)
  expect_true(all(tipos %in% eduBR_tipos_handle()))
})

test_that("handles: descrição opcional e retrocompatível", {
  sessao <- attr(ferramentas_edubr("fake_con"), "sessao")
  expect_equal(eduBR_handle_guardar(sessao, "dados", 1), "dados_1")
  expect_equal(eduBR_handle_guardar(sessao, "floresta", 2, descricao = "rf"),
               "floresta_1")
  lst <- eduBR_handle_listar(sessao)
  expect_identical(lst$id, c("dados_1", "floresta_1"))
  expect_identical(lst$descricao, c("", "rf"))
  expect_error(eduBR_handle_guardar(sessao, "dados", 1, descricao = 3),
               "descricao")
  expect_equal(
    eduBR_handle_descrever("covariaveis_escola",
                           list(uf = "AC", rede = NULL, ativas = TRUE)),
    "covariaveis_escola uf=AC ativas=TRUE"
  )
})

test_that("covariaveis_escola guarda o handle com descrição", {
  fake_cov <- function(con, ano = 2025L, ano_ideb = 2023L, uf = NULL,
                       rede = NULL, ativas = TRUE) {
    new_eduBR(base_teste(), "eduBR_covariaveis", con, list())
  }
  local_mocked_bindings(covariaveis_escola = fake_cov)
  tools <- ferramentas_edubr("fake_con")
  chamar(tools$covariaveis_escola, uf = "AC", rede = "Municipal")
  lst <- eduBR_handle_listar(attr(tools, "sessao"))
  expect_equal(lst$id, "dados_1")
  expect_equal(
    lst$descricao,
    "covariaveis_escola uf=AC rede=Municipal ano=2025 ano_ideb=2023 ativas=TRUE"
  )
})

test_that("regressao_escolas: fluxo completo numa chamada (#81)", {
  local_mocked_bindings(
    covariaveis_escola = function(con, ano, ano_ideb, uf, rede, ativas) {
      new_eduBR(base_teste(), "eduBR_covariaveis")
    }
  )
  tools <- ferramentas_edubr("fake_con", persona = "pesquisadora-educacional")
  expect_true("regressao_escolas" %in% names(tools))
  r <- chamar(tools$regressao_escolas, outcome = "ideb_fund_i",
              predictors = list("in_biblioteca", "docentes"),
              cuts = list("localizacao"), uf = "AC", rede = "Municipal")
  expect_null(r$env$erro)
  termos <- vapply(r$env$dados, `[[`, character(1), "termo")
  expect_true(all(c("in_biblioteca", "docentes") %in% termos))
  expect_setequal(unique(vapply(r$env$dados, `[[`, character(1),
                                "localizacao")), c("Urbana", "Rural"))
  ctx <- r$env$metadados$contexto
  expect_length(ctx$metricas, 2L)
  expect_true(all(c("r2", "nobs") %in% names(ctx$metricas[[1]])))
  expect_equal(ctx$n_recorte, 60)
  expect_match(ctx$formula, "ideb_fund_i", fixed = TRUE)
  expect_match(r$env$metadados$handle, "^regressao_[0-9]+$")
  for (h in c(ctx$dados_id, ctx$espec_id, ctx$regressao_id)) {
    expect_false(is.null(eduBR_handle_obter(attr(tools, "sessao"), h)))
  }
  for (marca in c("model_fit", "<environment", "clean.", "analytics.")) {
    expect_false(grepl(marca, r$json, fixed = TRUE), info = marca)
  }
  # uma chamada no ledger (as etapas internas não contam)
  expect_equal(ledger(tools)$tool, "regressao_escolas")
})

test_that("regressao_escolas: erros acionáveis e personas", {
  local_mocked_bindings(
    covariaveis_escola = function(con, ano, ano_ideb, uf, rede, ativas) {
      new_eduBR(base_teste(), "eduBR_covariaveis")
    }
  )
  tools <- ferramentas_edubr("fake_con")
  r <- chamar(tools$regressao_escolas, outcome = "nao_existe",
              predictors = list("docentes"))
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  expect_match(r$env$erro$mensagem, "nao_existe", fixed = TRUE)
  r <- chamar(tools$regressao_escolas, outcome = "ideb_fund_i",
              predictors = list("docentes"), uf = "XX")
  expect_equal(r$env$erro$tipo, "parametro_invalido")
  expect_false("regressao_escolas" %in%
                 names(ferramentas_edubr("fake_con", persona = "gestora-escolar")))
  expect_true("regressao_escolas" %in%
                names(ferramentas_edubr("fake_con", persona = "especialista-ml")))
})
