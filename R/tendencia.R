# R/tendencia.R
#
# Ajuste da tendencia (regressao linear) do IDEB medio por macrorregiao e
# etapa, usando apenas o historico das avaliacoes (o ano). O objetivo e
# caracterizar a tendencia natural de cada regiao, sem covariarias.

#' Tendencia do IDEB por regiao
#'
#' Ajusta, para cada macrorregiao e etapa, uma regressao linear simples do
#' IDEB medio sobre o ano da avaliacao (`ideb_medio ~ ano`). O IDEB medio por
#' regiao/ano/etapa e calculado no banco (a consulta e agregada antes de ser
#' materializada) e o modelo e ajustado com o `parsnip`.
#'
#' @param con Conexao criada por [conecta()].
#' @param etapa Filtro opcional pela etapa.
#' @param rede Filtro opcional pela rede.
#'
#' @return Um `tibble` de classe `eduBR_tendencia`, com uma linha por
#'   regiao x etapa e as colunas `nome_regiao`, `sigla_regiao`, `etapa`,
#'   `n_anos`, `data`, `modelo`, `coeficientes`, `metricas` e `predicoes`
#'   (as tres ultimas sao list-columns; achate com `tidyr::unnest()`).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' tendencia_regiao(con)
#' tendencia_regiao(con, etapa = "fundamental_ii", rede = "Municipal")
#' }
#'
#' @export
tendencia_regiao <- function(con, etapa = NULL, rede = NULL) {
  rlang::check_installed(
    c("parsnip", "broom", "tidyr", "purrr"),
    reason = "para ajustar as regressoes de tendencia do IDEB"
  )

  dados <- consulta(ideb_regiao(con, etapa = etapa, rede = rede)) |>
    dplyr::group_by(
      .data$nome_regiao, .data$sigla_regiao, .data$etapa, .data$ano
    ) |>
    dplyr::summarise(
      ideb_medio = mean(.data$ideb_observado, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::collect()

  ajustado <- dados |>
    tidyr::nest(data = dplyr::all_of(c("ano", "ideb_medio"))) |>
    dplyr::mutate(
      n_anos = purrr::map_int(.data$data, nrow),
      modelo = purrr::map(
        .data$data,
        ~ parsnip::fit(parsnip::linear_reg(), ideb_medio ~ ano, data = .x)
      ),
      coeficientes = purrr::map(.data$modelo, broom::tidy),
      metricas = purrr::map(.data$modelo, broom::glance),
      predicoes = purrr::map2(
        .data$modelo, .data$data,
        ~ broom::augment(.x, new_data = .y)
      )
    )

  structure(ajustado, class = c("eduBR_tendencia", class(ajustado)))
}

#' @export
print.eduBR_tendencia <- function(x, ...) {
  inclinacao <- purrr::map_dbl(
    x$coeficientes,
    function(cf) cf$estimate[cf$term == "ano"]
  )
  r2 <- purrr::map_dbl(x$metricas, function(m) m$r.squared)

  resumo <- tibble::tibble(
    nome_regiao  = x$nome_regiao,
    sigla_regiao = x$sigla_regiao,
    etapa        = x$etapa,
    n_anos       = x$n_anos,
    inclinacao   = inclinacao,
    r2           = r2
  )

  cat("<eduBR_tendencia>\n")
  print(resumo)
  invisible(x)
}
