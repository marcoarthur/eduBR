# R/ellmer_personas.R
#
# Prompts de sistema por persona (plans/ellmer-tools.md, D15/D17): os textos
# moram em inst/prompts/<persona>.md (escritos a partir de docs/personas/,
# que fica fora do build) e são anexados ao chat por registrar_tools() e
# chat_edubr().

# Prompt curto para tools sem persona (todas as ferramentas).
eduBR_prompt_generico <- function() {
  paste(
    "Voc\u00ea responde perguntas sobre educa\u00e7\u00e3o b\u00e1sica no Brasil com as",
    "ferramentas do eduBR (Censo Escolar, IDEB, INSE, IBGE). Responda em",
    "portugu\u00eas. Consulte `catalogo` quando n\u00e3o souber se um ano ou recorte",
    "existe. Leia `metadados.aviso`, `metadados.truncado` e `erro` de toda",
    "resposta. Nunca invente n\u00fameros que n\u00e3o vieram das ferramentas; cite a",
    "edi\u00e7\u00e3o do IDEB e o recorte; s\u00f3 compare IDEB na mesma edi\u00e7\u00e3o e rede;",
    "associa\u00e7\u00e3o n\u00e3o \u00e9 causa. N\u00fameros grandes e c\u00f3digos chegam como texto:",
    "converta antes de calcular. N\u00e3o pe\u00e7a nem exponha endere\u00e7o, telefone ou",
    "CNPJ. Handles (`dados_<k>` etc.) s\u00f3 valem nesta sess\u00e3o."
  )
}

# Arquivo do prompt: pacote instalado ou fonte (load_all).
eduBR_arquivo_prompt <- function(persona) {
  nome <- paste0(persona, ".md")
  f <- system.file("prompts", nome, package = "eduBR")
  if (nzchar(f) && file.exists(f)) {
    return(f)
  }
  raiz <- tryCatch(getNamespaceInfo("eduBR", "path"), error = function(e) "")
  f <- file.path(raiz, "inst", "prompts", nome)
  if (nzchar(raiz) && file.exists(f)) {
    return(f)
  }
  stop(
    sprintf("Prompt da persona \"%s\" n\u00e3o encontrado no pacote.", persona),
    call. = FALSE
  )
}

#' Prompt de sistema de uma persona
#'
#' Devolve o texto do prompt de sistema (em Markdown, PT-BR) usado para
#' conversar com um LLM no papel de uma das personas do eduBR. Cada prompt
#' descreve o usuário, o vocabulário (domínios do [catalogo()], etapas,
#' redes, código INEP), as perguntas típicas ligadas às ferramentas de
#' [ferramentas_edubr()] daquela persona, o que fazer sempre, o que nunca
#' fazer e as pegadinhas dos dados (`integer64` como texto, IDEB só
#' comparável na mesma edição e rede, tetos de linhas, handles da sessão).
#'
#' Os textos ficam em `inst/prompts/<persona>.md` no código-fonte.
#'
#' @param persona Uma de `"gestora-escolar"`, `"pesquisadora-educacional"`
#'   ou `"especialista-ml"`.
#'
#' @return Texto (character de comprimento 1).
#'
#' @seealso [registrar_tools()], [chat_edubr()].
#'
#' @examples
#' cat(prompt_persona("gestora-escolar"))
#'
#' @export
prompt_persona <- function(persona) {
  if (is.null(persona)) {
    stop(
      sprintf(
        "`persona` deve ser uma de: %s.",
        paste(eduBR_personas(), collapse = ", ")
      ),
      call. = FALSE
    )
  }
  persona <- eduBR_validar_persona(persona)
  linhas <- readLines(eduBR_arquivo_prompt(persona), encoding = "UTF-8",
                      warn = FALSE)
  texto <- paste(linhas, collapse = "\n")
  Encoding(texto) <- "UTF-8"
  trimws(texto)
}

