# R/indicador.R

#' Indicadores por escola (ranking)
#'
#' Acessa `analytics.ranking_escola`, com o valor de cada indicador por
#' escola e rede, além das posições (município, estado e nacional). A
#' consulta é preguiçosa; materialize com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#' @param escola_id Filtro opcional pelo código INEP da escola.
#' @param indicador Filtro opcional pelo identificador do indicador
#'   (ex.: `"infraestrutura"`).
#'
#' @return Objeto S3 de classe `eduBR_indicador`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' indicadores(con, indicador = "infraestrutura")
#' }
#'
#' @export
indicadores <- function(con, escola_id = NULL, indicador = NULL) {
  tb <- eduBR_tbl(con, "indicadores")
  if (!is.null(escola_id)) {
    tb <- dplyr::filter(tb, .data$id_escola == .env$escola_id)
  }
  if (!is.null(indicador)) {
    tb <- dplyr::filter(tb, .data$indicador_id == .env$indicador)
  }
  new_eduBR(
    tb, "eduBR_indicador", con,
    list(descricao = "Indicadores por escola (ranking)")
  )
}

#' Scores compostos por escola
#'
#' Acessa `clean.mv_escolas_scores`, com os scores consolidados
#' (infraestrutura, capacidade de atendimento, capacitação docente,
#' diversidade discente, capacidade gestora e sustentabilidade). A consulta
#' é preguiçosa; materialize com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#' @param escola_id Filtro opcional pelo código INEP da escola.
#'
#' @return Objeto S3 de classe `eduBR_score`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' scores(con, escola_id = "35012345")
#' }
#'
#' @export
scores <- function(con, escola_id = NULL) {
  tb <- eduBR_tbl(con, "scores")
  if (!is.null(escola_id)) {
    tb <- dplyr::filter(tb, .data$co_entidade == .env$escola_id)
  }
  new_eduBR(
    tb, "eduBR_score", con,
    list(descricao = "Scores compostos por escola")
  )
}
