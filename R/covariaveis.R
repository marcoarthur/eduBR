# R/covariaveis.R
#
# Base escola × covariáveis para modelagem, com as mesmas definições do
# `perfil_escola()` (infraestrutura, etapas, docentes, matrículas e IDEB por
# etapa). Tudo é composto na consulta lazy: o `collect` (ou a projeção feita
# por `executar_regressao()`) só traz as colunas usadas.

#' Covariáveis escolares para modelagem
#'
#' Monta, no banco, uma tabela com **uma linha por escola** e as covariáveis
#' usadas no [perfil_escola()]: identificação (`co_entidade`, `sg_uf`,
#' `co_municipio`), `rede` e `localizacao` rotuladas, os itens de
#' infraestrutura (`in_*`, 0/1), as etapas ofertadas (`in_comum_*`),
#' `docentes` (`qt_doc_bas`), `matriculas` (`qt_mat_bas`) e o IDEB de **uma
#' edição** por etapa (`ideb_fund_i`, `ideb_fund_ii`, `ideb_medio`; `NA` sem
#' nota). A consulta é preguiçosa: serve direto como `dados` de
#' [executar_regressao()], que projeta só as colunas da especificação.
#'
#' @param con Conexão criada por [conecta()].
#' @param ano Ano do Censo (padrão `2025`).
#' @param ano_ideb Edição do IDEB (padrão `2023`), a mesma para todas as
#'   escolas — corte transversal consistente.
#' @param uf Filtro opcional por UF (sigla).
#' @param rede Filtro opcional pela rede: códigos (1–4) ou nomes
#'   (`"Municipal"`, `"Estadual"`, `"Federal"`, `"Privada"`, `"publica"`).
#' @param ativas Só escolas em atividade (`tp_situacao_funcionamento == 1`)?
#'   Padrão `TRUE`: paralisadas/extintas vêm sem infraestrutura no Censo.
#'
#' @return Objeto S3 de classe `eduBR_covariaveis` (consulta lazy).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' cov <- covariaveis_escola(con, uf = "SP", rede = "Municipal")
#' espec <- especificar_regressao(
#'   "ideb_fund_i",
#'   c("in_biblioteca", "in_internet", "docentes", "matriculas"),
#'   cuts = "localizacao"
#' )
#' coeficientes(executar_regressao(con, espec, dados = cov))
#' }
#'
#' @export
covariaveis_escola <- function(con, ano = 2025L, ano_ideb = 2023L,
                               uf = NULL, rede = NULL, ativas = TRUE) {
  lab <- eduBR_rotulos()
  flags <- c(names(eduBR_infra_perfil()), unique(names(eduBR_etapas_oferta())))

  esc <- eduBR_tbl(con, "censo_escolas") |>
    dplyr::filter(.data$nu_ano_censo == .env$ano)
  if (isTRUE(ativas)) {
    esc <- eduBR_so_ativas(esc)
  }
  if (!is.null(uf)) {
    esc <- dplyr::filter(esc, .data$sg_uf %in% .env$uf)
  }
  if (!is.null(rede)) {
    codigos <- eduBR_codigos_rede(rede)
    esc <- dplyr::filter(esc, .data$tp_dependencia %in% .env$codigos)
  }
  esc <- esc |>
    dplyr::select(dplyr::any_of(c(
      "co_entidade", "sg_uf", "co_municipio", "tp_dependencia",
      "tp_localizacao", flags
    ))) |>
    dplyr::mutate(
      rede = !!eduBR_case_when_lookup("tp_dependencia", lab$rede),
      localizacao = !!eduBR_case_when_lookup("tp_localizacao", lab$localizacao)
    )

  doc <- eduBR_tbl(con, "censo_docentes") |>
    dplyr::filter(.data$nu_ano_censo == .env$ano) |>
    dplyr::select(dplyr::all_of(c("co_entidade", docentes = "qt_doc_bas")))
  mat <- eduBR_tbl(con, "censo_matriculas") |>
    dplyr::filter(.data$nu_ano_censo == .env$ano) |>
    dplyr::select(dplyr::all_of(c("co_entidade", matriculas = "qt_mat_bas")))

  media_etapa <- function(e) {
    rlang::expr(mean(
      dplyr::if_else(.data$etapa == !!e, .data$ideb_observado, NA_real_),
      na.rm = TRUE
    ))
  }
  ideb <- eduBR_tbl(con, "ideb") |>
    dplyr::filter(.data$ano == .env$ano_ideb) |>
    dplyr::group_by(co_entidade = .data$id_escola) |>
    dplyr::summarise(
      ideb_fund_i = !!media_etapa("fundamental_i"),
      ideb_fund_ii = !!media_etapa("fundamental_ii"),
      ideb_medio = !!media_etapa("ensino_medio"),
      .groups = "drop"
    )

  tb <- esc |>
    dplyr::left_join(doc, by = "co_entidade") |>
    dplyr::left_join(mat, by = "co_entidade") |>
    dplyr::left_join(ideb, by = "co_entidade")

  new_eduBR(
    tb, "eduBR_covariaveis", con,
    list(
      descricao = sprintf(
        "Covariáveis por escola (Censo %s, IDEB %s)", ano, ano_ideb
      ),
      ano = ano, ano_ideb = ano_ideb
    )
  )
}
