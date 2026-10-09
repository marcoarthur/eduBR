# R/ellmer_tools_pesquisa.R
#
# Tools da pesquisadora na camada ellmer (plans/ellmer-tools.md, chunk 3):
# municipios, redes_municipio, docentes_rede, ideb, tendencia_ideb_regiao,
# covariaveis_escola (handle) e perfil_gestor. Como no chunk 2, cada tool só
# envolve funções existentes do pacote e valida os argumentos **antes** do
# dbplyr. Os enums reaproveitam os mapas do pacote: UF/região de regiao.R
# (eduBR_ufs(), eduBR_regioes() derivada de eduBR_mutate_regiao()), rede e
# localização de eduBR_rotulos() (os mesmos rótulos de eduBR_codigos_rede()/
# eduBR_codigos_localizacao(), que fazem a tradução no SQL).

# ---------------------------------------------------------------------------
# Valores aceitos

# Redes: rótulos do pacote; `publica` só onde a função usa eduBR_codigos_rede().
eduBR_redes_tool <- function(publica = FALSE) {
  r <- unname(eduBR_rotulos()$rede)
  if (publica) c(r, "publica") else r
}

eduBR_localizacoes_tool <- function() {
  tolower(unname(eduBR_rotulos()$localizacao))
}

eduBR_cortes_gestor <- function() {
  c("brasil", "rede", "regiao", "uf", "categoria_privada")
}

eduBR_niveis_docentes <- function() c("brasil", "uf", "regiao", "municipio")

# ---------------------------------------------------------------------------
# Validação

# Enum opcional: NULL passa; fora de `valores` vira parametro_invalido.
eduBR_validar_enum <- function(x, nome, valores, dica = NULL) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x) || !x %in% valores) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        "`%s` inv\u00e1lido: %s. Use exatamente um de: %s.%s",
        nome, eduBR_valor_texto(x), paste(valores, collapse = ", "),
        if (is.null(dica)) "" else paste0(" ", dica)
      )
    )
  }
  x
}

eduBR_validar_uf <- function(uf) {
  eduBR_validar_enum(
    uf, "uf", eduBR_ufs(), "Siglas em mai\u00fasculas (ex.: \"SP\")."
  )
}

eduBR_validar_regiao <- function(regiao) {
  reg <- eduBR_regioes()
  eduBR_validar_enum(
    regiao, "regiao", c(reg$nomes, reg$siglas),
    "Grafia do pacote: \"Centro-oeste\" (o min\u00fasculo) ou a sigla \"CO\"."
  )
}

eduBR_validar_rede <- function(rede, publica = FALSE) {
  eduBR_validar_enum(
    rede, "rede", eduBR_redes_tool(publica),
    "Rede com inicial mai\u00fascula (ex.: \"Municipal\")."
  )
}

eduBR_validar_localizacao <- function(localizacao) {
  eduBR_validar_enum(localizacao, "localizacao", eduBR_localizacoes_tool())
}

# `n` opcional (o cap efetivo é aplicado depois por eduBR_cap_n()).
eduBR_validar_n <- function(n) {
  if (is.null(n)) {
    return(NULL)
  }
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 1 ||
      n != round(n)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf("`n` deve ser um inteiro positivo; recebido: %s.",
              eduBR_valor_texto(n))
    )
  }
  n
}

# Ano do Censo Escolar (a base tem só 2025; outros anos dão `sem_dados`).
eduBR_validar_ano_censo <- function(ano) {
  eduBR_validar_inteiro(ano, "ano", 1995L, 2100L)
}

# Edição do IDEB num argumento genérico (`ano` ou `ano_ideb`).
eduBR_validar_edicao <- function(x, nome) {
  if (is.null(x)) {
    return(NULL)
  }
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x) &&
    x %in% eduBR_edicoes_ideb()
  if (!ok) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        "`%s` inv\u00e1lido: %s. O IDEB \u00e9 bienal; use uma edi\u00e7\u00e3o entre 2005 e 2023 (%s).",
        nome, eduBR_valor_texto(x),
        paste(eduBR_edicoes_ideb(), collapse = ", ")
      )
    )
  }
  as.integer(x)
}

