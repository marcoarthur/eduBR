# R/municipio.R

#' Municípios (malha de São Paulo)
#'
#' Acessa a relação de municípios com identificação IBGE, região e
#' geometria. A consulta é preguiçosa; materialize com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#' @param uf Filtro opcional pela sigla da UF (ex.: `"SP"`).
#'
#' @return Objeto S3 de classe `eduBR_municipio`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' municipios(con, uf = "SP")
#' }
#'
#' @export
municipios <- function(con, uf = NULL) {
  tb <- eduBR_tbl(con, "municipios")
  if (!is.null(uf)) {
    tb <- dplyr::filter(tb, .data$sigla_estado == .env$uf)
  }
  new_eduBR(
    tb, "eduBR_municipio", con,
    list(descricao = "Municipios (identificacao e regiao)")
  )
}

#' Um município pelo código IBGE
#'
#' @param con Conexão criada por [conecta()].
#' @param codigo_ibge Código IBGE do município.
#'
#' @return Objeto S3 de classe `eduBR_municipio`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' municipio(con, "3555406")
#' }
#'
#' @export
municipio <- function(con, codigo_ibge) {
  tb <- dplyr::filter(
    eduBR_tbl(con, "municipios"),
    .data$codigo_ibge == .env$codigo_ibge
  )
  new_eduBR(
    tb, "eduBR_municipio", con,
    list(
      codigo_ibge = codigo_ibge,
      descricao = sprintf("Municipio IBGE %s", codigo_ibge)
    )
  )
}
