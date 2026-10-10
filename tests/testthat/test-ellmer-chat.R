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
      EDUBR_OLLAMA_MODELO = NA, EDUBR_ANTHROPIC_MODELO = NA,
      GEMINI_API_KEY = NA, GOOGLE_API_KEY = NA, EDUBR_GEMINI_MODELO = NA,
      EDUBR_MAX_TOKENS = NA),
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

test_that("gemini: chave no ambiente, escolha automática e modelo", {
  sem_vars_llm()
  cap <- new.env()
  local_mocked_bindings(eduBR_chat_construtor = construtor_falso(cap))

  expect_error(chat_edubr("gemini"), "GEMINI_API_KEY")

  withr::local_envvar(GEMINI_API_KEY = "chave-de-teste")
  chat <- chat_edubr(system_prompt = "papel")
  expect_equal(attr(chat, "provedor"), "gemini")
  expect_equal(cap$provedor, "gemini")
  expect_null(cap$args$model)
  expect_null(cap$args$base_url)
  expect_null(cap$args$api_args)
  expect_null(cap$args$params)
  expect_equal(cap$args$system_prompt, "papel")
  expect_false(any(c("api_key", "credentials") %in% names(cap$args)))
  expect_equal(attr(chat, "raciocinio"), "padrao")
  expect_error(chat_edubr("gemini", base_url = "http://x"), "ollama")

  withr::local_envvar(EDUBR_GEMINI_MODELO = "gemini-x")
  chat_edubr("gemini", max_tokens = 2000, raciocinio = "desligado")
  expect_equal(cap$args$model, "gemini-x")
  expect_equal(cap$args$params$max_tokens, 2000L)
  expect_null(cap$args$api_args)

  withr::local_envvar(GEMINI_API_KEY = NA, GOOGLE_API_KEY = "chave-google")
  chat_edubr()
  expect_equal(cap$provedor, "gemini")

  withr::local_envvar(ANTHROPIC_API_KEY = "chave-de-teste")
  chat_edubr()
  expect_equal(cap$provedor, "anthropic")
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

  expect_error(chat_edubr("openai"), "anthropic, gemini, ollama")
  expect_error(chat_edubr("anthropic"), "ANTHROPIC_API_KEY")
  withr::local_envvar(ANTHROPIC_API_KEY = "chave-de-teste")
  expect_error(chat_edubr("anthropic", base_url = "http://x"), "ollama")
  expect_error(chat_edubr("ollama", modelo = ""), "modelo")
  expect_error(chat_edubr("ollama", tools = list(1)), "ferramentas_edubr")
})

test_that("raciocinio desligado vira reasoning_effort none no Ollama", {
  sem_vars_llm()
  cap <- new.env()
  local_mocked_bindings(eduBR_chat_construtor = construtor_falso(cap))

  # padrão no Ollama: desligado (#94)
  chat <- chat_edubr("ollama")
  expect_equal(cap$args$api_args, list(reasoning_effort = "none"))
  expect_equal(attr(chat, "raciocinio"), "desligado")

  chat <- chat_edubr("ollama", raciocinio = "padrao")
  expect_null(cap$args$api_args)
  expect_equal(attr(chat, "raciocinio"), "padrao")

  chat <- chat_edubr("ollama", raciocinio = "desligado")
  expect_equal(cap$args$api_args, list(reasoning_effort = "none"))
  expect_equal(attr(chat, "raciocinio"), "desligado")

  chat_edubr("ollama", raciocinio = "desligado",
             api_args = list(temperature = 0))
  expect_equal(cap$args$api_args,
               list(temperature = 0, reasoning_effort = "none"))

  expect_error(
    chat_edubr("ollama", raciocinio = "desligado",
               api_args = list(reasoning_effort = "high")),
    "conflita"
  )
  expect_error(chat_edubr("ollama", raciocinio = "talvez"))

  withr::local_envvar(ANTHROPIC_API_KEY = "chave-de-teste")
  chat_edubr("anthropic", raciocinio = "desligado")
  expect_null(cap$args$api_args)
  chat <- chat_edubr("anthropic")
  expect_equal(attr(chat, "raciocinio"), "padrao")
})

