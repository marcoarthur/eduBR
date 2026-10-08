# R/pca.R
#
# PCA do perfil escolar sobre features numéricas (infraestrutura,
# matrículas, docentes, gestão e razões). Função pura (data.frame in,
# lista out): o recorte e o `collect` ficam com o chamador
# (ex.: features_escola() + coletar()).

# Colunas fora da PCA: identificadores, códigos categóricos do Censo (não
# são grandezas) e medidas de desempenho.
eduBR_exclui_pca <- function() {
  c("co_entidade", "etapa", names(eduBR_colunas_rotulo()),
    "nota_media", "media_inse", paste0("pc_nivel_", 1L:8L))
}

#' PCA do perfil escolar
#'
#' Ajusta uma PCA (`stats::prcomp`, com centro e escala) sobre as colunas
#' numéricas de `dados`, excluindo identificadores, códigos categóricos do
#' Censo (`tp_dependencia`, `tp_localizacao`, `tp_categoria_escola_privada`)
#' e medidas de desempenho (nota/INSE/percentuais por nível). Colunas sem variância ou só-NA caem
#' com aviso; linhas incompletas nas colunas usadas são descartadas. O sinal
#' de cada componente é fixado para que o maior peso (em módulo) seja
#' positivo. Componentes de variância numericamente nula (colunas que são
#' combinação linear exata de outras) são descartados com aviso.
#'
#' @param dados Um `data.frame` com as features (ex.: [features_escola()]
#'   materializado).
#' @param id Nome da coluna identificadora da escola (padrão `"co_entidade"`).
#'
#' @return Lista de classe `eduBR_pca` com `fit` (o `prcomp`), `variancia`
#'   (tibble `pc`/`prop`/`acumulada`), `loadings` (tibble longo
#'   `pc`/`variavel`/`peso`) e `scores` (tibble com `id` + PCs). O atributo
#'   `removidas` lista as colunas descartadas.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' df <- features_escola(con, etapa = "fundamental_ii") |> coletar(avisar = FALSE)
#' pca_perfil(df)
#' }
#'
#' @export
pca_perfil <- function(dados, id = "co_entidade") {
  if (!is.data.frame(dados)) {
    stop("`dados` deve ser um data.frame.", call. = FALSE)
  }
  if (!is.character(id) || length(id) != 1L || !id %in% names(dados)) {
    stop(sprintf("coluna identificadora inexistente: '%s'.", id), call. = FALSE)
  }

  num <- dados[!names(dados) %in% eduBR_exclui_pca()]
  num <- num[vapply(num, is.numeric, logical(1L))]
  # integer64 (bigint) vira double de verdade; as.matrix() leria os bits.
  num[] <- lapply(num, as.numeric)
  if (ncol(num) == 0L) {
    stop("sem colunas numéricas para a PCA.", call. = FALSE)
  }

  sem_dados <- names(num)[vapply(num, function(v) all(is.na(v)), logical(1L))]
  if (length(sem_dados)) {
    num <- num[!names(num) %in% sem_dados]
  }
  if (ncol(num) == 0L) {
    stop("sem colunas numéricas para a PCA.", call. = FALSE)
  }

  ok <- stats::complete.cases(num)
  if (sum(ok) < 2L) {
    stop("menos de 2 escolas com dados completos.", call. = FALSE)
  }
  n_inc <- sum(!ok)

  # Variância avaliada no subconjunto completo: constante fora dele quebra
  # o prcomp mesmo variando no total.
  mat <- num[ok, , drop = FALSE]
  descartadas <- c(sem_dados, names(mat)[vapply(mat, function(v) {
    length(v) < 2L || is.na(stats::var(v)) || stats::var(v) == 0
  }, logical(1L))])
  if (length(descartadas)) {
    warning(
      sprintf(
        "colunas sem variância/dados, fora da PCA: %s.",
        paste(descartadas, collapse = ", ")
      ),
      call. = FALSE
    )
    mat <- mat[!names(mat) %in% descartadas]
  }
  if (ncol(mat) == 0L) {
    stop("sem colunas numéricas para a PCA.", call. = FALSE)
  }
  ids <- as.character(dados[[id]][ok])
  if (anyDuplicated(ids)) {
    stop(sprintf("`%s` com valores duplicados no recorte.", id), call. = FALSE)
  }

  fit <- stats::prcomp(as.matrix(mat), center = TRUE, scale. = TRUE)
  # Sinal do componente é arbitrário: fixa o maior peso (em módulo) positivo
  # para a leitura dos eixos não mudar entre execuções.
  sinal <- apply(fit$rotation, 2L, function(v) sign(v[which.max(abs(v))]))
  sinal[sinal == 0] <- 1
  fit$rotation <- sweep(fit$rotation, 2L, sinal, `*`)
  fit$x <- sweep(fit$x, 2L, sinal, `*`)

  # Colinearidade exata (ex.: total = soma das partes) gera componentes de
  # variância numericamente nula, sem informação e instáveis: saem da saída.
  nulos <- fit$sdev <= 1e-8 * fit$sdev[[1L]]
  if (any(nulos)) {
    q <- qr(scale(as.matrix(mat)))
    redundantes <- colnames(mat)[q$pivot[-seq_len(q$rank)]]
    warning(
      sprintf(
        "%d componente(s) de vari\u00e2ncia nula descartado(s); colunas combina\u00e7\u00e3o linear de outras: %s.",
        sum(nulos),
        if (length(redundantes)) paste(redundantes, collapse = ", ") else "\u2014"
      ),
      call. = FALSE
    )
    fit$sdev <- fit$sdev[!nulos]
    fit$rotation <- fit$rotation[, !nulos, drop = FALSE]
    fit$x <- fit$x[, !nulos, drop = FALSE]
  }
  prop <- fit$sdev^2 / sum(fit$sdev^2)
  pcs <- paste0("PC", seq_along(prop))

  cargas <- as.data.frame(fit$rotation)
  loadings <- tibble::tibble(
    pc = rep(pcs, each = nrow(cargas)),
    variavel = rep(rownames(cargas), times = length(pcs)),
    peso = unname(unlist(cargas))
  )

  scores <- tibble::as_tibble(
    stats::setNames(
      c(list(id = ids), as.data.frame(fit$x)),
      c("id", pcs)
    )
  )

  structure(
    list(
      fit = fit,
      variancia = tibble::tibble(
        pc = pcs, prop = unname(prop), acumulada = unname(cumsum(prop))
      ),
      loadings = loadings,
      scores = scores
    ),
    class = "eduBR_pca",
    removidas = descartadas,
    n_incompletas = n_inc
  )
}

#' @export
print.eduBR_pca <- function(x, ...) {
  n_pc <- nrow(x$variancia)
  cat(sprintf(
    "<eduBR_pca> %d escolas x %d componentes (%.1f%% em PC1-PC2)\n",
    nrow(x$scores), n_pc, 100 * sum(x$variancia$prop[1L:2L])
  ))
  invisible(x)
}
