# R/gestor.R
#
# Perfil dos gestores escolares a partir do Censo Escolar. Acessa
# clean.censo_gestor (2025) — contagens de gestores por escola — e cruza com
# clean.censo_escolas para anexar rede, localização e território. O motor de
# perfil agrega as contagens e deriva, para cada dimensão, a categoria modal
# e a concentração, por unidade ("gestor" = cada gestor pesa 1; "escola" =
# cada escola contribui com a própria categoria predominante).

# Rótulos das categóricas do Censo (rede, categoria privada, localização).
eduBR_rotulos <- function() {
  list(
    rede = c(
      "1" = "Federal", "2" = "Estadual", "3" = "Municipal", "4" = "Privada"
    ),
    categoria_privada = c(
      "1" = "Particular", "2" = "Comunit\u00e1ria", "3" = "Confessional",
      "4" = "Filantr\u00f3pica"
    ),
    localizacao = c("1" = "Urbana", "2" = "Rural")
  )
}

# Constrói uma expressão `case_when` a partir de um vetor nomeado
# (código -> rótulo). Traduzível para SQL sem depender de indexação R.
eduBR_case_when_lookup <- function(col, lab) {
  clausulas <- mapply(
    function(k, v) {
      rlang::expr(.data[[col]] == !!as.integer(k) ~ !!v)
    },
    names(lab), unname(lab),
    SIMPLIFY = FALSE
  )
  rlang::expr(dplyr::case_when(!!!clausulas, TRUE ~ NA_character_))
}

# Especificação das dimensões do perfil: colunas de contagem (+ rótulo de
# cada categoria), tipo de denominador e restrição de rede.
#
# `denominador` ∈ {"soma", "complemento"}:
#   - "soma": denominador = soma das categorias listadas;
#   - "complemento": denominador = total de gestores, com a diferença entre o
#     total e a soma oferecida como categoria de fechamento (`complemento`).
# `fora` (nomeado) marca categorias computadas porém fora da composição/modal
# (cor/raça "não declarada"): entram em `proporcoes` com `composicao = FALSE`.
# `restrito = "publica"` limita a dimensão a escolas públicas.
eduBR_dimensoes_gestor <- function() {
  list(
    sexo = list(
      rotulo = "Sexo",
      categorias = c(
        qt_gest_bas_fem = "Feminino",
        qt_gest_bas_masc = "Masculino"
      ),
      denominador = "soma",
      restrito = NULL
    ),
    cor_raca = list(
      rotulo = "Cor/Ra\u00e7a",
      categorias = c(
        qt_gest_bas_branca = "Branca",
        qt_gest_bas_preta = "Preta",
        qt_gest_bas_parda = "Parda",
        qt_gest_bas_amarela = "Amarela",
        qt_gest_bas_indigena = "Ind\u00edgena"
      ),
      denominador = "soma",
      fora = c(qt_gest_bas_nd = "N\u00e3o declarada"),
      restrito = NULL
    ),
    escolaridade = list(
      rotulo = "Escolaridade (maior conclu\u00edda)",
      categorias = c(
        qt_gest_bas_esco_ef = "Fundamental",
        qt_gest_bas_esco_em = "M\u00e9dio",
        qt_gest_bas_esco_sup_grad = "Superior (gradua\u00e7\u00e3o)"
      ),
      denominador = "soma",
      restrito = NULL
    ),
    pos_graduacao = list(
      rotulo = "P\u00f3s-gradua\u00e7\u00e3o",
      categorias = c(
        qt_gest_bas_esco_sup_pos_espec = "Especializa\u00e7\u00e3o",
        qt_gest_bas_esco_sup_pos_mestra = "Mestrado",
        qt_gest_bas_esco_sup_pos_douto = "Doutorado",
        qt_gest_bas_esco_sup_pos_nenhum = "Sem p\u00f3s-gradua\u00e7\u00e3o"
      ),
      denominador = "soma",
      restrito = NULL
    ),
    faixa_etaria = list(
      rotulo = "Faixa et\u00e1ria",
      categorias = c(
        qt_gest_bas_0_24 = "At\u00e9 24 anos",
        qt_gest_bas_25_29 = "25\u201329",
        qt_gest_bas_30_39 = "30\u201339",
        qt_gest_bas_40_49 = "40\u201349",
        qt_gest_bas_50_54 = "50\u201354",
        qt_gest_bas_55_59 = "55\u201359",
        qt_gest_bas_60_mais = "60 ou mais"
      ),
      denominador = "soma",
      restrito = NULL
    ),
    vinculo = list(
      rotulo = "V\u00ednculo (escolas p\u00fablicas)",
      categorias = c(
        qt_gest_bas_vinculo_concur = "Concursado/efetivo/est\u00e1vel",
        qt_gest_bas_vinculo_contra = "Contrato tempor\u00e1rio",
        qt_gest_bas_vinculo_terceir = "Terceirizado",
        qt_gest_bas_vinculo_clt = "CLT"
      ),
      denominador = "soma",
      restrito = "publica"
    ),
    acesso = list(
      rotulo = "Forma de acesso ao cargo",
      categorias = c(
        qt_gest_bas_acesso_cargo_prop = "Propriet\u00e1rio/s\u00f3cio",
        qt_gest_bas_acesso_cargo_indic = "Indica\u00e7\u00e3o/escolha da gest\u00e3o",
        qt_gest_bas_acesso_cargo_sel = "Processo seletivo + nomea\u00e7\u00e3o",
        qt_gest_bas_acesso_cargo_conca = "Concurso p\u00fablico",
        qt_gest_bas_acesso_cargo_eleic = "Elei\u00e7\u00e3o com a comunidade",
        qt_gest_bas_acesso_cargo_p_sel = "Processo seletivo + elei\u00e7\u00e3o",
        qt_gest_bas_acesso_cargo_outro = "Outro crit\u00e9rio"
      ),
      denominador = "soma",
      restrito = NULL
    ),
    formacao_gestao = list(
      rotulo = "Forma\u00e7\u00e3o continuada em gest\u00e3o (\u226580h)",
      categorias = c(qt_gest_bas_espec_gestao = "Com forma\u00e7\u00e3o em gest\u00e3o"),
      denominador = "complemento",
      complemento = "Sem forma\u00e7\u00e3o em gest\u00e3o",
      restrito = NULL
    ),
    pcd = list(
      rotulo = "Defici\u00eancia/TEA/superdota\u00e7\u00e3o",
      categorias = c(qt_gest_bas_pcd = "Com defici\u00eancia"),
      denominador = "complemento",
      complemento = "Sem defici\u00eancia declarada",
      restrito = NULL
    )
  )
}

