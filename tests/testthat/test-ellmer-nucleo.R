# Núcleo da camada ellmer (chunk 1): contrato, envelope, serialização, cap,
# ledger, orçamento, erros, anti-vazamento, persona, handles e persistência.
# Sem banco: a conexão é falsa e as tools de teste usam dados em memória.

skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")

# Executa uma tool e devolve o envelope (lista R) a partir do JSON.
chamar <- function(tool, ...) {
  json <- tool(...)
  expect_type(json, "character")
  expect_length(json, 1L)
  expect_true(jsonlite::validate(json))
  eduBR_envelope_de(json)
}

# Tool de teste montada com os helpers internos, na sessão de `tools`.
tool_teste <- function(tools, fun, nome = "teste") {
  args <- list()
  if ("n" %in% names(formals(fun))) {
    args$n <- ellmer::type_integer("linhas", required = FALSE)
  }
  eduBR_tool(attr(tools, "sessao"), nome, fun, "Tool de teste.",
             arguments = args)
}

test_that("ferramentas_edubr() devolve lista nomeada de ToolDef", {
  tools <- ferramentas_edubr("fake_con")

  expect_type(tools, "list")
  expect_true("catalogo" %in% names(tools))
  expect_true(all(vapply(tools, inherits, logical(1), "ellmer::ToolDef")))
  expect_true(is.environment(attr(tools, "ledger")))
  expect_true(is.environment(attr(tools, "sessao")))
})

test_that("tool catalogo devolve envelope sem schema/tabela", {
  tools <- ferramentas_edubr("fake_con")
  json <- tools$catalogo()
  res <- eduBR_envelope_de(json)

  expect_named(res, c("dados", "metadados", "erro"))
  expect_null(res$erro)
  expect_equal(res$metadados$grao, "dominio")
  expect_equal(res$metadados$n, nrow(catalogo()))
  expect_gt(length(res$dados), 0L)
  for (reg in res$dados) {
    expect_false(any(c("schema", "tabela") %in% names(reg)))
    expect_true(all(c("dominio", "granularidade", "chave", "tipo_chave",
                      "coluna_ano", "anos") %in% names(reg)))
  }
  expect_no_error(jsonlite::toJSON(res, auto_unbox = TRUE, null = "null"))

  # nenhum schema.tabela físico no JSON devolvido
  rel <- eduBR_relacoes_fisicas()
  for (i in seq_len(nrow(rel))) {
    expect_false(grepl(paste0(rel$schema[i], ".", rel$tabela[i]), json,
                       fixed = TRUE))
  }
})

test_that("eduBR_serializar() converte tipos e omite geometria/PII", {
  df <- data.frame(
    data = as.Date(c("2023-01-02", NA)),
    momento = as.POSIXct(c("2023-01-02 03:04:05", NA), tz = "UTC"),
    fator = factor(c("a", "b")),
    valor = c(NaN, Inf),
    inteiro = c(1L, NA),
    nu_telefone = c("1199999", "1188888"),
    stringsAsFactors = FALSE
  )
  df$geometry <- c("POINT(0 0)", "POINT(1 1)")
  if (requireNamespace("bit64", quietly = TRUE)) {
    df$codigo <- bit64::as.integer64(c("35000000000000001", NA))
  }

  ser <- eduBR_serializar(df)

  expect_setequal(ser$omitidas, c("nu_telefone", "geometry"))
  r1 <- ser$dados[[1]]
  r2 <- ser$dados[[2]]
  expect_false(any(c("nu_telefone", "geometry") %in% names(r1)))
  expect_identical(r1$data, "2023-01-02")
  expect_identical(r1$momento, "2023-01-02T03:04:05Z")
  expect_identical(r1$fator, "a")
  expect_null(r1$valor)
  expect_null(r2$valor)
  expect_null(r2$data)
  expect_null(r2$inteiro)
  expect_true("valor" %in% names(r1))
  if (requireNamespace("bit64", quietly = TRUE)) {
    expect_identical(r1$codigo, "35000000000000001")
    expect_null(r2$codigo)
  }

  json <- jsonlite::toJSON(ser$dados, auto_unbox = TRUE, null = "null",
                           na = "null", digits = NA)
  expect_match(json, '"codigo":"35000000000000001"', fixed = TRUE,
               all = FALSE)
  expect_match(json, '"valor":null', fixed = TRUE)
})

