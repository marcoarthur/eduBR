# Chamadas recusadas pelo ellmer antes da tool entram no ledger (#75).

skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")

chat_com_ganchos <- function() {
  chat <- new.env()
  chat$callbacks <- list()
  chat$ferramentas <- list()
  chat$prompt <- NULL
  chat$register_tools <- function(tools) chat$ferramentas <- tools
  chat$get_tools <- function() {
    stats::setNames(chat$ferramentas,
                    vapply(chat$ferramentas, function(t) t@name, character(1)))
  }
  chat$on_tool_result <- function(callback) {
    chat$callbacks[[length(chat$callbacks) + 1L]] <- callback
  }
  chat$set_system_prompt <- function(x) chat$prompt <- x
  chat$get_system_prompt <- function() chat$prompt
  chat
}

recusa <- function(nome, args, erro = "Unused argument: escola") {
  ellmer::ContentToolResult(
    error = erro,
    request = ellmer::ContentToolRequest(id = "1", name = nome, arguments = args)
  )
}

test_that("recusa do ellmer vira linha no ledger e conta a chamada", {
  tools <- ferramentas_edubr("fake_con", persona = "gestora-escolar")
  chat <- chat_com_ganchos()
  registrar_tools(chat, tools)
  expect_length(chat$callbacks, 1L)

  chat$callbacks[[1]](recusa("perfil_escola", list(escola = "13078070")))
  chat$callbacks[[1]](recusa("nao_existe", list(), erro = "Unknown tool"))
  led <- ledger(tools)
  expect_equal(nrow(led), 2L)
  expect_equal(led$tool, c("perfil_escola", "nao_existe"))
  expect_equal(led$erro, rep("argumento_recusado", 2L))
  expect_equal(led$n_linhas, c(0L, 0L))
  expect_match(led$args[1], "13078070", fixed = TRUE)
  expect_equal(attr(tools, "sessao")$ledger$n_chamadas, 2L)
  expect_equal(attr(tools, "sessao")$ledger$n_linhas_total, 0L)
})

test_that("resultado sem erro não duplica a linha do wrapper", {
  tools <- ferramentas_edubr("fake_con", persona = "gestora-escolar")
  chat <- chat_com_ganchos()
  registrar_tools(chat, tools)
  ok <- ellmer::ContentToolResult(
    value = "{}",
    request = ellmer::ContentToolRequest(id = "1", name = "catalogo",
                                         arguments = list())
  )
  chat$callbacks[[1]](ok)
  expect_equal(nrow(ledger(tools)), 0L)
})

test_that("gancho instalado uma vez por chat e ignora tools de terceiros", {
  tools <- ferramentas_edubr("fake_con", persona = "gestora-escolar")
  chat <- chat_com_ganchos()
  registrar_tools(chat, tools)
  registrar_tools(chat, tools)
  expect_length(chat$callbacks, 1L)

  outra <- ellmer::tool(function(x) x, name = "outra", description = "outra",
                        arguments = list(x = ellmer::type_string("x")))
  chat$ferramentas <- c(chat$ferramentas, list(outra))
  chat$callbacks[[1]](recusa("outra", list(y = 1), erro = "Unused argument: y"))
  expect_equal(nrow(ledger(tools)), 0L)
})

test_that("chat_edubr() também instala o gancho", {
  withr::local_envvar(c(EDUBR_LLM_PROVEDOR = NA, ANTHROPIC_API_KEY = NA))
  chat <- chat_com_ganchos()
  local_mocked_bindings(
    eduBR_chat_construtor = function(provedor) function(...) chat
  )
  tools <- ferramentas_edubr("fake_con", persona = "gestora-escolar")
  chat_edubr("ollama", tools = tools)
  expect_length(chat$callbacks, 1L)
})

test_that("chat sem on_tool_result segue funcionando", {
  tools <- ferramentas_edubr("fake_con")
  chat <- chat_com_ganchos()
  rm("on_tool_result", envir = chat)
  expect_silent(registrar_tools(chat, tools))
})

test_that("Chat real do ellmer executa o gancho pelo CallbackManager", {
  chat <- suppressWarnings(
    ellmer::chat_openai(credentials = function() "x", model = "gpt-4.1")
  )
  cb <- tryCatch(chat$.__enclos_env__$private$callback_on_tool_result,
                 error = function(e) NULL)
  skip_if(is.null(cb) || !is.function(cb$invoke),
          "Internos do ellmer mudaram (CallbackManager)")

  tools <- ferramentas_edubr("fake_con", persona = "gestora-escolar")
  registrar_tools(chat, tools)
  cb$invoke(recusa("perfil_escola", list(escola = "13078070")))
  led <- ledger(tools)
  expect_equal(led$tool, "perfil_escola")
  expect_equal(led$erro, "argumento_recusado")
})
