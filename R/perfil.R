# R/perfil.R
#
# Foto de uma escola dentro do painel do município/estado. `perfil_escola()`
# coleta a linha da escola em `clean.censo_escolas`, as médias do município
# (por `co_municipio`, código) e da UF, o IDEB (`clean.ideb_notas_escolas`,
# por `id_escola`/`co_municipio`) e os docentes (`clean.censo_docentes`).
# Agregações rodam no banco; só o agregado atravessa a rede. `comparar()`
# devolve o quadro escola × município × estado em tabela tidy e o `print`
# resume em PT-BR para não-técnico.

# Infraestrutura comparada (coluna em clean.censo_escolas -> rótulo PT-BR).
eduBR_infra_perfil <- function() {
  c(
    in_agua_rede_publica = "Água de rede pública",
    in_energia_rede_publica = "Energia de rede pública",
    in_esgoto_rede_publica = "Esgoto de rede pública",
    in_biblioteca = "Biblioteca",
    in_laboratorio_informatica = "Laboratório de informática",
    in_quadra_esportes = "Quadra de esportes",
    in_refeitorio = "Refeitório",
    in_internet = "Internet",
    in_banda_larga = "Banda larga",
    in_sala_professor = "Sala dos professores"
  )
}

# Só escolas em atividade (1); paralisadas (2) e extintas (3) vêm sem
# infraestrutura. Sem a coluna (fixtures antigas), não filtra.
eduBR_so_ativas <- function(tb) {
  if ("tp_situacao_funcionamento" %in% colnames(tb)) {
    tb <- dplyr::filter(tb, .data$tp_situacao_funcionamento == 1L)
  }
  tb
}

# Etapas ofertadas (flag em clean.censo_escolas -> rótulo curto).
eduBR_etapas_oferta <- function() {
  c(
    in_comum_creche = "Creche",
    in_comum_pre = "Pr\u00e9-escola",
    in_comum_fund_ai = "Fund. I",
    in_comum_fund_af = "Fund. II",
    in_comum_medio_medio = "M\u00e9dio",
    in_comum_medio_integrado = "M\u00e9dio",
    in_comum_eja_fund = "EJA",
    in_comum_eja_medio = "EJA"
  )
}

