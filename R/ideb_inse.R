# R/ideb_inse.R
#
# Cruzamento do IDEB com o INSE. Como o INSE so existe em 2023, o join por
# (id_escola, ano = nu_ano_saeb) resulta num corte transversal de 2023 e
# cobre apenas escolas publicas (as que possuem INSE).

#' IDEB cruzado com o INSE
#'
#' Faz `inner_join` do IDEB (`clean.ideb_notas_escolas`) com o INSE
#' (`clean.inse`) por `id_escola` e ano (`ano = nu_ano_saeb`), anexando
#' `media_inse` e a classificacao do INSE, alem da macrorregiao derivada da
#' UF. Como o INSE so existe em 2023, o resultado e um corte transversal
#' daquele ano, restrito as escolas com INSE (apenas publicas). A consulta e
#' preguicosa; materialize com [as_tibble()].
#'
#' @param con Conexao criada por [conecta()].
#' @param regiao Filtro opcional pela macrorregiao (nome ou sigla).
#' @param uf Filtro opcional pela sigla da UF.
#' @param etapa Filtro opcional pela etapa.
#' @param rede Filtro opcional pela rede (`"Municipal"`, `"Estadual"`,
#'   `"Federal"`).
#'
#' @return Objeto S3 de classe `eduBR_ideb_inse`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' ideb_inse(con, regiao = "Nordeste", etapa = "fundamental_ii")
#' }
#'
#' @export
ideb_inse <- function(con, regiao = NULL, uf = NULL, etapa = NULL,
                      rede = NULL) {
  ins <- eduBR_tbl(con, "inse") |>
    dplyr::select(dplyr::all_of(c(
      "id_escola", "nu_ano_saeb", "media_inse", "inse_classificacao",
      "qtd_alunos_inse", "tp_tipo_rede", "tp_localizacao"
    )))

  tb <- dplyr::inner_join(
    eduBR_tbl(con, "ideb"), ins,
    by = c("id_escola" = "id_escola", "ano" = "nu_ano_saeb")
  )
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

  new_eduBR(
    tb, "eduBR_ideb_inse", con,
    list(descricao = "IDEB x INSE por escola (corte 2023, publicas)")
  )
}
