# Tools da pesquisadora na camada ellmer (chunk 3): contrato, enums e
# validação antes do banco, achatamento da tendência, handle lazy de
# covariáveis, sem geometria/schema.tabela e filtro por persona. Sem banco:
# funções do pacote mockadas com fixtures em memória.

skip_if_not_installed("ellmer")
skip_if_not_installed("jsonlite")

tools_pesquisa <- c("municipios", "redes_municipio", "docentes_rede", "ideb",
                    "tendencia_ideb_regiao", "covariaveis_escola",
                    "perfil_gestor")

chamar_json <- function(tool, ...) {
  json <- tool(...)
  expect_type(json, "character")
  expect_length(json, 1L)
  expect_true(jsonlite::validate(json))
  list(json = json, env = eduBR_envelope_de(json))
}

expect_sem_vazamento <- function(json, env) {
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
}

test_that("contrato: tools da pesquisadora registradas com argumentos", {
  tools <- ferramentas_edubr("fake_con")
  expect_true(all(tools_pesquisa %in% names(tools)))
  for (nm in tools_pesquisa) {
    expect_true(inherits(tools[[nm]], "ellmer::ToolDef"))
    expect_identical(tools[[nm]]@name, nm)
    expect_gt(nchar(tools[[nm]]@description), 300L)
  }
  args <- function(nm) names(formals(tools[[nm]]))
  expect_identical(args("municipios"), c("uf", "n"))
  expect_identical(args("redes_municipio"), c("uf", "regiao", "rede", "n"))
  expect_identical(args("docentes_rede"),
                   c("nivel", "uf", "regiao", "rede", "localizacao", "ano",
                     "colunas", "n"))
  expect_identical(args("ideb"),
                   c("uf", "municipio", "etapa", "rede", "ano", "n"))
  expect_identical(args("tendencia_ideb_regiao"), c("etapa", "rede"))
  expect_identical(args("covariaveis_escola"),
                   c("uf", "rede", "ano", "ano_ideb", "ativas", "n"))
  expect_identical(args("perfil_gestor"),
                   c("corte", "unidade", "rede", "uf", "regiao", "localizacao",
                     "n"))
})

test_that("enums: UF (27), região do pacote, rede, etapa, corte, nível", {
  expect_length(eduBR_ufs(), 27L)
  expect_false(anyDuplicated(eduBR_ufs()) > 0L)
  reg <- eduBR_regioes()
  expect_setequal(reg$nomes,
                  c("Norte", "Nordeste", "Sudeste", "Sul", "Centro-oeste"))
  expect_setequal(reg$siglas, c("N", "NE", "SE", "S", "CO"))

  tools <- ferramentas_edubr("fake_con")
  valores <- function(tool, arg) tools[[tool]]@arguments@properties[[arg]]@values
  expect_setequal(valores("municipios", "uf"), eduBR_ufs())
  expect_setequal(valores("redes_municipio", "regiao"),
                  c(reg$nomes, reg$siglas))
  expect_setequal(valores("redes_municipio", "rede"),
                  c("Federal", "Estadual", "Municipal", "Privada", "publica"))
  expect_setequal(valores("ideb", "rede"),
                  c("Federal", "Estadual", "Municipal", "Privada"))
  expect_setequal(valores("ideb", "etapa"),
                  c("fundamental_i", "fundamental_ii", "ensino_medio"))
  expect_setequal(valores("perfil_gestor", "corte"),
                  c("brasil", "rede", "regiao", "uf", "categoria_privada"))
  expect_setequal(valores("docentes_rede", "nivel"),
                  c("municipio", "uf", "regiao", "brasil"))
  expect_setequal(valores("docentes_rede", "localizacao"),
                  c("urbana", "rural"))
  # Os rótulos dos enums são aceitos pelos tradutores do pacote.
  expect_setequal(eduBR_codigos_rede(eduBR_redes_tool(publica = TRUE)), 1:4)
  expect_identical(
    vapply(eduBR_localizacoes_tool(), eduBR_codigos_localizacao, integer(1),
           USE.NAMES = FALSE),
    c(1L, 2L)
  )
})

