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
  out <- out[order(out$distancia, out$co_entidade), , drop = FALSE]
  utils::head(out, as.integer(n))
}

eduBR_vizinhos_etapa <- function(sub, id, n) {
  feats <- sub[!names(sub) %in% eduBR_exclui_similaridade()]
  feats <- feats[vapply(feats, is.numeric, logical(1L))]
  # integer64 (bigint) vira double de verdade; as.matrix() leria os bits.
  feats[] <- lapply(feats, as.numeric)
  if (nrow(feats) == 0L) {
    stop("sem dados para comparar.", call. = FALSE)
  }
  alvo <- which(as.character(sub$co_entidade) == id)
  m <- scale(as.matrix(feats))
  m[!is.finite(m)] <- 0
  d <- sqrt(rowSums(sweep(m, 2L, m[alvo, , drop = TRUE], `-`)^2))
  d[alvo] <- Inf
  ix <- utils::head(order(d, as.character(sub$co_entidade)), as.integer(n))
  tibble::tibble(
    co_entidade = as.character(sub$co_entidade[ix]),
    etapa = as.character(sub$etapa[ix]),
    distancia = unname(d[ix])
  )
}

# Mesma conta de eduBR_vizinhos() executada no banco: padroniza por etapa
# com funções de janela (NA/desvio zero -> 0, como em scale()), mede a
# distância até a escola de referência e traz só as `n` mais próximas.
eduBR_vizinhos_sql <- function(tb, id, n = 5L) {
  id <- as.character(id)
  amostra <- dplyr::collect(utils::head(tb, 1L))
  if (nrow(amostra) == 0L) {
    stop("sem dados para comparar.", call. = FALSE)
  }
  feats <- setdiff(names(amostra), eduBR_exclui_similaridade())
  feats <- feats[vapply(amostra[feats], is.numeric, logical(1L))]
  if (length(feats) == 0L) {
    stop("sem dados para comparar.", call. = FALSE)
  }

  tb <- dplyr::mutate(tb, co_entidade = as.character(.data$co_entidade))
  etapas <- tb |>
    dplyr::filter(.data$co_entidade == .env$id) |>
    dplyr::distinct(.data$etapa) |>
    dplyr::collect()
  if (nrow(etapas) == 0L) {
    stop(sprintf("escola fora do recorte: '%s'.", id), call. = FALSE)
  }

  eduBR_vizinhos_query(tb, id, n, feats, etapas$etapa) |>
    dplyr::collect()
}

# Consulta lazy do k-NN (sem collect). Média/desvio por etapa saem de um
# único GROUP BY; padronização (NA/desvio zero -> 0, como em scale()),
# distância até a referência, ordenação e LIMIT `n` rodam no banco, em
# double precision.
eduBR_vizinhos_query <- function(tb, id, n, feats, etapas) {
  casts <- stats::setNames(
    lapply(feats, function(f) dbplyr::sql(sprintf('CAST("%s" AS DOUBLE PRECISION)', f))),
    feats
  )
  base <- tb |>
    dplyr::filter(.data$etapa %in% !!etapas) |>
    dplyr::transmute(.data$co_entidade, .data$etapa, !!!casts)

  estat <- base |>
    dplyr::group_by(.data$etapa) |>
    dplyr::summarise(
      dplyr::across(
        dplyr::all_of(feats),
        list(
          m = ~ mean(.x, na.rm = TRUE),
          s = ~ dplyr::na_if(stats::sd(.x, na.rm = TRUE), 0)
        ),
        .names = "{.col}__{.fn}"
      ),
      .groups = "drop"
    )

  alvo <- base |>
    dplyr::filter(.data$co_entidade == .env$id) |>
    dplyr::select(dplyr::all_of(c("etapa", feats))) |>
    dplyr::rename_with(~ paste0(.x, "__a"), dplyr::all_of(feats))

  termo <- function(f) {
    sprintf(
      "(dplyr::coalesce((`%1$s` - `%1$s__m`) / `%1$s__s`, 0) - dplyr::coalesce((`%1$s__a` - `%1$s__m`) / `%1$s__s`, 0))^2",
      f
    )
  }
  soma <- rlang::parse_expr(paste(vapply(feats, termo, character(1L)), collapse = " + "))

  base |>
    dplyr::inner_join(estat, by = "etapa") |>
    dplyr::inner_join(alvo, by = "etapa") |>
    dplyr::filter(.data$co_entidade != .env$id) |>
    dplyr::mutate(distancia = sqrt(!!soma)) |>
    dplyr::select(dplyr::all_of(c("co_entidade", "etapa", "distancia"))) |>
    dplyr::arrange(.data$distancia, .data$co_entidade) |>
    utils::head(as.integer(n))
}