# `colunas` de docentes_rede(): valida contra a lista determinística que a
# própria função usa para projetar (sem consultar o banco; nomes fora dela
# seriam descartados em silêncio pela função).
eduBR_validar_colunas_docente <- function(colunas) {
  if (is.null(colunas)) {
    return(NULL)
  }
  colunas <- unlist(colunas, use.names = FALSE)
  if (!is.character(colunas) || !length(colunas) || anyNA(colunas)) {
    eduBR_abortar(
      "parametro_invalido",
      "`colunas` deve ser uma lista n\u00e3o vazia de nomes de colunas `qt_doc_*`."
    )
  }
  validas <- .eduBR_colunas_docente()
  invalidas <- setdiff(colunas, validas)
  if (length(invalidas)) {
    eduBR_abortar(
      "parametro_invalido",
      sprintf(
        paste0(
          "`colunas` com nome(s) inexistente(s): %s. Use nomes `qt_doc_*` ",
          "exatos; prefixos \u00fateis: %s. Omita `colunas` para trazer todas."
        ),
        paste(utils::head(invalidas, 5L), collapse = ", "),
        eduBR_prefixos_docente_texto()
      )
    )
  }
  unique(colunas)
}

eduBR_prefixos_docente_texto <- function() {
  paste0(
    "qt_doc_bas (total), qt_doc_fund_ai/qt_doc_fund_af/qt_doc_med (etapa), ",
    "qt_doc_bas_esco_* (forma\u00e7\u00e3o: ef, em, sup_grad, sup_grad_licen, ",
    "sup_pos_espec, sup_pos_mestra, sup_pos_douto, sup_pos_nenhum), ",
    "qt_doc_bas_vinculo_* (concur, contra, terceir, clt), ",
    "qt_doc_bas_espec_* (forma\u00e7\u00e3o continuada), qt_doc_bas_disc_* ",
    "(disciplina lecionada), qt_doc_bas_fem/masc, qt_doc_bas_branca/preta/",
    "parda/amarela/indigena, faixas et\u00e1rias qt_doc_bas_0_24 a ",
    "qt_doc_bas_60_mais, qt_doc_bas_pcd"
  )
}

# ---------------------------------------------------------------------------
# Argumentos (tipos ellmer)

eduBR_arg_uf <- function(descricao = "Sigla da UF (ex.: \"SP\"); omita para o Brasil todo.") {
  ellmer::type_enum(eduBR_ufs(), descricao, required = FALSE)
}

eduBR_arg_regiao <- function() {
  reg <- eduBR_regioes()
  ellmer::type_enum(
    c(reg$nomes, reg$siglas),
    paste0(
      "Macrorregi\u00e3o do IBGE pelo nome (Norte, Nordeste, Sudeste, Sul, ",
      "Centro-oeste) ou sigla (N, NE, SE, S, CO); omita para todas."
    ),
    required = FALSE
  )
}

eduBR_arg_rede <- function(publica = FALSE) {
  ellmer::type_enum(
    eduBR_redes_tool(publica),
    paste0(
      "Rede (depend\u00eancia administrativa) da escola",
      if (publica) "; \"publica\" junta Federal, Estadual e Municipal" else "",
      ". Omita para todas."
    ),
    required = FALSE
  )
}

eduBR_arg_localizacao <- function() {
  ellmer::type_enum(
    eduBR_localizacoes_tool(),
    "Localiza\u00e7\u00e3o da escola (urbana ou rural); omita para ambas.",
    required = FALSE
  )
}

eduBR_arg_n <- function(padrao = 100L) {
  ellmer::type_integer(
    sprintf(
      "Quantas linhas devolver (padr\u00e3o %d, m\u00e1ximo 1000 por chamada).",
      as.integer(padrao)
    ),
    required = FALSE
  )
}

# ---------------------------------------------------------------------------
# municipios

