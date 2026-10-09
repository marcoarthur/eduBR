# Prompts por persona, registrar_tools(), chat_edubr(persona =) e a matriz
# pergunta x tool de docs/ellmer.md. Sem banco nem rede.

skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")

tools_da_persona <- function(persona) {
  reg <- eduBR_tools_registro()
  names(reg)[vapply(reg, function(r) persona %in% r$personas, logical(1))]
}

# Nomes entre crases que casam com tools do registro.
tools_citadas <- function(texto) {
  crases <- regmatches(texto, gregexpr("`[^`\n]+`", texto))[[1]]
  crases <- gsub("`", "", crases)
  unique(intersect(crases, names(eduBR_tools_registro())))
}

# Chat falso com a interface usada por registrar_tools().
chat_falso <- function(prompt = NULL) {
  chat <- new.env()
  chat$prompt <- prompt
  chat$registradas <- NULL
  chat$register_tools <- function(tools) chat$registradas <- tools
  chat$set_system_prompt <- function(value) chat$prompt <- value
  chat$get_system_prompt <- function() chat$prompt
  chat
}

test_that("prompt_persona() devolve texto para as 3 personas", {
  for (p in eduBR_personas()) {
    txt <- prompt_persona(p)
    expect_type(txt, "character")
    expect_length(txt, 1L)
    expect_gt(nchar(txt), 500)
    linhas <- length(strsplit(txt, "\n", fixed = TRUE)[[1]])
    expect_lte(linhas, 140)
    for (secao in c("## Papel", "## Vocabulário", "## Sempre", "## Nunca",
                    "## Pegadinhas")) {
      expect_match(txt, secao, fixed = TRUE, info = p)
    }
  }
})

test_that("persona inválida em prompt_persona() é erro", {
  expect_error(prompt_persona("diretor"), "gestora-escolar")
  expect_error(prompt_persona(NULL), "persona")
  expect_error(prompt_persona(c("gestora-escolar", "especialista-ml")),
               "persona")
})

test_that("tools citadas no prompt existem e são da persona; todas aparecem", {
  for (p in eduBR_personas()) {
    citadas <- tools_citadas(prompt_persona(p))
    proprias <- tools_da_persona(p)
    expect_equal(setdiff(citadas, proprias), character(0), info = p)
    expect_equal(setdiff(proprias, citadas), character(0), info = p)
  }
  expect_false("treinar_floresta" %in% tools_citadas(prompt_persona("gestora-escolar")))
})

test_that("prompts não citam schema.tabela físico", {
  cat <- eduBR_catalogo()
  schemas <- unique(vapply(cat, `[[`, character(1), 1L))
  fisicos <- vapply(cat, paste, character(1), collapse = ".")
  # Tabelas cujo nome difere do domínio (as iguais são nomes de domínio).
  tabelas <- setdiff(vapply(cat, `[[`, character(1), 2L), names(cat))
  for (p in eduBR_personas()) {
    txt <- prompt_persona(p)
    for (s in c(schemas, "staging")) {
      expect_false(grepl(paste0(s, "."), txt, fixed = TRUE), info = paste(p, s))
    }
    for (f in c(fisicos, tabelas)) {
      expect_false(grepl(f, txt, fixed = TRUE), info = paste(p, f))
    }
  }
})

test_that("ferramentas_edubr() guarda a persona como atributo", {
  expect_equal(attr(ferramentas_edubr("fake_con", persona = "especialista-ml"),
                    "persona"), "especialista-ml")
  expect_null(attr(ferramentas_edubr("fake_con"), "persona"))
})

test_that("registrar_tools() registra as tools e define o prompt da persona", {
  tools <- ferramentas_edubr("fake_con", persona = "gestora-escolar")
  chat <- chat_falso()
  out <- registrar_tools(chat, tools)
  expect_identical(out, chat)
  expect_length(chat$registradas, length(tools))
  expect_true(all(vapply(chat$registradas, inherits, logical(1),
                         "ellmer::ToolDef")))
  expect_equal(chat$prompt, prompt_persona("gestora-escolar"))

  # Persona explícita igual à das tools.
  chat2 <- chat_falso()
  registrar_tools(chat2, tools, persona = "gestora-escolar")
  expect_equal(chat2$prompt, prompt_persona("gestora-escolar"))
})

test_that("registrar_tools() concatena com prompt existente sem duplicar", {
  tools <- ferramentas_edubr("fake_con", persona = "pesquisadora-educacional")
  base <- prompt_persona("pesquisadora-educacional")
  chat <- chat_falso("Responda em tópicos.")
  registrar_tools(chat, tools)
  expect_equal(chat$prompt, paste0(base, "\n\nResponda em tópicos."))

  registrar_tools(chat, tools)
  expect_equal(chat$prompt, paste0(base, "\n\nResponda em tópicos."))
})

test_that("registrar_tools(): sem persona usa prompt genérico; erros claros", {
  tools <- ferramentas_edubr("fake_con")
  chat <- chat_falso()
  registrar_tools(chat, tools)
  expect_equal(chat$prompt, eduBR_prompt_generico())
  expect_length(chat$registradas, length(eduBR_tools_registro()))

  chat <- chat_falso()
  registrar_tools(chat, tools, persona = "especialista-ml")
  expect_equal(chat$prompt, prompt_persona("especialista-ml"))

  tools_g <- ferramentas_edubr("fake_con", persona = "gestora-escolar")
  expect_error(registrar_tools(chat_falso(), tools_g, persona = "especialista-ml"),
               "difere")
  expect_error(registrar_tools(chat_falso(), list(1)), "ferramentas_edubr")
  expect_error(registrar_tools(list(), tools_g), "Chat")
  expect_error(registrar_tools(chat_falso(), tools_g, persona = "x"), "persona")
})

