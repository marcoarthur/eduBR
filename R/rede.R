# R/rede.R

#' Redes escolares por município
#'
#' Acessa a view materializada `analytics.mv_rede_escolas`, que consolida
#' matrículas, docentes e IDEB por município e rede (municipal, estadual,
#' privada). A consulta é preguiçosa; materialize com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#' @param municipio Filtro opcional pelo código IBGE do município.
#'
#' @return Objeto S3 de classe `eduBR_rede`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' redes(con, municipio = "3555406")
#' }
#'
#' @export
redes <- function(con, municipio = NULL) {
  tb <- eduBR_tbl(con, "redes")
  if (!is.null(municipio)) {
    tb <- dplyr::filter(tb, .data$co_municipio == .env$municipio)
  }
  new_eduBR(
    tb, "eduBR_rede", con,
    list(descricao = "Redes escolares por municipio")
  )
}
