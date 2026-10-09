# R/ellmer_tools_regressao.R
#
# Tools de regressão declarativa da camada ellmer (plans/ellmer-tools.md,
# chunk 4): especificar_regressao, executar_regressao, coeficientes,
# metricas e listar_handles. Só envolvem as funções do pacote
# (especificar_regressao(), executar_regressao(), coeficientes(),
# metricas()). Os nomes de colunas são validados contra a fonte **sem
# coletar dados** (tbl_vars() e um protótipo de 0 linhas) e o recorte é
# contado no banco antes de executar: executar_regressao() coleta o recorte
# filtrado inteiro, então recortes acima de `limites$max_amostra` são
# recusados com `limite_excedido` (sem amostrar).

# ---------------------------------------------------------------------------
# Valores aceitos

# Domínios do catálogo usáveis como `fonte` (sem os metadados de clusters e
# os pares de similaridade, que não são bases de modelagem).
eduBR_fontes_regressao <- function() {
  setdiff(names(eduBR_catalogo()), c("clusters", "similaridade"))
}

eduBR_modelos_regressao <- function() c("linear", "logistico")

# Tipos de handle conhecidos (os do chunk 5 já previstos).
eduBR_tipos_handle <- function() {
  c("dados", "espec", "regressao", "floresta", "treino", "teste")
}

eduBR_regex_numero <- function() "^-?[0-9]+(\\.[0-9]+)?$"

# ---------------------------------------------------------------------------
# Validação

# Vetor de nomes de colunas (string ou array do LLM) -> character único.
eduBR_validar_nomes <- function(x, nome, obrigatorio = TRUE) {
  if (is.null(x) || (is.list(x) && !length(x))) {
    if (obrigatorio) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf("`%s` \u00e9 obrigat\u00f3rio (nome(s) de coluna).", nome)
      )
    }
    return(NULL)
  }
  x <- unlist(x, use.names = FALSE)
  if (!is.character(x) || !length(x) || anyNA(x) || any(!nzchar(trimws(x)))) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf("`%s` deve conter nomes de coluna (texto n\u00e3o vazio); recebido: %s.",
              nome, eduBR_valor_texto(x))
    )
  }
  x <- trimws(x)
  if (anyDuplicated(x)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf("`%s` repete coluna(s): %s.", nome,
              paste(unique(x[duplicated(x)]), collapse = ", "))
    )
  }
  x
}

# Filtro do LLM (array de {coluna, valor}; o ellmer pode entregá-lo como
# data frame ou lista de listas) -> data frame (coluna, valor texto).
eduBR_filtro_pares <- function(filtro) {
  if (is.null(filtro) || !length(filtro)) {
    return(NULL)
  }
  erro <- function() {
    eduBR_abortar(
      "parametro_invalido",
      paste0(
        "`filtro` deve ser uma lista de objetos {\"coluna\": \"...\", ",
        "\"valor\": \"...\"} (igualdades combinadas com E), ex.: ",
        "[{\"coluna\": \"ano\", \"valor\": \"2023\"}, ",
        "{\"coluna\": \"sg_uf\", \"valor\": \"AC\"}]."
      )
    )
  }
  if (is.data.frame(filtro)) {
    if (!all(c("coluna", "valor") %in% names(filtro))) erro()
    itens <- lapply(seq_len(nrow(filtro)), function(i) {
      list(coluna = filtro$coluna[[i]], valor = filtro$valor[[i]])
    })
  } else if (is.list(filtro)) {
    itens <- filtro
  } else {
    erro()
  }
  escalar <- function(v) {
    (is.character(v) || is.numeric(v) || is.logical(v)) && length(v) == 1L &&
      !is.na(v)
  }
  pares <- lapply(itens, function(it) {
    if (!is.list(it) || !escalar(it$coluna) || !is.character(it$coluna) ||
        !nzchar(trimws(it$coluna)) || !escalar(it$valor)) {
      erro()
    }
    v <- it$valor
    if (is.logical(v)) v <- tolower(as.character(v))
    if (is.numeric(v)) v <- format(v, scientific = FALSE, trim = TRUE)
    c(coluna = trimws(it$coluna), valor = trimws(v))
  })
  out <- data.frame(
    coluna = vapply(pares, `[[`, character(1), "coluna"),
    valor = vapply(pares, `[[`, character(1), "valor"),
    stringsAsFactors = FALSE
  )
  if (anyDuplicated(out$coluna)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        paste0(
          "`filtro` repete a coluna %s; cada coluna aceita uma \u00fanica ",
          "igualdade (os itens s\u00e3o combinados com E)."
        ),
        paste(unique(out$coluna[duplicated(out$coluna)]), collapse = ", ")
      )
    )
  }
  out
}

