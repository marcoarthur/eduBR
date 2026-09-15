# R/cluster.R

#' Metadados de clusterização
#'
#' Acessa `analytics.clustering_metadata`, com o resultado das execuções de
#' clusterização: algoritmo, tamanho de cada cluster, centroides e métricas
#' extras (incluindo os rótulos em linguagem natural). A consulta é
#' preguiçosa; materialize com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#' @param run_id Filtro opcional por uma execução específica.
#'
#' @return Objeto S3 de classe `eduBR_cluster`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' clusters(con)
#' }
#'
#' @export
clusters <- function(con, run_id = NULL) {
  tb <- eduBR_tbl(con, "clusters")
  if (!is.null(run_id)) {
    tb <- dplyr::filter(tb, .data$run_id == .env$run_id)
  }
  new_eduBR(
    tb, "eduBR_cluster", con,
    list(descricao = "Metadados de clusterizacao")
  )
}
