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
