# R/geo.R
#
# Suporte geoespacial: converte a coluna `geometry` (hex EWKB, SRID 4674)
# em geometria `sf`. A materialização respeita os filtros lazy do objeto;
# a conversão roda em R após o `collect`.

# Hex EWKB -> raw (sf::st_as_sfc não lê hexadecimal direto).
eduBR_hex2raw <- function(h) {
  as.raw(strtoi(substring(h, seq(1L, nchar(h), 2L), seq(2L, nchar(h), 2L)), 16L))
}

#' Objeto eduBR como `sf`
#'
#' Materializa um objeto [eduBR] e converte a coluna de geometria (hex EWKB,
#' SRID 4674 — SIRGAS 2000) em geometria `sf`, permitindo mapas com
#' `ggplot2::geom_sf()` e companhia. Linhas sem geometria (`NA`) viram
#' geometrias vazias (as linhas são mantidas).
#'
#' @param x Um objeto `eduBR` com coluna de geometria.
#' @param geometry Nome da coluna de geometria (padrão `"geometry"`).
#' @param crs CRS aplicado (padrão `4674`, lido do EWKB quando presente).
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
as_sf <- function(x, geometry = "geometry", crs = 4674) {
  UseMethod("as_sf")
}

#' @export
# Indireção para permitir teste sem banco e sem o pacote `sf`.
eduBR_tem_sf <- function() {
  requireNamespace("sf", quietly = TRUE)
}

as_sf.eduBR <- function(x, geometry = "geometry", crs = 4674) {
  if (!eduBR_tem_sf()) {
    stop(
      "as_sf() exige o pacote `sf` (instale com install.packages(\"sf\")).",
      call. = FALSE
    )
  }
  df <- tibble::as_tibble(coletar(x, avisar = TRUE))
  if (!geometry %in% names(df)) {
    stop(
      sprintf("coluna de geometria inexistente: '%s'.", geometry),
      call. = FALSE
    )
  }
  hex <- as.character(df[[geometry]])
  geoms <- lapply(hex, function(h) {
    if (is.na(h) || !nzchar(h)) {
      sf::st_point()
    } else {
      sf::st_as_sfc(list(eduBR_hex2raw(h)), EWKB = TRUE)[[1L]]
    }
  })
  df[[geometry]] <- sf::st_sfc(geoms, crs = crs)
  sf::st_sf(df)
}