# Normaliza um data.frame de gestores para o motor de perfil: nomes em
# minúsculas, contagens sem NA e colunas derivadas (rede, categoria privada,
# região) quando ausentes.
eduBR_normalizar_gestores <- function(dados) {
  df <- tibble::as_tibble(dados)
  names(df) <- tolower(names(df))

  for (cl in grep("^qt_gest", names(df), value = TRUE)) {
    df[[cl]] <- dplyr::coalesce(df[[cl]], 0)
  }

  lab <- eduBR_rotulos()
  if (!"rede" %in% names(df) && "tp_dependencia" %in% names(df)) {
    df$rede <- unname(lab$rede[as.character(df$tp_dependencia)])
  }
  if (!"categoria_privada" %in% names(df) &&
      "tp_categoria_escola_privada" %in% names(df)) {
    df$categoria_privada <-
      unname(lab$categoria_privada[as.character(df$tp_categoria_escola_privada)])
  }
  if (!"nome_regiao" %in% names(df) && "sg_uf" %in% names(df)) {
    df <- eduBR_mutate_regiao(df)
  }
  df
}

# Resolve os valores aceitos de `rede` (códigos, nomes PT-BR ou "publica"/
# "privada") em códigos de `tp_dependencia`.
eduBR_codigos_rede <- function(rede) {
  lab <- eduBR_rotulos()$rede
  nomes <- stats::setNames(
    as.integer(names(lab)),
    gsub("\\s", "", tolower(iconv(lab, to = "ASCII//TRANSLIT")))
  )
  codes <- integer()
  for (r in rede) {
    x <- gsub("\\s", "", tolower(iconv(as.character(r), to = "ASCII//TRANSLIT")))
    if (x %in% c("publica", "publico")) {
      codes <- c(codes, 1L, 2L, 3L)
    } else if (x == "privada") {
      codes <- c(codes, 4L)
    } else if (x %in% names(nomes)) {
      codes <- c(codes, nomes[[x]])
    } else if (x %in% c("1", "2", "3", "4")) {
      codes <- c(codes, as.integer(x))
    } else {
      stop(
        sprintf(
          "rede inv\u00e1lida: '%s'. Use 1-4, um nome (Federal/Estadual/Municipal/Privada) ou 'publica'/'privada'.",
          r
        ),
        call. = FALSE
      )
    }
  }
  unique(codes)
}

