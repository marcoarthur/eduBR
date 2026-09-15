# R/conexao.R

#' Abre uma conexão com a base do EduMaps
#'
#' Cria uma conexão PostgreSQL usando o driver `RPostgres` a partir de um
#' *service* do libpq (arquivo `~/.pg_service.conf`). O uso de `service`
#' mantém host, usuário e senha fora do código e permite alternar entre
#' ambientes — por exemplo, `"edumaps"` (desenvolvimento) ou
#' `"edumaps_local"` (o mesmo serviço visto de dentro da rede dos containers).
#'
#' @param service Nome do serviço no `~/.pg_service.conf`. Por padrão,
#'   `"edumaps"`.
#' @param ... Argumentos adicionais repassados a [DBI::dbConnect()].
#'
#' @return Um objeto `DBIConnection` (S4 do `RPostgres`), pronto para uso com
#'   `DBI`, `dplyr`/`dbplyr` e demais pacotes compatíveis.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' DBI::dbListTables(con)
#' DBI::dbDisconnect(con)
#' }
#'
#' @export
conecta <- function(service = "edumaps", ...) {
  if (!is.character(service) || length(service) != 1L ||
      is.na(service) || !nzchar(service)) {
    stop(
      "`service` deve ser uma string nao vazia (nome do servico em ~/.pg_service.conf).",
      call. = FALSE
    )
  }
  eduBR_dbConnect(service = service, ...)
}

# Indireção interna sobre DBI::dbConnect para permitir teste sem banco.
eduBR_dbConnect <- function(service, ...) {
  DBI::dbConnect(RPostgres::Postgres(), service = service, ...)
}
