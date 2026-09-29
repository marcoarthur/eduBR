# R/similaridade.R

#' Similaridade entre municípios
#'
#' Acessa `analytics.municipio_similaridade`, com os pares de municípios,
#' a distância e o índice de similaridade. A consulta é preguiçosa;
#' materialize com [as_tibble()].
#'
#' @param con Conexão criada por [conecta()].
#'
#' @return Objeto S3 de classe `eduBR_similaridade`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' municipios_similares(con)
#' }
#'
#' @export
municipios_similares <- function(con) {
  tb <- eduBR_tbl(con, "similaridade")
  new_eduBR(
    tb, "eduBR_similaridade", con,
    list(descricao = "Similaridade entre municipios")
  )
}

# Colunas de analytics.escola_features fora da distância: identificadores,
# códigos categóricos e medidas de desempenho (evita comparar pelo desfecho).
eduBR_exclui_similaridade <- function() {
  c("co_entidade", "etapa", "tp_dependencia", "tp_localizacao",
    "nota_media", "media_inse",
    paste0("pc_nivel_", 1L:8L))
}

# k-NN euclidiano sobre features padronizadas (puro R, testável sem banco).
# A MV tem uma linha por escola × etapa: compara dentro de cada etapa da
# referência e junta os blocos.
eduBR_vizinhos <- function(df, id, n = 5L) {
  id <- as.character(id)
  if (nrow(df) == 0L) {
    stop("sem dados para comparar.", call. = FALSE)
  }
  if (!"etapa" %in% names(df)) {
    df$etapa <- "todas"
  }
  alvos <- which(as.character(df$co_entidade) == id)
  if (!length(alvos)) {
    stop(sprintf("escola fora do recorte: '%s'.", id), call. = FALSE)
  }
  blocos <- lapply(unique(as.character(df$etapa[alvos])), function(e) {
    eduBR_vizinhos_etapa(df[as.character(df$etapa) == e, , drop = FALSE], id, n)
  })
  out <- dplyr::bind_rows(blocos)
  out <- out[order(out$distancia), , drop = FALSE]
  utils::head(out, as.integer(n))
}

eduBR_vizinhos_etapa <- function(sub, id, n) {
  feats <- sub[!names(sub) %in% eduBR_exclui_similaridade()]
  feats <- feats[vapply(feats, is.numeric, logical(1L))]
  if (nrow(feats) == 0L) {
    stop("sem dados para comparar.", call. = FALSE)
  }
  alvo <- which(as.character(sub$co_entidade) == id)
  m <- scale(as.matrix(feats))
  m[!is.finite(m)] <- 0
  d <- sqrt(rowSums(sweep(m, 2L, m[alvo, , drop = TRUE], `-`)^2))
  d[alvo] <- Inf
  ix <- utils::head(order(d), as.integer(n))
  tibble::tibble(
    co_entidade = as.character(sub$co_entidade[ix]),
    etapa = as.character(sub$etapa[ix]),
    distancia = unname(d[ix])
  )
}

#' Escolas mais parecidas (benchmark escolar)
#'
#' Fase 1 da similaridade escolar: k-NN euclidiano sobre as features de
#' `analytics.escola_features` (infraestrutura, matrículas, docentes,
#' gestão e razões — sem medidas de desempenho), padronizadas **dentro de
#' cada etapa** (a MV tem uma linha por escola × etapa). O recorte (`etapa`,
#' só públicas por padrão) limita o volume coletado; a distância roda em R
#' após o `collect` (com aviso de custo).
#'
#' @param con Conexão criada por [conecta()].
#' @param codigo_inep Código INEP da escola de referência (`co_entidade`).
#' @param n Número de vizinhas (padrão `5`).
#' @param etapa Etapas do recorte (padrão as de [features_escola()]).
#' @param publica Só escolas públicas? Padrão `TRUE`.
#'
#' @return Um `tibble` com `co_entidade`, `etapa` e `distancia` (crescente).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' escolas_similares(con, "35012345")
#' }
#'
#' @export
escolas_similares <- function(con, codigo_inep, n = 5L,
                              etapa = c("fundamental_i", "fundamental_ii"),
                              publica = TRUE) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1) {
    stop("`n` deve ser um inteiro positivo.", call. = FALSE)
  }
  df <- coletar(consulta(features_escola(con, etapa = etapa, publica = publica)))
  eduBR_vizinhos(df, codigo_inep, n)
}
