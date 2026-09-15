# R/ideb.R

#' IDEB por escola
#'
#' Acessa `clean.ideb_notas_escolas`, com notas de matemática, português,
#' média, IDEB observado e projetado por escola, rede e etapa. A consulta é
#' preguiçosa; materialize com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#' @param escola_id Filtro opcional pelo código INEP da escola.
#'
#' @return Objeto S3 de classe `eduBR_ideb`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' ideb(con, escola_id = "35012345")
#' }
#'
#' @export
ideb <- function(con, escola_id = NULL) {
  tb <- eduBR_tbl(con, "ideb")
  if (!is.null(escola_id)) {
    tb <- dplyr::filter(tb, .data$id_escola == .env$escola_id)
  }
  new_eduBR(
    tb, "eduBR_ideb", con,
    list(descricao = "IDEB por escola")
  )
}
