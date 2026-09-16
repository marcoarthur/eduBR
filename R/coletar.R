# R/coletar.R
#
# Materializacao controlada: evita o "collect tudo" implicito de as_tibble()
# ao permitir limitar as linhas antes de coletar.

# Um tbl remoto (dbplyr)? Fatorado para permitir teste sem banco.
eduBR_lazy <- function(x) inherits(x, "tbl_sql")

#' Coleta um objeto eduBR ou uma consulta lazy
#'
#' Materializa um objeto eduBR ou um `tbl` lazy (dbplyr) como `tibble`. Com
#' `n`, aplica um `LIMIT` (via `head()`) antes de coletar; sem `n`, emite um
#' aviso de custo quando a consulta é remota.
#'
#' @param x Objeto eduBR ou `tbl` lazy.
#' @param n Número máximo de linhas (opcional). Sem `n`, materializa tudo.
#' @param avisar Emitir aviso quando `n` é `NULL` e a consulta é remota?
#'   Padrão `TRUE`.
#'
#' @return Um `tibble`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' coletar(escolas(con, uf = "SP"), n = 100)
#' coletar(escolas(con, uf = "SP"))            # aviso de custo
#' }
#'
#' @export
coletar <- function(x, n = NULL, avisar = TRUE) {
  tb <- if (inherits(x, "eduBR")) consulta(x) else x
  remoto <- eduBR_lazy(tb)

  if (!is.null(n)) {
    if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1) {
      stop("`n` deve ser um inteiro positivo.", call. = FALSE)
    }
    tb <- utils::head(tb, as.integer(n))
  } else if (remoto && isTRUE(avisar)) {
    warning(
      "Materializando a consulta sem limite; use `n =` ou filtre antes.",
      call. = FALSE
    )
  }

  if (remoto) dplyr::collect(tb) else tibble::as_tibble(tb)
}
