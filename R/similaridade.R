# R/similaridade.R

#' Similaridade entre municípios
#'
#' Acessa `analytics.municipio_similaridade`, com os pares de municípios,
#' a distância e o índice de similaridade. A consulta é preguiçosa;
#' materialize com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#'
#' @return Objeto S3 de classe `eduBR_similaridade`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' municipios_similares(con)
#' }
#'
#' @export
municipios_similares <- function(con) {
  tb <- eduBR_tbl(con, "similaridade")
  new_eduBR(
    tb, "eduBR_similaridade", con,
    list(descricao = "Similaridade entre municipios")
  )
}