#' Perfil de uma escola vs município e estado
#'
#' Monta a "foto" de uma escola dentro do painel do município e da UF:
#' identificação e rede, infraestrutura (fração das escolas com cada item),
#' IDEB por etapa e docentes por escola. O município é resolvido por
#' **código** (`co_municipio` de `clean.censo_escolas`), não pelo nome.
#'
#' O IDEB é comparado **na mesma edição**: para cada etapa usa-se `ano_ideb`
#' ou, se `NULL`, a edição mais recente com nota da escola; município e
#' estado são a média das escolas da **mesma rede** nessa edição.
#'
#' Município e estado consideram só escolas **em atividade**
#' (`tp_situacao_funcionamento == 1`; paralisadas/extintas não têm
#' infraestrutura no Censo). As médias são **descritivas** (média simples
#' das escolas com dado) —
#' servem para situar a escola, não para atribuir causalidade.
#'
#' @param con Conexão criada por [conecta()].
#' @param codigo_inep Código INEP da escola (`co_entidade`).
#' @param ano Ano do Censo para escola/infra/docentes (padrão `2025`).
#' @param ano_ideb Edição do IDEB (ex.: `2023`). `NULL` (padrão) usa, por
#'   etapa, a edição mais recente da escola.
#'
#' @return Objeto S3 de classe `eduBR_perfil_escola` com `$perfil` (tibble
#'   de 3 linhas: `escola`, `municipio`, `estado`), `$escola` (identificação),
#'   `$ano` e `$ano_ideb` (edição usada por etapa; `NA` sem nota).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' p <- perfil_escola(con, "35012345")
#' comparar(p)
#' }
#'
#' @export
perfil_escola <- function(con, codigo_inep, ano = 2025L, ano_ideb = NULL) {
  infra <- eduBR_infra_perfil()
  lab <- eduBR_rotulos()

  cols_esc <- c(
    "nu_ano_censo", "co_entidade", "no_entidade", "tp_dependencia",
    "tp_localizacao", "sg_uf", "no_municipio", "co_municipio",
    names(infra), names(eduBR_etapas_oferta())
  )

  esc <- eduBR_tbl(con, "censo_escolas") |>
    dplyr::filter(
      .data$nu_ano_censo == .env$ano,
      .data$co_entidade == .env$codigo_inep
    ) |>
    dplyr::select(dplyr::any_of(cols_esc)) |>
    dplyr::collect()

  if (nrow(esc) == 0L) {
    stop(
      sprintf("escola inexistente no Censo %s: '%s'.", ano, codigo_inep),
      call. = FALSE
    )
  }
  esc <- esc[1L, , drop = FALSE]
  mun_cod <- esc$co_municipio[[1L]]
  uf <- esc$sg_uf[[1L]]

  flags <- intersect(names(infra), names(esc))

  base_mun <- eduBR_tbl(con, "censo_escolas") |>
    dplyr::filter(
      .data$nu_ano_censo == .env$ano,
      .data$co_municipio == .env$mun_cod
    ) |>
    eduBR_so_ativas()
  base_uf <- eduBR_tbl(con, "censo_escolas") |>
    dplyr::filter(
      .data$nu_ano_censo == .env$ano,
      .data$sg_uf == .env$uf
    ) |>
    eduBR_so_ativas()

  agrega_infra <- function(tb) {
    tb |>
      dplyr::select(dplyr::any_of(c("co_entidade", flags))) |>
      dplyr::summarise(
        n_escolas = dplyr::n_distinct(.data$co_entidade, na.rm = TRUE),
        dplyr::across(
          dplyr::any_of(flags),
          ~ mean(as.numeric(.x), na.rm = TRUE)
        )
      ) |>
      dplyr::collect()
  }
  agg_mun <- agrega_infra(base_mun)
  agg_uf <- agrega_infra(base_uf)

  rede <- unname(lab$rede[as.character(esc$tp_dependencia[[1L]])])

  # IDEB por etapa na mesma edição (e rede) para escola, município e UF.
  ideb_etapas <- c("fundamental_i", "fundamental_ii", "ensino_medio")
  ideb_escola <- eduBR_tbl(con, "ideb") |>
    dplyr::filter(.data$id_escola == .env$codigo_inep) |>
    dplyr::select(dplyr::any_of(c("ano", "etapa", "ideb_observado"))) |>
    dplyr::collect()
  ideb_escola <- ideb_escola[!is.na(ideb_escola$ideb_observado), , drop = FALSE]

  ano_ref <- vapply(
    ideb_etapas,
    function(e) {
      anos <- ideb_escola$ano[ideb_escola$etapa == e]
      if (!is.null(ano_ideb)) {
        as.integer(ano_ideb)
      } else if (length(anos) == 0L) {
        NA_integer_
      } else {
        as.integer(max(anos))
      }
    },
    integer(1L)
  )
  anos_alvo <- unique(stats::na.omit(ano_ref))

  media_ideb <- function(tb) {
    if (!is.na(rede)) {
      tb <- dplyr::filter(tb, .data$rede == .env$rede)
    }
    tb |>
      dplyr::filter(
        .data$ano %in% .env$anos_alvo,
        .data$etapa %in% .env$ideb_etapas
      ) |>
      dplyr::group_by(.data$ano, .data$etapa) |>
      dplyr::summarise(
        ideb_observado = mean(.data$ideb_observado, na.rm = TRUE),
        .groups = "drop"
      ) |>
      dplyr::collect()
  }
  ideb_mun <- media_ideb(
    dplyr::filter(eduBR_tbl(con, "ideb"), .data$co_municipio == .env$mun_cod)
  )
  ideb_uf <- media_ideb(
    dplyr::filter(eduBR_tbl(con, "ideb"), .data$sg_uf == .env$uf)
  )

  media_etapa <- function(df) {
    vapply(
      ideb_etapas,
      function(e) {
        v <- df$ideb_observado[df$etapa == e & df$ano %in% ano_ref[[e]]]
        if (length(v) == 0L || all(is.na(v))) NA_real_ else mean(v, na.rm = TRUE)
      },
      numeric(1L)
    )
  }

  # Docentes: total da escola e média por escola no município/UF.
  doc_escola <- eduBR_tbl(con, "censo_docentes") |>
    dplyr::filter(
      .data$nu_ano_censo == .env$ano,
      .data$co_entidade == .env$codigo_inep
    ) |>
    dplyr::select(dplyr::any_of(c("qt_doc_bas"))) |>
    dplyr::collect()
  media_doc <- function(tb_esc) {
    tb_esc |>
      dplyr::select(dplyr::any_of("co_entidade")) |>
      dplyr::inner_join(
        eduBR_tbl(con, "censo_docentes") |>
          dplyr::filter(.data$nu_ano_censo == .env$ano) |>
          dplyr::select(dplyr::any_of(c("nu_ano_censo", "co_entidade", "qt_doc_bas"))),
        by = "co_entidade"
      ) |>
      dplyr::summarise(media = mean(as.numeric(.data$qt_doc_bas), na.rm = TRUE)) |>
      dplyr::collect()
    }
  doc_mun <- media_doc(base_mun)
  doc_uf <- media_doc(base_uf)

  telef <- function(x) if (length(x) == 0L || all(is.na(x))) NA_real_ else x[[1L]]

  linha <- function(nivel, infra_vals, ideb_vals, doc, n) {
    tibble::tibble(
      nivel = nivel,
      n_escolas = n,
      !!!stats::setNames(as.list(infra_vals), paste0("infra_", names(infra_vals))),
      ideb_fund_i = unname(ideb_vals[["fundamental_i"]]),
      ideb_fund_ii = unname(ideb_vals[["fundamental_ii"]]),
      ideb_medio = unname(ideb_vals[["ensino_medio"]]),
      docentes = doc
    )
  }
  infra_esc <- vapply(
    flags,
    function(f) {
      v <- esc[[f]][[1L]]
      if (is.na(v)) NA_real_ else as.numeric(v == 1)
    },
    numeric(1L)
  )

  perfil <- dplyr::bind_rows(
    linha("escola", infra_esc, media_etapa(ideb_escola),
          telef(doc_escola$qt_doc_bas), 1L),
    linha("municipio",
          vapply(flags, function(f) telef(agg_mun[[f]]), numeric(1L)),
          media_etapa(ideb_mun), telef(doc_mun$media), telef(agg_mun$n_escolas)),
    linha("estado",
          vapply(flags, function(f) telef(agg_uf[[f]]), numeric(1L)),
          media_etapa(ideb_uf), telef(doc_uf$media), telef(agg_uf$n_escolas))
  )

  mat <- eduBR_tbl(con, "censo_matriculas") |>
    dplyr::filter(
      .data$nu_ano_censo == .env$ano,
      .data$co_entidade == .env$codigo_inep
    ) |>
    dplyr::select(dplyr::any_of("qt_mat_bas")) |>
    dplyr::collect()
  oferta <- eduBR_etapas_oferta()
  etapas_of <- unname(oferta[vapply(names(oferta), function(f) {
    f %in% names(esc) && isTRUE(esc[[f]][[1L]] == 1)
  }, logical(1L))])

  structure(
    list(
      perfil = perfil,
      escola = list(
        codigo_inep = codigo_inep,
        nome = esc$no_entidade[[1L]],
        rede = rede,
        municipio = esc$no_municipio[[1L]],
        uf = uf,
        localizacao = unname(
          lab$localizacao[as.character(esc$tp_localizacao[[1L]])]
        ),
        etapas = unique(etapas_of),
        matriculas = as.numeric(telef(mat$qt_mat_bas))
      ),
      infra_rotulos = infra[flags],
      ano = ano,
      ano_ideb = ano_ref,
      ideb_serie = tibble::tibble(
        etapa = as.character(ideb_escola$etapa),
        ano = as.integer(ideb_escola$ano),
        ideb = as.numeric(ideb_escola$ideb_observado)
      )[order(ideb_escola$etapa, ideb_escola$ano), , drop = FALSE]
    ),
    class = "eduBR_perfil_escola"
  )
}

