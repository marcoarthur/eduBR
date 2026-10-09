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
#' @param system_prompt Instruções de sistema opcionais. Com `persona` (ou
#'   `tools`), vão **depois** do prompt da persona, separadas por uma linha
#'   em branco.
#' @param base_url Endereço do servidor (só Ollama; Anthropic usa o padrão
#'   do ellmer).
#' @param echo Repassado ao ellmer (`"none"`, `"output"` ou `"all"`).
#' @param ... Outros argumentos repassados ao construtor do ellmer.
#' @param persona `NULL` ou uma de `"gestora-escolar"`,
#'   `"pesquisadora-educacional"`, `"especialista-ml"`: o chat já sai com o
#'   prompt de sistema da persona ([prompt_persona()]). Sem `persona`, usa
#'   a persona com que `tools` foram criadas; `tools` sem persona recebem
#'   um prompt genérico curto; sem `tools` nem `persona`, só
#'   `system_prompt`. Uma `persona` diferente da das `tools` é erro.
#'
#' @param raciocinio `NULL` (padrão por provedor), `"padrao"` (comportamento
#'   do modelo) ou `"desligado"`. Sem valor, o Ollama usa `"desligado"` —
#'   com o raciocínio ligado o `qwen3.5:9b` às vezes fecha o turno sem texto
#'   (e o pedido seguinte falha com HTTP 400), o que aconteceu em fluxos com
#'   várias tools (#94) — e a Anthropic usa `"padrao"`. `"desligado"` envia
#'   `reasoning_effort = "none"` no Ollama; na Anthropic não muda nada (o
#'   ellmer já não liga o raciocínio estendido).
#'
#' @param max_tokens Limite de tokens gerados por resposta (inclui os de
#'   raciocínio). `NULL` usa `EDUBR_MAX_TOKENS`; sem ela, 4096 no Ollama
#'   (respostas longas eram cortadas com o padrão) e o padrão do ellmer na
#'   Anthropic. Combinado com `params` passado em `...`.
#'
#' @return Um objeto `Chat` do ellmer, com os atributos `provedor`,
#'   `persona`, `raciocinio` e `max_tokens`.
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
#' @seealso [registrar_tools()], [prompt_persona()].
#'
#' @export
chat_edubr <- function(provedor = NULL, modelo = NULL, tools = NULL,
                       system_prompt = NULL, base_url = NULL,
                       echo = c("none", "output", "all"), ...,
                       persona = NULL,
                       raciocinio = NULL,
                       max_tokens = NULL) {
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
  persona <- eduBR_persona_efetiva(persona, tools)
  system_prompt <- eduBR_prompt_sistema(persona, tools, system_prompt)

  raciocinio <- raciocinio %||%
    (if (provedor == "ollama") "desligado" else "padrao")
  if (!is.character(raciocinio) || length(raciocinio) != 1L ||
      !raciocinio %in% c("padrao", "desligado")) {
    stop("`raciocinio` deve ser \"padrao\" ou \"desligado\".", call. = FALSE)
  }
  args <- list(system_prompt = system_prompt, echo = echo, ...)
  max_tokens <- eduBR_max_tokens(max_tokens, provedor)
  if (!is.null(max_tokens)) {
    prm <- args$params %||% list()
    if (!is.null(prm$max_tokens) && !identical(as.integer(prm$max_tokens),
                                                max_tokens)) {
      stop(
        paste0(
          "`max_tokens` conflita com `params$max_tokens`; use s\u00f3 um dos ",
          "dois."
        ),
        call. = FALSE
      )
    }
    prm$max_tokens <- max_tokens
    args$params <- do.call(ellmer::params, prm)
  }
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
    if (raciocinio == "desligado") {
      api <- args$api_args %||% list()
      if (!is.list(api)) {
        stop("`api_args` deve ser uma lista.", call. = FALSE)
      }
      if (!is.null(api$reasoning_effort) &&
          !identical(api$reasoning_effort, "none")) {
        stop(
          paste0(
            "`raciocinio = \"desligado\"` conflita com ",
            "`api_args$reasoning_effort`; use s\u00f3 um dos dois."
          ),
          call. = FALSE
        )
      }
      api$reasoning_effort <- "none"
      args$api_args <- api
    }
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
    eduBR_ledger_gancho(chat, tools)
  }
  attr(chat, "provedor") <- provedor
  attr(chat, "persona") <- persona
  attr(chat, "raciocinio") <- raciocinio
  attr(chat, "max_tokens") <- max_tokens
  chat
}

# Limite efetivo de tokens gerados: argumento > EDUBR_MAX_TOKENS > 4096 no
# Ollama (na Anthropic, sem argumento nem vari\u00e1vel, fica o padr\u00e3o do
# ellmer).
eduBR_max_tokens <- function(max_tokens, provedor) {
  if (is.null(max_tokens)) {
    env <- eduBR_env_opcional("EDUBR_MAX_TOKENS")
    max_tokens <- if (!is.null(env)) {
      suppressWarnings(as.numeric(env))
    } else if (provedor == "ollama") {
      4096L
    }
  }
  if (is.null(max_tokens)) {
    return(NULL)
  }
  if (!is.numeric(max_tokens) || length(max_tokens) != 1L ||
      is.na(max_tokens) || max_tokens < 16 || max_tokens != round(max_tokens)) {
    stop("`max_tokens` deve ser um inteiro >= 16.", call. = FALSE)
  }
  as.integer(max_tokens)
}

eduBR_env_opcional <- function(nome) {
  v <- Sys.getenv(nome, "")
  if (nzchar(v)) v else NULL
}