test_that("validação: parametro_invalido sem chegar ao pacote", {
  chamadas <- 0L
  conta <- function(...) {
    chamadas <<- chamadas + 1L
    stop("não deveria ser chamada")
  }
  local_mocked_bindings(
    municipios = conta, rede_municipio = conta, docentes_rede = conta,
    ideb = conta, tendencia_regiao = conta, covariaveis_escola = conta,
    gestores = conta, perfil_gestor = conta
  )
  tools <- ferramentas_edubr("fake_con")

  casos <- list(
    list(tools$municipios, list(uf = "XX"), "`uf`"),
    list(tools$municipios, list(uf = "sp"), "SP"),
    list(tools$municipios, list(n = 0L), "`n`"),
    list(tools$redes_municipio, list(regiao = "Centro-Oeste"), "Centro-oeste"),
    list(tools$redes_municipio, list(rede = "municipal"), "Municipal"),
    list(tools$docentes_rede, list(nivel = "estado"), "`nivel`"),
    list(tools$docentes_rede, list(localizacao = "Urbana"), "urbana"),
    list(tools$docentes_rede, list(colunas = c("qt_doc_bas", "qt_doc_xyz")),
         "qt_doc_xyz"),
    list(tools$docentes_rede, list(colunas = character(0)), "`colunas`"),
    list(tools$docentes_rede, list(ano = "2025"), "`ano`"),
    list(tools$ideb, list(), "ao menos um filtro"),
    list(tools$ideb, list(n = 10L), "ao menos um filtro"),
    list(tools$ideb, list(ano = 2024L), "bienal"),
    list(tools$ideb, list(uf = "SP", rede = "publica"), "`rede`"),
    list(tools$ideb, list(etapa = "medio"), "ensino_medio"),
    list(tools$tendencia_ideb_regiao, list(rede = "privada"), "`rede`"),
    list(tools$covariaveis_escola, list(ano_ideb = 2022L), "ano_ideb"),
    list(tools$covariaveis_escola, list(ativas = "sim"), "ativas"),
    list(tools$perfil_gestor, list(corte = "municipio"), "`corte`"),
    list(tools$perfil_gestor, list(unidade = "docente"), "`unidade`"),
    list(tools$perfil_gestor,
         list(corte = "categoria_privada", rede = "Municipal"), "privadas")
  )
  for (cs in casos) {
    r <- chamar_json(function() do.call(cs[[1]], cs[[2]]))
    expect_equal(r$env$erro$tipo, "parametro_invalido", info = cs[[3]])
    expect_match(r$env$erro$mensagem, cs[[3]], fixed = TRUE)
    expect_length(r$env$dados, 0L)
  }
  expect_equal(chamadas, 0L)
  expect_true(all(ledger(tools)$erro == "parametro_invalido"))
})

test_that("municipios: sem geometria, chave em texto, uf repassada", {
  recebido <- "nada"
  fake_mun <- function(con, uf = NULL) {
    recebido <<- uf
    d <- tibble::tibble(
      id_original = c(33, 63), codigo_ibge = c("3543303", "3532801"),
      nome = c("Ribeirão Pires", "Nova Aliança"), sigla_estado = "SP",
      area_km2 = c(99.1, 217.3), geometry = c("POLYGON(...)", "POLYGON(...)"),
      geometria_corrigida = FALSE
    )
    new_eduBR(d, "eduBR_municipio", con, list())
  }
  local_mocked_bindings(municipios = fake_mun)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$municipios, uf = "SP")
  expect_null(r$env$erro)
  expect_sem_vazamento(r$json, r$env)
  expect_equal(recebido, "SP")
  expect_false(grepl("POLYGON", r$json, fixed = TRUE))
  expect_false("geometria_corrigida" %in% names(r$env$dados[[1]]))
  expect_identical(r$env$dados[[1]]$codigo_ibge, "3543303")
  expect_equal(r$env$metadados$grao, "município")
  expect_equal(r$env$metadados$filtros$uf, "SP")

  r <- chamar_json(tools$municipios, n = 1L)
  expect_null(recebido)
  expect_length(r$env$dados, 1L)
  expect_true(r$env$metadados$truncado)
})