# Acrescenta nome, município, UF e rede (Censo mais recente) às vizinhas.
eduBR_identifica_escolas <- function(con, viz) {
  vazio <- tibble::tibble(
    co_entidade = character(), escola = character(), municipio = character(),
    uf = character(), rede = character()
  )
  ids <- unique(viz$co_entidade)
  info <- if (length(ids) == 0L) {
    vazio
  } else {
    eduBR_tbl(con, "censo_escolas") |>
      dplyr::filter(.data$co_entidade %in% !!as.numeric(ids)) |>
      dplyr::select(dplyr::any_of(c(
        "nu_ano_censo", "co_entidade", "no_entidade", "no_municipio",
        "sg_uf", "tp_dependencia"
      ))) |>
      dplyr::collect()
  }
  if (nrow(info) > 0L) {
    info <- info[order(-info$nu_ano_censo), , drop = FALSE]
    info$co_entidade <- as.character(info$co_entidade)
    info <- info[!duplicated(info$co_entidade), , drop = FALSE]
    rotulos <- eduBR_rotulos()$rede
    info <- tibble::tibble(
      co_entidade = info$co_entidade,
      escola = info$no_entidade,
      municipio = info$no_municipio,
      uf = info$sg_uf,
      rede = unname(rotulos[as.character(info$tp_dependencia)])
    )
  } else {
    info <- vazio
  }
  out <- dplyr::left_join(
    dplyr::mutate(viz, co_entidade = as.character(.data$co_entidade)),
    info,
    by = "co_entidade"
  )
  dplyr::select(
    out,
    dplyr::all_of(c("co_entidade", "escola", "municipio", "uf", "rede",
                    "etapa", "distancia"))
  )
}

#' Escolas mais parecidas (benchmark escolar)
#'
#' Fase 1 da similaridade escolar: k-NN euclidiano sobre as features de
#' `analytics.escola_features` (infraestrutura, matrículas, docentes,
#' gestão e razões — sem medidas de desempenho), padronizadas **dentro de
#' cada etapa** (a MV tem uma linha por escola × etapa). Com conexão ao
#' banco, a padronização e a distância rodam **no banco** e só as `n`
#' vizinhas são baixadas; a saída é identificada pelo Censo (nome,
#' município, UF, rede).
#'
#' @param con Conexão criada por [conecta()].
#' @param codigo_inep Código INEP da escola de referência (`co_entidade`).
#' @param n Número de vizinhas (padrão `5`).
#' @param etapa Etapas do recorte (padrão as de [features_escola()]).
#' @param publica Só escolas públicas? Padrão `TRUE`.
#'
#' @return Um `tibble` com `co_entidade`, `escola`, `municipio`, `uf`,
#'   `rede`, `etapa` e `distancia` (crescente).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' escolas_similares(con, "13078070")
#' }
#'
#' @export
escolas_similares <- function(con, codigo_inep, n = 5L,
                              etapa = c("fundamental_i", "fundamental_ii"),
                              publica = TRUE) {
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1) {
    stop("`n` deve ser um inteiro positivo.", call. = FALSE)
  }
  tb <- consulta(features_escola(con, etapa = etapa, publica = publica))
  viz <- if (eduBR_lazy(tb)) {
    eduBR_vizinhos_sql(tb, codigo_inep, n)
  } else {
    eduBR_vizinhos(tibble::as_tibble(tb), codigo_inep, n)
  }
  eduBR_identifica_escolas(con, viz)
}