# Pares (coluna, valor texto) -> lista nomeada de igualdades. Valores no
# formato numérico viram número, exceto em colunas de texto (o protótipo de
# 0 linhas da fonte diz o tipo; comparar texto com número falharia no SQL).
eduBR_filtro_lista <- function(pares, prototipo) {
  if (is.null(pares)) {
    return(NULL)
  }
  out <- lapply(seq_len(nrow(pares)), function(i) {
    col <- prototipo[[pares$coluna[i]]]
    v <- pares$valor[i]
    numerico <- grepl(eduBR_regex_numero(), v)
    if (is.character(col) || is.factor(col)) {
      return(v)
    }
    if (is.logical(col)) {
      if (!v %in% c("true", "false", "TRUE", "FALSE")) {
        eduBR_abortar(
          "parametro_invalido",
          sprintf("`filtro`: a coluna %s \u00e9 l\u00f3gica; use \"true\" ou \"false\".",
                  pares$coluna[i])
        )
      }
      return(toupper(v) == "TRUE")
    }
    if (is.numeric(col) || inherits(col, "integer64")) {
      if (!numerico) {
        eduBR_abortar(
          "parametro_invalido",
          sprintf(
            "`filtro`: a coluna %s \u00e9 num\u00e9rica e recebeu %s; use um n\u00famero (ex.: \"2023\").",
            pares$coluna[i], eduBR_valor_texto(v)
          )
        )
      }
      return(as.numeric(v))
    }
    if (numerico) as.numeric(v) else v
  })
  names(out) <- pares$coluna
  out
}

# Colunas inexistentes -> parametro_invalido com as colunas disponíveis.
eduBR_validar_colunas_fonte <- function(usadas, disponiveis, papel) {
  faltam <- setdiff(usadas, disponiveis)
  if (length(faltam)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        paste0(
          "%s com coluna(s) inexistente(s) na fonte: %s. Colunas ",
          "dispon\u00edveis: %s."
        ),
        papel, paste(faltam, collapse = ", "),
        paste(utils::head(disponiveis, 120L), collapse = ", ")
      )
    )
  }
  invisible(TRUE)
}

# Handle de dados (`dados_<k>`) -> objeto eduBR/tbl/data frame.
eduBR_obter_dados_handle <- function(sessao, dados_id) {
  dados_id <- eduBR_validar_texto(dados_id, "dados_id")
  if (!grepl("^dados_[0-9]+$", dados_id)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        paste0(
          "`dados_id` deve ser um handle de dados (\"dados_<k>\", ex.: o ",
          "`metadados.handle` de `covariaveis_escola`); recebido: %s."
        ),
        eduBR_valor_texto(dados_id)
      )
    )
  }
  obj <- eduBR_handle_obter(sessao, dados_id)
  if (!(inherits(obj, "eduBR") || is.data.frame(obj) || eduBR_lazy(obj))) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf("O handle %s n\u00e3o guarda uma base de dados.", dados_id)
    )
  }
  obj
}

# Handle do tipo esperado (prefixo) -> objeto.
eduBR_obter_handle_tipo <- function(sessao, id, tipo, nome, origem) {
  id <- eduBR_validar_texto(id, nome)
  if (!grepl(sprintf("^%s_[0-9]+$", tipo), id)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        "`%s` deve ser um handle \"%s_<k>\" devolvido por `%s`; recebido: %s.",
        nome, tipo, origem, eduBR_valor_texto(id)
      )
    )
  }
  eduBR_handle_obter(sessao, id)
}

# ---------------------------------------------------------------------------
# Resumos

eduBR_formula_texto <- function(espec) {
  paste(espec$outcome, "~", paste(espec$predictors, collapse = " + "))
}

eduBR_filtro_texto <- function(filtro) {
  if (is.null(filtro) || !length(filtro)) {
    return(NA_character_)
  }
  paste(
    sprintf("%s == %s", names(filtro), vapply(filtro, function(v) {
      if (is.character(v)) sprintf("\"%s\"", v) else format(v)
    }, character(1))),
    collapse = " E "
  )
}