eduBR_tool_municipios <- function(sessao) {
  fun <- function(uf = NULL, n = NULL) {
    uf <- eduBR_validar_uf(uf)
    eduBR_validar_n(n)
    tb <- consulta(municipios(sessao$con, uf = uf)) |>
      dplyr::select(-dplyr::any_of(c("geometry", "geom", "geometria_corrigida")))
    eduBR_resultado(tb, grao = "munic\u00edpio", filtros = list(uf = uf))
  }
  eduBR_tool(
    sessao, "municipios", fun,
    descricao = paste0(
      "Tabela de munic\u00edpios do IBGE (todas as 27 UFs, 5.570 munic\u00edpios): ",
      "c\u00f3digo IBGE, nome, UF, regi\u00e3o imediata/intermedi\u00e1ria, ",
      "macrorregi\u00e3o e \u00e1rea (km\u00b2). Use para achar o c\u00f3digo de um ",
      "munic\u00edpio pelo nome (ou o contr\u00e1rio) antes de cruzar fontes. ",
      "Cuidados: a chave \u00e9 `codigo_ibge`, TEXTO de 7 d\u00edgitos (\"3555406\"), ",
      "que casa com `co_municipio` de `redes_municipio`; `id_original` \u00e9 ",
      "interno e chega como texto. N\u00e3o devolve geometria. Sem `uf` traz o ",
      "pa\u00eds todo e corta no limite de linhas: filtre por `uf`."
    ),
    arguments = list(uf = eduBR_arg_uf(), n = eduBR_arg_n()),
    titulo = "Munic\u00edpios (IBGE)"
  )
}

# ---------------------------------------------------------------------------
# redes_municipio

eduBR_tool_redes_municipio <- function(sessao) {
  fun <- function(uf = NULL, regiao = NULL, rede = NULL, n = NULL) {
    uf <- eduBR_validar_uf(uf)
    regiao <- eduBR_validar_regiao(regiao)
    rede <- eduBR_validar_rede(rede, publica = TRUE)
    eduBR_validar_n(n)
    eduBR_resultado(
      rede_municipio(sessao$con, uf = uf, regiao = regiao, rede = rede),
      grao = "munic\u00edpio \u00d7 rede",
      filtros = list(uf = uf, regiao = regiao, rede = rede),
      n_padrao = 20L
    )
  }
  eduBR_tool(
    sessao, "redes_municipio", fun,
    descricao = paste0(
      "Redes escolares de cada munic\u00edpio, uma linha por munic\u00edpio \u00d7 rede ",
      "(Federal, Estadual, Municipal, Privada): total de escolas, ",
      "matr\u00edculas por etapa, docentes (com superior e concursados, em ",
      "n\u00famero e %), alunos por docente e por escola, e o IDEB m\u00e9dio da rede ",
      "no munic\u00edpio por etapa (`ideb_fund_i`, `ideb_fund_ii`, `ideb_medio`, ",
      "edi\u00e7\u00e3o em `ano_ideb`). Responde \"quais redes atendem cada munic\u00edpio ",
      "e como se comparam?\". Cuidados: o IDEB vem `null` onde a rede n\u00e3o foi ",
      "avaliada naquela etapa (cobertura incompleta, n\u00e3o \u00e9 zero); compare ",
      "IDEB s\u00f3 na mesma edi\u00e7\u00e3o e etapa; contagens (`total_*`, ",
      "`matriculas_*`, `docentes_*`) chegam como TEXTO (inteiros grandes) e ",
      "devem ser convertidas para n\u00famero; `co_municipio` \u00e9 o c\u00f3digo IBGE ",
      "(texto). Filtre por `uf` ou `regiao`: o Brasil todo tem ~15 mil linhas."
    ),
    arguments = list(
      uf = eduBR_arg_uf(),
      regiao = eduBR_arg_regiao(),
      rede = eduBR_arg_rede(publica = TRUE),
      n = eduBR_arg_n(20L)
    ),
    titulo = "Redes por munic\u00edpio"
  )
}

# ---------------------------------------------------------------------------
# docentes_rede

