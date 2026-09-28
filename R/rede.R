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

#' Redes escolares com filtros territoriais
#'
#' Consulta `analytics.mv_rede_escolas` aplicando filtros por UF, região e/ou
#' rede de ensino. Mantém a consulta preguiçosa para agregações posteriores
#' no banco antes de materializar.
#'
#' @param con Conexão criada por [conecta()].
#' @param uf Filtro opcional pela sigla da UF (ex.: `"SP"`).
#' @param regiao Filtro opcional pela macrorregião (nome ou sigla:
#'   `"Sudeste"`, `"SE"`, `"Nordeste"`, `"NE"`, etc.).
#' @param rede Filtro opcional pela rede. Aceita códigos (1–4) ou nomes:
#'   `"Federal"`, `"Estadual"`, `"Municipal"`, `"Privada"`.
#'
#' @return Objeto S3 de classe `eduBR_rede`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' rede_municipio(con, uf = "SP", rede = "Municipal")
#' rede_municipio(con, regiao = "Nordeste")
#' }
#'
#' @export
rede_municipio <- function(con, uf = NULL, regiao = NULL, rede = NULL) {
  tb <- eduBR_tbl(con, "redes")

  if (!is.null(uf)) {
    tb <- dplyr::filter(tb, .data$sg_uf %in% .env$uf)
  }

  # A MV ja traz `no_regiao`/`sg_uf`; deriva `nome_regiao`/`sigla_regiao`
  # da UF (padrao do pacote) e filtra pelo helper existente.
  tb <- eduBR_mutate_regiao(tb)
  if (!is.null(regiao)) {
    tb <- eduBR_filtrar_regiao(tb, regiao)
  }

  if (!is.null(rede)) {
    codigos_rede <- eduBR_codigos_rede(rede)
    tb <- dplyr::filter(tb, .data$codigo_rede %in% .env$codigos_rede)
  }

  new_eduBR(
    tb, "eduBR_rede", con,
    list(descricao = "Redes escolares por municipio (com filtros territoriais)")
  )
}