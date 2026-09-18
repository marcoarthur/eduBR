# R/floresta.R
#
# Random Forest (ranger) para classificacao de desempenho escolar. O padrao
# segue a literatura: floresta com probabilidade e importancia por permutacao
# para reducao de dimensao + classificacao alto/medio/baixo.

#' Separa dados de forma estratificada
#'
#' Divide um `data.frame` em `treino`/`teste`, preservando a proporcao de cada
#' estrato (por padrao, o nivel de desempenho) nos dois lados. Usado antes de
#' [treinar_floresta()] para avaliar a classificacao fora da amostra.
#'
#' @param dados `data.frame`.
#' @param var Coluna usada para estratificar (padrao `nivel`).
#' @param prop Proporcao de linhas por estrato que ficam no treino.
#' @param semente Semente aleatoria para reprodutibilidade.
#'
#' @return Uma lista com `treino` e `teste` (tibbles).
#'
#' @examples
#' \dontrun{
#' d <- classificar_desempenho(features_escola(con))
#' partes <- dividir_dados(d)
#' }
#'
#' @export
dividir_dados <- function(dados, var = "nivel", prop = 0.8, semente = 2023) {
  if (!is.data.frame(dados)) {
    stop("`dados` deve ser um data.frame.", call. = FALSE)
  }
  if (!var %in% names(dados)) {
    stop(sprintf("coluna `%s` inexistente em `dados`.", var), call. = FALSE)
  }
  if (!is.numeric(prop) || length(prop) != 1L || is.na(prop) || prop <= 0 ||
      prop >= 1) {
    stop("`prop` deve estar em (0, 1).", call. = FALSE)
  }

  estratos <- unique(dados[[var]])
  set.seed(semente)
  idx <- integer()
  for (e in estratos) {
    ix <- which(dados[[var]] == e)
    idx <- c(idx, sample(ix, ceiling(length(ix) * prop)))
  }
  idx <- sort(idx)
  list(
    treino = tibble::as_tibble(dados[idx, ]),
    teste  = tibble::as_tibble(dados[-idx, ])
  )
}

#' Treina a floresta aleatoria
#'
#' Ajusta uma Random Forest de **classificacao com probabilidade** (`ranger`)
#' para um alvo categorico (ex.: `nivel` criado por [classificar_desempenho()]).
#' A importancia de cada variavel e calculada por **permutacao**, permitindo a
#' reducao de dimensao via [importancia_floresta()].
#'
#' @param dados `data.frame` com o alvo e as features.
#' @param alvo Nome da coluna alvo (fator). Padrao `nivel`.
#' @param features Vetor de colunas usadas como preditoras. Padrao `NULL`:
#'   todas exceto `alvo`, os identificadores espaciais e as medidas de
#'   desempenho (`co_entidade`, `id_escola`, `etapa`, `sg_uf`, `co_municipio`,
#'   `nota_matematica`, `nota_portugues`, `nota_media`). Identificadores como UF
#'   nao devem entrar como preditor: funcionam como rotulo espacial, nao como
#'   caracteristica da escola.
#' @param semente Semente aleatoria.
#' @param trees Numero de arvores.
#' @param min_node_size Tamanho minimo do no folha.
#' @param ... Argumentos adicionais passados a [ranger::ranger()].
#'
#' @return Objeto de classe `eduBR_floresta`: lista com `modelo` (saida do
#'   ranger), `alvo`, `features`, `formula` e `classes`.
#'
#' @examples
#' \dontrun{
#' d <- classificar_desempenho(features_escola(con))
#' partes <- dividir_dados(d)
#' rf <- treinar_floresta(partes$treino)
#' importancia_floresta(rf)
#' }
#'
#' @export
treinar_floresta <- function(dados, alvo = "nivel", features = NULL,
                             semente = 2023, trees = 500,
                             min_node_size = 5, ...) {
  rlang::check_installed("ranger", reason = "para treinar a floresta aleatoria")
  if (!is.data.frame(dados)) {
    stop("`dados` deve ser um data.frame.", call. = FALSE)
  }
  if (!alvo %in% names(dados)) {
    stop(sprintf("coluna alvo `%s` inexistente em `dados`.", alvo), call. = FALSE)
  }
  y <- dados[[alvo]]
  if (!is.factor(y)) {
    stop(
      "`alvo` deve ser um fator; use classificar_desempenho() para criar o nivel.",
      call. = FALSE
    )
  }
  if (anyNA(y)) {
    stop("`alvo` nao pode conter NA.", call. = FALSE)
  }

  if (is.null(features)) {
    excluir <- c(
      alvo, "co_entidade", "id_escola", "etapa",
      "sg_uf", "uf", "sg_regiao", "regiao",
      "co_municipio", "co_uf", "no_municipio",
      "nota_matematica", "nota_portugues", "nota_media"
    )
    features <- setdiff(names(dados), excluir)
  }
  features <- setdiff(features, alvo)
  faltantes <- setdiff(features, names(dados))
  if (length(faltantes)) {
    stop(
      sprintf("features inexistentes em `dados`: %s", paste(faltantes, collapse = ", ")),
      call. = FALSE
    )
  }

  formula <- stats::as.formula(paste(alvo, "~", paste(features, collapse = " + ")))
  modelo <- ranger::ranger(
    formula = formula,
    data = dados,
    classification = TRUE,
    probability = TRUE,
    importance = "permutation",
    seed = semente,
    num.trees = trees,
    min.node.size = min_node_size,
    ...
  )

  structure(
    list(
      modelo   = modelo,
      alvo     = alvo,
      features = features,
      formula  = formula,
      classes  = levels(y)
    ),
    class = "eduBR_floresta"
  )
}

