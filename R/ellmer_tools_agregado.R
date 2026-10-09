# R/ellmer_tools_agregado.R
#
# Agregação do IDEB no banco para perguntas regionais (#82): com o limite de
# texto por resposta (#71), tabelas grandes chegam cortadas ao modelo; esta
# tool devolve poucas linhas já agregadas (média, escolas com nota).

eduBR_niveis_agregado <- function() c("uf", "regiao", "municipio")

eduBR_tool_ideb_agregado <- function(sessao) {
  fun <- function(etapa = NULL, nivel = "uf", ano = NULL, rede = NULL, uf = NULL,
                  regiao = NULL, por_rede = NULL, n = NULL) {
    etapa <- eduBR_validar_etapa(etapa)
    if (is.null(etapa)) {
      eduBR_abortar(
        "parametro_invalido",
        paste0(
          "Informe `etapa` (fundamental_i, fundamental_ii ou ensino_medio): ",
          "m\u00e9dias de etapas diferentes n\u00e3o s\u00e3o compar\u00e1veis."
        )
      )
    }
    nivel <- eduBR_validar_enum(nivel %||% "uf", "nivel", eduBR_niveis_agregado())
    ano <- eduBR_validar_edicao(ano %||% 2023L, "ano")
    rede <- eduBR_validar_rede(rede)
    uf <- eduBR_validar_uf(uf)
    regiao <- eduBR_validar_regiao(regiao)
    por_rede <- eduBR_validar_logico(por_rede %||% FALSE, "por_rede")
    eduBR_validar_n(n)

    grupos <- switch(
      nivel,
      uf = c("nome_regiao", "sg_uf"),
      regiao = "nome_regiao",
      municipio = c("sg_uf", "co_municipio", "no_municipio")
    )
    if (isTRUE(por_rede)) {
      grupos <- c(grupos, "rede")
    }
    tb <- consulta(ideb_regiao(
      sessao$con, regiao = regiao, uf = uf, etapa = etapa, rede = rede,
      ano = ano
    )) |>
      dplyr::group_by(dplyr::across(dplyr::all_of(grupos))) |>
      dplyr::summarise(
        ideb_medio = mean(.data$ideb_observado, na.rm = TRUE),
        escolas_com_nota = sum(ifelse(is.na(.data$ideb_observado), 0L, 1L),
                               na.rm = TRUE),
        escolas = dplyr::n(),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::across(dplyr::all_of(grupos)))

    eduBR_resultado(
      tb,
      grao = paste0(
        switch(nivel, uf = "UF", regiao = "macrorregi\u00e3o",
               municipio = "munic\u00edpio"),
        if (isTRUE(por_rede)) " \u00d7 rede" else ""
      ),
      filtros = list(etapa = etapa, nivel = nivel, ano = ano, rede = rede,
                     uf = uf, regiao = regiao, por_rede = por_rede),
      n_padrao = if (nivel == "municipio") 50L else 200L,
      aviso = if (nivel == "municipio" && is.null(uf)) {
        paste0(
          "N\u00edvel munic\u00edpio sem `uf`: s\u00e3o milhares de linhas e a resposta ",
          "ser\u00e1 cortada; filtre por `uf`."
        )
      }
    )
  }
  eduBR_tool(
    sessao, "ideb_agregado", fun,
    descricao = paste0(
      "IDEB m\u00e9dio J\u00c1 AGREGADO no banco, para perguntas regionais (\"qual o ",
      "IDEB m\u00e9dio da rede municipal por UF?\"): uma linha por UF (padr\u00e3o), ",
      "macrorregi\u00e3o ou munic\u00edpio \u2014 opcionalmente tamb\u00e9m por rede ",
      "(`por_rede = true`) \u2014 com `ideb_medio` (m\u00e9dia simples das escolas com ",
      "nota), `escolas_com_nota` e `escolas`. Exige `etapa` e usa UMA edi\u00e7\u00e3o ",
      "(`ano`, padr\u00e3o 2023): s\u00f3 compare dentro da mesma etapa e edi\u00e7\u00e3o. ",
      "Filtros: `rede` (Estadual, Federal, Municipal, Privada), `uf`, `regiao`. ",
      "Use esta ferramenta em vez de `ideb` quando a pergunta for sobre ",
      "m\u00e9dias por territ\u00f3rio (a `ideb` devolve escolas e chega cortada). ",
      "Cuidado: m\u00e9dia simples de escolas, n\u00e3o ponderada por matr\u00edculas."
    ),
    arguments = list(
      etapa = ellmer::type_enum(eduBR_etapas_ideb(), "Etapa (obrigat\u00f3ria)."),
      nivel = ellmer::type_enum(
        eduBR_niveis_agregado(),
        "Agrupar por uf (padr\u00e3o), regiao ou municipio.", required = FALSE
      ),
      ano = ellmer::type_integer(
        "Edi\u00e7\u00e3o do IDEB (bienal, padr\u00e3o 2023).", required = FALSE
      ),
      rede = eduBR_arg_rede(),
      uf = eduBR_arg_uf("Filtra uma UF (ex.: \"SP\"); \u00fatil com nivel = municipio."),
      regiao = eduBR_arg_regiao(),
      por_rede = ellmer::type_boolean(
        "Separar tamb\u00e9m por rede? Padr\u00e3o false.", required = FALSE
      ),
      n = eduBR_arg_n(200L)
    ),
    titulo = "IDEB m\u00e9dio agregado"
  )
}
