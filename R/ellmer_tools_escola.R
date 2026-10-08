# R/ellmer_tools_escola.R
#
# Tools de escola da camada ellmer (plans/ellmer-tools.md, chunk 2; foco na
# gestora escolar): perfil_escola, resumo_escola, serie_ideb_escola,
# escolas_similares, scores_escola e indicadores_escola. Cada tool só envolve
# funções existentes do pacote; os argumentos são validados **antes** de
# chegar ao dbplyr, para que o modelo receba `parametro_invalido` com uma
# mensagem que diga o que corrigir (erros do banco viram `conexao` genérico).

# ---------------------------------------------------------------------------
# Validação de argumentos

# Edições bienais do IDEB.
eduBR_edicoes_ideb <- function() seq(2005L, 2023L, by = 2L)

# Etapas do IDEB aceitas pelas tools.
eduBR_etapas_ideb <- function() c("fundamental_i", "fundamental_ii", "ensino_medio")

eduBR_validar_escola_id <- function(escola_id) {
  if (is.null(escola_id)) {
    eduBR_abortar(
      "parametro_invalido",
      "`escola_id` \u00e9 obrigat\u00f3rio: c\u00f3digo INEP da escola com 8 d\u00edgitos (ex.: \"13078070\")."
    )
  }
  if (is.numeric(escola_id) && length(escola_id) == 1L && !is.na(escola_id) &&
      escola_id == round(escola_id)) {
    escola_id <- format(escola_id, scientific = FALSE, trim = TRUE)
  }
  ok <- is.character(escola_id) && length(escola_id) == 1L &&
    !is.na(escola_id) && grepl("^[0-9]{8}$", trimws(escola_id))
  if (!ok) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        paste0(
          "`escola_id` inv\u00e1lido: %s. Informe o c\u00f3digo INEP da escola com ",
          "exatamente 8 d\u00edgitos (ex.: \"13078070\"), sem pontos ou espa\u00e7os."
        ),
        eduBR_valor_texto(escola_id)
      )
    )
  }
  trimws(escola_id)
}

eduBR_validar_etapa <- function(etapa) {
  if (is.null(etapa)) {
    return(NULL)
  }
  if (!is.character(etapa) || length(etapa) != 1L || is.na(etapa) ||
      !etapa %in% eduBR_etapas_ideb()) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        "`etapa` inv\u00e1lida: %s. Use uma de: %s.",
        eduBR_valor_texto(etapa), paste(eduBR_etapas_ideb(), collapse = ", ")
      )
    )
  }
  etapa
}

eduBR_validar_ano_ideb <- function(ano_ideb) {
  if (is.null(ano_ideb)) {
    return(NULL)
  }
  ok <- is.numeric(ano_ideb) && length(ano_ideb) == 1L && !is.na(ano_ideb) &&
    ano_ideb %in% eduBR_edicoes_ideb()
  if (!ok) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        paste0(
          "`ano_ideb` inv\u00e1lido: %s. O IDEB \u00e9 bienal; use uma edi\u00e7\u00e3o entre ",
          "2005 e 2023 (%s) ou omita para usar a mais recente da escola."
        ),
        eduBR_valor_texto(ano_ideb),
        paste(eduBR_edicoes_ideb(), collapse = ", ")
      )
    )
  }
  as.integer(ano_ideb)
}

eduBR_validar_inteiro <- function(x, nome, minimo, maximo) {
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x) && x == round(x) &&
    x >= minimo && x <= maximo
  if (!ok) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        "`%s` inv\u00e1lido: %s. Use um inteiro entre %d e %d.",
        nome, eduBR_valor_texto(x), as.integer(minimo), as.integer(maximo)
      )
    )
  }
  as.integer(x)
}

eduBR_validar_logico <- function(x, nome) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf("`%s` deve ser true ou false; recebido: %s.", nome,
              eduBR_valor_texto(x))
    )
  }
  x
}

eduBR_validar_texto <- function(x, nome) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(trimws(x))) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf("`%s` deve ser um texto n\u00e3o vazio; recebido: %s.", nome,
              eduBR_valor_texto(x))
    )
  }
  trimws(x)
}

