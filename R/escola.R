# R/escola.R

#' Escolas da base do EduMaps
#'
#' Acessa as escolas do Censo Escolar (código INEP, nome, código e nome do
#' município, UF, rede, localização e coordenadas). A consulta é
#' preguiçosa: só vai ao banco quando materializada, por exemplo com
#' [as_tibble()].
#'
#' @details A fonte é o cadastro do Censo Escolar (domínio `censo_escolas`
#'   do [catalogo()]), a fonte de verdade sobre as escolas. O domínio
#'   `escolas` do catálogo é a primeira ingestão do EduMaps, incompleta (sem
#'   código do município e sem parte das escolas), e não é mais usado aqui.
#'   `codigo_inep` é o `co_entidade` do Censo e `co_municipio` é o código
#'   IBGE do município (7 dígitos, `integer`), a chave para juntar com
#'   [docentes_rede()], [gestores()], [covariaveis_escola()] e [ideb()].
#'
#'   Cobertura de coordenadas: cerca de 19% das escolas ativas do Censo
#'   2025 não têm `latitude`/`longitude`/`geometry` (24% na zona rural,
#'   65% no AC); essas linhas viram geometrias vazias em [as_sf()], que
#'   informa quantas são.
#'
#' @param con Conexão criada por [conecta()].
#' @param municipio Filtro opcional pelo nome do município.
#' @param uf Filtro opcional pela sigla da UF (ex.: `"SP"`).
#' @param co_municipio Filtro opcional pelo código IBGE do município (um ou
#'   mais).
#' @param ano Ano do Censo Escolar (padrão 2025).
#' @param ativas Só escolas em atividade (`tp_situacao_funcionamento == 1`)?
#'   Padrão `FALSE` (todas as escolas do cadastro).
#'
#' @return Objeto S3 de classe `eduBR_escola`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' escolas(con, uf = "SP")
#' escolas(con, co_municipio = 3555406)
#' }
#'
#' @export
escolas <- function(con, municipio = NULL, uf = NULL, co_municipio = NULL,
                    ano = 2025L, ativas = FALSE) {
  tb <- eduBR_escolas_censo(con, ano = ano, ativas = ativas)
  if (!is.null(municipio)) {
    tb <- dplyr::filter(tb, .data$municipio == .env$municipio)
  }
  if (!is.null(uf)) {
    tb <- dplyr::filter(tb, .data$uf == .env$uf)
  }
  if (!is.null(co_municipio)) {
    codigos <- suppressWarnings(as.integer(co_municipio))
    if (anyNA(codigos)) {
      stop("`co_municipio` deve ser num\u00e9rico (c\u00f3digo IBGE).",
           call. = FALSE)
    }
    tb <- dplyr::filter(tb, .data$co_municipio %in% .env$codigos)
  }
  new_eduBR(
    tb, "eduBR_escola", con,
    list(descricao = "Escolas (identificacao e localizacao)", ano = ano)
  )
}

# Escolas do cadastro do Censo (fonte de verdade), com os nomes de colunas
# da API de escolas() e rótulos de rede/localização derivados no SQL.
eduBR_escolas_censo <- function(con, ano = 2025L, ativas = FALSE) {
  lab <- eduBR_rotulos()
  tb <- eduBR_tbl(con, "censo_escolas") |>
    dplyr::filter(.data$nu_ano_censo == .env$ano)
  if (isTRUE(ativas)) {
    tb <- eduBR_so_ativas(tb)
  }
  tb <- dplyr::select(tb, dplyr::any_of(c(
    codigo_inep = "co_entidade", escola = "no_entidade",
    "co_municipio", municipio = "no_municipio", uf = "sg_uf",
    "tp_dependencia", "tp_localizacao", "latitude", "longitude", "geometry"
  )))
  cols <- colnames(tb)
  if ("tp_dependencia" %in% cols) {
    tb <- dplyr::mutate(
      tb, rede = !!eduBR_case_when_lookup("tp_dependencia", lab$rede)
    )
  }
  if ("tp_localizacao" %in% cols) {
    tb <- dplyr::mutate(
      tb,
      localizacao = !!eduBR_case_when_lookup("tp_localizacao", lab$localizacao)
    )
  }
  tb |>
    dplyr::select(dplyr::any_of(c(
      "codigo_inep", "escola", "co_municipio", "municipio", "uf", "rede",
      "localizacao", "latitude", "longitude", "geometry"
    )))
}

#' Uma escola pelo código INEP
#'
#' @param con Conexão criada por [conecta()].
#' @param codigo_inep Código INEP da escola (`co_entidade` do Censo).
#' @param ano Ano do Censo Escolar (padrão 2025).
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
escola <- function(con, codigo_inep, ano = 2025L) {
  tb <- dplyr::filter(
    eduBR_escolas_censo(con, ano = ano),
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
