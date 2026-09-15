#' eduBR: acesso de alto nível a dados educacionais brasileiros
#'
#' O pacote `eduBR` oferece conexão e objetos de domínio (S3) para a base
#' pública do EduMaps — Censo Escolar, IDEB, IBGE e OpenStreetMap —
#' armazenada em PostgreSQL. A ideia é que o usuário trabalhe com conceitos
#' do domínio (`escola`, `municipio`, `rede`, `indicador`, ...) sem precisar
#' conhecer os nomes físicos de schema e tabela.
#'
#' @section Conexão:
#' Use [conecta()] para abrir a conexão a partir de um *service* do libpq
#' (`~/.pg_service.conf`):
#'
#' ```r
#' con <- conecta(service = "edumaps")
#' ```
#'
#' @section Objetos de domínio:
#' As funções de acesso devolvem objetos S3 (classe `eduBR`) com consulta
#' preguiçosa. Materialize com [as_tibble()] ou inspecione o SQL com
#' [consulta()]: `escolas()`, `escola()`, `municipios()`, `municipio()`,
#' `redes()`, `indicadores()`, `scores()`, `censo_escolar()`,
#' `censo_docentes()`, `censo_matriculas()`, `ideb()`, `clusters()` e
#' `municipios_similares()`.
#'
#' @importFrom rlang .data .env
#' @keywords internal
"_PACKAGE"