test_that("redes_municipio: filtros repassados, NA vira null", {
  recebido <- NULL
  fake_rede <- function(con, uf = NULL, regiao = NULL, rede = NULL) {
    recebido <<- list(uf = uf, regiao = regiao, rede = rede)
    d <- tibble::tibble(
      co_municipio = c("1200013", "1200013"), sg_uf = "AC",
      rede = c("Estadual", "Municipal"), total_matriculas = c(1555, 2010),
      ideb_medio = c(3.4, NA)
    )
    new_eduBR(d, "eduBR_rede", con, list())
  }
  local_mocked_bindings(rede_municipio = fake_rede)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$redes_municipio, regiao = "Centro-oeste",
                   rede = "publica")
  expect_null(r$env$erro)
  expect_sem_vazamento(r$json, r$env)
  expect_equal(recebido, list(uf = NULL, regiao = "Centro-oeste",
                              rede = "publica"))
  expect_null(r$env$dados[[2]]$ideb_medio)
  expect_equal(r$env$metadados$grao, "município × rede")

  r <- chamar_json(tools$redes_municipio, uf = "AC", regiao = "N")
  expect_null(r$env$erro)
  expect_equal(recebido$regiao, "N")
})

test_that("docentes_rede: nível padrão brasil e colunas validadas", {
  recebido <- NULL
  fake_doc <- function(con, ano = 2025L, rede = NULL, uf = NULL, regiao = NULL,
                       localizacao = NULL, nivel = "municipio",
                       colunas = NULL) {
    recebido <<- list(ano = ano, rede = rede, uf = uf, regiao = regiao,
                      localizacao = localizacao, nivel = nivel,
                      colunas = colunas)
    d <- tibble::tibble(rede = c("Estadual", "Municipal"),
                        localizacao = "Urbana", qt_doc_bas = c(10, 20))
    new_eduBR(d, "eduBR_docentes_rede", con, list())
  }
  local_mocked_bindings(docentes_rede = fake_doc)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$docentes_rede)
  expect_null(r$env$erro)
  expect_sem_vazamento(r$json, r$env)
  expect_equal(recebido$nivel, "brasil")
  expect_equal(recebido$ano, 2025L)
  expect_null(recebido$colunas)
  expect_equal(r$env$metadados$grao,
               "rede × localização (Brasil)")

  cols <- c("qt_doc_bas_esco_sup_grad", "qt_doc_bas_vinculo_concur")
  r <- chamar_json(tools$docentes_rede, nivel = "uf", uf = "AC",
                   rede = "Municipal", localizacao = "rural", colunas = cols)
  expect_null(r$env$erro)
  expect_equal(recebido$nivel, "uf")
  expect_equal(recebido$localizacao, "rural")
  expect_equal(recebido$colunas, cols)
  expect_equal(unlist(r$env$metadados$filtros$colunas), cols)

  # ellmer pode entregar o array como lista
  r <- chamar_json(tools$docentes_rede, colunas = as.list(cols))
  expect_null(r$env$erro)
  expect_equal(recebido$colunas, cols)
})

test_that("ideb: exige filtro, repassa argumentos e id_escola em texto", {
  recebido <- NULL
  fake_ideb <- function(con, escola_id = NULL, uf = NULL, municipio = NULL,
                        etapa = NULL, rede = NULL, ano = NULL) {
    recebido <<- list(uf = uf, municipio = municipio, etapa = etapa,
                      rede = rede, ano = ano)
    id <- c(11000011, 11000012, 11000013)
    if (requireNamespace("bit64", quietly = TRUE)) id <- bit64::as.integer64(id)
    d <- tibble::tibble(
      id_escola = id, sg_uf = "SP", no_municipio = "Ubatuba",
      rede = "Municipal", ano = c(2023L, 2021L, 2023L),
      etapa = "fundamental_i", ideb_observado = c(5.0, 4.0, NA)
    )
    new_eduBR(d, "eduBR_ideb", con, list())
  }
  local_mocked_bindings(ideb = fake_ideb)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$ideb, municipio = "Ubatuba", ano = 2023L)
  expect_null(r$env$erro)
  expect_sem_vazamento(r$json, r$env)
  expect_equal(recebido, list(uf = NULL, municipio = "Ubatuba", etapa = NULL,
                              rede = NULL, ano = 2023L))
  expect_match(r$env$metadados$aviso, "homônimos", fixed = TRUE)
  expect_identical(r$env$dados[[1]]$id_escola, "11000012")
  anos <- vapply(r$env$dados, `[[`, integer(1), "ano")
  expect_identical(anos, c(2021L, 2023L, 2023L))
  expect_null(r$env$dados[[3]]$ideb_observado)
  expect_equal(r$env$metadados$grao,
               "escola × etapa × edição do IDEB")

  r <- chamar_json(tools$ideb, uf = "SP", municipio = "Ubatuba",
                   etapa = "fundamental_i", rede = "Municipal")
  expect_null(r$env$erro)
  expect_null(r$env$metadados$aviso)
  expect_equal(recebido$rede, "Municipal")
})