test_that("max_tokens: padrão 4096 no Ollama, configurável e combinado (#89)", {
  sem_vars_llm()
  withr::local_envvar(EDUBR_MAX_TOKENS = NA)
  cap <- new.env()
  local_mocked_bindings(eduBR_chat_construtor = construtor_falso(cap))

  chat <- chat_edubr("ollama")
  expect_equal(cap$args$params$max_tokens, 4096L)
  expect_equal(attr(chat, "max_tokens"), 4096L)

  chat_edubr("ollama", max_tokens = 8000)
  expect_equal(cap$args$params$max_tokens, 8000L)

  chat_edubr("ollama", params = ellmer::params(temperature = 0))
  expect_equal(cap$args$params$temperature, 0)
  expect_equal(cap$args$params$max_tokens, 4096L)

  expect_error(chat_edubr("ollama", max_tokens = 100,
                          params = ellmer::params(max_tokens = 200)),
               "conflita")
  expect_error(chat_edubr("ollama", max_tokens = 0), "inteiro")

  withr::local_envvar(EDUBR_MAX_TOKENS = "2048")
  chat_edubr("ollama")
  expect_equal(cap$args$params$max_tokens, 2048L)

  withr::local_envvar(EDUBR_MAX_TOKENS = NA, ANTHROPIC_API_KEY = "chave-de-teste")
  chat_edubr("anthropic")
  expect_null(cap$args$params)
  chat_edubr("anthropic", max_tokens = 3000)
  expect_equal(cap$args$params$max_tokens, 3000L)
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

test_that("chat_edubr() devolve um EduBRChat com prompt, modelo e tools", {
  skip_if_not_installed("R6")
  sem_vars_llm()
  withr::local_envvar(GEMINI_API_KEY = "chave-de-teste")

  tools <- ferramentas_edubr("fake_con", persona = "gestora-escolar")
  chat <- chat_edubr("gemini", modelo = "gemini-x", tools = tools,
                     system_prompt = "papel")
  expect_s3_class(chat, "EduBRChat")
  expect_s3_class(chat, "Chat")
  expect_equal(chat$get_model(), "gemini-x")
  expect_match(chat$get_system_prompt(), "papel$")
  expect_setequal(names(chat$get_tools()), names(tools))
  expect_equal(attr(chat, "provedor"), "gemini")
})

# Resposta HTTP simulada (sem rede); retry-after 0 evita a espera do
# retry do ellmer.
resposta_http <- function(status, mensagem) {
  function(req) {
    httr2::response(
      status,
      headers = list("Content-Type" = "application/json", "retry-after" = "0"),
      body = charToRaw(sprintf(
        '{"error":{"code":%d,"message":"%s"}}', status, mensagem
      ))
    )
  }
}

test_that("HTTP 429 vira mensagem acionável em PT-BR (#105)", {
  skip_if_not_installed("R6")
  skip_if_not_installed("httr2")
  sem_vars_llm()
  withr::local_envvar(GEMINI_API_KEY = "chave-secreta-de-teste")
  chat <- chat_edubr("gemini", modelo = "gemini-x")
  httr2::local_mocked_responses(
    resposta_http(429, "Quota exceeded. Please retry in 1h2m3.45s.")
  )

  e <- tryCatch(chat$chat("oi"), error = function(e) e)
  expect_s3_class(e, "eduBR_cota_esgotada")
  expect_s3_class(e$parent, "httr2_http_429")
  msg <- conditionMessage(e)
  expect_match(msg, "provedor \"gemini\" (modelo gemini-x)", fixed = TRUE)
  expect_match(msg, "tentar de novo em 1h2m3s", fixed = TRUE)
  expect_match(msg, "EDUBR_GEMINI_MODELO", fixed = TRUE)
  expect_false(grepl("chave-secreta-de-teste", msg, fixed = TRUE))

  e2 <- tryCatch(chat$chat_structured("oi", type = ellmer::type_string()),
                 error = function(e) e)
  expect_s3_class(e2, "eduBR_cota_esgotada")
})

test_that("outros erros HTTP passam sem tradução", {
  skip_if_not_installed("R6")
  skip_if_not_installed("httr2")
  sem_vars_llm()
  withr::local_envvar(GEMINI_API_KEY = "chave-de-teste")
  chat <- chat_edubr("gemini", modelo = "gemini-x")
  httr2::local_mocked_responses(resposta_http(400, "Bad request"))

  e <- tryCatch(chat$chat("oi"), error = function(e) e)
  expect_s3_class(e, "httr2_http_400")
  expect_false(inherits(e, "eduBR_cota_esgotada"))
})

test_that("tempo de espera: texto da API, retry-after ou nenhum", {
  skip_if_not_installed("httr2")
  erro <- function(msg, ra = NULL) {
    hd <- if (is.null(ra)) list() else list("retry-after" = ra)
    structure(
      class = c("httr2_http_429", "error", "condition"),
      list(message = msg, resp = httr2::response(429, headers = hd))
    )
  }
  expect_equal(eduBR_espera_429(erro("Please retry in 10h27m59.69s.")),
               "10h27m59s")
  expect_equal(eduBR_espera_429(erro("Rate limited", ra = "30")), "30 s")
  expect_null(eduBR_espera_429(erro("Rate limited", ra = "0")))
  expect_null(eduBR_espera_429(erro("Rate limited")))
})

# Smoke com LLM real: EDUBR_LLM_SMOKE=ollama|anthropic|gemini (+ EDUBR_SMOKE para o
# banco). Ollama no container exige o túnel aberto (tools/tunnel-ollama.sh).
test_that("LLM real usa a ferramenta catalogo", {
  provedor <- Sys.getenv("EDUBR_LLM_SMOKE", "")
  skip_if(provedor == "", "Defina EDUBR_LLM_SMOKE=ollama|anthropic|gemini")

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