# Valor recebido, em texto curto, para as mensagens de erro.
eduBR_valor_texto <- function(x) {
  if (is.null(x)) {
    return("null")
  }
  txt <- tryCatch(
    paste(utils::head(format(x), 3L), collapse = ", "),
    error = function(e) "?"
  )
  if (!length(txt) || !nzchar(txt)) txt <- "vazio"
  if (nchar(txt) > 40L) txt <- paste0(substr(txt, 1L, 40L), "...")
  if (is.character(x)) sprintf("\"%s\"", txt) else txt
}

# Argumento de etapa (enum) das tools.
eduBR_arg_etapa <- function(descricao) {
  ellmer::type_enum(eduBR_etapas_ideb(), descricao, required = FALSE)
}

eduBR_arg_escola_id <- function() {
  ellmer::type_string(
    paste0(
      "C\u00f3digo INEP da escola (8 d\u00edgitos, ex.: \"13078070\"). Se o usu\u00e1rio ",
      "s\u00f3 souber o nome, pe\u00e7a o c\u00f3digo."
    )
  )
}

eduBR_arg_ano_ideb <- function() {
  ellmer::type_integer(
    paste0(
      "Edi\u00e7\u00e3o do IDEB (bienal: 2005, 2007, ..., 2023). Omita para usar, ",
      "em cada etapa, a edi\u00e7\u00e3o mais recente com nota da escola."
    ),
    required = FALSE
  )
}

# ---------------------------------------------------------------------------
# perfil_escola / resumo_escola

# Chama perfil_escola(); escola ausente do Censo vira `sem_dados`.
eduBR_perfil_tool <- function(con, escola_id, ano_ideb) {
  tryCatch(
    perfil_escola(con, escola_id, ano_ideb = ano_ideb),
    error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("^escola inexistente", msg)) {
        eduBR_abortar(
          "sem_dados",
          paste0(
            msg, " Confira o c\u00f3digo INEP; a escola pode ter sido extinta ou ",
            "n\u00e3o constar do Censo de refer\u00eancia."
          )
        )
      }
      stop(e)
    }
  )
}

# Identificação da escola (campo `contexto` dos metadados).
eduBR_contexto_perfil <- function(p) {
  e <- p$escola
  escalar <- function(v) if (is.null(v) || !length(v) || is.na(v[[1L]])) NULL else v[[1L]]
  ano_ideb <- lapply(as.list(p$ano_ideb), escalar)
  ofertada <- lapply(as.list(p$ideb_ofertada), escalar)
  list(
    codigo_inep = as.character(e$codigo_inep),
    nome = escalar(e$nome),
    rede = escalar(e$rede),
    municipio = escalar(e$municipio),
    uf = escalar(e$uf),
    localizacao = escalar(e$localizacao),
    etapas_ofertadas = I(as.character(e$etapas %||% character(0))),
    matriculas = escalar(e$matriculas),
    ano_censo = as.integer(p$ano),
    edicao_ideb = ano_ideb,
    ideb_etapa_ofertada = ofertada
  )
}

