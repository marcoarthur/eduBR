test_that("coletar() limita as linhas com n", {
  d <- tibble::tibble(a = 1:10)

  expect_equal(nrow(coletar(d, n = 3)), 3L)
  expect_error(coletar(d, n = 0), "n")
  expect_error(coletar(d, n = -1), "n")
  expect_error(coletar(d, n = NA), "n")
})

test_that("coletar() aceita objeto eduBR", {
  obj <- structure(
    list(tbl = tibble::tibble(a = 1:5), con = NULL, meta = list()),
    class = c("eduBR_escola", "eduBR")
  )

  expect_equal(nrow(coletar(obj, n = 2)), 2L)
  expect_silent(coletar(obj, n = 2))
})

test_that("coletar() avisa quando remoto e sem n", {
  local_mocked_bindings(eduBR_lazy = function(x) TRUE)
  d <- tibble::tibble(a = 1:3)

  expect_warning(coletar(d), "limite")
  expect_silent(coletar(d, n = 2))
  expect_silent(coletar(d, avisar = FALSE))
})
