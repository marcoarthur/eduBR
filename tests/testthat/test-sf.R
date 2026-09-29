# as_sf(): hex EWKB (ponto SP) + NA. Pula sem o pacote `sf`.

PT_SP <- "01010000204212000083FAB747C68241C0C39F953FD5F21CC0"

fake_geo_tbl <- function(con, nome) {
  if (nome != "escolas") {
    stop(sprintf("fixture inesperada: %s", nome))
  }
  tibble::tibble(
    codigo_inep = c("1", "2"),
    escola = c("A", "B"),
    geometry = c(PT_SP, NA_character_)
  )
}

test_that("as_sf() converte hex EWKB em POINT 4674", {
  testthat::skip_if_not_installed("sf")
  local_mocked_bindings(eduBR_tbl = fake_geo_tbl)

  s <- as_sf(escolas("fake_con"))

  expect_s3_class(s, "sf")
  expect_equal(as.character(sf::st_geometry_type(s, by_geometry = FALSE)), "POINT")
  expect_equal(sf::st_crs(s)$epsg, 4674)
  expect_equal(nrow(s), 2L)
  expect_true(sf::st_is_empty(s$geometry[[2L]]))
  xy <- sf::st_coordinates(s)
  expect_true(all(is.finite(xy[1L, ])))
})

test_that("as_sf() erro sem coluna de geometria", {
  testthat::skip_if_not_installed("sf")
  local_mocked_bindings(
    eduBR_tbl = function(con, nome) tibble::tibble(codigo_inep = "1")
  )

  expect_error(as_sf(escolas("fake_con")), "geometria inexistente")
})

test_that("as_sf() erro amigavel sem o pacote sf", {
  local_mocked_bindings(
    eduBR_tbl = fake_geo_tbl,
    eduBR_tem_sf = function() FALSE
  )

  expect_error(as_sf(escolas("fake_con")), "exige o pacote")
})