test_that("envelope informa colunas omitidas", {
  tools <- ferramentas_edubr("fake_con")
  t <- tool_teste(tools, function() {
    tibble::tibble(a = 1:2, ds_endereco = c("x", "y"))
  })
  res <- chamar(t)

  expect_null(res$erro)
  expect_equal(unlist(res$metadados$colunas_omitidas), "ds_endereco")
  expect_false("ds_endereco" %in% names(res$dados[[1]]))
  expect_match(res$metadados$aviso, "ds_endereco")
})

test_that("cap: n enorme devolve no máximo 1000 linhas com aviso", {
  tools <- ferramentas_edubr("fake_con")
  grande <- new_eduBR(tibble::tibble(i = seq_len(5000)), "eduBR_x")
  t <- tool_teste(tools, function(n = NULL) grande)

  res <- chamar(t, n = 1e6)
  expect_null(res$erro)
  expect_lte(length(res$dados), 1000L)
  expect_equal(res$metadados$n, 1000L)
  expect_true(res$metadados$truncado)
  expect_equal(res$metadados$n_total, 5000L)
  expect_match(res$metadados$aviso, "reduzido")

  res <- chamar(t)
  expect_equal(length(res$dados), 100L)

  expect_error(
    ferramentas_edubr("fake_con", limites = list(max_linhas = 5000)),
    "1000"
  )
})

test_that("limites inválidos são rejeitados", {
  expect_error(ferramentas_edubr("fake_con", limites = list(xpto = 1)),
               "desconhecida")
  expect_error(ferramentas_edubr("fake_con", limites = list(max_chamadas = -1)),
               "max_chamadas")
  expect_error(ferramentas_edubr("fake_con", limites = list(timeout_s = "a")),
               "timeout_s")
  expect_error(ferramentas_edubr("fake_con", limites = list(max_amostra = 1e5)),
               "max_amostra")
  expect_error(ferramentas_edubr("fake_con", limites = list(persistir = NA)),
               "persistir")
  lim <- attr(ferramentas_edubr("fake_con"), "sessao")$limites
  expect_equal(lim$n_padrao, 100L)
  expect_equal(lim$max_linhas, 1000L)
  expect_equal(lim$max_chamadas, 50L)
  expect_equal(lim$max_linhas_total, 10000)
  expect_equal(lim$timeout_s, 30)
  expect_equal(lim$max_amostra, 15000L)
  expect_false(lim$persistir)
  expect_null(lim$ledger_arquivo)
})

test_that("ledger registra chamadas e linhas", {
  tools <- ferramentas_edubr("fake_con")
  expect_equal(nrow(ledger(tools)), 0L)
  t <- tool_teste(tools, function(n = NULL) tibble::tibble(i = 1:20))

  tools$catalogo()
  t(n = 5L)
  t()

  led <- ledger(tools)
  expect_equal(nrow(led), 3L)
  expect_named(led, c("timestamp", "tool", "args", "n_linhas", "duracao_ms",
                      "erro"))
  expect_s3_class(led$timestamp, "POSIXct")
  expect_equal(led$tool, c("catalogo", "teste", "teste"))
  expect_equal(led$args, c("{}", '{"n":5}', "{}"))
  expect_equal(sum(led$n_linhas), nrow(catalogo()) + 5L + 20L)
  expect_true(all(is.na(led$erro)))
  expect_error(ledger(list()), "ferramentas_edubr")
})