eduBR_tool_docentes_rede <- function(sessao) {
  fun <- function(nivel = "brasil", uf = NULL, regiao = NULL, rede = NULL,
                  localizacao = NULL, ano = 2025L, colunas = NULL, n = NULL) {
    nivel <- eduBR_validar_enum(
      nivel %||% "brasil", "nivel", eduBR_niveis_docentes()
    )
    uf <- eduBR_validar_uf(uf)
    regiao <- eduBR_validar_regiao(regiao)
    rede <- eduBR_validar_rede(rede, publica = TRUE)
    localizacao <- eduBR_validar_localizacao(localizacao)
    ano <- eduBR_validar_ano_censo(ano %||% 2025L)
    colunas <- eduBR_validar_colunas_docente(colunas)
    eduBR_validar_n(n)
    grao <- switch(
      nivel,
      brasil = "rede \u00d7 localiza\u00e7\u00e3o (Brasil)",
      regiao = "regi\u00e3o \u00d7 rede \u00d7 localiza\u00e7\u00e3o",
      uf = "UF \u00d7 rede \u00d7 localiza\u00e7\u00e3o",
      municipio = "munic\u00edpio \u00d7 rede \u00d7 localiza\u00e7\u00e3o"
    )
    eduBR_resultado(
      docentes_rede(
        sessao$con, ano = ano, rede = rede, uf = uf, regiao = regiao,
        localizacao = localizacao, nivel = nivel, colunas = colunas
      ),
      grao = grao,
      filtros = list(nivel = nivel, uf = uf, regiao = regiao, rede = rede,
                     localizacao = localizacao, ano = ano,
                     colunas = if (is.null(colunas)) NULL else I(colunas))
    )
  }
  eduBR_tool(
    sessao, "docentes_rede", fun,
    descricao = paste0(
      "Perfil docente do Censo Escolar somado por rede, localiza\u00e7\u00e3o ",
      "(Urbana/Rural) e territ\u00f3rio (`nivel`: brasil [padr\u00e3o desta ",
      "ferramenta], regiao, uf ou municipio). Responde \"o perfil docente ",
      "muda entre regi\u00f5es/redes?\" (forma\u00e7\u00e3o, v\u00ednculo, sexo, cor/ra\u00e7a, ",
      "idade, disciplina). Cada coluna `qt_doc_*` \u00e9 uma CONTAGEM de docentes ",
      "(somada sobre as escolas do grupo); para comparar grupos divida pelo ",
      "total `qt_doc_bas`. Cuidados: um docente que leciona em mais de uma ",
      "escola conta em cada uma (\u00e9 soma de v\u00ednculos escola-docente, n\u00e3o ",
      "pessoas \u00fanicas); as contagens chegam como TEXTO (inteiros grandes) e ",
      "devem ser convertidas; o Censo dispon\u00edvel \u00e9 2025 (`ano`). Sem ",
      "`colunas` vem ~100 contagens por linha: pe\u00e7a s\u00f3 as necess\u00e1rias, ",
      "sobretudo em `nivel` uf/municipio. Colunas por prefixo: ",
      eduBR_prefixos_docente_texto(), "."
    ),
    arguments = list(
      nivel = ellmer::type_enum(
        eduBR_niveis_docentes(),
        "N\u00edvel territorial de agrega\u00e7\u00e3o; padr\u00e3o \"brasil\".",
        required = FALSE
      ),
      uf = eduBR_arg_uf(),
      regiao = eduBR_arg_regiao(),
      rede = eduBR_arg_rede(publica = TRUE),
      localizacao = eduBR_arg_localizacao(),
      ano = ellmer::type_integer(
        "Ano do Censo Escolar (padr\u00e3o 2025, o \u00fanico carregado).",
        required = FALSE
      ),
      colunas = ellmer::type_array(
        ellmer::type_string("Nome exato de uma coluna `qt_doc_*`."),
        paste0(
          "Contagens a incluir (ex.: [\"qt_doc_bas_esco_sup_grad\", ",
          "\"qt_doc_bas_vinculo_concur\"]); `qt_doc_bas` vem sempre. Omita ",
          "para todas."
        ),
        required = FALSE
      ),
      n = eduBR_arg_n()
    ),
    titulo = "Perfil docente por rede e territ\u00f3rio"
  )
}

# ---------------------------------------------------------------------------
# ideb