# Contagem de linhas do recorte (fonte + filtro) feita no banco.
eduBR_contar_recorte <- function(tb) {
  n <- dplyr::collect(dplyr::summarise(tb, n = dplyr::n()))$n
  as.numeric(n[1])
}

# Valores distintos (n\u00e3o nulos) do desfecho no recorte, contados no banco.
eduBR_contar_niveis <- function(tb, coluna) {
  tb <- dplyr::filter(tb, !is.na(.data[[coluna]]))
  k <- dplyr::collect(
    dplyr::summarise(tb, k = dplyr::n_distinct(.data[[coluna]]))
  )$k
  as.numeric(k[1])
}

# ---------------------------------------------------------------------------
# especificar_regressao

eduBR_tool_especificar_regressao <- function(sessao) {
  fun <- function(outcome, predictors, cuts = NULL, modelo = "linear",
                  fonte = NULL, dados_id = NULL, filtro = NULL) {
    outcome <- eduBR_validar_nomes(outcome, "outcome")
    if (length(outcome) != 1L) {
      eduBR_abortar(
        "parametro_invalido",
        "`outcome` deve ser UMA coluna (o desfecho)."
      )
    }
    predictors <- eduBR_validar_nomes(predictors, "predictors")
    cuts <- eduBR_validar_nomes(cuts, "cuts", obrigatorio = FALSE)
    modelo <- eduBR_validar_enum(
      modelo %||% "linear", "modelo", eduBR_modelos_regressao()
    )
    fonte <- eduBR_validar_enum(
      fonte, "fonte", eduBR_fontes_regressao(),
      "Ou use `dados_id` com um handle de `covariaveis_escola`."
    )
    if (is.null(fonte) == is.null(dados_id)) {
      eduBR_abortar(
        "parametro_invalido",
        paste0(
          "Informe exatamente um entre `fonte` (dom\u00ednio do cat\u00e1logo, ex.: ",
          "\"ideb\") e `dados_id` (handle \"dados_<k>\" de ",
          "`covariaveis_escola`)."
        )
      )
    }
    if (outcome %in% c(predictors, cuts)) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf(
          "O desfecho `%s` n\u00e3o pode estar entre `predictors` ou `cuts`.",
          outcome
        )
      )
    }
    comuns <- intersect(predictors, cuts)
    if (length(comuns)) {
      eduBR_abortar(
        "parametro_invalido",
        sprintf(
          paste0(
            "Coluna(s) em `predictors` e `cuts` ao mesmo tempo: %s. Um corte ",
            "\u00e9 constante dentro de cada modelo; use-a em um s\u00f3 papel."
          ),
          paste(comuns, collapse = ", ")
        )
      )
    }
    pares <- eduBR_filtro_pares(filtro)

    dados <- if (!is.null(dados_id)) {
      eduBR_obter_dados_handle(sessao, dados_id)
    }
    base <- if (is.null(dados)) {
      eduBR_tbl(sessao$con, fonte)
    } else if (inherits(dados, "eduBR")) {
      consulta(dados)
    } else {
      dados
    }

    # Nomes e tipos sem coletar dados: tbl_vars() e protótipo de 0 linhas.
    colunas <- as.character(dplyr::tbl_vars(base))
    eduBR_validar_colunas_fonte(outcome, colunas, "`outcome`")
    eduBR_validar_colunas_fonte(predictors, colunas, "`predictors`")
    eduBR_validar_colunas_fonte(cuts, colunas, "`cuts`")
    filtro_lista <- NULL
    if (!is.null(pares)) {
      eduBR_validar_colunas_fonte(pares$coluna, colunas, "`filtro`")
      prototipo <- dplyr::collect(utils::head(
        dplyr::select(base, dplyr::all_of(unique(pares$coluna))), 0L
      ))
      filtro_lista <- eduBR_filtro_lista(pares, prototipo)
    }

    espec <- especificar_regressao(
      outcome = outcome, predictors = predictors, cuts = cuts,
      modelo = modelo, fonte = fonte, filtro = filtro_lista
    )
    origem <- if (is.null(dados_id)) fonte else dados_id
    formula <- eduBR_formula_texto(espec)
    filtro_txt <- eduBR_filtro_texto(filtro_lista)
    id <- eduBR_handle_guardar(
      sessao, "espec",
      list(espec = espec, dados = dados, dados_id = dados_id),
      descricao = paste0(
        modelo, " ", formula,
        if (length(cuts)) paste0(" por ", paste(cuts, collapse = ", ")) else "",
        " em ", origem,
        if (is.na(filtro_txt)) "" else paste0(" [", filtro_txt, "]")
      )
    )
    espec$id <- id
    assign(id, list(espec = espec, dados = dados, dados_id = dados_id),
           envir = sessao$handles$objetos)

    resumo <- tibble::tibble(
      handle = id,
      formula = formula,
      modelo = modelo,
      cortes = if (length(cuts)) paste(cuts, collapse = ", ") else NA_character_,
      fonte = fonte %||% NA_character_,
      dados_id = dados_id %||% NA_character_,
      filtro = filtro_txt
    )
    eduBR_resultado(
      resumo,
      grao = "especifica\u00e7\u00e3o de regress\u00e3o",
      filtros = list(fonte = fonte, dados_id = dados_id),
      handle = id,
      aviso = sprintf(
        "Especifica\u00e7\u00e3o guardada em %s; rode-a com `executar_regressao(espec_id = \"%s\")`.",
        id, id
      ),
      contexto = list(
        handle = id,
        outcome = outcome,
        predictors = I(predictors),
        cuts = I(cuts %||% character(0)),
        modelo = modelo,
        filtro = if (is.null(filtro_lista)) NULL else filtro_lista
      )
    )
  }
  eduBR_tool(
    sessao, "especificar_regressao", fun,
    descricao = paste0(
      "Declara uma regress\u00e3o (sem rodar): desfecho `outcome`, preditores ",
      "`predictors`, cortes opcionais `cuts` (a MESMA regress\u00e3o ser\u00e1 ",
      "ajustada separadamente para cada combina\u00e7\u00e3o de valores dos cortes, ",
      "ex.: por `localizacao` ou por `etapa`), `modelo` linear (padr\u00e3o) ou ",
      "logistico (desfecho bin\u00e1rio 0/1) e a base: EXATAMENTE UM entre ",
      "`fonte` (dom\u00ednio do cat\u00e1logo, ex.: \"ideb\" com `ideb_observado`, ",
      "`nota_media`, `etapa`, `ano`, `sg_uf`, `rede`) e `dados_id` (handle ",
      "\"dados_<k>\" devolvido por `covariaveis_escola`, a base escola \u00d7 ",
      "covari\u00e1veis). `filtro` restringe a base por igualdades (combinadas ",
      "com E), ex.: [{\"coluna\":\"ano\",\"valor\":\"2023\"}, ",
      "{\"coluna\":\"sg_uf\",\"valor\":\"AC\"}]; valores num\u00e9ricos em texto ",
      "viram n\u00famero em colunas num\u00e9ricas. Os nomes de colunas s\u00e3o ",
      "conferidos na base antes de guardar (erro lista as colunas ",
      "dispon\u00edveis; consulte `metadados.contexto.colunas` de ",
      "`covariaveis_escola`). Devolve a f\u00f3rmula leg\u00edvel e o handle ",
      "\"espec_<k>\" para `executar_regressao`. Cuidados: o desfecho n\u00e3o pode ",
      "ser preditor nem corte; filtre a fonte (ano, UF, etapa) para o recorte ",
      "caber no limite de linhas da execu\u00e7\u00e3o."
    ),
    arguments = list(
      outcome = ellmer::type_string(
        "Coluna do desfecho (ex.: \"ideb_fund_i\", \"ideb_observado\")."
      ),
      predictors = ellmer::type_array(
        ellmer::type_string("Nome exato de uma coluna preditora."),
        "Colunas preditoras (ex.: [\"in_biblioteca\", \"docentes\"])."
      ),
      cuts = ellmer::type_array(
        ellmer::type_string("Nome exato de uma coluna de corte."),
        paste0(
          "Colunas de corte: um modelo por combina\u00e7\u00e3o de valores (ex.: ",
          "[\"localizacao\"]). Omita para um modelo \u00fanico."
        ),
        required = FALSE
      ),
      modelo = ellmer::type_enum(
        eduBR_modelos_regressao(),
        "\"linear\" (padr\u00e3o) ou \"logistico\" (desfecho bin\u00e1rio).",
        required = FALSE
      ),
      fonte = ellmer::type_enum(
        eduBR_fontes_regressao(),
        "Dom\u00ednio do cat\u00e1logo usado como base. Use isto OU `dados_id`.",
        required = FALSE
      ),
      dados_id = ellmer::type_string(
        paste0(
          "Handle de dados \"dados_<k>\" (ex.: de `covariaveis_escola`). Use ",
          "isto OU `fonte`."
        ),
        required = FALSE
      ),
      filtro = ellmer::type_array(
        ellmer::type_object(
          "Igualdade coluna == valor.",
          coluna = ellmer::type_string("Nome exato da coluna."),
          valor = ellmer::type_string(
            "Valor como texto (ex.: \"2023\", \"AC\", \"Municipal\")."
          )
        ),
        "Igualdades aplicadas \u00e0 base antes do ajuste, combinadas com E.",
        required = FALSE
      )
    ),
    titulo = "Especificar regress\u00e3o"
  )
}

