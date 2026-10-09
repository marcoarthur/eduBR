# tools/aceite-ellmer.R
#
# Aceite da camada ellmer com chat real (Ollama): faz as perguntas de um
# arquivo a uma persona e grava a transcricao (turns, chamadas de tool com
# argumentos, resultados, resposta, tempo, tokens e ledger) em <SAIDA>.json
# e <SAIDA>.md, mais checagens de fronteira (nomes fisicos, integer64 cru,
# linhas por chamada). Rode NO CONTAINER, como rsuser, com o tunel aberto:
#
#   EDUBR_DEST=$(tools/rstudio-dest.sh)   # destino da worktree no container
#   PERSONA=gestora-escolar               # ou pesquisadora-educacional,
#                                         #    especialista-ml
#   PERGUNTAS_ARQ=perguntas.txt           # perguntas separadas por "---"
#   SAIDA=/tmp/aceite/gestora             # prefixo dos arquivos
#   THINK=1                               # 0 = sem raciocinio (reasoning_effort
#                                         #     "none" no Ollama)
#   SEGUIR_SE_VAZIO=1                     # repete com um pedido de resposta
#                                         #     se a resposta vier vazia
#   NOVO_CHAT=0                           # 1 = um chat por pergunta
#
# Transcricoes de 2026-10-09 em docs/aceite-ellmer/.
dest <- Sys.getenv("EDUBR_DEST")
persona <- Sys.getenv("PERSONA")
perg_arq <- Sys.getenv("PERGUNTAS_ARQ")
saida <- Sys.getenv("SAIDA")
novo_chat <- Sys.getenv("NOVO_CHAT", "0") == "1"
suppressMessages(devtools::load_all(dest, quiet = TRUE))
library(ellmer)

txt <- paste(readLines(perg_arq, encoding = "UTF-8"), collapse = "\n")
perguntas <- trimws(strsplit(txt, "\n---\n", fixed = TRUE)[[1]])
perguntas <- perguntas[nzchar(perguntas)]

con <- conecta(service = "edumaps")
tools <- ferramentas_edubr(con, persona = persona,
                           limites = list(timeout_s = 180))
pensar <- Sys.getenv("THINK", "1") == "1"
novo <- function() {
  if (pensar) chat_edubr("ollama", tools = tools, echo = "none")
  else chat_edubr("ollama", tools = tools, echo = "none",
                  api_args = list(reasoning_effort = "none"))
}
seguir <- Sys.getenv("SEGUIR_SE_VAZIO", "1") == "1"
chat <- novo()

prop <- function(x, p) tryCatch(S7::prop(x, p), error = function(e) NULL)

conteudo <- function(cn) {
  cls <- class(cn)[1]
  if (S7::S7_inherits(cn, ellmer::ContentToolRequest)) {
    list(tipo = "tool_request", id = prop(cn, "id"), tool = prop(cn, "name"),
         argumentos = prop(cn, "arguments"))
  } else if (S7::S7_inherits(cn, ellmer::ContentToolResult)) {
    v <- prop(cn, "value")
    req <- prop(cn, "request")
    e <- prop(cn, "error")
    list(tipo = "tool_result",
         id = if (!is.null(req)) prop(req, "id") else NULL,
         tool = if (!is.null(req)) prop(req, "name") else NULL,
         valor = if (is.character(v)) paste(v, collapse = "") else
           as.character(jsonlite::toJSON(v, auto_unbox = TRUE, force = TRUE)),
         erro = if (is.null(e)) NULL else conditionMessage(e))
  } else if (S7::S7_inherits(cn, ellmer::ContentThinking)) {
    list(tipo = "thinking", texto = prop(cn, "thinking"))
  } else if (S7::S7_inherits(cn, ellmer::ContentText)) {
    list(tipo = "texto", texto = prop(cn, "text"))
  } else {
    list(tipo = cls)
  }
}

