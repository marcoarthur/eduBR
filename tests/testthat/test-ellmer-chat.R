# chat_edubr(): escolha de provedor e montagem dos argumentos, sem rede.

skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")

# Construtor falso: guarda os argumentos e devolve um "chat" mínimo.
construtor_falso <- function(env) {
  function(provedor) {
    env$provedor <- provedor
    function(...) {
      env$args <- list(...)
      chat <- new.env()
      chat$registradas <- NULL
      chat$register_tools <- function(tools) chat$registradas <- tools
      chat
    }
  }
}

sem_vars_llm <- function(env = parent.frame()) {
  withr::local_envvar(
    c(EDUBR_LLM_PROVEDOR = NA, ANTHROPIC_API_KEY = NA, OLLAMA_BASE_URL = NA,
      EDUBR_OLLAMA_MODELO = NA, EDUBR_ANTHROPIC_MODELO = NA),
    .local_envir = env
  )
}

test_that("sem chave nem variável, o provedor padrão é ollama", {
  sem_vars_llm()
  cap <- new.env()
  local_mocked_bindings(eduBR_chat_construtor = construtor_falso(cap))

  chat <- chat_edubr()
  expect_equal(attr(chat, "provedor"), "ollama")
  expect_equal(cap$provedor, "ollama")
  expect_equal(cap$args$model, "qwen3.5:9b")
  expect_equal(cap$args$base_url, "http://localhost:11434")
  expect_equal(cap$args$echo, "none")
  expect_null(cap$args$system_prompt)
})

test_that("com ANTHROPIC_API_KEY o padrão é anthropic", {
  sem_vars_llm()
  withr::local_envvar(ANTHROPIC_API_KEY = "chave-de-teste")
  cap <- new.env()
  local_mocked_bindings(eduBR_chat_construtor = construtor_falso(cap))

  chat <- chat_edubr(system_prompt = "papel")
  expect_equal(attr(chat, "provedor"), "anthropic")
  expect_null(cap$args$base_url)
  expect_null(cap$args$model)
  expect_equal(cap$args$system_prompt, "papel")
  expect_false("api_key" %in% names(cap$args))
})

test_that("EDUBR_LLM_PROVEDOR e argumentos têm precedência", {
  sem_vars_llm()
  withr::local_envvar(
    ANTHROPIC_API_KEY = "chave-de-teste", EDUBR_LLM_PROVEDOR = "ollama",
    OLLAMA_BASE_URL = "http://servidor:11434", EDUBR_OLLAMA_MODELO = "granite4.1:8b"
  )
  cap <- new.env()
  local_mocked_bindings(eduBR_chat_construtor = construtor_falso(cap))

  chat_edubr()
  expect_equal(cap$provedor, "ollama")
  expect_equal(cap$args$model, "granite4.1:8b")
  expect_equal(cap$args$base_url, "http://servidor:11434")

  chat_edubr("ollama", modelo = "outro", base_url = "http://x:1")
  expect_equal(cap$args$model, "outro")
  expect_equal(cap$args$base_url, "http://x:1")

  chat_edubr("anthropic", modelo = "claude-x")
  expect_equal(cap$provedor, "anthropic")
  expect_equal(cap$args$model, "claude-x")
})

test_that("erros claros: provedor, chave, base_url, tools", {
  sem_vars_llm()
  cap <- new.env()
  local_mocked_bindings(eduBR_chat_construtor = construtor_falso(cap))

  expect_error(chat_edubr("openai"), "anthropic, ollama")
  expect_error(chat_edubr("anthropic"), "ANTHROPIC_API_KEY")
  withr::local_envvar(ANTHROPIC_API_KEY = "chave-de-teste")
  expect_error(chat_edubr("anthropic", base_url = "http://x"), "ollama")
  expect_error(chat_edubr("ollama", modelo = ""), "modelo")
  expect_error(chat_edubr("ollama", tools = list(1)), "ferramentas_edubr")
})

test_that("tools são registradas no chat", {
  sem_vars_llm()
  cap <- new.env()
  local_mocked_bindings(eduBR_chat_construtor = construtor_falso(cap))

  tools <- ferramentas_edubr("fake_con", persona = "gestora-escolar")
  chat <- chat_edubr("ollama", tools = tools)
  expect_length(chat$registradas, length(tools))
  expect_true(all(vapply(chat$registradas, inherits, logical(1),
                         "ellmer::ToolDef")))
})

test_that("falha de conexão com o Ollama vira mensagem acionável", {
  sem_vars_llm()
  local_mocked_bindings(
    eduBR_chat_construtor = function(provedor) {
      function(...) stop("Can't find locally running ollama.")
    }
  )
  expect_error(chat_edubr("ollama"), "tunnel-ollama.sh")
})

# Smoke com LLM real: EDUBR_LLM_SMOKE=ollama|anthropic (+ EDUBR_SMOKE para o
# banco). Ollama no container exige o túnel aberto (tools/tunnel-ollama.sh).
test_that("LLM real usa a ferramenta catalogo", {
  provedor <- Sys.getenv("EDUBR_LLM_SMOKE", "")
  skip_if(provedor == "", "Defina EDUBR_LLM_SMOKE=ollama|anthropic")

  con <- conecta(service = "edumaps")
  withr::defer(DBI::dbDisconnect(con))
  tools <- ferramentas_edubr(con, persona = "gestora-escolar",
                             limites = list(timeout_s = 120))
  chat <- chat_edubr(provedor, tools = tools)

  t0 <- Sys.time()
  resposta <- chat$chat(paste(
    "Use a ferramenta `catalogo` e responda apenas com o número de",
    "domínios de dados disponíveis."
  ))
  message(sprintf("LLM (%s): %.1f s; resposta: %s", provedor,
                  as.numeric(difftime(Sys.time(), t0, units = "secs")),
                  substr(as.character(resposta), 1, 200)))

  led <- ledger(tools)
  expect_true("catalogo" %in% led$tool)
  expect_true(all(is.na(led$erro[led$tool == "catalogo"])))
  expect_match(as.character(resposta), "16")
})
