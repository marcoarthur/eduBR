# R/catalogo.R
#
# Mapeamento entre os nomes de domínio expostos ao usuário e as relações
# físicas do banco. As funções de alto nível dependem apenas deste catálogo,
# de modo que renomear/mover uma tabela ou view exige mudar só aqui.

eduBR_catalogo <- function() {
  list(
    escolas          = c("clean", "escolas"),
    municipios       = c("clean", "municipios_sp"),
    ibge             = c("clean", "dados_ibge"),
    populacao        = c("clean", "populacao_municipal"),
    redes            = c("analytics", "mv_rede_escolas"),
    indicadores      = c("analytics", "ranking_escola"),
    scores           = c("clean", "mv_escolas_scores"),
    censo_escolas    = c("clean", "censo_escolas"),
    censo_docentes   = c("clean", "censo_docentes"),
    censo_matriculas = c("clean", "censo_matriculas"),
    censo_gestor     = c("clean", "censo_gestor"),
    ideb             = c("clean", "ideb_notas_escolas"),
    inse             = c("clean", "inse"),
    escola_features  = c("analytics", "escola_features"),
    clusters         = c("analytics", "clustering_metadata"),
    similaridade     = c("analytics", "municipio_similaridade")
  )
}

#' Catálogo de relações disponíveis no eduBR
#'
#' Lista, em termos de domínio, quais relações físicas do banco de dados
#' estão disponíveis para as funções de acesso. Útil para inspeção e para
#' entender a que `schema.tabela` cada nome de domínio corresponde.
#'
#' @return Um `data.frame` com as colunas `dominio`, `schema` e `tabela`.
#'
#' @examples
#' catalogo()
#'
#' @export
catalogo <- function() {
  cat <- eduBR_catalogo()
  data.frame(
    dominio = names(cat),
    schema  = vapply(cat, `[[`, character(1), 1L),
    tabela  = vapply(cat, `[[`, character(1), 2L),
    row.names = NULL
  )
}

# Resolve um nome de domínio para uma consulta preguiçosa (dbplyr).
eduBR_tbl <- function(con, nome) {
  alvo <- eduBR_catalogo()[[nome]]
  if (is.null(alvo)) {
    stop(
      sprintf("Relacao desconhecida no catalogo do eduBR: %s", nome),
      call. = FALSE
    )
  }
  dplyr::tbl(con, dbplyr::in_schema(alvo[1], alvo[2]))
}
