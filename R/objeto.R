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

#' Exibe um objeto eduBR
#'
#' Mostra o domínio, a descrição, o número de colunas e uma prévia de `n`
#' linhas, sem SQL nem dados de conexão (host/usuário). Códigos do Censo
#' presentes na prévia aparecem com rótulos em PT-BR (ver [rotular()]). Só
#' as `n` linhas da prévia são buscadas no banco.
#'
#' @param x Um objeto `eduBR`.
#' @param n Linhas da prévia (padrão `5`; `0` omite a prévia).
#' @param ... Não utilizado.
#' @return `x`, invisível.
#' @export
print.eduBR <- function(x, n = 5L, ...) {
  cat(sprintf("<%s>", class(x)[1]))
  if (!is.null(x$meta$descricao)) {
    cat(" ", x$meta$descricao, sep = "")
  }
  cat("\n")
  cat(sprintf("%d colunas\n", length(colnames(x$tbl))))

  vazio <- FALSE
  if (is.numeric(n) && length(n) == 1L && !is.na(n) && n >= 1) {
    previa <- tryCatch(coletar(x, n = n), error = function(e) NULL)
    if (is.null(previa)) {
      cat("(pr\u00e9via indispon\u00edvel: falha ao consultar o banco)\n")
    } else if (nrow(previa) == 0L) {
      cat("Nenhuma linha encontrada.\n")
      vazio <- TRUE
    } else {
      cat(sprintf(
        "Pr\u00e9via (%d %s):\n", nrow(previa),
        if (nrow(previa) == 1L) "linha" else "linhas"
      ))
      print(eduBR_previa(previa), n = n)
    }
  }
  if (eduBR_lazy(x$tbl) && !vazio) {
    cat("Dados ainda no banco: use coletar(x, n = ...) para baixar.\n")
  }
  invisible(x)
}

# Prévia legível: troca as colunas de código do Censo pelos rótulos, na
# mesma posição (ex.: tp_dependencia -> rede).
eduBR_previa <- function(df) {
  df <- rotular(df)
  mapa <- eduBR_colunas_rotulo()
  for (col in intersect(names(mapa), names(df))) {
    novo <- mapa[[col]]
    if (!novo %in% names(df)) {
      next
    }
    df[[col]] <- df[[novo]]
    df[[novo]] <- NULL
    names(df)[names(df) == col] <- novo
  }
  df
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