eduBR_tool_perfil_escola <- function(sessao) {
  fun <- function(escola_id = NULL, ano_ideb = NULL) {
    escola_id <- eduBR_validar_escola_id(escola_id)
    ano_ideb <- eduBR_validar_ano_ideb(ano_ideb)
    p <- eduBR_perfil_tool(sessao$con, escola_id, ano_ideb)
    eduBR_resultado(
      comparar(p),
      grao = "item de compara\u00e7\u00e3o (escola \u00d7 munic\u00edpio \u00d7 estado)",
      filtros = list(escola_id = escola_id, ano_ideb = ano_ideb),
      contexto = eduBR_contexto_perfil(p)
    )
  }
  eduBR_tool(
    sessao, "perfil_escola", fun,
    descricao = paste0(
      "Foto de uma escola dentro do seu munic\u00edpio e do seu estado. Responde ",
      "\"como minha escola est\u00e1 em rela\u00e7\u00e3o ao munic\u00edpio e ao estado?\". Cada ",
      "linha de `dados` \u00e9 um item: em Infraestrutura (\u00e1gua, energia, esgoto, ",
      "biblioteca, laborat\u00f3rio de inform\u00e1tica, quadra, refeit\u00f3rio, internet, ",
      "banda larga, sala dos professores) a escola vale 1 (tem) ou 0 (n\u00e3o ",
      "tem) e munic\u00edpio/estado valem a FRA\u00c7\u00c3O das escolas que t\u00eam o item ",
      "(0,75 = 75%); em IDEB e Docentes s\u00e3o os valores da escola e as m\u00e9dias ",
      "simples das escolas do munic\u00edpio e do estado. `dif_municipio` = escola ",
      "menos munic\u00edpio. Cuidados de leitura: o IDEB \u00e9 comparado s\u00f3 na MESMA ",
      "EDI\u00c7\u00c3O (indicada no item, ex.: \"IDEB fund. I (2023)\") e na MESMA ",
      "REDE da escola (municipal com municipal etc.); munic\u00edpio e estado ",
      "contam s\u00f3 escolas em atividade; o campo `ofertada` = false sinaliza ",
      "IDEB de uma etapa que a escola N\u00c3O oferta mais no Censo de refer\u00eancia ",
      "(nota hist\u00f3rica, n\u00e3o atual). `metadados.contexto` traz a ",
      "identifica\u00e7\u00e3o (nome, rede, munic\u00edpio, UF, localiza\u00e7\u00e3o, etapas, ",
      "matr\u00edculas, ano do Censo e edi\u00e7\u00e3o do IDEB usada por etapa). S\u00e3o ",
      "m\u00e9dias descritivas para situar a escola, n\u00e3o indicam causa. N\u00e3o traz ",
      "endere\u00e7o nem contatos. Leva cerca de 10 s."
    ),
    arguments = list(
      escola_id = eduBR_arg_escola_id(),
      ano_ideb = eduBR_arg_ano_ideb()
    ),
    titulo = "Perfil da escola vs munic\u00edpio e estado"
  )
}

eduBR_tool_resumo_escola <- function(sessao) {
  fun <- function(escola_id = NULL, ano_ideb = NULL) {
    escola_id <- eduBR_validar_escola_id(escola_id)
    ano_ideb <- eduBR_validar_ano_ideb(ano_ideb)
    p <- eduBR_perfil_tool(sessao$con, escola_id, ano_ideb)
    eduBR_resultado(
      resumo_escola(p),
      grao = "escola",
      filtros = list(escola_id = escola_id, ano_ideb = ano_ideb)
    )
  }
  eduBR_tool(
    sessao, "resumo_escola", fun,
    descricao = paste0(
      "A escola numa linha: nome, rede, munic\u00edpio/UF, localiza\u00e7\u00e3o, etapas ",
      "ofertadas, matr\u00edculas da educa\u00e7\u00e3o b\u00e1sica e docentes, e, para cada ",
      "etapa do IDEB (fund_i, fund_ii, medio), a nota da edi\u00e7\u00e3o de ",
      "refer\u00eancia (`ideb_*`), o ano dessa edi\u00e7\u00e3o (`ano_*`), a varia\u00e7\u00e3o em ",
      "rela\u00e7\u00e3o \u00e0 edi\u00e7\u00e3o anterior com nota da escola (`var_*`, positiva = ",
      "melhorou) e se a etapa ainda \u00e9 ofertada no Censo (`oferta_*`). Use ",
      "para apresentar a escola rapidamente ou responder \"minha escola ",
      "melhorou desde a \u00faltima edi\u00e7\u00e3o?\". `null` indica etapa sem nota. Para ",
      "comparar com munic\u00edpio/estado use `perfil_escola`; para a s\u00e9rie ",
      "completa use `serie_ideb_escola`. Leva cerca de 10 s."
    ),
    arguments = list(
      escola_id = eduBR_arg_escola_id(),
      ano_ideb = eduBR_arg_ano_ideb()
    ),
    titulo = "Resumo da escola"
  )
}