eduBR_tool_ideb <- function(sessao) {
  fun <- function(uf = NULL, municipio = NULL, etapa = NULL, rede = NULL,
                  ano = NULL, n = NULL) {
    uf <- eduBR_validar_uf(uf)
    municipio <- eduBR_validar_texto(municipio, "municipio")
    etapa <- eduBR_validar_etapa(etapa)
    rede <- eduBR_validar_rede(rede)
    ano <- eduBR_validar_edicao(ano, "ano")
    eduBR_validar_n(n)
    if (is.null(uf) && is.null(municipio) && is.null(etapa) &&
        is.null(rede) && is.null(ano)) {
      eduBR_abortar(
        "parametro_invalido",
        paste0(
          "Informe ao menos um filtro (`uf`, `municipio`, `etapa`, `rede` ou ",
          "`ano`): o IDEB tem ~814 mil linhas (escola \u00d7 etapa \u00d7 edi\u00e7\u00e3o). ",
          "Para a s\u00e9rie de uma escola use `perfil_escola`; para tend\u00eancias ",
          "regionais, `tendencia_ideb_regiao`."
        )
      )
    }
    aviso <- if (!is.null(municipio) && is.null(uf)) {
      paste0(
        "Nomes de munic\u00edpio se repetem entre UFs; informe `uf` para n\u00e3o ",
        "misturar hom\u00f4nimos."
      )
    }
    tb <- consulta(ideb(
      sessao$con, uf = uf, municipio = municipio, etapa = etapa,
      rede = rede, ano = ano
    )) |>
      dplyr::arrange(.data$ano, .data$etapa, .data$id_escola)
    eduBR_resultado(
      tb,
      grao = "escola \u00d7 etapa \u00d7 edi\u00e7\u00e3o do IDEB",
      filtros = list(uf = uf, municipio = municipio, etapa = etapa,
                     rede = rede, ano = ano),
      aviso = aviso,
      n_padrao = 20L
    )
  }
  eduBR_tool(
    sessao, "ideb", fun,
    descricao = paste0(
      "IDEB observado por escola, uma linha por escola \u00d7 etapa \u00d7 edi\u00e7\u00e3o ",
      "(bienal, 2005 a 2023; ensino m\u00e9dio por escola s\u00f3 nas edi\u00e7\u00f5es ",
      "recentes), com taxas de aprova\u00e7\u00e3o, notas SAEB de matem\u00e1tica e ",
      "portugu\u00eas, nota m\u00e9dia padronizada, IDEB observado e a meta ",
      "projetada. Use para recortes por UF, munic\u00edpio, rede, etapa e ",
      "edi\u00e7\u00e3o. EXIGE ao menos um filtro. Cuidados: s\u00f3 compare IDEB dentro ",
      "da MESMA edi\u00e7\u00e3o e da MESMA rede (e etapa: escalas diferentes); ",
      "escolas sem nota v\u00eam `null` (poucos alunos avaliados), n\u00e3o zero; ",
      "`id_escola` (c\u00f3digo INEP) chega como TEXTO; `municipio` \u00e9 o NOME ",
      "exato com acentos (\"S\u00e3o Paulo\"), combine com `uf`. Ordenado por ",
      "edi\u00e7\u00e3o, etapa e escola; o resultado \u00e9 cortado no limite de linhas."
    ),
    arguments = list(
      uf = eduBR_arg_uf("Sigla da UF (ex.: \"SP\")."),
      municipio = ellmer::type_string(
        "Nome do munic\u00edpio, grafia exata com acentos (ex.: \"Ubatuba\").",
        required = FALSE
      ),
      etapa = eduBR_arg_etapa("Etapa do IDEB."),
      rede = eduBR_arg_rede(),
      ano = ellmer::type_integer(
        "Edi\u00e7\u00e3o do IDEB (bienal: 2005, 2007, ..., 2023).",
        required = FALSE
      ),
      n = eduBR_arg_n(20L)
    ),
    titulo = "IDEB por escola"
  )
}

# ---------------------------------------------------------------------------
# tendencia_ideb_regiao

# Achata a saída de tendencia_regiao(): uma linha por região × etapa × termo,
# com r² e nobs do mesmo modelo.
eduBR_tendencia_achatar <- function(tr) {
  linhas <- lapply(seq_len(nrow(tr)), function(i) {
    cf <- tr$coeficientes[[i]]
    mt <- tr$metricas[[i]]
    anos <- tr$data[[i]]$ano
    tibble::tibble(
      nome_regiao = tr$nome_regiao[[i]],
      sigla_regiao = tr$sigla_regiao[[i]],
      etapa = tr$etapa[[i]],
      n_anos = tr$n_anos[[i]],
      ano_inicial = if (length(anos)) as.integer(min(anos)) else NA_integer_,
      ano_final = if (length(anos)) as.integer(max(anos)) else NA_integer_,
      termo = cf$term,
      estimativa = cf$estimate,
      erro_padrao = cf$std.error,
      p_valor = cf$p.value,
      r2 = mt$r.squared[[1]],
      nobs = as.integer(mt$nobs[[1]])
    )
  })
  dplyr::bind_rows(linhas)
}