# Idem a `rede`, para `tp_localizacao` (1 urbana, 2 rural).
eduBR_codigos_localizacao <- function(localizacao) {
  lab <- eduBR_rotulos()$localizacao
  nomes <- stats::setNames(
    as.integer(names(lab)),
    gsub("\\s", "", tolower(iconv(lab, to = "ASCII//TRANSLIT")))
  )
  x <- gsub("\\s", "", tolower(iconv(as.character(localizacao), to = "ASCII//TRANSLIT")))
  if (x %in% names(nomes)) {
    as.integer(nomes[[x]])
  } else if (x %in% c("1", "2")) {
    as.integer(x)
  } else {
    stop(
      sprintf(
        "localizacao inv\u00e1lida: '%s'. Use 1 (urbana) ou 2 (rural).",
        localizacao
      ),
      call. = FALSE
    )
  }
}

#' Microdados do Censo de Gestores
#'
#' Acessa `clean.censo_gestor` (contagens de gestores por escola, por sexo,
#' cor/raça, escolaridade, vínculo, forma de acesso e formação continuada).
#' A consulta é preguiçosa; materialize com [as_tibble()] ou [coletar()].
#'
#' @inheritParams censo_escolar
#' @param ano Filtro opcional pelo ano do censo (`nu_ano_censo`). A base tem
#'   apenas 2025.
#'
#' @return Objeto S3 de classe `eduBR_censo`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' censo_gestor(con, ano = 2025)
#' }
#'
#' @export
censo_gestor <- function(con, escola_id = NULL, ano = NULL) {
  tb <- eduBR_tbl(con, "censo_gestor")
  if (!is.null(escola_id)) {
    tb <- dplyr::filter(tb, .data$co_entidade == .env$escola_id)
  }
  if (!is.null(ano)) {
    tb <- dplyr::filter(tb, .data$nu_ano_censo == .env$ano)
  }
  new_eduBR(
    tb, "eduBR_censo", con,
    list(descricao = "Microdados do Censo de Gestores")
  )
}