test_that("tendencia_ideb_regiao: coeficientes achatados com r2/nobs", {
  fake_tend <- function(con, etapa = NULL, rede = NULL) {
    cf <- function(b) {
      tibble::tibble(term = c("(Intercept)", "ano"), estimate = c(-200, b),
                     std.error = c(10, 0.01), statistic = c(-20, 10),
                     p.value = c(0.001, 0.002))
    }
    mt <- function(r2, n) tibble::tibble(r.squared = r2, nobs = n)
    tibble::tibble(
      nome_regiao = c("Norte", "Centro-oeste"), sigla_regiao = c("N", "CO"),
      etapa = "fundamental_i", n_anos = c(10L, 4L),
      data = list(
        tibble::tibble(ano = seq(2005L, 2023L, 2L), ideb_medio = 4),
        tibble::tibble(ano = seq(2017L, 2023L, 2L), ideb_medio = 4)
      ),
      modelo = list("m1", "m2"),
      coeficientes = list(cf(0.1), cf(0.05)),
      metricas = list(mt(0.9, 10L), mt(0.6, 4L)),
      predicoes = list(NULL, NULL)
    )
  }
  local_mocked_bindings(tendencia_regiao = fake_tend)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$tendencia_ideb_regiao, etapa = "fundamental_i",
                   rede = "Municipal")
  expect_null(r$env$erro)
  expect_sem_vazamento(r$json, r$env)
  expect_length(r$env$dados, 4L)
  expect_identical(
    names(r$env$dados[[1]]),
    c("nome_regiao", "sigla_regiao", "etapa", "n_anos", "ano_inicial",
      "ano_final", "termo", "estimativa", "erro_padrao", "p_valor", "r2",
      "nobs")
  )
  co <- Filter(function(x) x$sigla_regiao == "CO" && x$termo == "ano",
               r$env$dados)[[1]]
  expect_equal(co$estimativa, 0.05)
  expect_equal(co$r2, 0.6)
  expect_equal(co$nobs, 4L)
  expect_equal(co$ano_inicial, 2017L)
  expect_equal(co$ano_final, 2023L)
  expect_false(grepl("\"modelo\"", r$json, fixed = TRUE))
})

