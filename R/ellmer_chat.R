# R/ellmer_chat.R
#
# Criação do chat (ellmer) com o provedor escolhido: API da Anthropic (chave
# no ambiente) ou Ollama (local ou via túnel). As ferramentas do eduBR não
# dependem do provedor; só o construtor do chat muda.

eduBR_provedores <- function() c("anthropic", "ollama")

eduBR_ollama_modelo_padrao <- function() "qwen3.5:9b"

# Construtor do ellmer para cada provedor (indireção para testes sem rede).
eduBR_chat_construtor <- function(provedor) {
  switch(
    provedor,
    anthropic = ellmer::chat_anthropic,
    ollama = ellmer::chat_ollama
  )
}

# Provedor efetivo: argumento > EDUBR_LLM_PROVEDOR > anthropic se houver
# chave > ollama.
eduBR_resolver_provedor <- function(provedor) {
  if (is.null(provedor)) {
    env <- Sys.getenv("EDUBR_LLM_PROVEDOR", "")
    provedor <- if (nzchar(env)) {
      env
    } else if (nzchar(Sys.getenv("ANTHROPIC_API_KEY", ""))) {
      "anthropic"
    } else {
      "ollama"
    }
  }
  if (!is.character(provedor) || length(provedor) != 1L ||
      !provedor %in% eduBR_provedores()) {
    stop(
      sprintf(
        "`provedor` deve ser um de: %s.",
        paste(eduBR_provedores(), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  provedor
}

eduBR_texto_opcional <- function(x, nome) {
  if (!is.null(x) && (!is.character(x) || length(x) != 1L || !nzchar(x))) {
    stop(sprintf("`%s` deve ser um texto n\u00e3o vazio.", nome), call. = FALSE)
  }
  x
}

#' Chat com LLM para as ferramentas do eduBR
#'
#' Cria um chat do [ellmer](https://ellmer.tidyverse.org) com um de dois
#' provedores e, opcionalmente, registra nele as ferramentas de
#' [ferramentas_edubr()]:
#'
#' - **`"anthropic"`**: API da Anthropic via [ellmer::chat_anthropic()]. A
#'   chave vem **só** da variável de ambiente `ANTHROPIC_API_KEY` (ex.: no
#'   `~/.Renviron`); nunca a coloque no código.
#' - **`"ollama"`**: modelo local via [ellmer::chat_ollama()]. O endereço vem
#'   de `base_url`, de `OLLAMA_BASE_URL` ou do padrão
#'   `http://localhost:11434`. Para usar no container um Ollama que roda em
#'   outra máquina, abra um túnel SSH reverso (ver `tools/tunnel-ollama.sh`
#'   no repositório). O modelo precisa suportar *tool calling* (ex.:
#'   `qwen3.5:9b`, `granite4.1:8b`).
#'
#' Sem `provedor`, a escolha segue: `EDUBR_LLM_PROVEDOR`; senão `"anthropic"`
#' se `ANTHROPIC_API_KEY` estiver definida; senão `"ollama"`.
#'
#' @param provedor `"anthropic"`, `"ollama"` ou `NULL` (escolha automática).
#' @param modelo Nome do modelo. `NULL` usa `EDUBR_ANTHROPIC_MODELO` /
#'   `EDUBR_OLLAMA_MODELO`; sem elas, o padrão do ellmer (Anthropic) ou
#'   `"qwen3.5:9b"` (Ollama).
#' @param tools Lista opcional de [ferramentas_edubr()] para registrar no
#'   chat.
#' @param system_prompt Instruções de sistema opcionais.
#' @param base_url Endereço do servidor (só Ollama; Anthropic usa o padrão
#'   do ellmer).
#' @param echo Repassado ao ellmer (`"none"`, `"output"` ou `"all"`).
#' @param ... Outros argumentos repassados ao construtor do ellmer.
#'
#' @return Um objeto `Chat` do ellmer, com o atributo `provedor`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' tools <- ferramentas_edubr(con, persona = "gestora-escolar")
#'
#' # Anthropic (ANTHROPIC_API_KEY no ambiente)
#' chat <- chat_edubr("anthropic", tools = tools)
#'
#' # Ollama local (ou via túnel no container)
#' chat <- chat_edubr("ollama", modelo = "qwen3.5:9b", tools = tools)
#' chat$chat("Como está a infraestrutura da escola 13078070?")
#' }
#'
#' @export
chat_edubr <- function(provedor = NULL, modelo = NULL, tools = NULL,
                       system_prompt = NULL, base_url = NULL,
                       echo = c("none", "output", "all"), ...) {
  rlang::check_installed("ellmer", reason = "para conversar com um LLM.")
  provedor <- eduBR_resolver_provedor(provedor)
  modelo <- eduBR_texto_opcional(modelo, "modelo")
  system_prompt <- eduBR_texto_opcional(system_prompt, "system_prompt")
  base_url <- eduBR_texto_opcional(base_url, "base_url")
  echo <- match.arg(echo)
  if (!is.null(tools) &&
      (!is.list(tools) || is.null(attr(tools, "sessao")))) {
    stop("`tools` deve ser o resultado de ferramentas_edubr().", call. = FALSE)
  }

  args <- list(system_prompt = system_prompt, echo = echo, ...)
  if (provedor == "anthropic") {
    if (!nzchar(Sys.getenv("ANTHROPIC_API_KEY", ""))) {
      stop(
        paste0(
          "Defina a vari\u00e1vel de ambiente ANTHROPIC_API_KEY (ex.: no ",
          "~/.Renviron) para usar o provedor \"anthropic\"; a chave nunca ",
          "deve ir no c\u00f3digo."
        ),
        call. = FALSE
      )
    }
    if (!is.null(base_url)) {
      stop("`base_url` s\u00f3 se aplica ao provedor \"ollama\".", call. = FALSE)
    }
    modelo <- modelo %||% eduBR_env_opcional("EDUBR_ANTHROPIC_MODELO")
  } else {
    modelo <- modelo %||% eduBR_env_opcional("EDUBR_OLLAMA_MODELO") %||%
      eduBR_ollama_modelo_padrao()
    base_url <- base_url %||% eduBR_env_opcional("OLLAMA_BASE_URL") %||%
      "http://localhost:11434"
    args$base_url <- base_url
  }
  args$model <- modelo
  args <- args[!vapply(args, is.null, logical(1))]

  chat <- tryCatch(
    do.call(eduBR_chat_construtor(provedor), args),
    error = function(e) {
      if (provedor == "ollama") {
        stop(
          sprintf(
            paste0(
              "N\u00e3o foi poss\u00edvel conectar ao Ollama em %s. Confira se o ",
              "servidor est\u00e1 rodando (ou, no container, se o t\u00fanel SSH ",
              "est\u00e1 aberto: tools/tunnel-ollama.sh) e se o modelo \"%s\" ",
              "existe (ollama list)."
            ),
            base_url, modelo
          ),
          call. = FALSE
        )
      }
      stop(e)
    }
  )
  if (!is.null(tools)) {
    chat$register_tools(unname(tools))
  }
  attr(chat, "provedor") <- provedor
  chat
}

eduBR_env_opcional <- function(nome) {
  v <- Sys.getenv(nome, "")
  if (nzchar(v)) v else NULL
}