#' Comparar escola com município e estado
#'
#' Achata o [perfil_escola()] numa tabela tidy de comparações: para cada
#' item de infraestrutura (tem/não tem vs % das escolas) e cada número
#' (IDEB, docentes), os valores da escola, do município e do estado, com a
#' diferença escola − município.
#'
#' @param x Objeto `eduBR_perfil_escola` (de [perfil_escola()]).
#'
#' @return Um `tibble` com `dimensao`, `item`, `escola`, `municipio`,
#'   `estado` e `dif_municipio`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' comparar(perfil_escola(con, "35012345"))
#' }
#'
#' @export
comparar <- function(x) {
  if (!inherits(x, "eduBR_perfil_escola")) {
    stop("`x` deve ser um eduBR_perfil_escola (ver perfil_escola()).",
         call. = FALSE)
  }
  p <- x$perfil
  esc <- p[p$nivel == "escola", , drop = FALSE]
  mun <- p[p$nivel == "municipio", , drop = FALSE]
  est <- p[p$nivel == "estado", , drop = FALSE]
  g <- function(df, col) {
    v <- df[[col]]
    if (length(v) == 0L) NA_real_ else v[[1L]]
  }

  infra_cols <- grep("^infra_", names(p), value = TRUE)
  rot <- x$infra_rotulos
  blocos <- lapply(infra_cols, function(col) {
    f <- sub("^infra_", "", col)
    tibble::tibble(
      dimensao = "Infraestrutura",
      item = unname(rot[f]),
      escola = g(esc, col),
      municipio = g(mun, col),
      estado = g(est, col),
      dif_municipio = g(esc, col) - g(mun, col)
    )
  })

  nums <- c(ideb_fund_i = "IDEB fund. I", ideb_fund_ii = "IDEB fund. II",
            ideb_medio = "IDEB médio", docentes = "Docentes")
  edicao <- c(ideb_fund_i = "fundamental_i", ideb_fund_ii = "fundamental_ii",
              ideb_medio = "ensino_medio")
  for (col in names(edicao)) {
    a <- x$ano_ideb[edicao[[col]]]
    if (length(a) == 1L && !is.na(a)) {
      nums[[col]] <- sprintf("%s (%s)", nums[[col]], a)
    }
  }
  for (col in names(nums)) {
    if (col %in% names(p)) {
      blocos <- c(blocos, list(tibble::tibble(
        dimensao = if (startsWith(col, "ideb")) "IDEB" else "Docentes",
        item = unname(nums[col]),
        escola = g(esc, col),
        municipio = g(mun, col),
        estado = g(est, col),
        dif_municipio = g(esc, col) - g(mun, col)
      )))
    }
  }
  dplyr::bind_rows(blocos)
}