eduBR_tool_tendencia_ideb_regiao <- function(sessao) {
  fun <- function(etapa = NULL, rede = NULL) {
    etapa <- eduBR_validar_etapa(etapa)
    rede <- eduBR_validar_rede(rede)
    tr <- tendencia_regiao(sessao$con, etapa = etapa, rede = rede)
    if (!nrow(tr)) {
      eduBR_abortar(
        "sem_dados",
        "Sem IDEB para o recorte (etapa/rede) informado."
      )
    }
    eduBR_resultado(
      eduBR_tendencia_achatar(tr),
      grao = "regi\u00e3o \u00d7 etapa \u00d7 termo do modelo",
      filtros = list(etapa = etapa, rede = rede)
    )
  }
  eduBR_tool(
    sessao, "tendencia_ideb_regiao", fun,
    descricao = paste0(
      "Tend\u00eancia LINEAR do IDEB m\u00e9dio de cada macrorregi\u00e3o ao longo das ",
      "edi\u00e7\u00f5es: para cada regi\u00e3o \u00d7 etapa ajusta `ideb_medio ~ ano` (m\u00e9dia ",
      "simples das escolas por edi\u00e7\u00e3o). Cada linha \u00e9 um termo do modelo: ",
      "`termo = \"ano\"` \u00e9 a inclina\u00e7\u00e3o (pontos de IDEB por ano; \u00d72 = por ",
      "edi\u00e7\u00e3o) e `(Intercept)` \u00e9 o valor extrapolado para o ano 0 (sem ",
      "leitura substantiva). Traz estimativa, erro-padr\u00e3o, p-valor, `r2` e ",
      "`nobs` (n\u00ba de edi\u00e7\u00f5es) do mesmo modelo e o intervalo de anos. ",
      "Cuidados: \u00e9 associa\u00e7\u00e3o temporal bivariada, N\u00c3O causal; com poucas ",
      "edi\u00e7\u00f5es (ensino m\u00e9dio tem 4) o p-valor e o r2 s\u00e3o fr\u00e1geis; a ",
      "composi\u00e7\u00e3o das escolas avaliadas muda entre edi\u00e7\u00f5es. Filtre por ",
      "`rede` para n\u00e3o misturar redes."
    ),
    arguments = list(
      etapa = eduBR_arg_etapa("Etapa do IDEB; omita para as tr\u00eas."),
      rede = eduBR_arg_rede()
    ),
    titulo = "Tend\u00eancia do IDEB por regi\u00e3o"
  )
}

# ---------------------------------------------------------------------------
# covariaveis_escola

# Escolas da base e escolas com IDEB por etapa (contagem no banco). A
# prévia pode vir toda com IDEB nulo; sem a contagem, o modelo desconfia da
# base e desvia para outras tools (aceite com chat real, 2026-10-09).
eduBR_contar_respostas <- function(cv, respostas) {
  tb <- consulta(cv)
  exprs <- c(
    list(n_escolas = rlang::quo(dplyr::n())),
    lapply(respostas, function(r) {
      rlang::quo(sum(ifelse(is.na(.data[[r]]), 0L, 1L), na.rm = TRUE))
    })
  )
  names(exprs) <- c("n_escolas", respostas)
  res <- dplyr::collect(dplyr::summarise(tb, !!!exprs))
  vapply(res, function(v) as.numeric(v)[1], numeric(1))
}

