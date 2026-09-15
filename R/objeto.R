# R/objeto.R
#
# Base comum dos objetos de domínio do eduBR. Todo objeto é uma lista com
# `tbl` (consulta preguiçosa via dbplyr), `con` (a conexão) e `meta`
# (descrição/filtros aplicados), com classe S3 `c("<dominio>", "eduBR")`.
# Os métodos genéricos (print/summary/as_tibble/consulta/conexao) são
# registrados uma única vez em `eduBR`.

# Construtor interno compartilhado.
new_eduBR <- function(tbl, classe, con = NULL, meta = list()) {
  structure(
    list(tbl = tbl, con = con, meta = meta),
    class = c(classe, "eduBR")
  )
}

#' Consulta preguiçosa de um objeto eduBR
#'
#' Devolve o objeto de consulta subjacente (`tbl` do `dbplyr`), permitindo
#' encadear operações `dplyr` sem materializar os dados.
#'
#' @param x Um objeto `eduBR`.
#' @return Um `tbl` do `dbplyr`.
#' @export
consulta <- function(x) {
  UseMethod("consulta")
}

#' @export
consulta.eduBR <- function(x) {
  x$tbl
}

#' Conexão associada a um objeto eduBR
#'
#' @param x Um objeto `eduBR`.
#' @return A conexão `DBI` usada para criar o objeto.
#' @export
conexao <- function(x) {
  UseMethod("conexao")
}

#' @export
conexao.eduBR <- function(x) {
  x$con
}

#' Materializa um objeto eduBR como tibble
#'
#' Executa a consulta preguiçosa e devolve um `tibble` com o resultado.
#'
#' @param x Um objeto `eduBR`.
#' @param ... Não utilizado.
#' @return Um `tibble`.
#' @importFrom tibble as_tibble
#' @export
as_tibble.eduBR <- function(x, ...) {
  if (inherits(x$tbl, "tbl_sql")) {
    dplyr::collect(x$tbl)
  } else {
    tibble::as_tibble(x$tbl)
  }
}

#' @export
print.eduBR <- function(x, ...) {
  cat(sprintf("<%s>\n", class(x)[1]))
  if (!is.null(x$meta$descricao)) {
    cat(" ", x$meta$descricao, "\n", sep = "")
  }
  if (inherits(x$tbl, "tbl_sql")) {
    print(x$tbl)
  } else {
    print(tibble::as_tibble(x$tbl))
  }
  invisible(x)
}

#' @export
summary.eduBR <- function(object, ...) {
  dados <- as_tibble(object)
  list(
    classe  = class(object)[1],
    linhas  = nrow(dados),
    colunas = ncol(dados),
    meta    = object$meta
  )
}
