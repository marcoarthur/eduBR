# R/regressao_inse.R
#
# Regressao transversal do desempenho escolar sobre o INSE, por macrorregiao
# e etapa. Como o INSE so existe em 2023, o modelo e um corte transversal
# daquele ano (nao ha dimensao temporal).

#' Regressao do IDEB sobre o INSE por regiao
#'
#' Ajusta, para cada macrorregiao e etapa, uma regressao linear simples do
#' IDEB observado sobre o INSE medio da escola
#' (`ideb_observado ~ media_inse`), no nivel da escola. Usa apenas as escolas
#' que possuem INSE (corte de 2023, apenas publicas). O modelo e ajustado com
#' o `parsnip`.
#'
#' @param con Conexao criada por [conecta()].
#' @param etapa Filtro opcional pela etapa.
#' @param rede Filtro opcional pela rede.
#'
#' @return Um `tibble` de classe `eduBR_regressao_inse`, com uma linha por
#'   regiao x etapa e as colunas `nome_regiao`, `sigla_regiao`, `etapa`,
#'   `n_escolas`, `data`, `modelo`, `coeficientes`, `metricas` e `predicoes`
#'   (as tres ultimas sao list-columns; achate com `tidyr::unnest()`).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' regressao_inse(con)
#' regressao_inse(con, etapa = "fundamental_ii", rede = "Municipal")
#' }
#'
#' @export
regressao_inse <- function(con, etapa = NULL, rede = NULL) {
  rlang::check_installed(
    c("parsnip", "broom", "tidyr", "purrr"),
    reason = "para ajustar as regressoes de INSE"
  )

  dados <- consulta(ideb_inse(con, etapa = etapa, rede = rede)) |>
    dplyr::select(dplyr::all_of(c(
      "nome_regiao", "sigla_regiao", "etapa", "media_inse", "ideb_observado"
    ))) |>
    dplyr::filter(
      !is.na(.data$media_inse), !is.na(.data$ideb_observado)
    ) |>
    dplyr::collect()

  ajustado <- dados |>
    tidyr::nest(data = dplyr::all_of(c("media_inse", "ideb_observado"))) |>
    dplyr::mutate(
      n_escolas = purrr::map_int(.data$data, nrow),
      modelo = purrr::map(
        .data$data,
        ~ parsnip::fit(
          parsnip::linear_reg(), ideb_observado ~ media_inse, data = .x
        )
      ),
      coeficientes = purrr::map(.data$modelo, broom::tidy),
      metricas = purrr::map(.data$modelo, broom::glance),
      predicoes = purrr::map2(
        .data$modelo, .data$data,
        ~ broom::augment(.x, new_data = .y)
      )
    )

  structure(ajustado, class = c("eduBR_regressao_inse", class(ajustado)))
}

#' @export
print.eduBR_regressao_inse <- function(x, ...) {
  inclinacao <- purrr::map_dbl(
    x$coeficientes,
    function(cf) cf$estimate[cf$term == "media_inse"]
  )
  r2 <- purrr::map_dbl(x$metricas, function(m) m$r.squared)

  resumo <- tibble::tibble(
    nome_regiao  = x$nome_regiao,
    sigla_regiao = x$sigla_regiao,
    etapa        = x$etapa,
    n_escolas    = x$n_escolas,
    inclinacao   = inclinacao,
    r2           = r2
  )

  cat("<eduBR_regressao_inse>\n")
  print(resumo)
  invisible(x)
}
