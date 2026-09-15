test_that("conecta() usa 'edumaps' por padrao", {
  visto <- NULL
  local_mocked_bindings(
    eduBR_dbConnect = function(service, ...) {
      visto <<- service
      structure(list(), class = "fake_con")
    }
  )

  con <- conecta()

  expect_equal(visto, "edumaps")
  expect_s3_class(con, "fake_con")
})

test_that("conecta() respeita o service informado", {
  visto <- NULL
  local_mocked_bindings(
    eduBR_dbConnect = function(service, ...) {
      visto <<- service
      structure(list(), class = "fake_con")
    }
  )

  conecta(service = "edumaps_local")

  expect_equal(visto, "edumaps_local")
})

test_that("conecta() rejeita service invalido", {
  expect_error(conecta(service = ""), "service")
  expect_error(conecta(service = NA_character_), "service")
  expect_error(conecta(service = c("a", "b")), "service")
})