#' Gestores escolares por rede e território
#'
#' Cruza `clean.censo_gestor` com `clean.censo_escolas` por
#' `(nu_ano_censo, co_entidade)`, anexando a rede (`rede`), a categoria da
#' escola privada (`categoria_privada`), a localização e a macrorregião
#' derivada da UF. Mantém apenas as colunas de contagem (`qt_gest_bas_*`)
#' relevantes para o perfil. A consulta é preguiçosa; materialize com
#' [as_tibble()] ou passe o objeto a [perfil_gestor()].
#'
#' @param con Conexão criada por [conecta()].
#' @param rede Filtro pelas redes. Aceita códigos (1–4), nomes
#'   (`"Federal"`, `"Estadual"`, `"Municipal"`, `"Privada"`) ou
#'   `"publica"`/`"privada"`.
#' @param uf Filtro opcional pela sigla da UF (ex.: `"SP"`).
#' @param regiao Filtro opcional pela macrorregião (nome ou sigla).
#' @param localizacao Filtro opcional pela localização (`1` urbana, `2` rural,
#'   ou `"urbana"`/`"rural"`).
#' @param ano Ano do censo (padrão `2025`, o único disponível).
#'
#' @return Objeto S3 de classe `eduBR_gestores` (consulta preguiçosa).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' gestores(con)                      # todas as escolas, 2025
#' gestores(con, rede = "Municipal")  # só municipais
#' gestores(con, regiao = "Nordeste")
#' }
#'
#' @export
gestores <- function(con, rede = NULL, uf = NULL, regiao = NULL,
                     localizacao = NULL, ano = 2025) {
  cols_escola <- c(
    "nu_ano_censo", "co_entidade", "tp_dependencia",
    "tp_categoria_escola_privada", "tp_localizacao",
    "sg_uf", "co_uf", "no_municipio", "co_municipio"
  )

  tb_g <- eduBR_tbl(con, "censo_gestor")
  tb_g <- dplyr::select(
    tb_g,
    dplyr::all_of(c("co_entidade", "nu_ano_censo", "qt_gest_bas")),
    dplyr::starts_with("qt_gest_bas_")
  )

  tb_e <- eduBR_tbl(con, "censo_escolas") |>
    dplyr::select(dplyr::all_of(cols_escola))

  tb <- dplyr::inner_join(
    tb_g, tb_e,
    by = c("nu_ano_censo" = "nu_ano_censo", "co_entidade" = "co_entidade")
  )

  lab <- eduBR_rotulos()
  tb <- dplyr::mutate(
    tb,
    rede = !!eduBR_case_when_lookup("tp_dependencia", lab$rede),
    categoria_privada = !!eduBR_case_when_lookup(
      "tp_categoria_escola_privada", lab$categoria_privada
    ),
    localizacao = !!eduBR_case_when_lookup("tp_localizacao", lab$localizacao)
  )
  tb <- eduBR_mutate_regiao(tb)

  if (!is.null(ano)) {
    tb <- dplyr::filter(tb, .data$nu_ano_censo == .env$ano)
  }
  if (!is.null(rede)) {
    filtro_rede <- eduBR_codigos_rede(rede)
    tb <- dplyr::filter(tb, .data$tp_dependencia %in% .env$filtro_rede)
  }
  if (!is.null(uf)) {
    tb <- dplyr::filter(tb, .data$sg_uf %in% .env$uf)
  }
  if (!is.null(regiao)) {
    tb <- eduBR_filtrar_regiao(tb, regiao)
  }
  if (!is.null(localizacao)) {
    filtro_loc <- eduBR_codigos_localizacao(localizacao)
    tb <- dplyr::filter(tb, .data$tp_localizacao %in% .env$filtro_loc)
  }

  new_eduBR(
    tb, "eduBR_gestores", con,
    list(descricao = "Gestores escolares por rede e territ\u00f3rio (Censo 2025)")
  )
}

# Valor do corte para cada linha. `corte` é validado por perfil_gestor().
eduBR_grupos <- function(df, corte) {
  switch(
    corte,
    brasil = rep("Brasil", nrow(df)),
    rede = as.character(df$rede),
    regiao = as.character(df$nome_regiao),
    uf = as.character(df$sg_uf),
    categoria_privada = as.character(df$categoria_privada)
  )
}