test_that("covariaveis_escola: handle guarda o objeto lazy e devolve prévia", {
  recebido <- NULL
  obj <- NULL
  fake_cov <- function(con, ano = 2025L, ano_ideb = 2023L, uf = NULL,
                       rede = NULL, ativas = TRUE) {
    recebido <<- list(ano = ano, ano_ideb = ano_ideb, uf = uf, rede = rede,
                      ativas = ativas)
    d <- tibble::tibble(
      co_entidade = 12000001 + 0:29, sg_uf = "AC", rede = "Municipal",
      localizacao = "Urbana", in_biblioteca = rep(0:1, 15),
      docentes = 1:30, matriculas = 10 * (1:30),
      ideb_fund_i = c(rep(NA_real_, 10), rep(5, 20))
    )
    obj <<- new_eduBR(d, "eduBR_covariaveis", con, list(ano = ano))
    obj
  }
  local_mocked_bindings(covariaveis_escola = fake_cov)
  tools <- ferramentas_edubr("fake_con")
  sessao <- attr(tools, "sessao")

  r <- chamar_json(tools$covariaveis_escola, uf = "AC", rede = "publica")
  env <- r$env
  expect_null(env$erro)
  expect_sem_vazamento(r$json, env)
  expect_equal(recebido, list(ano = 2025L, ano_ideb = 2023L, uf = "AC",
                              rede = "publica", ativas = TRUE))
  expect_equal(env$metadados$handle, "dados_1")
  expect_length(env$dados, 10L)
  expect_true(env$metadados$truncado)
  expect_match(env$metadados$aviso, "dados_1", fixed = TRUE)
  expect_match(env$metadados$aviso, "especificar_regressao(dados_id = \"dados_1\"",
               fixed = TRUE)
  expect_match(env$metadados$aviso, "IDEB `null`", fixed = TRUE)
  # Contagem no banco: a prévia (10 primeiras) vem toda nula, a base não.
  expect_true(all(vapply(env$dados, function(l) is.null(l$ideb_fund_i),
                         logical(1))))
  expect_match(env$metadados$aviso, "30 escolas; com IDEB: ideb_fund_i = 20",
               fixed = TRUE)
  expect_equal(env$metadados$contexto$n_escolas, 30)
  expect_equal(env$metadados$contexto$n_com_ideb$ideb_fund_i, 20)
  ctx <- env$metadados$contexto
  expect_equal(ctx$handle, "dados_1")
  expect_true(all(c("ideb_fund_i", "docentes", "rede") %in% unlist(ctx$colunas)))
  expect_equal(unlist(ctx$respostas), "ideb_fund_i")
  expect_equal(ctx$edicao_ideb, 2023L)

  # O handle guarda o objeto eduBR inteiro, sem coletar nem truncar.
  guardado <- eduBR_handle_obter(sessao, "dados_1")
  expect_s3_class(guardado, "eduBR")
  expect_identical(guardado, obj)
  expect_equal(nrow(consulta(guardado)), 30L)

  r <- chamar_json(tools$covariaveis_escola, ano_ideb = 2021L, ativas = FALSE,
                   n = 3L)
  expect_equal(r$env$metadados$handle, "dados_2")
  expect_length(r$env$dados, 3L)
  expect_equal(recebido$ano_ideb, 2021L)
  expect_false(recebido$ativas)
})

test_that("perfil_gestor: modal em dados e n por corte no contexto", {
  recebido <- NULL
  fake_gest <- function(con, rede = NULL, uf = NULL, regiao = NULL,
                        localizacao = NULL, ano = 2025) {
    recebido <<- list(rede = rede, uf = uf, regiao = regiao,
                      localizacao = localizacao)
    "gestores_lazy"
  }
  fake_perfil <- function(dados, corte = "rede", unidade = "gestor",
                          dimensoes = NULL) {
    recebido$dados <<- dados
    recebido$corte <<- corte
    recebido$unidade <<- unidade
    structure(
      list(
        proporcoes = tibble::tibble(),
        modal = tibble::tibble(
          corte = c("Estadual", "Municipal"), dimensao = "Sexo",
          categoria_modal = "Feminino", n = c(20, 90), denom = c(30, 100),
          prop_modal = c(2 / 3, 0.9), concentracao = c(0.56, 0.82)
        ),
        n = tibble::tibble(corte = c("Estadual", "Municipal"),
                           n_gestores = c(30, 100), n_escolas = c(28L, 95L)),
        corte = corte, unidade = unidade
      ),
      class = "eduBR_perfil_gestor"
    )
  }
  local_mocked_bindings(gestores = fake_gest, perfil_gestor = fake_perfil)
  tools <- ferramentas_edubr("fake_con")

  r <- chamar_json(tools$perfil_gestor, regiao = "NE", rede = "publica",
                   localizacao = "urbana")
  env <- r$env
  expect_null(env$erro)
  expect_sem_vazamento(r$json, env)
  expect_equal(recebido$dados, "gestores_lazy")
  expect_equal(recebido$corte, "rede")
  expect_equal(recebido$unidade, "gestor")
  expect_equal(recebido$regiao, "NE")
  expect_equal(recebido$rede, "publica")
  expect_equal(recebido$localizacao, "urbana")
  expect_length(env$dados, 2L)
  expect_identical(names(env$dados[[1]]),
                   c("corte", "dimensao", "categoria_modal", "n", "denom",
                     "prop_modal", "concentracao"))
  ctx <- env$metadados$contexto
  expect_equal(ctx$corte, "rede")
  expect_length(ctx$n_por_corte, 2L)
  expect_equal(ctx$n_por_corte[[2]]$n_escolas, 95L)

  r <- chamar_json(tools$perfil_gestor, corte = "categoria_privada",
                   unidade = "escola", rede = "Privada")
  expect_null(r$env$erro)
  expect_equal(recebido$corte, "categoria_privada")
  expect_equal(recebido$unidade, "escola")
})