# ---------------------------------------------------------------------------
# executar_regressao

eduBR_tool_executar_regressao <- function(sessao) {
  fun <- function(espec_id) {
    guardado <- eduBR_obter_handle_tipo(
      sessao, espec_id, "espec", "espec_id", "especificar_regressao"
    )
    espec <- guardado$espec
    dados <- guardado$dados

    # Conta o recorte no banco antes de coletar (executar_regressao() coleta
    # o recorte filtrado inteiro).
    recorte <- eduBR_espec_tbl(sessao$con, espec, dados)
    n_recorte <- eduBR_contar_recorte(recorte)
    teto <- sessao$limites$max_amostra
    if (n_recorte > teto) {
      eduBR_abortar(
        "limite_excedido",
        sprintf(
          paste0(
            "O recorte de %s tem %s linhas, acima do limite de %s linhas por ",
            "execu\u00e7\u00e3o. Nada foi coletado. Restrinja a base: acrescente ",
            "igualdades em `filtro` (ex.: ano, sg_uf, etapa, rede) ou use um ",
            "handle de `covariaveis_escola` filtrado por `uf`/`rede`, e ",
            "especifique de novo."
          ),
          espec_id,
          format(n_recorte, big.mark = ".", decimal.mark = ",",
                 scientific = FALSE),
          format(teto, big.mark = ".", decimal.mark = ",", scientific = FALSE)
        )
      )
    }
    if (n_recorte == 0) {
      eduBR_abortar(
        "sem_dados",
        sprintf(
          "O recorte de %s n\u00e3o tem linhas; confira os valores do `filtro`.",
          espec_id
        )
      )
    }

    if (identical(espec$modelo, "logistico")) {
      # Desfecho da log\u00edstica precisa ter exatamente 2 valores no recorte.
      niveis <- eduBR_contar_niveis(recorte, espec$outcome)
      if (niveis != 2) {
        eduBR_abortar(
          "parametro_invalido",
          sprintf(
            paste0(
              "O modelo log\u00edstico exige desfecho bin\u00e1rio, mas `%s` tem %s ",
              "valores distintos no recorte de %s. Use `modelo = \"linear\"` ",
              "ou um desfecho 0/1 (ex.: colunas `in_*`)."
            ),
            espec$outcome, format(niveis), espec_id
          )
        )
      }
    }

    reg <- executar_regressao(sessao$con, espec, dados = dados)
    cortes <- espec$cuts %||% character(0)
    ajustado <- !vapply(reg$modelo, is.null, logical(1))
    id <- eduBR_handle_guardar(
      sessao, "regressao", reg,
      descricao = sprintf(
        "%s: %d modelo(s) ajustado(s) de %d corte(s)",
        espec_id, sum(ajustado), nrow(reg)
      )
    )

    resumo <- tibble::as_tibble(reg)[cortes]
    resumo$n <- reg$n
    resumo$ajustado <- ajustado
    if (length(cortes)) {
      resumo <- resumo[do.call(order, unname(as.list(resumo[cortes]))), ]
    }
    aviso <- NULL
    n_usado <- sum(reg$n)
    if (n_usado < n_recorte) {
      aviso <- sprintf(
        paste0(
          "%s de %s linhas do recorte foram descartadas por `null` no ",
          "desfecho ou nos preditores (ex.: escolas sem IDEB na etapa)."
        ),
        format(n_recorte - n_usado, big.mark = ".", decimal.mark = ",",
               scientific = FALSE),
        format(n_recorte, big.mark = ".", decimal.mark = ",",
               scientific = FALSE)
      )
    }
    if (any(!ajustado)) {
      aviso <- c(aviso, sprintf(
        paste0(
          "%d corte(s) sem modelo: linhas completas insuficientes (n \u2264 ",
          "n\u00ba de preditores + 1). Cortes com n pequeno, mesmo ajustados, ",
          "t\u00eam estimativas inst\u00e1veis."
        ),
        sum(!ajustado)
      ))
    }
    if (length(aviso)) {
      aviso <- paste(aviso, collapse = " ")
    }
    eduBR_resultado(
      resumo,
      grao = if (length(cortes)) {
        paste0("corte (", paste(cortes, collapse = " \u00d7 "), ")")
      } else {
        "modelo \u00fanico"
      },
      filtros = list(espec_id = espec_id),
      handle = id,
      aviso = aviso,
      contexto = list(
        handle = id,
        espec_id = espec_id,
        formula = eduBR_formula_texto(espec),
        modelo = espec$modelo,
        n_recorte = n_recorte,
        n_usado = n_usado,
        n_cortes = nrow(reg),
        n_ajustados = sum(ajustado)
      )
    )
  }
  eduBR_tool(
    sessao, "executar_regressao", fun,
    descricao = paste0(
      "Roda uma especifica\u00e7\u00e3o (`espec_id` de `especificar_regressao`): ",
      "ajusta a MESMA regress\u00e3o para cada combina\u00e7\u00e3o de valores dos ",
      "cortes. Antes de rodar conta as linhas do recorte (base + filtro); se ",
      "passar do limite da sess\u00e3o (padr\u00e3o 15.000) devolve ",
      "`limite_excedido` sem coletar, e voc\u00ea deve filtrar mais. Devolve uma ",
      "linha por corte com `n` (linhas completas usadas) e `ajustado` (false ",
      "quando o corte tem poucas linhas e ficou sem modelo) e o handle ",
      "\"regressao_<k>\" para `coeficientes` e `metricas`. Cuidados: \u00e9 ",
      "ASSOCIA\u00c7\u00c3O, n\u00e3o causalidade (vari\u00e1veis omitidas, sele\u00e7\u00e3o); ",
      "linhas com `null` no desfecho ou nos preditores s\u00e3o descartadas; ",
      "cortes pequenos (n de poucas dezenas) d\u00e3o estimativas inst\u00e1veis ",
      "\u2014 n\u00e3o compare cortes sem olhar `n` e o erro-padr\u00e3o."
    ),
    arguments = list(
      espec_id = ellmer::type_string(
        "Handle \"espec_<k>\" devolvido por `especificar_regressao`."
      )
    ),
    titulo = "Executar regress\u00e3o"
  )
}

