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

# Metadados por domínio: granularidade, chave de junção (e tipo no banco),
# coluna de ano e anos disponíveis no edumaps_dev (levantados em
# 2026-10-07; mudam com novas cargas).
eduBR_catalogo_meta <- function() {
  m <- function(granularidade, chave, tipo_chave, coluna_ano, anos) {
    list(
      granularidade = granularidade, chave = chave, tipo_chave = tipo_chave,
      coluna_ano = coluna_ano, anos = anos
    )
  }
  list(
    escolas          = m("escola (legado: 1\u00aa ingest\u00e3o, incompleta)",
                         "codigo_inep", "bigint", NA, NA),
    municipios       = m("munic\u00edpio", "codigo_ibge", "varchar(7)", NA, NA),
    ibge             = m("munic\u00edpio", "codigo_ibge", "text", "ano", "vazia no dev"),
    populacao        = m("munic\u00edpio", "codigo_ibge", "varchar(7)", NA, NA),
    redes            = m("munic\u00edpio \u00d7 rede", "co_municipio", "text", "ano_ideb",
                         "2007-2023 (bienal)"),
    indicadores      = m("escola \u00d7 indicador", "id_escola", "integer", "ano",
                         "vazia no dev"),
    scores           = m("escola", "co_entidade", "bigint", "nu_ano_censo", "2025"),
    censo_escolas    = m("escola", "co_entidade", "bigint", "nu_ano_censo", "2025"),
    censo_docentes   = m("escola", "co_entidade", "bigint", "nu_ano_censo", "2025"),
    censo_matriculas = m("escola", "co_entidade", "bigint", "nu_ano_censo", "2025"),
    censo_gestor     = m("escola", "co_entidade", "bigint", "nu_ano_censo", "2025"),
    ideb             = m("escola \u00d7 etapa \u00d7 edi\u00e7\u00e3o", "id_escola", "bigint",
                         "ano", "2005-2023 (bienal)"),
    inse             = m("escola", "id_escola", "bigint", "nu_ano_saeb", "2023"),
    escola_features  = m("escola \u00d7 etapa", "co_entidade", "text", NA,
                         "Censo 2025 + IDEB/INSE"),
    clusters         = m("execu\u00e7\u00e3o \u00d7 cluster", "run_id", "text", NA, NA),
    similaridade     = m("par de munic\u00edpios", "municipio_1, municipio_2",
                         "varchar(8)", NA, "vazia no dev")
  )
}

#' Catálogo de relações disponíveis no eduBR
#'
#' Lista, em termos de domínio, quais relações físicas do banco de dados
#' estão disponíveis para as funções de acesso, com a granularidade, a chave
#' de junção (e seu tipo no banco) e o ano de referência de cada uma. Útil
#' para inspeção e para juntar relações sem adivinhar chaves ou anos.
#'
#' Atenção aos tipos: `codigo_inep`/`co_entidade`/`id_escola` são `bigint`
#' (chegam como `integer64`), enquanto `codigo_ibge` é texto; converta antes
#' de juntar. Os anos refletem o `edumaps_dev` em 2026-10-07 e mudam com
#' novas cargas. Relações de [registrar_relacao()] aparecem com metadados
#' `NA`.
#'
#' A fonte de verdade sobre as escolas é `censo_escolas` (cadastro do Censo
#' Escolar, com `co_municipio`), usada por [escolas()]; `escolas` é a
#' primeira ingestão do EduMaps, incompleta, mantida só como legado.
#'
#' @return Um `data.frame` com as colunas `dominio`, `schema`, `tabela`,
#'   `granularidade`, `chave`, `tipo_chave`, `coluna_ano` e `anos`.
#'
#' @examples
#' catalogo()
#'
#' @export
catalogo <- function() {
  cat <- utils::modifyList(eduBR_catalogo(), eduBR_catalogo_extra())
  meta <- eduBR_catalogo_meta()
  campo <- function(nome) {
    vapply(
      names(cat),
      function(d) {
        v <- meta[[d]][[nome]]
        if (is.null(v) || is.na(v) || d %in% names(eduBR_catalogo_extra())) {
          NA_character_
        } else {
          v
        }
      },
      character(1L),
      USE.NAMES = FALSE
    )
  }
  data.frame(
    dominio = names(cat),
    schema  = vapply(cat, `[[`, character(1), 1L),
    tabela  = vapply(cat, `[[`, character(1), 2L),
    granularidade = campo("granularidade"),
    chave = campo("chave"),
    tipo_chave = campo("tipo_chave"),
    coluna_ano = campo("coluna_ano"),
    anos = campo("anos"),
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
