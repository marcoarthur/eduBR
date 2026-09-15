# R/escola.R

#' Escolas da base do EduMaps
#'
#' Acessa a relação de escolas (código INEP, nome, município, UF e
#' coordenadas). A consulta é preguiçosa: só vai ao banco quando
#' materializada, por exemplo com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#' @param municipio Filtro opcional pelo nome do município.
#' @param uf Filtro opcional pela sigla da UF (ex.: `"SP"`).
#'
#' @return Objeto S3 de classe `eduBR_escola`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' escolas(con, uf = "SP")
#' }
#'
#' @export
escolas <- function(con, municipio = NULL, uf = NULL) {
  tb <- eduBR_tbl(con, "escolas")
  if (!is.null(municipio)) {
    tb <- dplyr::filter(tb, .data$municipio == .env$municipio)
  }
  if (!is.null(uf)) {
    tb <- dplyr::filter(tb, .data$uf == .env$uf)
  }
  new_eduBR(
    tb, "eduBR_escola", con,
    list(descricao = "Escolas (identificacao e localizacao)")
  )
}

#' Uma escola pelo código INEP
#'
#' @param con Conexão criada por [conecta()].
#' @param codigo_inep Código INEP da escola.
#'
#' @return Objeto S3 de classe `eduBR_escola`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' escola(con, "35012345")
#' }
#'
#' @export
escola <- function(con, codigo_inep) {
  tb <- dplyr::filter(
    eduBR_tbl(con, "escolas"),
    .data$codigo_inep == .env$codigo_inep
  )
  new_eduBR(
    tb, "eduBR_escola", con,
    list(
      codigo_inep = codigo_inep,
      descricao = sprintf("Escola INEP %s", codigo_inep)
    )
  )
}