# ---------------------------------------------------------------------------
# coeficientes / metricas

eduBR_tool_coeficientes <- function(sessao) {
  fun <- function(regressao_id, n = NULL) {
    eduBR_validar_n(n)
    reg <- eduBR_obter_handle_tipo(
      sessao, regressao_id, "regressao", "regressao_id", "executar_regressao"
    )
    cf <- coeficientes(reg)
    cf <- dplyr::rename(
      cf,
      dplyr::any_of(c(termo = "term", estimativa = "estimate",
                      erro_padrao = "std.error", estatistica = "statistic",
                      p_valor = "p.value"))
    )
    eduBR_resultado(
      cf,
      grao = "corte \u00d7 termo do modelo",
      filtros = list(regressao_id = regressao_id)
    )
  }
  eduBR_tool(
    sessao, "coeficientes", fun,
    descricao = paste0(
      "Coeficientes de uma regress\u00e3o executada (`regressao_id`): uma linha ",
      "por corte \u00d7 termo, com os valores dos cortes, `termo`, `estimativa`, ",
      "`erro_padrao`, `estatistica` (t no linear, z no log\u00edstico) e ",
      "`p_valor`. Leitura: no linear, a estimativa \u00e9 a varia\u00e7\u00e3o m\u00e9dia do ",
      "desfecho por unidade do preditor, mantidos os demais; no log\u00edstico, ",
      "\u00e9 a varia\u00e7\u00e3o no log-odds (exp(estimativa) = raz\u00e3o de chances). ",
      "`(Intercept)` raramente tem leitura substantiva. Cortes sem modelo n\u00e3o ",
      "aparecem. Cuidados: associa\u00e7\u00e3o, n\u00e3o causalidade; p-valores n\u00e3o ",
      "corrigem m\u00faltiplas compara\u00e7\u00f5es entre cortes."
    ),
    arguments = list(
      regressao_id = ellmer::type_string(
        "Handle \"regressao_<k>\" devolvido por `executar_regressao`."
      ),
      n = eduBR_arg_n()
    ),
    titulo = "Coeficientes da regress\u00e3o"
  )
}

