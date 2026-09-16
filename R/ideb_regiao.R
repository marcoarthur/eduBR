# R/ideb_regiao.R
#
# IDEB com a dimensao regional (macrorregioes do IBGE) anexada. O mapa
# UF -> regiao esta em R/regiao.R e e aplicado direto no SQL.

#' IDEB por regiao
#'
#' Acessa o IDEB por escola (`clean.ideb_notas_escolas`) anexando a
#' macrorregiao do IBGE derivada da UF (`sg_uf`). A consulta e preguicosa;
#' materialize com [as_tibble()]. Combine com [as_tibble()] + `dplyr` para
#' agregar por regiao, ano e etapa.
#'
#' @param con Conexao criada por [conecta()].
#' @param regiao Filtro opcional pela macrorregiao: nome (`"Sudeste"`) ou
#'   sigla (`"SE"`), sem diferenciar maiusculas/minusculas.
#' @param uf Filtro opcional pela sigla da UF (ex.: `"SP"`).
#' @param etapa Filtro opcional pela etapa
#'   (`"fundamental_i"`, `"fundamental_ii"` ou `"ensino_medio"`).
#' @param rede Filtro opcional pela rede
#'   (`"Municipal"`, `"Estadual"`, `"Federal"` ou `"Privada"`).
#' @param ano Filtro opcional pelo ano da avaliacao (ex.: `2019`).
#'
#' @return Objeto S3 de classe `eduBR_ideb_regiao`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' ideb_regiao(con, regiao = "Sudeste", etapa = "fundamental_ii")
#' ideb_regiao(con, regiao = "NE", ano = 2019)
#' }
#'
#' @export
ideb_regiao <- function(con, regiao = NULL, uf = NULL, etapa = NULL,
                        rede = NULL, ano = NULL) {
  tb <- eduBR_tbl(con, "ideb")
  tb <- eduBR_mutate_regiao(tb)

  if (!is.null(regiao)) {
    tb <- eduBR_filtrar_regiao(tb, regiao)
  }
  if (!is.null(uf)) {
    tb <- dplyr::filter(tb, .data$sg_uf == .env$uf)
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
    tb, "eduBR_ideb_regiao", con,
    list(descricao = "IDEB por regiao (macrorregioes do IBGE)")
  )
}
