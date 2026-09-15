# R/censo.R
#
# Acesso aos microdados do Censo Escolar. As tabelas são grandes: o acesso
# é preguiçoso e o filtro por escola deve ser usado sempre que possível
# antes de materializar.

#' Microdados do Censo Escolar
#'
#' Acessa `clean.censo_escolas` (infraestrutura, equipamentos, etapas e
#' características da escola). A consulta é preguiçosa; materialize com
#' [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#' @param escola_id Filtro opcional pelo código INEP da escola (`co_entidade`).
#'
#' @return Objeto S3 de classe `eduBR_censo`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' censo_escolar(con, escola_id = "35012345")
#' }
#'
#' @export
censo_escolar <- function(con, escola_id = NULL) {
  tb <- eduBR_tbl(con, "censo_escolas")
  if (!is.null(escola_id)) {
    tb <- dplyr::filter(tb, .data$co_entidade == .env$escola_id)
  }
  new_eduBR(
    tb, "eduBR_censo", con,
    list(descricao = "Microdados do Censo Escolar")
  )
}

#' Microdados do Censo de Docentes
#'
#' Acessa `clean.censo_docentes` (quantidade e formação dos docentes por
#' escola). A consulta é preguiçosa; materialize com [as_tibble()].
#'
#' @inheritParams censo_escolar
#'
#' @return Objeto S3 de classe `eduBR_censo`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' censo_docentes(con, escola_id = "35012345")
#' }
#'
#' @export
censo_docentes <- function(con, escola_id = NULL) {
  tb <- eduBR_tbl(con, "censo_docentes")
  if (!is.null(escola_id)) {
    tb <- dplyr::filter(tb, .data$co_entidade == .env$escola_id)
  }
  new_eduBR(
    tb, "eduBR_censo", con,
    list(descricao = "Microdados do Censo de Docentes")
  )
}

#' Microdados do Censo de Matrículas
#'
#' Acessa `clean.censo_matriculas` (matrículas por etapa, turno e perfil).
#' A consulta é preguiçosa; materialize com [as_tibble()].
#'
#' @inheritParams censo_escolar
#'
#' @return Objeto S3 de classe `eduBR_censo`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' censo_matriculas(con, escola_id = "35012345")
#' }
#'
#' @export
censo_matriculas <- function(con, escola_id = NULL) {
  tb <- eduBR_tbl(con, "censo_matriculas")
  if (!is.null(escola_id)) {
    tb <- dplyr::filter(tb, .data$co_entidade == .env$escola_id)
  }
  new_eduBR(
    tb, "eduBR_censo", con,
    list(descricao = "Microdados do Censo de Matriculas")
  )
}