# ---------------------------------------------------------------------------
# serie_ideb_escola

eduBR_tool_serie_ideb_escola <- function(sessao) {
  fun <- function(escola_id = NULL, etapa = NULL) {
    escola_id <- eduBR_validar_escola_id(escola_id)
    etapa <- eduBR_validar_etapa(etapa)
    tb <- consulta(ideb(sessao$con, escola_id = escola_id, etapa = etapa))
    tb <- tb |>
      dplyr::select(dplyr::any_of(
        c("etapa", "ano", "ideb_observado", "nota_media")
      )) |>
      dplyr::arrange(.data$etapa, .data$ano)
    eduBR_resultado(
      tb,
      grao = "escola \u00d7 etapa \u00d7 edi\u00e7\u00e3o do IDEB",
      filtros = list(escola_id = escola_id, etapa = etapa)
    )
  }
  eduBR_tool(
    sessao, "serie_ideb_escola", fun,
    descricao = paste0(
      "S\u00e9rie hist\u00f3rica do IDEB de uma escola, uma linha por etapa e edi\u00e7\u00e3o ",
      "(bienal, 2005 a 2023), com o IDEB observado e, quando houver, a nota ",
      "m\u00e9dia SAEB (`nota_media`). Responde \"melhoramos no IDEB?\" e \"qual ",
      "a tend\u00eancia da escola?\". Cuidados: compare s\u00f3 edi\u00e7\u00f5es da MESMA ",
      "etapa (fundamental_i, fundamental_ii e ensino_medio t\u00eam escalas de ",
      "refer\u00eancia diferentes); edi\u00e7\u00f5es sem nota aparecem com `null` (ex.: ",
      "poucos alunos avaliados) e n\u00e3o devem ser lidas como zero. Filtre por ",
      "`etapa` para uma etapa s\u00f3."
    ),
    arguments = list(
      escola_id = eduBR_arg_escola_id(),
      etapa = eduBR_arg_etapa("Etapa do IDEB; omita para todas as etapas da escola.")
    ),
    titulo = "S\u00e9rie do IDEB da escola"
  )
}

# ---------------------------------------------------------------------------
# escolas_similares

eduBR_tool_escolas_similares <- function(sessao) {
  fun <- function(escola_id = NULL, n = 5L, etapa = NULL, publica = TRUE) {
    escola_id <- eduBR_validar_escola_id(escola_id)
    n <- eduBR_validar_inteiro(n %||% 5L, "n", 1L, 20L)
    etapa <- eduBR_validar_etapa(etapa)
    publica <- eduBR_validar_logico(publica %||% TRUE, "publica")
    viz <- escolas_similares(
      sessao$con, escola_id, n = n, etapa = etapa, publica = publica
    )
    eduBR_resultado(
      viz,
      grao = "escola vizinha \u00d7 etapa",
      filtros = list(escola_id = escola_id, n = n, etapa = etapa,
                     publica = publica)
    )
  }
  eduBR_tool(
    sessao, "escolas_similares", fun,
    descricao = paste0(
      "Benchmark: as escolas mais parecidas com a escola informada, para a ",
      "gestora saber com quem se comparar ou trocar experi\u00eancias. A ",
      "semelhan\u00e7a usa infraestrutura, porte (matr\u00edculas), docentes, gest\u00e3o ",
      "e raz\u00f5es entre eles, padronizados dentro de cada etapa; N\u00c3O usa a ",
      "nota (IDEB/SAEB) nem o INSE, ent\u00e3o \u00e9 poss\u00edvel comparar desempenho ",
      "entre escolas de perfil parecido. `distancia` menor = mais parecida ",
      "(s\u00f3 tem sentido para ordenar, n\u00e3o tem unidade). Por padr\u00e3o compara ",
      "nas etapas da pr\u00f3pria escola e s\u00f3 entre escolas p\u00fablicas ",
      "(`publica = false` inclui privadas; obrigat\u00f3rio se a escola for ",
      "privada). Devolve c\u00f3digo, nome, munic\u00edpio, UF, rede e etapa das ",
      "vizinhas, sem endere\u00e7o nem contatos. Leva cerca de 10 s."
    ),
    arguments = list(
      escola_id = eduBR_arg_escola_id(),
      n = ellmer::type_integer(
        "Quantas escolas parecidas devolver (padr\u00e3o 5, m\u00e1ximo 20).",
        required = FALSE
      ),
      etapa = eduBR_arg_etapa(
        "Etapa do recorte; omita para usar as etapas da pr\u00f3pria escola."
      ),
      publica = ellmer::type_boolean(
        "S\u00f3 escolas p\u00fablicas? Padr\u00e3o true.", required = FALSE
      )
    ),
    titulo = "Escolas similares"
  )
}