#' Importancia das variaveis por permutacao
#'
#' Extrai, em ordem decrescente, a importancia por permutacao calculada no
#' ajuste de [treinar_floresta()]. Serve para reducao de dimensao (selecionar
#' as features que mais contribuem para a classificacao).
#'
#' @param modelo Objeto criado por [treinar_floresta()].
#'
#' @return Um `tibble` com as colunas `var` e `importancia`, ordenado da
#'   variavel mais influente para a menos influente.
#'
#' @export
importancia_floresta <- function(modelo) {
  if (!inherits(modelo, "eduBR_floresta")) {
    stop("`modelo` deve ser um ajuste de treinar_floresta().", call. = FALSE)
  }
  imp <- modelo$modelo$variable.importance
  if (is.null(imp)) {
    stop(
      "Modelo sem importancia; treine com importance = 'permutation'.",
      call. = FALSE
    )
  }
  out <- tibble::tibble(var = names(imp), importancia = unname(imp))
  dplyr::arrange(out, dplyr::desc(.data$importancia))
}

#' Prediz o nivel de desempenho
#'
#' Aplica um modelo de [treinar_floresta()] a um `data.frame` com as mesmas
#' features, devolvendo o nivel previsto e, quando o modelo usa probabilidade,
#' a probabilidade de cada classe.
#'
#' @param modelo Objeto criado por [treinar_floresta()].
#' @param dados `data.frame` com as features usadas no treino.
#'
#' @return Um `tibble` com `nivel_pred` (fator) e, se o modelo teve
#'   `probability = TRUE`, colunas `p_<classe>` com as probabilidades.
#'
#' @export
predizer_floresta <- function(modelo, dados) {
  if (!inherits(modelo, "eduBR_floresta")) {
    stop("`modelo` deve ser um ajuste de treinar_floresta().", call. = FALSE)
  }
  faltantes <- setdiff(modelo$features, names(dados))
  if (length(faltantes)) {
    stop(
      sprintf(
        "features necessarias ausentes em `dados`: %s",
        paste(faltantes, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  pred <- stats::predict(modelo$modelo, data = dados[, modelo$features])
  p <- pred$predictions

  if (is.matrix(p)) {
    if (is.null(colnames(p))) {
      colnames(p) <- modelo$classes
    }
    prob <- tibble::as_tibble(p)
    names(prob) <- paste0("p_", modelo$classes)
    nivel <- factor(colnames(p)[apply(p, 1, which.max)], levels = modelo$classes)
    out <- dplyr::bind_cols(
      tibble::tibble(nivel_pred = nivel),
      prob
    )
  } else {
    out <- tibble::tibble(
      nivel_pred = factor(as.character(p), levels = modelo$classes)
    )
  }
  out
}

#' Metricas da classificacao em dados de teste
#'
#' Compara a predicao de [predizer_floresta()] com o rotulo real em um conjunto
#' de teste, devolvendo acuracia, F1 macro, AUC macro (média das curvas
#' one-vs-rest) e a acuracia do baseline (classe dominante). A matriz de
#' confusao e as metricas por classe ficam em atributos.
#'
#' @param modelo Objeto criado por [treinar_floresta()].
#' @param dados_teste `data.frame` com o rotulo real e as features.
#' @param rotulo Nome da coluna com o rotulo real (padrao `nivel`).
#' @param auc Calcular AUC multiclasse? Padrao `TRUE`.
#'
#' @return Um `tibble` de uma linha com `acuracia`, `f1_macro`, `auc_macro` e
#'   `baseline_acerto`; atributos `confusao`, `f1_classe` e `auc_classe`.
#'
#' @export
metricas_floresta <- function(modelo, dados_teste, rotulo = "nivel", auc = TRUE) {
  if (!inherits(modelo, "eduBR_floresta")) {
    stop("`modelo` deve ser um ajuste de treinar_floresta().", call. = FALSE)
  }
  if (!rotulo %in% names(dados_teste)) {
    stop(
      sprintf("coluna `%s` inexistente em `dados_teste`.", rotulo),
      call. = FALSE
    )
  }
  verdadeiro <- factor(as.character(dados_teste[[rotulo]]), levels = modelo$classes)
  pred <- predizer_floresta(modelo, dados_teste)
  predito <- pred$nivel_pred

  mat <- table(verdadeiro, predito, dnn = c("real", "predito"))
  total <- sum(mat)
  acuracia <- sum(diag(mat)) / total

  n_real <- rowSums(mat)
  n_pred <- colSums(mat)
  f1 <- vapply(modelo$classes, function(k) {
    prec <- if (n_pred[k] > 0) mat[k, k] / n_pred[k] else NA_real_
    rec  <- if (n_real[k] > 0) mat[k, k] / n_real[k] else NA_real_
    if (is.na(prec) || is.na(rec)) NA_real_ else 2 * prec * rec / (prec + rec)
  }, numeric(1))

  auc_macro <- NA_real_
  auc_classe <- NULL
  if (isTRUE(auc) && any(grepl("^p_", names(pred)))) {
    auc_classe <- vapply(modelo$classes, function(k) {
      auc_univariavel(pred[[paste0("p_", k)]], verdadeiro == k)
    }, numeric(1))
    auc_macro <- mean(auc_classe, na.rm = TRUE)
  }

  out <- tibble::tibble(
    acuracia        = acuracia,
    f1_macro        = mean(f1, na.rm = TRUE),
    auc_macro       = auc_macro,
    baseline_acerto = max(n_real) / total
  )
  attr(out, "confusao")   <- mat
  attr(out, "f1_classe")  <- f1
  if (!is.null(auc_classe)) {
    attr(out, "auc_classe") <- auc_classe
  }
  out
}

# AUC binaria por soma de postos (equivalente a Wilcoxon-Mann-Whitney).
# `score`: vetor com a probabilidade da classe; `pos`: lógico da classe positiva.
auc_univariavel <- function(score, pos) {
  n_pos <- sum(pos)
  n_neg <- sum(!pos)
  if (n_pos == 0L || n_neg == 0L) {
    return(NA_real_)
  }
  r <- rank(score, na.last = "keep")
  (sum(r[pos], na.rm = TRUE) - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg)
}

#' @export
print.eduBR_floresta <- function(x, ...) {
  cat(sprintf(
    "<eduBR_floresta> | alvo: %s | classes: %s | features: %d\n",
    x$alvo, paste(x$classes, collapse = "/"), length(x$features)
  ))
  cat(sprintf(
    "  erro OOB: %.4f (Brier para classificacao com probabilidade)\n",
    x$modelo$prediction.error
  ))
  imp <- importancia_floresta(x)
  cat("  top-5 importancia por permutacao:\n")
  print(utils::head(imp, 5L), row.names = FALSE)
  invisible(x)
}