# R/ideb_regiao.R
#
# IDEB com a dimensao regional (macrorregioes do IBGE) anexada. O mapa
# UF -> regiao e estatico (27 UFs) e aplicado direto no SQL via `case_when`,
# evitando o join por municipio (`co_municipio` e `integer` na tabela do
# IDEB enquanto `codigo_ibge` e `varchar(7)`, com zeros a esquerda).

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

  # Macrorregiao a partir da UF (mapa canonico do IBGE).
  tb <- dplyr::mutate(
    tb,
    nome_regiao = dplyr::case_when(
      .data$sg_uf %in% c("RO", "AC", "AM", "RR", "PA", "AP", "TO") ~ "Norte",
      .data$sg_uf %in% c(
        "MA", "PI", "CE", "RN", "PB", "PE", "AL", "SE", "BA"
      ) ~ "Nordeste",
      .data$sg_uf %in% c("MG", "ES", "RJ", "SP") ~ "Sudeste",
      .data$sg_uf %in% c("PR", "SC", "RS") ~ "Sul",
      .data$sg_uf %in% c("MS", "MT", "GO", "DF") ~ "Centro-oeste",
      TRUE ~ NA_character_
    )
  )
  tb <- dplyr::mutate(
    tb,
    sigla_regiao = dplyr::case_when(
      .data$nome_regiao == "Norte" ~ "N",
      .data$nome_regiao == "Nordeste" ~ "NE",
      .data$nome_regiao == "Sudeste" ~ "SE",
      .data$nome_regiao == "Sul" ~ "S",
      .data$nome_regiao == "Centro-oeste" ~ "CO",
      TRUE ~ NA_character_
    )
  )

  if (!is.null(regiao)) {
    alvo <- toupper(regiao)
    tb <- dplyr::filter(
      tb,
      toupper(.data$nome_regiao) == .env$alvo | .data$sigla_regiao == .env$alvo
    )
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
