# Tools da persona analista-espacial.

eduBR_raios_ivet <- function() c(500L, 1000L, 2000L)

eduBR_tool_ivet_socioeconomico <- function(sessao) {
  fun <- function(escola_id, ano = 2025L, raio_m = 1000L, n = 1L) {
    escola_id <- eduBR_validar_escola_id(escola_id)
    ano <- eduBR_validar_ano_censo(ano)
    if (!is.numeric(raio_m) || length(raio_m) != 1L || is.na(raio_m) ||
        !raio_m %in% eduBR_raios_ivet()) {
      eduBR_abortar("parametro_invalido", "`raio_m` deve ser 500, 1000 ou 2000.")
    }
    eduBR_validar_n(n)
    eduBR_resultado(
      ivet_socioeconomico(sessao$con, escola_id, ano, raio_m),
      grao = "escola x ano escolar x raio",
      filtros = list(escola_id = escola_id, ano = ano, raio_m = raio_m),
      contexto = list(referencia_setorial = 2022L,
                      interpretacao = "Componentes brutos; sem escore agregado.")
    )
  }
  eduBR_tool(sessao, "ivet_socioeconomico", fun,
    descricao = paste0("Componentes observados do entorno escolar: analfabetismo, renda do responsavel e saneamento. ",
      "Preserva valores ausentes; informa raio, cobertura e versao; nao retorna escore agregado."),
    arguments = list(
      escola_id = ellmer::type_string("Codigo INEP da escola, com 8 digitos."),
      ano = ellmer::type_integer("Ano do cadastro escolar (padrao 2025).", required = FALSE),
      raio_m = ellmer::type_integer("Raio de influencia: 500, 1000 ou 2000 m (padrao 1000).", required = FALSE),
      n = eduBR_arg_n(1L)
    ), titulo = "Componentes do entorno escolar"
  )
}

eduBR_tool_ivet_contexto <- function(sessao) {
  fun <- function(co_municipio = NULL, uf = NULL, rede = "Municipal",
                  ano = 2025L, raio_m = 1000L, n = 1L) {
    if (is.null(co_municipio) && is.null(uf)) {
      eduBR_abortar("parametro_invalido", "Informe `co_municipio` ou `uf`.")
    }
    if (!is.null(co_municipio) &&
        (!is.character(co_municipio) || length(co_municipio) != 1L ||
         is.na(co_municipio) || !grepl("^[0-9]{7}$", co_municipio))) {
      eduBR_abortar("parametro_invalido", "`co_municipio` deve ter 7 digitos IBGE.")
    }
    uf <- eduBR_validar_uf(uf)
    rede <- eduBR_validar_rede(rede, publica = TRUE)
    ano <- eduBR_validar_ano_censo(ano)
    if (!is.numeric(raio_m) || length(raio_m) != 1L || is.na(raio_m) ||
        !raio_m %in% eduBR_raios_ivet()) {
      eduBR_abortar("parametro_invalido", "`raio_m` deve ser 500, 1000 ou 2000.")
    }
    eduBR_validar_n(n)
    eduBR_resultado(
      ivet_contexto_socioeconomico(sessao$con, co_municipio, uf, rede, ano, raio_m),
      grao = "media simples entre escolas",
      filtros = list(co_municipio = co_municipio, uf = uf, rede = rede,
                     ano = ano, raio_m = raio_m),
      contexto = list(referencia_setorial = 2022L,
                      ponderacao = "Nao ponderada por area, populacao ou matriculas.")
    )
  }
  eduBR_tool(sessao, "ivet_contexto", fun,
    descricao = "Compara as medias simples dos componentes entre escolas de uma rede em municipio ou UF. Cada componente traz seu n valido; nao e medida ponderada nem escore IVET.",
    arguments = list(
      co_municipio = ellmer::type_string("Codigo IBGE de 7 digitos; informe municipio ou UF.", required = FALSE),
      uf = eduBR_arg_uf(), rede = eduBR_arg_rede(publica = TRUE),
      ano = ellmer::type_integer("Ano escolar (padrao 2025).", required = FALSE),
      raio_m = ellmer::type_integer("Raio em metros: 500, 1000 ou 2000.", required = FALSE),
      n = eduBR_arg_n(1L)
    ), titulo = "Contexto territorial IVET"
  )
}

