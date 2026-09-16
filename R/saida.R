# R/saida.R
#
# Helpers para achatar os resultados de executar_regressao().

#' Coeficientes das regressões executadas
#'
#' Achata a list-column `coeficientes` de um objeto [executar_regressao()],
#' repetindo as colunas de corte em cada coeficiente.
#'
#' @param x Objeto `eduBR_regressoes`.
#'
#' @return Um `tibble` com as colunas de corte e as colunas dos coeficientes
#'   (`term`, `estimate`, `std.error`, ...).
#'
#' @export
coeficientes <- function(x) {
  if (!inherits(x, "eduBR_regressoes")) {
    stop("`x` deve ser um objeto devolvido por executar_regressao().",
         call. = FALSE)
  }
  rlang::check_installed(c("tidyr", "purrr"), reason = "para achatar coeficientes")
  tidyr::unnest(x, "coeficientes")
}

#' Métricas das regressões executadas
#'
#' Achata a list-column `metricas` de um objeto [executar_regressao()].
#'
#' @param x Objeto `eduBR_regressoes`.
#'
#' @return Um `tibble` com as colunas de corte e as métricas do modelo
#'   (`r.squared`, `p.value`, `nobs`, ...).
#'
#' @export
metricas <- function(x) {
  if (!inherits(x, "eduBR_regressoes")) {
    stop("`x` deve ser um objeto devolvido por executar_regressao().",
         call. = FALSE)
  }
  rlang::check_installed(c("tidyr", "purrr"), reason = "para achatar metricas")
  tidyr::unnest(x, "metricas")
}