eduBR_tool_metricas <- function(sessao) {
  fun <- function(regressao_id, n = NULL) {
    eduBR_validar_n(n)
    reg <- eduBR_obter_handle_tipo(
      sessao, regressao_id, "regressao", "regressao_id", "executar_regressao"
    )
    mt <- metricas(reg)
    mt <- dplyr::rename(
      mt,
      dplyr::any_of(c(
        r2 = "r.squared", r2_ajustado = "adj.r.squared", p_valor = "p.value",
        estatistica = "statistic", gl = "df", gl_residuo = "df.residual",
        log_verossimilhanca = "logLik", deviance_nula = "null.deviance",
        gl_nulo = "df.null"
      ))
    )
    eduBR_resultado(
      mt,
      grao = "corte (m\u00e9tricas do modelo)",
      filtros = list(regressao_id = regressao_id)
    )
  }
  eduBR_tool(
    sessao, "metricas", fun,
    descricao = paste0(
      "M\u00e9tricas de ajuste de uma regress\u00e3o executada (`regressao_id`), ",
      "uma linha por corte com modelo. Linear: `r2` (fra\u00e7\u00e3o da vari\u00e2ncia ",
      "do desfecho explicada), `r2_ajustado` (penaliza preditores), `sigma` ",
      "(erro t\u00edpico na escala do desfecho), `estatistica`/`p_valor` (teste F ",
      "do modelo), `AIC`/`BIC` (menor \u00e9 melhor, s\u00f3 entre modelos do MESMO ",
      "recorte e desfecho) e `nobs` (linhas usadas). Log\u00edstico: `auc` (0,5 = ",
      "acaso, 1 = separa\u00e7\u00e3o perfeita), `mcfadden` (pseudo-R\u00b2; 0,2 a 0,4 j\u00e1 ",
      "\u00e9 bom ajuste), `deviance` vs `deviance_nula`, `AIC`/`BIC` e `nobs`. ",
      "Cuidados: r2 baixo \u00e9 comum em dados educacionais e n\u00e3o invalida um ",
      "coeficiente; m\u00e9tricas em cortes com `nobs` pequeno s\u00e3o inst\u00e1veis."
    ),
    arguments = list(
      regressao_id = ellmer::type_string(
        "Handle \"regressao_<k>\" devolvido por `executar_regressao`."
      ),
      n = eduBR_arg_n()
    ),
    titulo = "M\u00e9tricas da regress\u00e3o"
  )
}