# Calcula a distribuição de uma dimensão num data.frame já cortado. Devolve
# um tibble longo (uma linha por corte × categoria).
eduBR_dimensao <- function(dim, df, unidade) {
  if (isTRUE(dim$restrito == "publica")) {
    dfd <- dplyr::filter(df, .data$tp_dependencia %in% c(1L, 2L, 3L))
  } else {
    dfd <- df
  }

  cats <- dim$categorias
  if (nrow(dfd) == 0L) {
    return(NULL)
  }
  ausentes <- setdiff(names(cats), names(dfd))
  if (length(ausentes)) {
    stop(
      sprintf(
        "colunas de contagem ausentes para a dimens\u00e3o '%s': %s",
        dim$rotulo, paste(ausentes, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  if (isTRUE(dim$denominador == "complemento") &&
      !"qt_gest_bas" %in% names(dfd)) {
    stop(
      sprintf("dimens\u00e3o '%s' (complemento) exige a coluna `qt_gest_bas`.",
              dim$rotulo),
      call. = FALSE
    )
  }

  m <- as.matrix(dfd[names(cats)])
  m[is.na(m)] <- 0
  grp <- as.character(dfd$grupo)
  grps <- sort(unique(grp))

  if (unidade == "gestor") {
    soma <- rowsum(m, group = grp, na.rm = TRUE)
    soma <- soma[grps, , drop = FALSE]
    if (isTRUE(dim$denominador == "complemento")) {
      total <- tapply(dfd$qt_gest_bas, grp, sum, na.rm = TRUE)
      total <- total[grps]
      completar <- pmax(total - rowSums(soma), 0)
      out_n <- cbind(soma, complemento = completar)
      out_cat <- c(unname(cats), dim$complemento)
      out_comp <- rep(TRUE, length(out_cat))
    } else {
      out_n <- soma
      out_cat <- unname(cats)
      out_comp <- rep(TRUE, length(out_cat))
    }
    denom <- rowSums(out_n)
  } else {
    if (isTRUE(dim$denominador == "complemento")) {
      com <- m[, names(cats), drop = FALSE]
      sem <- dfd$qt_gest_bas - com
      m_ef <- cbind(com, complemento = sem)
      ef_cat <- c(unname(cats), dim$complemento)
      out_comp <- rep(TRUE, length(ef_cat))
    } else {
      m_ef <- m
      ef_cat <- unname(cats)
      out_comp <- rep(TRUE, length(ef_cat))
    }
    valid <- rowSums(m_ef) > 0
    idx <- max.col(m_ef, ties.method = "first")
    escolha <- ef_cat[idx]
    keep <- valid
    tab <- table(grp[keep], escolha[keep])
    out_n <- tab[grps, , drop = FALSE]
    out_cat <- colnames(out_n)
    out_comp <- rep(TRUE, ncol(out_n))
    denom <- tab_freq <- table(grp[keep])[grps]
    denom[is.na(denom)] <- 0L
  }

  if (is.null(dim(out_n)) || nrow(out_n) == 0L) {
    return(NULL)
  }

  # Categorias "fora" da composição (ex.: cor/raça não declarada).
  fora <- dim$fora
  if (length(fora)) {
    fcols <- intersect(names(fora), names(dfd))
    if (length(fcols)) {
      mf <- as.matrix(dfd[fcols])
      mf[is.na(mf)] <- 0
      if (unidade == "gestor") {
        nf <- rowsum(mf, group = grp, na.rm = TRUE)[grps, , drop = FALSE]
      } else {
        nf <- matrix(
          tapply(rowSums(m) == 0 & rowSums(mf) > 0, grp, sum)[grps],
          ncol = 1L
        )
        colnames(nf) <- names(fora)[1L]
        nf[is.na(nf)] <- 0
        rownames(nf) <- grps
      }
      if (ncol(nf)) {
        out_n <- cbind(out_n, nf)
        out_cat <- c(out_cat, unname(fora[colnames(nf)]))
        out_comp <- c(out_comp, rep(FALSE, ncol(nf)))
      }
    }
  }

  linhas <- data.frame(
    corte = rep(grps, times = ncol(out_n)),
    dimensao = dim$rotulo,
    categoria = rep(out_cat, each = length(grps)),
    n = as.vector(out_n),
    stringsAsFactors = FALSE
  )
  linhas$denom <- rep(denom, times = ncol(out_n))
  linhas$prop <- linhas$n / linhas$denom
  linhas$composicao <- rep(out_comp, each = length(grps))

  tibble::as_tibble(linhas)
}

#' Perfil modal dos gestores escolares
#'
#' Agrega as contagens de [gestores()] em cortes e deriva, para cada dimensão,
#' a distribuição de categorias e a categoria **modal** (a mais frequente).
#'
#' Duas unidades de agregação:
#'
#' - `"gestor"` (padrão): cada gestor pesa 1 (soma das contagens por escola);
#' - `"escola"`: cada escola contribui com **uma** observação na categoria
#'   predominante daquele colégio (sensibilidade ao peso de escolas pequenas).
#'
#' Denominadores por dimensão (base válida): dimensões com `"soma"` usam a
#' soma das categorias; `"complemento"` usa o total de gestores com o
#' fechamento como categoria; cor/raça "não declarada" sai do denominador e
#' aparece com `composicao = FALSE`; vínculo vale apenas para escolas
#' públicas.
#'
#' @param dados Objeto `eduBR_gestores` (de [gestores()]) ou um `data.frame`
#'   com as colunas de contagem e as chaves de corte.
#' @param corte Agrupamento do perfil: `"brasil"`, `"rede"` (padrão),
#'   `"regiao"`, `"uf"` ou `"categoria_privada"`.
#' @param unidade Unidade de agregação: `"gestor"` ou `"escola"`.
#' @param dimensoes Dimensões incluídas. `NULL` (padrão) usa todas.
#'
#' @return Objeto S3 de classe `eduBR_perfil_gestor` com `$proporcoes`
#'   (longo: `corte`, `dimensao`, `categoria`, `n`, `denom`, `prop`,
#'   `composicao`), `$modal` (categoria modal, `prop_modal` e concentração —
#'   índice de Herfindahl — por corte × dimensão) e `$n` (escolas e gestores
#'   por corte).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' p <- perfil_gestor(gestores(con), corte = "rede")
#' p$modal
#' }
#'
#' @export
perfil_gestor <- function(dados, corte = "rede",
                          unidade = c("gestor", "escola"),
                          dimensoes = NULL) {
  unidade <- rlang::arg_match(unidade)
  cortes <- c("brasil", "rede", "regiao", "uf", "categoria_privada")
  if (!is.character(corte) || length(corte) != 1L || is.na(corte) ||
      !corte %in% cortes) {
    stop(
      sprintf("`corte` deve ser um de: %s.", paste(cortes, collapse = ", ")),
      call. = FALSE
    )
  }

  df <- eduBR_normalizar_gestores(
    if (inherits(dados, "eduBR")) coletar(dados, avisar = FALSE) else dados
  )

  precisa <- switch(
    corte,
    brasil = character(),
    rede = "rede",
    regiao = "nome_regiao",
    uf = "sg_uf",
    categoria_privada = "categoria_privada"
  )
  faltando <- setdiff(precisa, names(df))
  if (length(faltando)) {
    stop(
      sprintf(
        "dados sem colunas necess\u00e1rias para o corte '%s': %s",
        corte, paste(faltando, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  dims <- eduBR_dimensoes_gestor()
  if (!is.null(dimensoes)) {
    ausentes <- setdiff(dimensoes, names(dims))
    if (length(ausentes)) {
      stop(
        sprintf(
          "dimens\u00f5es desconhecidas: %s. Dispon\u00edveis: %s.",
          paste(ausentes, collapse = ", "),
          paste(names(dims), collapse = ", ")
        ),
        call. = FALSE
      )
    }
    dims <- dims[dimensoes]
  }

  if (corte == "categoria_privada") {
    df <- dplyr::filter(df, .data$tp_dependencia == 4L)
  }
  df$grupo <- factor(eduBR_grupos(df, corte))
  df <- dplyr::filter(df, !is.na(.data$grupo))
  df$grupo <- droplevels(df$grupo)

  blocos <- lapply(dims, function(dim) {
    tbl <- eduBR_dimensao(dim, df, unidade)
    if (!is.null(tbl)) tbl else NULL
  })
  proporcoes <- dplyr::bind_rows(blocos) |>
    dplyr::filter(.data$denom > 0)

  modal <- proporcoes |>
    dplyr::filter(.data$composicao) |>
    dplyr::group_by(.data$corte, .data$dimensao) |>
    dplyr::summarise(
      categoria_modal = .data$categoria[which.max(.data$n)],
      n           = max(.data$n),
      denom       = unique(.data$denom),
      prop_modal  = max(.data$prop),
      concentracao = sum(.data$prop^2),
      .groups = "drop"
    )

  n_sum <- df |>
    dplyr::group_by(.data$grupo) |>
    dplyr::summarise(
      n_gestores = sum(.data$qt_gest_bas, na.rm = TRUE),
      n_escolas  = if ("co_entidade" %in% names(df)) {
        dplyr::n_distinct(.data$co_entidade)
      } else {
        dplyr::n()
      },
      .groups = "drop"
    ) |>
    dplyr::rename(corte = "grupo") |>
    dplyr::mutate(corte = as.character(.data$corte))

  structure(
    list(
      proporcoes = proporcoes,
      modal      = modal,
      n          = n_sum,
      corte      = corte,
      unidade    = unidade
    ),
    class = "eduBR_perfil_gestor"
  )
}

#' @export
print.eduBR_perfil_gestor <- function(x, ...) {
  cat(sprintf(
    "<eduBR_perfil_gestor> \u2014 Censo Escolar de gestores (corte: %s, unidade: %s)\n",
    x$corte, x$unidade
  ))
  cat(sprintf(
    "%d dimens\u00f5es \u00d7 %d cortes\n",
    length(unique(x$proporcoes$dimensao)), nrow(x$n)
  ))
  print(x$modal)
  invisible(x)
}