#' @export
print.eduBR_perfil_escola <- function(x, ...) {
  e <- x$escola
  rede <- if (is.null(e$rede) || is.na(e$rede)) "—" else e$rede
  cat(sprintf("%s\n", e$nome))
  cat(sprintf(
    "Rede %s — %s/%s (Censo %s)\n",
    rede, e$municipio, e$uf, x$ano
  ))
  porte <- c(
    if (length(e$etapas)) paste(e$etapas, collapse = ", "),
    if (!is.null(e$matriculas) && !is.na(e$matriculas)) {
      sprintf("%s matr\u00edculas", fmt_num(e$matriculas))
    },
    if (!is.null(e$localizacao) && !is.na(e$localizacao)) e$localizacao
  )
  if (length(porte)) cat(paste(porte, collapse = " \u00b7 "), "\n", sep = "")
  evo <- eduBR_ideb_evolucao(x)
  rot_ideb <- c(fundamental_i = "IDEB fund. I", fundamental_ii = "IDEB fund. II",
                ensino_medio = "IDEB m\u00e9dio")
  cmp <- comparar(x)
  infra <- cmp[cmp$dimensao == "Infraestrutura", , drop = FALSE]
  tem <- infra$item[!is.na(infra$escola) & infra$escola == 1]
  falta <- infra$item[!is.na(infra$escola) & infra$escola == 0]
  if (length(tem)) cat("Tem:", paste(tem, collapse = ", "), "\n")
  if (length(falta)) cat("Não tem:", paste(falta, collapse = ", "), "\n")
  for (i in seq_len(nrow(cmp))) {
    r <- cmp[i, , drop = FALSE]
    if (r$dimensao != "Infraestrutura" && !is.na(r$escola)) {
      extra <- ""
      etapa <- names(rot_ideb)[rot_ideb == sub(" \\(.*$", "", r$item)]
      if (length(etapa) == 1L) {
        ev <- evo[evo$etapa == etapa, , drop = FALSE]
        if (nrow(ev) == 1L && !is.na(ev$ideb_anterior)) {
          extra <- sprintf(
            "; em %s: %s (%s)", ev$ano_anterior, fmt_num(ev$ideb_anterior),
            fmt_var(ev$variacao)
          )
        }
      }
      cat(sprintf(
        "%s: %s (município %s, estado %s)%s\n",
        r$item, fmt_num(r$escola), fmt_num(r$municipio), fmt_num(r$estado),
        extra
      ))
    }
  }
  invisible(x)
}