# ---------------------------------------------------------------------------
# listar_handles

eduBR_tool_listar_handles <- function(sessao) {
  fun <- function() {
    lst <- eduBR_handle_listar(sessao)
    if (!nrow(lst)) {
      return(eduBR_resultado(
        NULL, grao = "handle",
        aviso = paste0(
          "Nenhum handle nesta sess\u00e3o ainda. Bases v\u00eam de ",
          "`covariaveis_escola`, especifica\u00e7\u00f5es de `especificar_regressao` e ",
          "resultados de `executar_regressao`."
        )
      ))
    }
    eduBR_resultado(lst, grao = "handle", n_padrao = 1000L)
  }
  eduBR_tool(
    sessao, "listar_handles", fun,
    descricao = paste0(
      "Lista os handles (ids de objetos guardados) desta sess\u00e3o, na ordem ",
      "de cria\u00e7\u00e3o: `id` (ex.: \"dados_1\"), `tipo` (",
      paste(eduBR_tipos_handle(), collapse = ", "),
      ") e uma `descricao` curta de origem (ex.: \"covariaveis_escola uf=AC ",
      "rede=Municipal\"). Use para retomar um encadeamento sem refazer ",
      "consultas: `dados_<k>` vai em `especificar_regressao(dados_id=)`, ",
      "`espec_<k>` em `executar_regressao`, `regressao_<k>` em ",
      "`coeficientes`/`metricas`. Handles somem ao fim da sess\u00e3o. N\u00e3o ",
      "recebe argumentos."
    ),
    titulo = "Handles da sess\u00e3o"
  )
}
