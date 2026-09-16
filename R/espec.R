# R/espec.R
#
# Especificacao declarativa de uma regressao. Uma spec descreve o desfecho,
# os preditores, os recortes (cortes) e a fonte de dados. Pode ser construida
# em R (especificar_regressao()) ou lida de um YAML (ler_espec()).

#' Especificação de regressão
#'
#' Cria um objeto `eduBR_espec` descrevendo uma regressão a ser executada por
#' [executar_regressao()]: desfecho, preditores, cortes (recortes), modelo e
#' fonte de dados. O mesmo objeto pode ser rodado para muitas combinações de
#' cortes.
#'
#' @param outcome Nome da coluna do desfecho (string).
#' @param predictors Vetor de nomes das colunas preditoras.
#' @param cuts Vetor opcional de colunas de recorte; a regressão é ajustada
#'   separadamente para cada combinação.
#' @param modelo `"linear"` (padrão) ou `"logistico"`.
#' @param fonte Nome de um domínio do catálogo ([catalogo()]) usado como base,
#'   quando `dados` não é informado em [executar_regressao()].
#' @param filtro Lista nomeada opcional de igualdades aplicadas antes do
#'   ajuste (ex.: `list(ano = 2023, sg_uf = "SP")`).
#' @param id Identificador opcional da especificação.
#'
#' @return Objeto de classe `eduBR_espec`.
#'
#' @examples
#' especificar_regressao(
#'   outcome = "ideb_observado",
#'   predictors = c("nota_media"),
#'   cuts = c("ano", "sg_uf", "etapa"),
#'   fonte = "ideb"
#' )
#'
#' @export
especificar_regressao <- function(outcome, predictors, cuts = NULL,
                                  modelo = c("linear", "logistico"),
                                  fonte = NULL, filtro = NULL, id = NULL) {
  modelo <- match.arg(modelo)

  if (!is.character(outcome) || length(outcome) != 1L || !nzchar(outcome)) {
    stop("`outcome` deve ser uma string nao vazia.", call. = FALSE)
  }
  if (!is.character(predictors) || length(predictors) < 1L ||
      any(!nzchar(predictors))) {
    stop("`predictors` deve ser um vetor de strings nao vazias.", call. = FALSE)
  }
  if (!is.null(cuts) && (!is.character(cuts) || any(!nzchar(cuts)))) {
    stop("`cuts` deve ser um vetor de strings nao vazias.", call. = FALSE)
  }
  if (!is.null(filtro) && (!is.list(filtro) || is.null(names(filtro)))) {
    stop("`filtro` deve ser uma lista nomeada.", call. = FALSE)
  }
  if (!is.null(id) && (!is.character(id) || length(id) != 1L)) {
    stop("`id` deve ser uma string.", call. = FALSE)
  }

  structure(
    list(
      id         = id,
      outcome    = outcome,
      predictors = predictors,
      cuts       = cuts,
      modelo     = modelo,
      fonte      = fonte,
      filtro     = filtro
    ),
    class = "eduBR_espec"
  )
}

#' Lê uma especificação de regressão a partir de um YAML
#'
#' Lê um arquivo YAML com os campos `outcome`, `predictors`, `cuts`,
#' `modelo`, `fonte`, `filtro` e `id` e devolve um `eduBR_espec` validado.
#'
#' Atenção: o YAML trata `y`, `n`, `yes`, `no`, `on`, `off` como lógicos.
#' Evite nomes de coluna com esses valores ou coloque-os entre aspas
#' (`outcome: "y"`).
#'
#' @param caminho Caminho do arquivo YAML.
#'
#' @return Objeto de classe `eduBR_espec`.
#'
#' @examples
#' \dontrun{
#' espec <- ler_espec("analysis/regressoes_censo.yaml")
#' }
#'
#' @export
ler_espec <- function(caminho) {
  rlang::check_installed("yaml", reason = "para ler especificacoes em YAML")
  if (!is.character(caminho) || length(caminho) != 1L ||
      !file.exists(caminho)) {
    stop("`caminho` deve apontar para um arquivo YAML existente.",
         call. = FALSE)
  }
  cfg <- yaml::read_yaml(caminho)
  if (!is.list(cfg)) {
    stop("YAML invalido: esperado um mapeamento no topo.", call. = FALSE)
  }
  especificar_regressao(
    outcome    = cfg$outcome,
    predictors = unlist(cfg$predictors, use.names = FALSE),
    cuts       = unlist(cfg$cuts, use.names = FALSE),
    modelo     = if (is.null(cfg$modelo)) "linear" else cfg$modelo,
    fonte      = cfg$fonte,
    filtro     = cfg$filtro,
    id         = cfg$id
  )
}

#' @export
print.eduBR_espec <- function(x, ...) {
  id <- if (is.null(x$id)) "(sem id)" else x$id
  fonte <- if (is.null(x$fonte)) "(dados em executar_regressao)" else x$fonte
  cuts <- if (is.null(x$cuts)) "(nenhum)" else paste(x$cuts, collapse = ", ")
  cat("<eduBR_espec>\n")
  cat("  id:         ", id, "\n", sep = "")
  cat("  modelo:     ", x$modelo, "\n", sep = "")
  cat("  fonte:      ", fonte, "\n", sep = "")
  cat("  outcome:    ", x$outcome, "\n", sep = "")
  cat("  predictors: ", paste(x$predictors, collapse = ", "), "\n", sep = "")
  cat("  cuts:       ", cuts, "\n", sep = "")
  if (!is.null(x$filtro)) {
    itens <- sprintf("%s == %s", names(x$filtro), vapply(
      x$filtro, function(v) paste(v, collapse = "|"), character(1)
    ))
    cat("  filtro:     ", paste(itens, collapse = ", "), "\n", sep = "")
  }
  invisible(x)
}