registros <- list()
for (i in seq_along(perguntas)) {
  if (novo_chat && i > 1) chat <- novo()
  n0 <- length(chat$get_turns())
  l0 <- nrow(ledger(tools))
  t0 <- Sys.time()
  resp <- tryCatch(as.character(chat$chat(perguntas[i])),
                   error = function(e) paste("ERRO:", conditionMessage(e)))
  seguimento <- NULL
  if (seguir && !nzchar(trimws(resp))) {
    seguimento <- "Responda agora, em texto, com base nos resultados das ferramentas."
    resp <- tryCatch(as.character(chat$chat(seguimento)),
                     error = function(e) paste("ERRO:", conditionMessage(e)))
  }
  dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  turns <- chat$get_turns()
  novos <- if (length(turns) > n0) turns[(n0 + 1):length(turns)] else list()
  tr <- lapply(novos, function(t) list(
    papel = prop(t, "role"),
    conteudos = lapply(prop(t, "contents"), conteudo)
  ))
  led <- ledger(tools)
  led_q <- if (nrow(led) > l0) led[(l0 + 1):nrow(led), ] else led[0, ]
  registros[[i]] <- list(pergunta = perguntas[i], seguimento = seguimento,
                         pensar = pensar, segundos = round(dt, 1),
                         resposta = resp, turns = tr,
                         ledger = led_q,
                         tokens = tryCatch(as.data.frame(chat$get_tokens()),
                                           error = function(e) NULL))
  message(sprintf("[%d] %.1f s; tools: %s", i, dt,
                  paste(led_q$tool, collapse = " -> ")))
}

# Verificações de fronteira em todos os resultados de tool.
cat_fis <- eduBR_catalogo()
fisicos <- unique(paste(cat_fis$schema, cat_fis$tabela, sep = "."))
resultados <- unlist(lapply(registros, function(r) lapply(r$turns, function(t)
  lapply(t$conteudos, function(cn) if (identical(cn$tipo, "tool_result")) cn$valor))))
checks <- list(
  n_resultados = length(resultados),
  nomes_fisicos = sum(vapply(fisicos, function(f)
    any(grepl(f, resultados, fixed = TRUE)), logical(1))),
  denormais_int64 = sum(grepl("[0-9]e-3[0-2][0-9]", resultados)),
  max_n_ledger = max(c(0, ledger(tools)$n_linhas))
)
message("checks: ", paste(names(checks), unlist(checks), sep = "=", collapse = "; "))

out <- list(persona = persona, modelo = "qwen3.5:9b", provedor = "ollama",
            data = format(Sys.time(), "%Y-%m-%d %H:%M %Z"),
            registros = registros, ledger_total = ledger(tools),
            checks = checks)
jsonlite::write_json(out, paste0(saida, ".json"), auto_unbox = TRUE,
                     pretty = TRUE, null = "null", na = "null", digits = NA,
                     POSIXt = "ISO8601")

# Transcrição legível.
corta <- function(x, n = 1500) if (nchar(x) > n) paste0(substr(x, 1, n), " [...]") else x
linhas <- c(sprintf("# Aceite %s (ollama qwen3.5:9b, thinking=%s) %s", persona, pensar, out$data), "")
for (i in seq_along(registros)) {
  r <- registros[[i]]
  linhas <- c(linhas, sprintf("## Pergunta %d (%.1f s)", i, r$segundos), "",
              paste(">", r$pergunta), "",
              if (!is.null(r$seguimento)) c(paste("> (seguimento, resposta vazia)", r$seguimento), "") else NULL)
  for (t in r$turns) for (cn in t$conteudos) {
    if (identical(cn$tipo, "tool_request")) {
      linhas <- c(linhas, sprintf("- CALL `%s`(%s)", cn$tool,
        as.character(jsonlite::toJSON(cn$argumentos, auto_unbox = TRUE, null = "null"))))
    } else if (identical(cn$tipo, "tool_result")) {
      linhas <- c(linhas, sprintf("  - RESULT `%s`: %s", cn$tool %||% "?",
                                  corta(cn$valor %||% "")))
    }
  }
  linhas <- c(linhas, "", "### Resposta", "", r$resposta, "")
}
linhas <- c(linhas, "## Ledger", "", utils::capture.output(print(out$ledger_total)),
            "", "## Checks", "", utils::capture.output(str(checks)))
writeLines(linhas, paste0(saida, ".md"), useBytes = TRUE)
DBI::dbDisconnect(con)
