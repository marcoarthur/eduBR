# R/regressao.R
#
# Motor generico: executa uma especificacao (R/espec.R) sobre uma fonte de
# dados qualquer, ajustando um modelo por combinacao de cortes. Recapitua o
# padrao de list-columns usado em tendencia_regiao()/regressao_inse()
# (modelo + coeficientes + metricas + predicoes), sem depender de variaveis
# globais: tudo entra por argumento.

# Resolve a fonte de dados (tbl lazy) a partir da spec.
eduBR_espec_tbl <- function(con, espec, dados) {
  if (!is.null(dados)) {
    tb <- if (inherits(dados, "eduBR")) consulta(dados) else dados
  } else if (!is.null(espec$fonte)) {
    tb <- eduBR_tbl(con, espec$fonte)
  } else {
    stop(
      "Informe `dados` em executar_regressao() ou o campo `fonte` da especificacao.",
      call. = FALSE
    )
  }

  if (!is.null(espec$filtro)) {
    for (nm in names(espec$filtro)) {
      val <- espec$filtro[[nm]]
      tb <- dplyr::filter(tb, .data[[nm]] == .env$val)
    }
  }
  tb
}

# Ajusta um modelo para um data.frame. Devolve uma lista com n e o fit
# (NULL quando nao ha linhas suficientes).
eduBR_espec_fit <- function(df, espec, formula) {
  cols <- unique(c(espec$outcome, espec$predictors))
  df <- tidyr::drop_na(df, dplyr::all_of(cols))

  if (identical(espec$modelo, "logistico") &&
      !is.factor(df[[espec$outcome]])) {
    df[[espec$outcome]] <- factor(df[[espec$outcome]])
  }

  n <- nrow(df)

  minimo <- length(espec$predictors) + 1L
  if (n <= minimo) {
    return(list(n = n, modelo = NULL, dados = df))
  }

  modelo <- if (identical(espec$modelo, "logistico")) {
    parsnip::fit(
      parsnip::logistic_reg() |> parsnip::set_engine("glm"),
      formula, data = df
    )
  } else {
    parsnip::fit(parsnip::linear_reg(), formula, data = df)
  }

  list(n = n, modelo = modelo, dados = df)
}

# AUC (metodo de postos) do desfecho binario, sem dependencia extra.
eduBR_auc <- function(fit, data, outcome) {
  y <- data[[outcome]]
  if (!is.factor(y)) {
    y <- factor(y)
  }
  if (nlevels(y) != 2L) {
    return(NA_real_)
  }

  prob <- tryCatch(
    stats::predict(fit, new_data = data, type = "prob"),
    error = function(e) NULL
  )
  if (is.null(prob) || ncol(prob) < 2L) {
    return(NA_real_)
  }
  prob <- prob[[2]]

  positivo <- y == levels(y)[2]
  n1 <- sum(positivo)
  n0 <- sum(!positivo)
  if (n1 == 0L || n0 == 0L) {
    return(NA_real_)
  }
  r <- rank(prob)
  (sum(r[positivo]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# broom::glance + metricas de classificacao no modo logistico.
eduBR_glance <- function(fit, data, espec) {
  g <- broom::glance(fit)
  if (identical(espec$modelo, "logistico")) {
    g$mcfadden <- if (!is.null(g$null.deviance) && g$null.deviance > 0) {
      1 - (g$deviance / g$null.deviance)
    } else {
      NA_real_
    }
    g$auc <- eduBR_auc(fit, data, espec$outcome)
  }
  g
}

#' Executa uma especificação de regressão
#'
#' Ajusta o modelo descrito em `espec` para cada combinação das colunas de
#' corte (`espec$cuts`). Os dados vêm do argumento `dados` (um `tbl` lazy ou
#' um objeto eduBR) ou do domínio `espec$fonte`. O modelo é ajustado com o
#' `parsnip` e os resultados são devolvidos como list-columns padronizadas.
#'
#' @param con Conexão criada por [conecta()].
#' @param espec Objeto `eduBR_espec` criado por [especificar_regressao()] ou
#'   [ler_espec()].
#' @param dados Fonte de dados opcional (`tbl` ou objeto eduBR). Tem
#'   precedência sobre `espec$fonte`.
#'
#' @return Um `tibble` de classe `eduBR_regressoes`, com as colunas de corte,
#'   `n`, `modelo`, `coeficientes`, `metricas` e `predicoes` (list-columns;
#'   achate com [coeficientes()], [metricas()] ou `tidyr::unnest()`).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' espec <- especificar_regressao(
#'   outcome = "ideb_observado",
#'   predictors = c("nota_media"),
#'   cuts = c("ano", "sg_uf", "etapa"),
#'   fonte = "ideb"
#' )
#' executar_regressao(con, espec)
#' }
#'
#' @export
executar_regressao <- function(con, espec, dados = NULL) {
  if (!inherits(espec, "eduBR_espec")) {
    stop(
      "`espec` deve ser criado por especificar_regressao() ou ler_espec().",
      call. = FALSE
    )
  }
  rlang::check_installed(
    c("parsnip", "broom", "tidyr", "purrr"),
    reason = "para executar as regressoes"
  )

  dados_tbl <- eduBR_espec_tbl(con, espec, dados)

  por <- espec$cuts
  if (is.null(por)) {
    por <- character(0)
  }

  # Projeta apenas o necessario antes de materializar (pushdown no SQL).
  cols <- unique(c(espec$outcome, espec$predictors, por))
  dados_tbl <- dados_tbl |>
    dplyr::select(dplyr::all_of(cols)) |>
    dplyr::collect()

  modelar <- setdiff(names(dados_tbl), por)
  formula <- stats::reformulate(espec$predictors, response = espec$outcome)

  ajustado <- tidyr::nest(dados_tbl, data = dplyr::all_of(modelar)) |>
    dplyr::mutate(
      resultado = purrr::map(
        .data$data, ~ eduBR_espec_fit(.x, espec, formula)
      ),
      n = purrr::map_int(.data$resultado, "n"),
      modelo = purrr::map(.data$resultado, "modelo"),
      coeficientes = purrr::map(
        .data$modelo, ~ if (is.null(.x)) NULL else broom::tidy(.x)
      ),
      metricas = purrr::map2(
        .data$modelo, .data$data,
        ~ if (is.null(.x)) NULL else eduBR_glance(.x, .y, espec)
      ),
      predicoes = purrr::map2(
        .data$modelo, .data$data,
        ~ if (is.null(.x)) {
          tibble::tibble()
        } else {
          broom::augment(.x, new_data = .y)
        }
      )
    ) |>
    dplyr::select(-dplyr::all_of(c("resultado", "data")))

  structure(ajustado, class = c("eduBR_regressoes", class(ajustado)))
}

#' @export
print.eduBR_regressoes <- function(x, ...) {
  chaves <- setdiff(
    names(x),
    c("modelo", "coeficientes", "metricas", "predicoes", "n")
  )
  r2 <- purrr::map_dbl(
    x$metricas,
    function(m) {
      if (is.null(m) || is.null(m$r.squared)) NA_real_ else m$r.squared
    }
  )
  resumo <- tibble::as_tibble(x)[c(chaves, "n")]
  resumo$r2 <- r2

  cat("<eduBR_regressoes>\n")
  print(resumo)
  invisible(x)
}
