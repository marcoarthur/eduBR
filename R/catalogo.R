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
  cat <- utils::modifyList(eduBR_catalogo(), eduBR_catalogo_extra())
  data.frame(
    dominio = names(cat),
    schema  = vapply(cat, `[[`, character(1), 1L),
    tabela  = vapply(cat, `[[`, character(1), 2L),
    row.names = NULL
  )
}

# Relações customizadas da sessão (via registrar_relacao()).
eduBR_catalogo_extra <- function() {
  extra <- getOption("eduBR.catalogo.extra", list())
  if (!is.list(extra)) {
    extra <- list()
  }
  extra
}

#' Registrar relação customizada no catálogo
#'
#' Estende o catálogo do pacote na sessão: `dominio` passa a resolver para
#' `schema.tabela` em [eduBR_tbl()] (com precedência sobre o embutido) e
#' aparece em [catalogo()]. Útil para tabelas de análise (`staging.*`) sem
#' reescrever o pacote. A existência da tabela só é verificada no primeiro
#' uso (erro do banco, se inexistente).
#'
#' @param dominio Nome do domínio (string única, sem espaços).
#' @param schema Schema da relação (ex.: `"staging"`).
#' @param tabela Tabela ou view (ex.: `"minha_base"`).
#'
#' @return O `dominio`, invisível. Desfaça com [desregistrar_relacao()].
#'
#' @examples
#' \dontrun{
#' registrar_relacao("minha_base", "staging", "experimento_1")
#' catalogo()
#' }
#'
#' @export
registrar_relacao <- function(dominio, schema, tabela) {
  for (nm in c("dominio", "schema", "tabela")) {
    v <- get(nm)
    if (!is.character(v) || length(v) != 1L || is.na(v) || !nzchar(v)) {
      stop(sprintf("`%s` deve ser uma string nao vazia.", nm), call. = FALSE)
    }
  }
  if (grepl("\\s", dominio)) {
    stop("`dominio` nao pode conter espacos.", call. = FALSE)
  }
  extra <- eduBR_catalogo_extra()
  extra[[dominio]] <- c(schema, tabela)
  options(eduBR.catalogo.extra = extra)
  invisible(dominio)
}

#' Desregistrar relação customizada
#'
#' Remove do catálogo da sessão um domínio registrado por
#' [registrar_relacao()]. Sem efeito quando o domínio não é customizado.
#'
#' @param dominio Nome do domínio.
#'
#' @return O `dominio`, invisível.
#'
#' @export
desregistrar_relacao <- function(dominio) {
  extra <- eduBR_catalogo_extra()
  extra[[dominio]] <- NULL
  options(eduBR.catalogo.extra = extra)
  invisible(dominio)
}

# Resolve um nome de domínio para uma consulta preguiçosa (dbplyr).
eduBR_tbl <- function(con, nome) {
  alvo <- eduBR_catalogo_extra()[[nome]]
  if (is.null(alvo)) {
    alvo <- eduBR_catalogo()[[nome]]
  }
  if (is.null(alvo)) {
    stop(
      sprintf("Relacao desconhecida no catalogo do eduBR: %s", nome),
      call. = FALSE
    )
  }
  dplyr::tbl(con, dbplyr::in_schema(alvo[1], alvo[2]))
}