test_that("orçamento: max_chamadas e max_linhas_total", {
  executou <- 0L
  tools <- ferramentas_edubr("fake_con", limites = list(max_chamadas = 2))
  t <- tool_teste(tools, function() {
    executou <<- executou + 1L
    tibble::tibble(i = 1:3)
  })
  expect_null(chamar(t)$erro)
  expect_null(chamar(t)$erro)
  res <- chamar(t)
  expect_equal(res$erro$tipo, "limite_excedido")
  expect_equal(executou, 2L)
  led <- ledger(tools)
  expect_equal(nrow(led), 3L)
  expect_equal(led$erro[3], "limite_excedido")

  tools <- ferramentas_edubr("fake_con",
                             limites = list(max_linhas_total = 10))
  t <- tool_teste(tools, function(n = NULL) tibble::tibble(i = 1:100))
  res <- chamar(t, n = 50L)
  expect_equal(length(res$dados), 10L)
  expect_match(res$metadados$aviso, "orçamento")
  res <- chamar(t)
  expect_equal(res$erro$tipo, "limite_excedido")
  expect_length(res$dados, 0L)
})

test_that("erros são classificados sem vazar SQL", {
  tools <- ferramentas_edubr("fake_con")

  t <- tool_teste(tools, function() {
    stop(paste0(
      "ERROR: relation \"clean.ideb_notas_escolas\" does not exist ",
      "LINE 1: SELECT * FROM \"clean\".\"ideb_notas_escolas\""
    ))
  }, "falha_sql")
  json <- t()
  res <- eduBR_envelope_de(json)
  expect_equal(res$erro$tipo, "conexao")
  for (s in c("clean.", "SELECT", "ERROR:", "relation")) {
    expect_false(grepl(s, res$erro$mensagem, fixed = TRUE))
    expect_false(grepl(s, json, fixed = TRUE))
  }

  t <- tool_teste(tools, function() {
    stop("`n` deve ser um inteiro positivo.", call. = FALSE)
  }, "falha_param")
  res <- chamar(t)
  expect_equal(res$erro$tipo, "parametro_invalido")
  expect_equal(res$erro$mensagem, "`n` deve ser um inteiro positivo.")

  t <- tool_teste(tools, function(n = NULL) tibble::tibble(i = integer(0)),
                  "vazia")
  res <- chamar(t)
  expect_equal(res$erro$tipo, "sem_dados")
  expect_length(res$dados, 0L)

  t <- tool_teste(tools, function(n = NULL) tibble::tibble(i = 1:3))
  expect_equal(chamar(t, n = -1L)$erro$tipo, "parametro_invalido")

  led <- ledger(tools)
  expect_equal(led$erro, c("conexao", "parametro_invalido", "sem_dados",
                           "parametro_invalido"))
})

test_that("timeout interrompe a chamada como limite_excedido", {
  tools <- ferramentas_edubr("fake_con", limites = list(timeout_s = 1))
  # laço em R (setTimeLimit não interrompe código em C, como Sys.sleep;
  # no banco quem corta é o statement_timeout)
  t <- tool_teste(tools, function() {
    t0 <- Sys.time()
    while (Sys.time() - t0 < 4) x <- sum(stats::runif(1e3))
    tibble::tibble(i = 1)
  }, "lenta")
  res <- chamar(t)
  expect_equal(res$erro$tipo, "limite_excedido")
  expect_match(res$erro$mensagem, "tempo limite")
  # o limite de tempo é restaurado depois da chamada
  t0 <- Sys.time()
  expect_no_error(while (Sys.time() - t0 < 1.5) x <- sum(stats::runif(1e3)))
})

test_that("anti-vazamento troca schema.tabela pelo domínio", {
  env <- eduBR_envelope(
    dados = list(list(origem = "clean.ideb_notas_escolas")),
    aviso = "ver \"clean\".\"inse\""
  )
  out <- eduBR_anti_vazamento(env)
  expect_identical(out$dados[[1]]$origem, "ideb")
  expect_identical(out$metadados$aviso, "ver inse")
  expect_null(out$erro)

  json <- eduBR_envelope_json(env)
  expect_false(grepl("clean.", json, fixed = TRUE))
  expect_match(json, '"origem":"ideb"', fixed = TRUE)

  expect_identical(eduBR_anti_vazamento("clean.escolas_x"), "clean.escolas_x")
})

