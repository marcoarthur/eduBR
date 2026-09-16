# R/ideb.R

#' IDEB por escola
#'
#' Acessa `clean.ideb_notas_escolas`, com notas de matemática, português,
#' média, IDEB observado e projetado por escola, rede e etapa. A consulta é
#' preguiçosa; materialize com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#' @param escola_id Filtro opcional pelo código INEP da escola (`id_escola`).
#' @param uf Filtro opcional pela sigla da UF (ex.: `"SP"`).
#' @param municipio Filtro opcional pelo nome do município.
#' @param etapa Filtro opcional pela etapa
#'   (`"fundamental_i"`, `"fundamental_ii"` ou `"ensino_medio"`).
#' @param rede Filtro opcional pela rede
#'   (`"Municipal"`, `"Estadual"`, `"Federal"` ou `"Privada"`).
#' @param ano Filtro opcional pelo ano da avaliação (ex.: `2019`).
#'
#' @return Objeto S3 de classe `eduBR_ideb`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' ideb(con, escola_id = "35012345")
#' ideb(con, uf = "SP", etapa = "fundamental_ii", ano = 2019)
#' }
#'
#' @export
ideb <- function(con, escola_id = NULL, uf = NULL, municipio = NULL,
                 etapa = NULL, rede = NULL, ano = NULL) {
  tb <- eduBR_tbl(con, "ideb")
  if (!is.null(escola_id)) {
    tb <- dplyr::filter(tb, .data$id_escola == .env$escola_id)
  }
  if (!is.null(uf)) {
    tb <- dplyr::filter(tb, .data$sg_uf == .env$uf)
  }
  if (!is.null(municipio)) {
    tb <- dplyr::filter(tb, .data$no_municipio == .env$municipio)
  }
  if (!is.null(etapa)) {
    tb <- dplyr::filter(tb, .data$etapa == .env$etapa)
  }
  if (!is.null(rede)) {
    tb <- dplyr::filter(tb, .data$rede == .env$rede)
  }
  if (!is.null(ano)) {
    tb <- dplyr::filter(tb, .data$ano == .env$ano)
  }
  new_eduBR(
    tb, "eduBR_ideb", con,
    list(descricao = "IDEB por escola")
  )
}
