# R/dicionario.R
#
# Dicionário das variáveis categóricas do Censo Escolar usadas no pacote:
# códigos numéricos -> rótulos em PT-BR. Serve para leitura de saídas
# (ex.: apêndice de reports) e para rotular colunas após o `collect`
# sem decorar os códigos.

#' Dicionário das categóricas do Censo
#'
#' Devolve a tabela código → rótulo das variáveis categóricas do Censo
#' Escolar cobertas pelo pacote: `tp_dependencia` (rede),
#' `tp_categoria_escola_privada` e `tp_localizacao`. Os mesmos rótulos são
#' usados nas colunas `rede`/`categoria_privada`/`localizacao` derivadas por
#' [gestores()] e [docentes_rede()].
#'
#' @return Um `tibble` com as colunas `variavel`, `codigo` (inteiro) e
#'   `rotulo`.
#'
#' @examples
#' dicionario()
#'
#' @export
dicionario <- function() {
  lab <- eduBR_rotulos()
  vars <- c(
    rede = "tp_dependencia",
    categoria_privada = "tp_categoria_escola_privada",
    localizacao = "tp_localizacao"
  )
  tibble::tibble(
    variavel = rep(unname(vars), times = lengths(lab[names(vars)])),
    codigo = unlist(lapply(lab[names(vars)], function(x) as.integer(names(x)))),
    rotulo = unname(unlist(lab[names(vars)]))
  )
}

# Coluna do Censo -> coluna de rótulo criada por rotular().
eduBR_colunas_rotulo <- function() {
  c(
    tp_dependencia = "rede",
    tp_categoria_escola_privada = "categoria_privada",
    tp_localizacao = "localizacao"
  )
}

#' Rotula códigos do Censo após o `collect`
#'
#' Aplica os rótulos de [dicionario()] às colunas de código presentes no
#' `data.frame` (`tp_dependencia` → `rede`,
#' `tp_categoria_escola_privada` → `categoria_privada`,
#' `tp_localizacao` → `localizacao`), sem remover as originais. Os mesmos
#' rótulos das colunas derivadas no SQL por [gestores()] e [docentes_rede()].
#'
#' @param dados Um `data.frame` (em geral materializado com [coletar()]).
#'
#' @return Um `tibble` com as colunas de rótulo adicionadas.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' censo_escolar(con) |> coletar(n = 10) |> rotular()
#' }
#'
#' @export
rotular <- function(dados) {
  if (!is.data.frame(dados)) {
    stop("`dados` deve ser um data.frame.", call. = FALSE)
  }
  df <- tibble::as_tibble(dados)
  dic <- dicionario()
  mapa <- eduBR_colunas_rotulo()
  for (col in names(mapa)) {
    if (!col %in% names(df) || mapa[[col]] %in% names(df)) {
      next
    }
    sub <- dic[dic$variavel == col, , drop = FALSE]
    df[[mapa[[col]]]] <- sub$rotulo[match(as.integer(df[[col]]), sub$codigo)]
  }
  df
}