test_that("filtro por persona", {
  expect_error(ferramentas_edubr("fake_con", persona = "x"), "persona")
  for (p in eduBR_personas()) {
    expect_true("catalogo" %in% names(ferramentas_edubr("fake_con", persona = p)))
  }
})

test_that("handles: guardar e obter", {
  sessao <- attr(ferramentas_edubr("fake_con"), "sessao")
  id1 <- eduBR_handle_guardar(sessao, "dados", mtcars)
  id2 <- eduBR_handle_guardar(sessao, "dados", iris)
  id3 <- eduBR_handle_guardar(sessao, "espec", 1)
  expect_identical(c(id1, id2, id3), c("dados_1", "dados_2", "espec_1"))
  expect_identical(eduBR_handle_obter(sessao, "dados_2"), iris)

  err <- tryCatch(eduBR_handle_obter(sessao, "dados_9"), error = identity)
  expect_s3_class(err, "eduBR_erro_tool")
  expect_equal(err$tipo, "parametro_invalido")
  expect_match(conditionMessage(err), "handle inexistente")
  expect_equal(eduBR_classificar_erro(err)$tipo, "parametro_invalido")

  expect_error(eduBR_handle_guardar(sessao, "Dados X", 1), "prefixo")
})

test_that("ledger persiste em CSV quando pedido", {
  arq <- withr::local_tempfile(fileext = ".csv")
  tools <- ferramentas_edubr("fake_con", limites = list(ledger_arquivo = arq))
  tools$catalogo()
  expect_true(file.exists(arq))
  expect_equal(nrow(utils::read.csv(arq)), 1L)
  tools$catalogo()
  csv <- utils::read.csv(arq, stringsAsFactors = FALSE)
  expect_equal(nrow(csv), 2L)
  expect_named(csv, c("timestamp", "tool", "args", "n_linhas", "duracao_ms",
                      "erro"))
  expect_equal(csv$tool, c("catalogo", "catalogo"))
})

test_that("persistir = TRUE grava em R_user_dir", {
  dir <- withr::local_tempdir()
  withr::local_envvar(R_USER_DATA_DIR = dir)
  tools <- ferramentas_edubr("fake_con", limites = list(persistir = TRUE))
  tools$catalogo()
  arq <- file.path(
    tools::R_user_dir("eduBR", "data"), "ledger",
    sprintf("ledger-%s.csv", format(Sys.Date(), "%Y-%m-%d"))
  )
  expect_true(file.exists(arq))
  expect_true(startsWith(normalizePath(arq), normalizePath(dir)))
})

test_that("max_caracteres corta linhas do fim e avisa", {
  base <- tibble::tibble(id = sprintf("%05d", 1:200),
                         texto = strrep("x", 200))
  tools <- ferramentas_edubr("fake_con", limites = list(max_caracteres = 5000))
  s <- attr(tools, "sessao")
  env <- eduBR_executar_tool(s, "teste", list(n = 200),
                             function(n) eduBR_resultado(base))
  expect_null(env$erro)
  expect_true(env$metadados$truncado)
  expect_lt(length(env$dados), 200L)
  expect_gte(length(env$dados), 1L)
  expect_lte(nchar(jsonlite::toJSON(env$dados, auto_unbox = TRUE)), 5000)
  expect_match(env$metadados$aviso, "limite de texto", fixed = TRUE)
  expect_equal(env$dados[[1]]$id, "00001")

  pequeno <- eduBR_executar_tool(s, "teste", list(n = 3),
                                 function(n) eduBR_resultado(base))
  expect_length(pequeno$dados, 3L)
  expect_false(grepl("limite de texto", pequeno$metadados$aviso %||% "",
                     fixed = TRUE))

  expect_error(ferramentas_edubr("fake_con", limites = list(max_caracteres = 10)),
               "1000")
})