eduBR_tool_regressao_ivet <- function(sessao) {
  f_esp <- eduBR_tool_funcao(sessao, eduBR_tool_especificar_regressao)
  f_exe <- eduBR_tool_funcao(sessao, eduBR_tool_executar_regressao)
  f_coef <- eduBR_tool_funcao(sessao, eduBR_tool_coeficientes)
  f_met <- eduBR_tool_funcao(sessao, eduBR_tool_metricas)
  fun <- function(outcome, predictors, uf = NULL, co_municipio = NULL,
                  rede = NULL, ano = 2025L,
                  ano_ideb = 2023L, raio_m = 1000L, n = 100L) {
    uf <- eduBR_validar_uf(uf)
    if (!is.null(co_municipio) &&
        (!is.character(co_municipio) || length(co_municipio) != 1L ||
         is.na(co_municipio) || !grepl("^[0-9]{7}$", co_municipio))) {
      eduBR_abortar("parametro_invalido", "`co_municipio` deve ter 7 digitos IBGE.")
    }
    rede <- eduBR_validar_rede(rede, publica = TRUE)
    ano <- eduBR_validar_ano_censo(ano)
    ano_ideb <- eduBR_validar_edicao(ano_ideb, "ano_ideb")
    if (is.null(ano_ideb)) ano_ideb <- 2023L
    if (!is.numeric(raio_m) || length(raio_m) != 1L || is.na(raio_m) ||
        !raio_m %in% eduBR_raios_ivet()) {
      eduBR_abortar("parametro_invalido", "`raio_m` deve ser 500, 1000 ou 2000.")
    }
    if (!is.character(outcome) || length(outcome) != 1L ||
        !outcome %in% c("ideb_fund_i", "ideb_fund_ii", "ideb_medio")) {
      eduBR_abortar("parametro_invalido", "`outcome` deve ser uma coluna IDEB valida.")
    }
    pred_validos <- eduBR_ivet_componentes()
    if (!is.character(predictors) || !length(predictors) || anyNA(predictors) ||
        any(!predictors %in% pred_validos)) {
      eduBR_abortar("parametro_invalido", sprintf("`predictors` deve conter apenas: %s.", paste(pred_validos, collapse = ", ")))
    }
    eduBR_validar_n(n)
    cv <- covariaveis_ivet_escola(sessao$con, ano, ano_ideb, uf, rede,
                                  co_municipio = co_municipio,
                                  ativas = TRUE, raio_m = raio_m)
    completos <- consulta(cv)
    for (coluna in c(outcome, predictors)) {
      completos <- dplyr::filter(completos, !is.na(.data[[coluna]]))
    }
    n_completos <- dplyr::collect(
      dplyr::summarise(completos, n = dplyr::n())
    )$n[[1L]]
    if (is.na(n_completos) || n_completos <= length(predictors) + 1L) {
      eduBR_abortar(
        "sem_dados",
        sprintf(
          paste0(
            "A regress\u00e3o precisa de mais de %d escolas com IDEB e todos os",
            " componentes informados. O recorte tem %s casos completos; confira",
            " os dados dispon\u00edveis ou escolha outros componentes."
          ),
          length(predictors) + 1L,
          if (is.na(n_completos)) "0" else as.character(n_completos)
        )
      )
    }
    dados_id <- eduBR_handle_guardar(sessao, "dados", cv,
      eduBR_handle_descrever("covariaveis_ivet", list(uf = uf, rede = rede, raio_m = raio_m)))
    es <- f_esp(outcome = outcome, predictors = predictors, cuts = NULL,
                modelo = "linear", dados_id = dados_id)
    ex <- f_exe(espec_id = es$handle)
    co <- f_coef(regressao_id = ex$handle)
    me <- f_met(regressao_id = ex$handle)
    eduBR_resultado(co$dados, grao = co$grao,
      filtros = list(outcome = outcome, predictors = predictors, uf = uf,
                     co_municipio = co_municipio,
                     rede = rede, ano = ano, ano_ideb = ano_ideb, raio_m = raio_m),
      handle = ex$handle, aviso = ex$aviso,
      contexto = list(metricas = eduBR_registros(me$dados), n_usado = ex$contexto$n_usado,
                      referencia_setorial = 2022L, interpretacao = "Associacao observacional; nao causal."))
  }
  eduBR_tool(sessao, "regressao_ivet", fun,
    descricao = "Ajusta regressao linear do IDEB contra componentes territoriais IVET. Um unico raio por escola; observa a remocao de valores ausentes. Interpretar como associacao, nunca causalidade.",
    arguments = list(
      outcome = ellmer::type_enum(c("ideb_fund_i", "ideb_fund_ii", "ideb_medio"), "Desfecho IDEB."),
      predictors = ellmer::type_array(ellmer::type_string("Componente territorial."), "Componentes preditores."),
      uf = eduBR_arg_uf(),
      co_municipio = ellmer::type_string("Codigo IBGE municipal de 7 digitos (opcional).", required = FALSE),
      rede = eduBR_arg_rede(publica = TRUE),
      ano = ellmer::type_integer("Ano escolar (2025).", required = FALSE),
      ano_ideb = ellmer::type_integer("Edicao IDEB (2023).", required = FALSE),
      raio_m = ellmer::type_integer("Raio em metros: 500, 1000 ou 2000.", required = FALSE),
      n = eduBR_arg_n(100L)
    ), titulo = "Regressao com componentes territoriais"
  )
}
