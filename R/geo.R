# R/geo.R
#
# Suporte geoespacial: converte a coluna `geometry` (hex EWKB, SRID 4674)
# em geometria `sf`. A materialização respeita os filtros lazy do objeto;
# a conversão (vetorizada, pelo próprio `sf`) roda em R após o `collect`.

#' Objeto eduBR como `sf`
#'
#' Materializa um objeto [eduBR] e converte a coluna de geometria (hex EWKB,
#' SRID 4674 — SIRGAS 2000) em geometria `sf`, permitindo mapas com
#' `ggplot2::geom_sf()` e companhia. Linhas sem geometria (`NA`) viram
#' geometrias vazias (as linhas são mantidas) e uma mensagem informa
#' quantas são. Pedir o `sf` já é pedir a materialização, então não há
#' aviso de custo; use `n` para limitar.
#'
#' Nas escolas ([escolas()]), a falta de geometria vem da fonte: cerca de
#' 19% das escolas ativas do Censo Escolar 2025 não têm coordenada (24% na
#' zona rural; 65% no AC).
#'
#' @param x Um objeto `eduBR` com coluna de geometria.
#' @param geometry Nome da coluna de geometria (padrão `"geometry"`).
#' @param crs CRS aplicado (padrão `4674`, lido do EWKB quando presente).
#' @param n Opcional: número máximo de linhas a materializar (`LIMIT`).
#'
#' @return Um `sf` (`data.frame` com coluna `sfc` ativa).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' mapa <- as_sf(escolas(con, uf = "AC"))
#' ggplot2::ggplot(mapa) + ggplot2::geom_sf()
#' }
#'
#' @export
as_sf <- function(x, geometry = "geometry", crs = 4674, n = NULL) {
  UseMethod("as_sf")
}

# Indireção para permitir teste sem banco e sem o pacote `sf`.
eduBR_tem_sf <- function() {
  requireNamespace("sf", quietly = TRUE)
}

#' @export
as_sf.eduBR <- function(x, geometry = "geometry", crs = 4674, n = NULL) {
  if (!eduBR_tem_sf()) {
    stop(
      "as_sf() exige o pacote `sf` (instale com install.packages(\"sf\")).",
      call. = FALSE
    )
  }
  df <- tibble::as_tibble(coletar(x, n = n, avisar = FALSE))
  if (!geometry %in% names(df)) {
    stop(
      sprintf("coluna de geometria inexistente: '%s'.", geometry),
      call. = FALSE
    )
  }
  hex <- as.character(df[[geometry]])
  ok <- !is.na(hex) & nzchar(hex)
  geoms <- rep(list(sf::st_point()), length(hex))
  if (any(ok)) {
    geoms[ok] <- as.list(
      sf::st_as_sfc(structure(hex[ok], class = "WKB"), EWKB = TRUE)
    )
  }
  df[[geometry]] <- sf::st_sfc(geoms, crs = crs)
  vazias <- sum(!ok)
  if (vazias > 0L) {
    message(sprintf(
      "as_sf(): %d de %d linhas sem geometria (sem coordenada na fonte).",
      vazias, length(ok)
    ))
  }
  sf::st_sf(df)
}
