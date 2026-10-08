# Smoke da camada ellmer contra o banco real [edumaps] (tools de escola).
# Rode com EDUBR_SMOKE=1. Lento (perfil e similares levam ~10 s cada):
# mantenha o número de chamadas pequeno.

skip_if(
  Sys.getenv("EDUBR_SMOKE", "") == "",
  "Defina EDUBR_SMOKE=1 para rodar o smoke test"
)
skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")

# Confere envelope: JSON válido, dentro do cap, sem PII e sem schema.tabela.
smoke_checar <- function(json, cap = 1000L) {
  expect_type(json, "character")
  expect_true(jsonlite::validate(json))
  env <- eduBR_envelope_de(json)
  expect_lte(length(env$dados), cap)
  for (reg in env$dados) {
    expect_false(any(names(reg) %in% c(eduBR_colunas_pii(), "geometry", "geom")))
  }
  rel <- eduBR_relacoes_fisicas()
  for (i in seq_len(nrow(rel))) {
    expect_false(grepl(paste0(rel$schema[i], ".", rel$tabela[i]), json,
                       fixed = TRUE))
  }
  expect_false(grepl("clean.", json, fixed = TRUE))
  expect_false(grepl("analytics.", json, fixed = TRUE))
  env
}

test_that("tools de escola respondem no banco real (13078070, 26106582)", {
  con <- conecta(service = "edumaps")
  withr::defer(DBI::dbDisconnect(con))
  tools <- ferramentas_edubr(con, limites = list(timeout_s = 120))
  id <- "13078070"

  env <- smoke_checar(tools$perfil_escola(escola_id = id))
  expect_null(env$erro)
  expect_gt(length(env$dados), 0L)
  ctx <- env$metadados$contexto
  expect_equal(ctx$codigo_inep, id)
  expect_equal(ctx$uf, "AM")
  expect_false(is.null(ctx$nome))

  env <- smoke_checar(tools$resumo_escola(escola_id = id))
  expect_null(env$erro)
  expect_length(env$dados, 1L)

  env <- smoke_checar(tools$serie_ideb_escola(escola_id = id))
  expect_null(env$erro)
  expect_gt(length(env$dados), 0L)

  env <- smoke_checar(tools$escolas_similares(escola_id = id, n = 3L))
  expect_null(env$erro)
  expect_length(env$dados, 3L)
  nomes <- vapply(env$dados, function(r) r$escola %||% NA_character_,
                  character(1))
  expect_false(anyNA(nomes))
  expect_false(id %in% vapply(env$dados, `[[`, character(1), "co_entidade"))

  env <- smoke_checar(tools$scores_escola(escola_id = id))
  expect_null(env$erro)

  env <- smoke_checar(tools$indicadores_escola(escola_id = id))
  expect_equal(env$erro$tipo, "sem_dados")

  # Abreu e Lima/PE: IDEB de ensino médio, mas não oferta médio no Censo 2025
  env <- smoke_checar(tools$perfil_escola(escola_id = "26106582"))
  expect_null(env$erro)
  itens <- vapply(env$dados, `[[`, character(1), "item")
  medio <- env$dados[grepl("^IDEB m", itens)]
  expect_length(medio, 1L)
  expect_false(medio[[1]]$ofertada)

  led <- ledger(tools)
  expect_equal(nrow(led), 7L)
  message(paste(sprintf("%s: %.1f s", led$tool, led$duracao_ms / 1000),
                collapse = "; "))
})