# Persona efetiva: argumento > atributo das tools; diverge -> erro.
eduBR_persona_efetiva <- function(persona, tools) {
  persona <- eduBR_validar_persona(persona)
  da_tools <- if (is.null(tools)) NULL else attr(tools, "persona")
  if (!is.null(persona) && !is.null(da_tools) && !identical(persona, da_tools)) {
    stop(
      sprintf(
        paste0(
          "`persona` (\"%s\") difere da persona das ferramentas (\"%s\"); ",
          "crie as ferramentas com ferramentas_edubr(con, persona = \"%s\")."
        ),
        persona, da_tools, persona
      ),
      call. = FALSE
    )
  }
  persona %||% da_tools
}

# Prompt de sistema final: persona (ou genérico) primeiro, depois o prompt
# extra/existente, separados por uma linha em branco. Sem persona e sem
# tools, devolve só `extra` (pode ser NULL).
eduBR_prompt_sistema <- function(persona, tools, extra = NULL) {
  base <- if (!is.null(persona)) {
    prompt_persona(persona)
  } else if (!is.null(tools)) {
    eduBR_prompt_generico()
  } else {
    NULL
  }
  extra <- if (length(extra) && !all(is.na(extra))) {
    paste(extra[!is.na(extra)], collapse = "\n\n")
  } else {
    NULL
  }
  if (!is.null(extra) && !nzchar(trimws(extra))) {
    extra <- NULL
  }
  if (is.null(base)) {
    return(extra)
  }
  if (is.null(extra) || startsWith(extra, base)) {
    return(extra %||% base)
  }
  paste(base, extra, sep = "\n\n")
}

eduBR_validar_tools <- function(tools) {
  if (!is.list(tools) || is.null(attr(tools, "sessao"))) {
    stop("`tools` deve ser o resultado de ferramentas_edubr().", call. = FALSE)
  }
  tools
}

#' Registrar as ferramentas do eduBR num chat
#'
#' Anexa a um chat do [ellmer](https://ellmer.tidyverse.org) as ferramentas
#' de [ferramentas_edubr()] (`chat$register_tools()`) e o prompt de sistema
#' da persona (`chat$set_system_prompt()`).
#'
#' A persona vem de `persona` ou, se `NULL`, da persona com que `tools`
#' foram criadas (`ferramentas_edubr(con, persona = ...)`). Sem persona em
#' nenhum dos dois (todas as ferramentas), usa um prompt genérico curto.
#' Informar uma `persona` diferente da das `tools` é erro.
#'
#' Se o chat já tiver prompt de sistema, o resultado é **o prompt da persona
#' primeiro, uma linha em branco e o prompt existente**. Se o prompt
#' existente já começar pelo da persona (ex.: `registrar_tools()` chamado
#' duas vezes), ele é mantido sem duplicar.
#'
#' @param chat Objeto `Chat` do ellmer (ex.: de [chat_edubr()] ou
#'   `ellmer::chat_anthropic()`).
#' @param tools Lista criada por [ferramentas_edubr()].
#' @param persona `NULL` ou uma de `"gestora-escolar"`,
#'   `"pesquisadora-educacional"`, `"especialista-ml"`.
#'
#' @return O `chat`, invisível (modificado no lugar).
#'
#' @seealso [prompt_persona()], [chat_edubr()].
#'
#' @examples
#' \dontrun{
#' con <- conecta(service = "edumaps")
#' tools <- ferramentas_edubr(con, persona = "gestora-escolar")
#' chat <- ellmer::chat_anthropic()
#' registrar_tools(chat, tools)
#' chat$chat("Como está a infraestrutura da escola 13078070?")
#' }
#'
#' @export
registrar_tools <- function(chat, tools, persona = NULL) {
  eduBR_validar_tools(tools)
  metodos <- c("register_tools", "set_system_prompt", "get_system_prompt")
  tem <- vapply(metodos, function(m) {
    is.function(tryCatch(chat[[m]], error = function(e) NULL))
  }, logical(1))
  if (!all(tem)) {
    stop(
      "`chat` deve ser um objeto Chat do ellmer (ex.: chat_edubr()).",
      call. = FALSE
    )
  }
  persona <- eduBR_persona_efetiva(persona, tools)
  prompt <- eduBR_prompt_sistema(persona, tools, chat$get_system_prompt())
  chat$register_tools(unname(tools))
  chat$set_system_prompt(prompt)
  invisible(chat)
}