eduBR_tool_covariaveis_escola <- function(sessao) {
  fun <- function(uf = NULL, rede = NULL, ano = 2025L, ano_ideb = 2023L,
                  ativas = TRUE, n = NULL) {
    uf <- eduBR_validar_uf(uf)
    rede <- eduBR_validar_rede(rede, publica = TRUE)
    ano <- eduBR_validar_ano_censo(ano %||% 2025L)
    ano_ideb <- eduBR_validar_edicao(ano_ideb %||% 2023L, "ano_ideb")
    ativas <- eduBR_validar_logico(ativas %||% TRUE, "ativas")
    if (!is.null(n)) {
      n <- eduBR_validar_inteiro(n, "n", 1L, 20L)
    }
    cv <- covariaveis_escola(
      sessao$con, ano = ano, ano_ideb = ano_ideb, uf = uf, rede = rede,
      ativas = ativas
    )
    colunas <- as.character(dplyr::tbl_vars(consulta(cv)))
    respostas <- intersect(c("ideb_fund_i", "ideb_fund_ii", "ideb_medio"),
                           colunas)
    contagem <- eduBR_contar_respostas(cv, respostas)
    id <- eduBR_handle_guardar(
      sessao, "dados", cv,
      descricao = eduBR_handle_descrever(
        "covariaveis_escola",
        list(uf = uf, rede = rede, ano = ano, ano_ideb = ano_ideb,
             ativas = ativas)
      )
    )
    eduBR_resultado(
      cv,
      grao = "escola",
      filtros = list(uf = uf, rede = rede, ano = ano, ano_ideb = ano_ideb,
                     ativas = ativas),
      handle = id,
      n_padrao = 10L,
      aviso = sprintf(
        paste0(
          "Pr\u00e9via: a base completa (uma linha por escola) fica no handle ",
          "%s. Pr\u00f3ximo passo: `especificar_regressao(dados_id = \"%s\", ",
          "...)` e depois `executar_regressao` com o `espec_<k>` devolvido; ",
          "n\u00e3o reconstrua a tabela a partir da pr\u00e9via. IDEB `null` na ",
          "pr\u00e9via \u00e9 esperado (escola sem a etapa ou sem nota): a ",
          "regress\u00e3o descarta essas linhas, n\u00e3o \u00e9 preciso buscar o ",
          "IDEB em outra ferramenta. Na base: %s escolas; com IDEB: %s."
        ),
        id, id, format(contagem[["n_escolas"]], scientific = FALSE),
        if (length(respostas)) {
          paste(sprintf("%s = %s", respostas,
                        format(contagem[respostas], scientific = FALSE,
                               trim = TRUE)),
                collapse = ", ")
        } else {
          "nenhuma coluna de IDEB"
        }
      ),
      contexto = list(
        handle = id,
        ano_censo = ano,
        edicao_ideb = ano_ideb,
        colunas = I(colunas),
        respostas = I(respostas),
        n_escolas = contagem[["n_escolas"]],
        n_com_ideb = as.list(contagem[respostas]),
        cortes = I(intersect(c("rede", "localizacao", "sg_uf"), colunas))
      )
    )
  }
  eduBR_tool(
    sessao, "covariaveis_escola", fun,
    descricao = paste0(
      "Monta a base escola \u00d7 covari\u00e1veis para modelagem (uma linha por ",
      "escola), com as mesmas defini\u00e7\u00f5es de `perfil_escola`: ",
      "identifica\u00e7\u00e3o (`co_entidade`, `sg_uf`, `co_municipio`), `rede` e ",
      "`localizacao`, infraestrutura `in_*` (0/1), etapas ofertadas ",
      "`in_comum_*` (0/1), `docentes`, `matriculas` e o IDEB de UMA edi\u00e7\u00e3o ",
      "por etapa (`ideb_fund_i`, `ideb_fund_ii`, `ideb_medio`; `null` sem ",
      "nota). A base N\u00c3O \u00e9 devolvida inteira: fica guardada na sess\u00e3o e a ",
      "resposta traz `metadados.handle` (ex.: \"dados_1\") para usar em ",
      "`especificar_regressao(dados_id = )`, uma pr\u00e9via de poucas linhas (`n`, padr\u00e3o 10) e, ",
      "em `metadados.contexto`, a lista de colunas, as respostas (IDEB) e os ",
      "cortes dispon\u00edveis. Cuidados: `ano` (Censo, padr\u00e3o 2025) e ",
      "`ano_ideb` (padr\u00e3o 2023) s\u00e3o fixos para todas as escolas (corte ",
      "transversal); `ativas = true` mant\u00e9m s\u00f3 escolas em atividade; ",
      "`co_entidade` chega como texto; IDEB nulo em escolas que n\u00e3o ofertam a ",
      "etapa ou n\u00e3o foram avaliadas (a base j\u00e1 traz o IDEB: n\u00e3o ",
      "\u00e9 preciso juntar com `ideb`)."
    ),
    arguments = list(
      uf = eduBR_arg_uf(),
      rede = eduBR_arg_rede(publica = TRUE),
      ano = ellmer::type_integer(
        "Ano do Censo Escolar (padr\u00e3o 2025, o \u00fanico carregado).",
        required = FALSE
      ),
      ano_ideb = ellmer::type_integer(
        "Edi\u00e7\u00e3o do IDEB usada (bienal, padr\u00e3o 2023).",
        required = FALSE
      ),
      ativas = ellmer::type_boolean(
        "S\u00f3 escolas em atividade? Padr\u00e3o true.", required = FALSE
      ),
      n = ellmer::type_integer(
        paste0(
          "Linhas da pr\u00e9via (padr\u00e3o 10, m\u00e1ximo 20). A base completa fica ",
          "no handle; n\u00e3o pe\u00e7a mais linhas para ver os dados."
        ),
        required = FALSE
      )
    ),
    titulo = "Covari\u00e1veis escolares (handle)"
  )
}