test_that("prompt genérico não cita schema físico e é ASCII-seguro em R", {
  txt <- eduBR_prompt_generico()
  expect_false(grepl("clean.", txt, fixed = TRUE))
  expect_true(all(tools_citadas(txt) %in% names(eduBR_tools_registro())))
})

# chat_edubr() com construtor mockado.
construtor_persona <- function(env) {
  function(provedor) {
    function(...) {
      env$args <- list(...)
      chat <- new.env()
      chat$register_tools <- function(tools) chat$registradas <- tools
      chat
    }
  }
}

test_that("chat_edubr(persona =) passa o prompt da persona", {
  withr::local_envvar(
    c(EDUBR_LLM_PROVEDOR = NA, ANTHROPIC_API_KEY = NA, OLLAMA_BASE_URL = NA,
      EDUBR_OLLAMA_MODELO = NA, EDUBR_ANTHROPIC_MODELO = NA)
  )
  cap <- new.env()
  local_mocked_bindings(eduBR_chat_construtor = construtor_persona(cap))

  chat <- chat_edubr("ollama", persona = "gestora-escolar")
  expect_equal(cap$args$system_prompt, prompt_persona("gestora-escolar"))
  expect_equal(attr(chat, "persona"), "gestora-escolar")

  # Persona inferida das tools; system_prompt vai depois.
  tools <- ferramentas_edubr("fake_con", persona = "especialista-ml")
  chat <- chat_edubr("ollama", tools = tools, system_prompt = "Seja breve.")
  expect_equal(cap$args$system_prompt,
               paste0(prompt_persona("especialista-ml"), "\n\nSeja breve."))
  expect_length(chat$registradas, length(tools))

  # Tools sem persona: prompt genérico.
  chat_edubr("ollama", tools = ferramentas_edubr("fake_con"))
  expect_equal(cap$args$system_prompt, eduBR_prompt_generico())

  # Sem tools nem persona: comportamento anterior.
  chat_edubr("ollama", system_prompt = "papel")
  expect_equal(cap$args$system_prompt, "papel")
  chat_edubr("ollama")
  expect_null(cap$args$system_prompt)

  expect_error(chat_edubr("ollama", persona = "outra"), "persona")
  expect_error(chat_edubr("ollama", tools = tools, persona = "gestora-escolar"),
               "difere")
})

# docs/ellmer.md fica fora do build: só roda no repositório.
arquivo_doc <- function(...) testthat::test_path("..", "..", "docs", ...)

perguntas_canonicas <- function(arquivo) {
  linhas <- readLines(arquivo, encoding = "UTF-8", warn = FALSE)
  ini <- which(linhas == "## Perguntas canônicas")
  expect_length(ini, 1L)
  fim <- ini + which(startsWith(linhas[(ini + 1):length(linhas)], "## "))[1]
  bloco <- linhas[(ini + 1):(fim - 1)]
  grupo <- cumsum(grepl("^[0-9]+\\. ", bloco))
  itens <- split(bloco[grupo > 0], grupo[grupo > 0])
  vapply(itens, function(x) {
    sub("^[0-9]+\\. ", "", normalizar(paste(x, collapse = " ")))
  }, character(1), USE.NAMES = FALSE)
}

normalizar <- function(x) {
  x <- gsub("**", "", x, fixed = TRUE)
  trimws(gsub("\\s+", " ", x))
}

test_that("docs/ellmer.md cobre as perguntas canônicas e todas as tools", {
  doc <- arquivo_doc("ellmer.md")
  skip_if_not(file.exists(doc), "docs/ fora do build")
  txt <- paste(readLines(doc, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  txt_norm <- normalizar(txt)

  for (p in eduBR_personas()) {
    arq <- arquivo_doc("personas", paste0(p, ".md"))
    perguntas <- perguntas_canonicas(arq)
    expect_gte(length(perguntas), 4L)
    for (q in perguntas) {
      expect_true(grepl(q, txt_norm, fixed = TRUE), info = paste(p, q))
    }
  }

  citadas <- gsub("`", "", regmatches(txt, gregexpr("`[^`\n]+`", txt))[[1]])
  expect_equal(setdiff(names(eduBR_tools_registro()), citadas), character(0))
})

test_that("bloco 'tools por persona' de docs/ellmer.md bate com o registro", {
  doc <- arquivo_doc("ellmer.md")
  skip_if_not(file.exists(doc), "docs/ fora do build")
  linhas <- readLines(doc, encoding = "UTF-8", warn = FALSE)
  ini <- which(linhas == "<!-- tools-por-persona:inicio -->")
  fim <- which(linhas == "<!-- tools-por-persona:fim -->")
  expect_length(ini, 1L)
  expect_length(fim, 1L)
  esperado <- vapply(eduBR_personas(), function(p) {
    t <- tools_da_persona(p)
    sprintf("- **%s** (%d): %s", p, length(t),
            paste0("`", t, "`", collapse = ", "))
  }, character(1), USE.NAMES = FALSE)
  expect_equal(linhas[(ini + 1):(fim - 1)], esperado)
})