# ---------------------------------------------------------------------------
# scores_escola / indicadores_escola

eduBR_tool_scores_escola <- function(sessao) {
  fun <- function(escola_id = NULL) {
    escola_id <- eduBR_validar_escola_id(escola_id)
    eduBR_resultado(
      scores(sessao$con, escola_id = escola_id),
      grao = "escola \u00d7 ano do Censo",
      filtros = list(escola_id = escola_id)
    )
  }
  eduBR_tool(
    sessao, "scores_escola", fun,
    descricao = paste0(
      "Scores compostos pr\u00e9-calculados da escola, por ano do Censo: ",
      "infraestrutura, capacidade de atendimento, capacita\u00e7\u00e3o docente, ",
      "diversidade discente, capacidade gestora e sustentabilidade. V\u00eam ",
      "prontos do pipeline EduMaps (n\u00e3o s\u00e3o recalculados aqui). Escala de 0 ",
      "a 10, quanto maior melhor; `data_atualizacao` indica a frescura. ",
      "Cuidados de leitura: cada score \u00e9 uma soma ponderada de indicadores ",
      "bin\u00e1rios `in_*` do Censo (tem/n\u00e3o tem), ent\u00e3o mede PRESEN\u00c7A de ",
      "recursos, n\u00e3o qualidade nem uso; diferen\u00e7as pequenas podem vir de um ",
      "\u00fanico item. N\u00e3o \u00e9 nota de desempenho (para isso use IDEB). Use para ",
      "mostrar \u00e0 gestora onde a escola \u00e9 mais forte ou mais fr\u00e1gil."
    ),
    arguments = list(escola_id = eduBR_arg_escola_id()),
    titulo = "Scores compostos da escola"
  )
}

eduBR_tool_indicadores_escola <- function(sessao) {
  fun <- function(escola_id = NULL, indicador = NULL) {
    escola_id <- eduBR_validar_escola_id(escola_id)
    indicador <- eduBR_validar_texto(indicador, "indicador")
    eduBR_resultado(
      indicadores(sessao$con, escola_id = escola_id, indicador = indicador),
      grao = "escola \u00d7 indicador",
      filtros = list(escola_id = escola_id, indicador = indicador)
    )
  }
  eduBR_tool(
    sessao, "indicadores_escola", fun,
    descricao = paste0(
      "Indicadores da escola com posi\u00e7\u00e3o no ranking (munic\u00edpio, estado e ",
      "nacional) e a rede de compara\u00e7\u00e3o. Use para saber em que posi\u00e7\u00e3o a ",
      "escola fica num indicador (ex.: \"infraestrutura\"). Aten\u00e7\u00e3o: a base ",
      "de ranking pode estar VAZIA no ambiente atual; nesse caso a ",
      "ferramenta responde `sem_dados` e voc\u00ea deve usar `scores_escola` ",
      "(scores compostos) ou `perfil_escola` no lugar, sem inventar posi\u00e7\u00f5es."
    ),
    arguments = list(
      escola_id = eduBR_arg_escola_id(),
      indicador = ellmer::type_string(
        "Identificador do indicador (ex.: \"infraestrutura\"); omita para todos.",
        required = FALSE
      )
    ),
    titulo = "Indicadores e ranking da escola"
  )
}