fmt_num <- function(x) {
  if (is.na(x)) return("—")
  if (abs(x - round(x)) < .Machine$double.eps^0.5) format(round(x), big.mark = ".", decimal.mark = ",")
  else format(round(x, 1L), nsmall = 1L, big.mark = ".", decimal.mark = ",")
}

fmt_var <- function(x) {
  sub(".", ",", sprintf("%+.1f", x), fixed = TRUE)
}

# IDEB da escola na edição de referência vs a edição anterior com nota.
eduBR_ideb_evolucao <- function(x) {
  serie <- x$ideb_serie
  linhas <- lapply(names(x$ano_ideb), function(e) {
    a <- x$ano_ideb[[e]]
    s <- serie[serie$etapa == e & !is.na(serie$ideb), , drop = FALSE]
    atual <- if (is.na(a)) NA_real_ else mean(s$ideb[s$ano == a])
    ant <- s[!is.na(a) & s$ano < a, , drop = FALSE]
    ano_ant <- if (nrow(ant)) max(ant$ano) else NA_integer_
    ideb_ant <- if (nrow(ant)) mean(ant$ideb[ant$ano == ano_ant]) else NA_real_
    tibble::tibble(
      etapa = e, ano = as.integer(a), ideb = atual,
      ano_anterior = as.integer(ano_ant), ideb_anterior = ideb_ant,
      variacao = atual - ideb_ant
    )
  })
  dplyr::bind_rows(linhas)
}

#' Resumo de uma linha da escola
#'
#' Achata o [perfil_escola()] numa linha: identificação, rede, localização,
#' etapas ofertadas, porte (matrículas da educação básica), docentes e, por
#' etapa, o IDEB da edição de referência com a variação em relação à edição
#' anterior com nota da escola.
#'
#' @param x Objeto `eduBR_perfil_escola` (de [perfil_escola()]).
#'
#' @return Um `tibble` de uma linha com `codigo_inep`, `escola`, `rede`,
#'   `municipio`, `uf`, `localizacao`, `etapas`, `matriculas`, `docentes` e,
#'   para `fund_i`/`fund_ii`/`medio`, `ideb_*`, `ano_*` e `var_*`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' resumo_escola(perfil_escola(con, "13078070"))
#' }
#'
#' @export
resumo_escola <- function(x) {
  if (!inherits(x, "eduBR_perfil_escola")) {
    stop("`x` deve ser um eduBR_perfil_escola (ver perfil_escola()).",
         call. = FALSE)
  }
  e <- x$escola
  nulo <- function(v, na) if (is.null(v) || length(v) == 0L) na else v
  esc <- x$perfil[x$perfil$nivel == "escola", , drop = FALSE]
  evo <- eduBR_ideb_evolucao(x)
  base <- tibble::tibble(
    codigo_inep = as.character(e$codigo_inep),
    escola = e$nome,
    rede = nulo(e$rede, NA_character_),
    municipio = e$municipio,
    uf = e$uf,
    localizacao = nulo(e$localizacao, NA_character_),
    etapas = paste(nulo(e$etapas, character()), collapse = ", "),
    matriculas = nulo(e$matriculas, NA_real_),
    docentes = esc$docentes[[1L]]
  )
  sufixo <- c(fundamental_i = "fund_i", fundamental_ii = "fund_ii",
              ensino_medio = "medio")
  for (et in names(sufixo)) {
    ev <- evo[evo$etapa == et, , drop = FALSE]
    s <- sufixo[[et]]
    base[[paste0("ideb_", s)]] <- if (nrow(ev)) ev$ideb else NA_real_
    base[[paste0("ano_", s)]] <- if (nrow(ev)) ev$ano else NA_integer_
    base[[paste0("var_", s)]] <- if (nrow(ev)) ev$variacao else NA_real_
  }
  base
}
