# R/ellmer_ledger.R
#
# Ledger e orçamento da camada ellmer (decisões D7/D8 de
# plans/ellmer-tools.md). Cada sessão de tools tem um ambiente de ledger
# (mutável, compartilhado pelas tools da sessão) que registra toda chamada,
# inclusive as recusadas por orçamento. A persistência em CSV é opcional e
# fica em tools::R_user_dir("eduBR", "data"), nunca em inst/.

# Colunas do ledger, na ordem.
eduBR_ledger_colunas <- function() {
  c("timestamp", "tool", "args", "n_linhas", "duracao_ms", "erro")
}

# Novo ambiente de ledger (vazio).
eduBR_ledger_novo <- function() {
  led <- new.env(parent = emptyenv())
  led$registros <- list()
  led$n_chamadas <- 0L
  led$n_linhas_total <- 0
  led
}

# Argumentos de uma chamada como texto JSON (para o ledger).
eduBR_ledger_args_json <- function(args) {
  if (!length(args)) {
    return("{}")
  }
  txt <- tryCatch(
    jsonlite::toJSON(args, auto_unbox = TRUE, null = "null", na = "null",
                     digits = NA, force = TRUE),
    error = function(e) NULL
  )
  if (is.null(txt)) "{}" else as.character(txt)
}

# Arquivo CSV do ledger, ou NULL quando não há persistência.
eduBR_ledger_arquivo <- function(limites) {
  if (!is.null(limites$ledger_arquivo)) {
    return(limites$ledger_arquivo)
  }
  if (!isTRUE(limites$persistir)) {
    return(NULL)
  }
  file.path(
    tools::R_user_dir("eduBR", "data"), "ledger",
    sprintf("ledger-%s.csv", format(Sys.Date(), "%Y-%m-%d"))
  )
}

# Acrescenta uma linha ao CSV (cria o diretório e o cabeçalho se preciso).
eduBR_ledger_persistir <- function(linha, arquivo) {
  dir.create(dirname(arquivo), recursive = TRUE, showWarnings = FALSE)
  novo <- !file.exists(arquivo)
  linha$timestamp <- format(linha$timestamp, "%Y-%m-%dT%H:%M:%OS3%z")
  utils::write.table(
    linha, arquivo,
    sep = ",", qmethod = "double", row.names = FALSE,
    col.names = novo, append = !novo, fileEncoding = "UTF-8"
  )
  invisible(arquivo)
}

# Registra uma chamada no ledger da sessão. `contar = FALSE` para chamadas
# recusadas pelo orçamento (registradas, mas sem consumir orçamento).
eduBR_ledger_registrar <- function(sessao, tool, args, n_linhas, duracao_ms,
                                   erro = NA_character_, contar = TRUE) {
  led <- sessao$ledger
  linha <- data.frame(
    timestamp = Sys.time(),
    tool = tool,
    args = eduBR_ledger_args_json(args),
    n_linhas = as.integer(n_linhas),
    duracao_ms = as.numeric(duracao_ms),
    erro = if (is.null(erro)) NA_character_ else as.character(erro),
    stringsAsFactors = FALSE
  )
  led$registros[[length(led$registros) + 1L]] <- linha
  if (isTRUE(contar)) {
    led$n_chamadas <- led$n_chamadas + 1L
    led$n_linhas_total <- led$n_linhas_total + linha$n_linhas
  }
  arquivo <- eduBR_ledger_arquivo(sessao$limites)
  if (!is.null(arquivo)) {
    tryCatch(
      eduBR_ledger_persistir(linha, arquivo),
      error = function(e) {
        warning(
          "N\u00e3o foi poss\u00edvel gravar o ledger em disco: ",
          conditionMessage(e), call. = FALSE
        )
      }
    )
  }
  invisible(linha)
}

# Verifica o orçamento (D8) antes de executar. Devolve NULL quando a
# chamada pode seguir, ou a mensagem do estouro.
eduBR_orcamento_estourado <- function(sessao) {
  led <- sessao$ledger
  lim <- sessao$limites
  if (led$n_chamadas >= lim$max_chamadas) {
    return(sprintf(
      paste0(
        "Or\u00e7amento da sess\u00e3o esgotado: %d chamadas (m\u00e1ximo %d). ",
        "Responda com o que j\u00e1 foi obtido ou abra uma nova sess\u00e3o."
      ),
      led$n_chamadas, as.integer(lim$max_chamadas)
    ))
  }
  if (led$n_linhas_total >= lim$max_linhas_total) {
    return(sprintf(
      paste0(
        "Or\u00e7amento da sess\u00e3o esgotado: %s linhas devolvidas ",
        "(m\u00e1ximo %s). Responda com o que j\u00e1 foi obtido ou abra ",
        "uma nova sess\u00e3o."
      ),
      format(led$n_linhas_total), format(lim$max_linhas_total)
    ))
  }
  NULL
}

# Linhas ainda disponíveis no orçamento da sessão.
eduBR_orcamento_linhas_restantes <- function(sessao) {
  max(0, sessao$limites$max_linhas_total - sessao$ledger$n_linhas_total)
}

#' Ledger de uma sessão de ferramentas ellmer
#'
#' Devolve o registro de todas as chamadas feitas às ferramentas criadas por
#' [ferramentas_edubr()] na sessão: quando, qual ferramenta, com que
#' argumentos, quantas linhas voltaram ao modelo, quanto tempo levou e, se
#' houve, o tipo de erro (`parametro_invalido`, `sem_dados`,
#' `limite_excedido` ou `conexao`). Chamadas recusadas por orçamento também
#' aparecem (com `erro = "limite_excedido"`).
#'
#' O ledger vive na memória da sessão. Para guardá-lo em disco, use
#' `limites = list(persistir = TRUE)` (arquivo diário em
#' `tools::R_user_dir("eduBR", "data")/ledger/`) ou
#' `limites = list(ledger_arquivo = "<caminho.csv>")` em
#' [ferramentas_edubr()].
#'
#' @param tools Lista devolvida por [ferramentas_edubr()].
#'
#' @return Um `data.frame` com as colunas `timestamp` (POSIXct), `tool`,
#'   `args` (JSON), `n_linhas`, `duracao_ms` e `erro` (`NA` quando a
#'   chamada deu certo), uma linha por chamada, na ordem em que ocorreram.
#'
#' @examples
#' \dontrun{
#' con <- conecta(service = "edumaps")
#' tools <- ferramentas_edubr(con)
#' tools$catalogo()
#' ledger(tools)
#' }
#'
#' @export
ledger <- function(tools) {
  led <- attr(tools, "ledger", exact = TRUE)
  if (!is.environment(led)) {
    stop(
      "`tools` deve ser a lista devolvida por `ferramentas_edubr()`.",
      call. = FALSE
    )
  }
  if (!length(led$registros)) {
    return(data.frame(
      timestamp = as.POSIXct(character(0)),
      tool = character(0),
      args = character(0),
      n_linhas = integer(0),
      duracao_ms = numeric(0),
      erro = character(0),
      stringsAsFactors = FALSE
    ))
  }
  out <- do.call(rbind, led$registros)
  rownames(out) <- NULL
  out[, eduBR_ledger_colunas(), drop = FALSE]
}
