# R/inse.R
#
# Indice de Nivel Socioeconomico (INSE) do SAEB. Ha apenas o ano de 2023 e
# cobre exclusivamente escolas publicas (federal, estadual e municipal).

#' Indice de Nivel Socioeconomico (INSE)
#'
#' Acessa `clean.inse`, com o INSE medio por escola do SAEB (`media_inse`),
#' a classificacao em niveis e a distribuicao de alunos por nivel
#' (`pc_nivel_1` a `pc_nivel_8`). A consulta e preguicosa; materialize com
#' [as_tibble()].
#'
#' @param con Conexao criada por [conecta()].
#' @param uf Filtro opcional pela sigla da UF (ex.: `"SP"`).
#' @param municipio Filtro opcional pelo nome do municipio.
#' @param ano Filtro opcional pelo ano do SAEB (`nu_ano_saeb`, ex.: `2023`).
#' @param rede Filtro opcional pelo codigo do tipo de rede
#'   (`1` federal, `2` estadual, `3` municipal).
#' @param classificacao Filtro opcional pela classificacao do INSE
#'   (ex.: `"Nivel III"`).
#'
#' @return Objeto S3 de classe `eduBR_inse`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' inse(con, uf = "SP")
#' inse(con, ano = 2023, rede = 3)
#' }
#'
#' @export
inse <- function(con, uf = NULL, municipio = NULL, ano = NULL,
                 rede = NULL, classificacao = NULL) {
  tb <- eduBR_tbl(con, "inse")
  if (!is.null(uf)) {
    tb <- dplyr::filter(tb, .data$sg_uf == .env$uf)
  }
  if (!is.null(municipio)) {
    tb <- dplyr::filter(tb, .data$no_municipio == .env$municipio)
  }
  if (!is.null(ano)) {
    tb <- dplyr::filter(tb, .data$nu_ano_saeb == .env$ano)
  }
  if (!is.null(rede)) {
    tb <- dplyr::filter(tb, .data$tp_tipo_rede == .env$rede)
  }
  if (!is.null(classificacao)) {
    tb <- dplyr::filter(tb, .data$inse_classificacao == .env$classificacao)
  }
  new_eduBR(
    tb, "eduBR_inse", con,
    list(descricao = "Indice de Nivel Socioeconomico (INSE) por escola")
  )
}