test_that("filtro por persona das tools da pesquisadora", {
  nomes <- function(p) names(ferramentas_edubr("fake_con", persona = p))

  gestora <- nomes("gestora-escolar")
  expect_false(any(tools_pesquisa %in% gestora))

  pesq <- nomes("pesquisadora-educacional")
  expect_true(all(c("catalogo", "perfil_escola", tools_pesquisa) %in% pesq))

  ml <- nomes("especialista-ml")
  expect_true(all(c("ideb", "covariaveis_escola", "tendencia_ideb_regiao")
                  %in% ml))
  expect_false(any(c("perfil_gestor", "municipios", "redes_municipio",
                     "docentes_rede") %in% ml))

  expect_true(all(tools_pesquisa %in% nomes(NULL)))
})

test_that("ideb_agregado: média por UF/região/município na mesma edição (#82)", {
  ideb_fake <- tibble::tibble(
    id_escola = 1:8,
    sg_uf = c("AC", "AC", "AC", "SP", "SP", "SP", "SP", "AC"),
    co_municipio = c(1L, 1L, 2L, 3L, 3L, 4L, 4L, 1L),
    no_municipio = c("A", "A", "B", "C", "C", "D", "D", "A"),
    rede = c("Municipal", "Municipal", "Estadual", "Municipal", "Estadual",
             "Municipal", "Municipal", "Municipal"),
    etapa = c(rep("fundamental_i", 7), "fundamental_ii"),
    ano = c(2023L, 2023L, 2023L, 2023L, 2023L, 2023L, 2021L, 2023L),
    ideb_observado = c(4, 5, 6, 6, NA, 8, 9, 3)
  )
  local_mocked_bindings(eduBR_tbl = function(con, nome) ideb_fake)
  tools <- ferramentas_edubr("fake_con", persona = "pesquisadora-educacional")
  expect_true("ideb_agregado" %in% names(tools))

  r <- eduBR_envelope_de(tools$ideb_agregado(etapa = "fundamental_i"))
  expect_null(r$erro)
  uf <- vapply(r$dados, `[[`, character(1), "sg_uf")
  expect_equal(uf, c("AC", "SP"))
  ac <- r$dados[[1]]
  expect_equal(ac$ideb_medio, 5)            # 4, 5, 6 (2023, fund. I)
  expect_equal(ac$escolas, 3)
  sp <- r$dados[[2]]
  expect_equal(sp$ideb_medio, 7)            # 6 e 8; NA fora; 2021 fora
  expect_equal(sp$escolas_com_nota, 2)
  expect_equal(sp$escolas, 3)

  r <- eduBR_envelope_de(tools$ideb_agregado(etapa = "fundamental_i",
                                             por_rede = TRUE, uf = "AC"))
  expect_equal(vapply(r$dados, `[[`, character(1), "rede"),
               c("Estadual", "Municipal"))

  r <- eduBR_envelope_de(tools$ideb_agregado(etapa = "fundamental_i",
                                             nivel = "regiao"))
  expect_setequal(vapply(r$dados, `[[`, character(1), "nome_regiao"),
                  c("Norte", "Sudeste"))

  r <- eduBR_envelope_de(tools$ideb_agregado(etapa = "fundamental_i",
                                             nivel = "municipio"))
  expect_match(r$metadados$aviso, "filtre por `uf`", fixed = TRUE)

  e <- eduBR_envelope_de(tools$ideb_agregado())
  expect_equal(e$erro$tipo, "parametro_invalido")
  expect_match(e$erro$mensagem, "etapa", fixed = TRUE)
  e <- eduBR_envelope_de(tools$ideb_agregado(etapa = "fundamental_i", ano = 2022L))
  expect_equal(e$erro$tipo, "parametro_invalido")
  expect_false("ideb_agregado" %in%
                 names(ferramentas_edubr("fake_con", persona = "gestora-escolar")))
})