# ---------------------------------------------------------------------------
# perfil_gestor

eduBR_tool_perfil_gestor <- function(sessao) {
  fun <- function(corte = "rede", unidade = "gestor", rede = NULL, uf = NULL,
                  regiao = NULL, localizacao = NULL, n = NULL) {
    corte <- eduBR_validar_enum(corte %||% "rede", "corte", eduBR_cortes_gestor())
    unidade <- eduBR_validar_enum(
      unidade %||% "gestor", "unidade", c("gestor", "escola")
    )
    rede <- eduBR_validar_rede(rede, publica = TRUE)
    uf <- eduBR_validar_uf(uf)
    regiao <- eduBR_validar_regiao(regiao)
    localizacao <- eduBR_validar_localizacao(localizacao)
    eduBR_validar_n(n)
    if (corte == "categoria_privada" && !is.null(rede) && rede != "Privada") {
      eduBR_abortar(
        "parametro_invalido",
        paste0(
          "`corte = \"categoria_privada\"` s\u00f3 vale para escolas privadas; ",
          "omita `rede` ou use `rede = \"Privada\"`."
        )
      )
    }
    p <- perfil_gestor(
      gestores(sessao$con, rede = rede, uf = uf, regiao = regiao,
               localizacao = localizacao),
      corte = corte, unidade = unidade
    )
    eduBR_resultado(
      p$modal,
      grao = "corte \u00d7 dimens\u00e3o do perfil",
      filtros = list(corte = corte, unidade = unidade, rede = rede, uf = uf,
                     regiao = regiao, localizacao = localizacao),
      n_padrao = 300L,
      contexto = list(
        corte = corte,
        unidade = unidade,
        ano_censo = 2025L,
        n_por_corte = eduBR_serializar(p$n)$dados
      )
    )
  }
  eduBR_tool(
    sessao, "perfil_gestor", fun,
    descricao = paste0(
      "Perfil dos gestores escolares (Censo 2025): para cada corte (`corte`: ",
      "brasil, rede [padr\u00e3o], regiao, uf ou categoria_privada) e dimens\u00e3o ",
      "(sexo, cor/ra\u00e7a, escolaridade, p\u00f3s-gradua\u00e7\u00e3o, faixa et\u00e1ria, v\u00ednculo, ",
      "forma de acesso ao cargo, forma\u00e7\u00e3o em gest\u00e3o, defici\u00eancia) devolve a ",
      "categoria MODAL, `n` e `denom` da categoria, `prop_modal` (propor\u00e7\u00e3o) ",
      "e `concentracao` (Herfindahl: 1 = todos na mesma categoria). Responde ",
      "\"quem s\u00e3o os gestores por rede/regi\u00e3o?\". Em `metadados.contexto` vem ",
      "`n_por_corte` (gestores e escolas de cada corte). Cuidados: ",
      "`unidade = \"gestor\"` pesa cada gestor; `\"escola\"` conta cada escola ",
      "uma vez na sua categoria predominante; cor/ra\u00e7a exclui \"n\u00e3o ",
      "declarada\" do denominador; v\u00ednculo s\u00f3 para escolas p\u00fablicas; ",
      "`categoria_privada` s\u00f3 escolas privadas. S\u00e3o contagens agregadas, sem ",
      "dados pessoais. Brasil todo leva ~6 s."
    ),
    arguments = list(
      corte = ellmer::type_enum(
        eduBR_cortes_gestor(), "Agrupamento do perfil; padr\u00e3o \"rede\".",
        required = FALSE
      ),
      unidade = ellmer::type_enum(
        c("gestor", "escola"),
        "Unidade de agrega\u00e7\u00e3o; padr\u00e3o \"gestor\".",
        required = FALSE
      ),
      rede = eduBR_arg_rede(publica = TRUE),
      uf = eduBR_arg_uf(),
      regiao = eduBR_arg_regiao(),
      localizacao = eduBR_arg_localizacao(),
      n = eduBR_arg_n(300L)
    ),
    titulo = "Perfil dos gestores escolares"
  )
}
