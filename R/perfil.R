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

#' Perfil de uma escola vs município e estado
#'
#' Monta a "foto" de uma escola dentro do painel do município e da UF:
#' identificação e rede, infraestrutura (fração das escolas com cada item),
#' IDEB médio por etapa e docentes por escola. O município é resolvido por
#' **código** (`co_municipio` de `clean.censo_escolas`), não pelo nome.
#'
#' As médias são **descritivas** (média simples das escolas com dado, IDEB
#' agregado sobre as avaliações disponíveis) — servem para situar a escola,
#' não para atribuir causalidade.
#'
#' @param con Conexão criada por [conecta()].
#' @param codigo_inep Código INEP da escola (`co_entidade`).
#' @param ano Ano do Censo para escola/infra/docentes (padrão `2025`). O
#'   IDEB usa todas as avaliações disponíveis da escola.
#'
#' @return Objeto S3 de classe `eduBR_perfil_escola` com `$perfil` (tibble
#'   de 3 linhas: `escola`, `municipio`, `estado`), `$escola` (identificação)
#'   e `$ano`.
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' p <- perfil_escola(con, "35012345")
#' comparar(p)
#' }
#'
#' @export
perfil_escola <- function(con, codigo_inep, ano = 2025L) {
  infra <- eduBR_infra_perfil()
  lab <- eduBR_rotulos()

  cols_esc <- c(
    "nu_ano_censo", "co_entidade", "no_entidade", "tp_dependencia",
    "tp_localizacao", "sg_uf", "no_municipio", "co_municipio",
    names(infra)
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
    )
  base_uf <- eduBR_tbl(con, "censo_escolas") |>
    dplyr::filter(
      .data$nu_ano_censo == .env$ano,
      .data$sg_uf == .env$uf
    )

  agrega_infra <- function(tb) {
    tb |>
      dplyr::select(dplyr::any_of(c("co_entidade", flags))) |>
      dplyr::summarise(
        n_escolas = dplyr::n_distinct(.data$co_entidade),
        dplyr::across(
          dplyr::any_of(flags),
          ~ mean(as.numeric(.x), na.rm = TRUE)
        )
      ) |>
      dplyr::collect()
  }
  agg_mun <- agrega_infra(base_mun)
  agg_uf <- agrega_infra(base_uf)

  # IDEB por etapa: escola, município (por código) e UF.
  ideb_etapas <- c("fundamental_i", "fundamental_ii", "ensino_medio")
  ideb_escola <- eduBR_tbl(con, "ideb") |>
    dplyr::filter(.data$id_escola == .env$codigo_inep) |>
    dplyr::select(dplyr::any_of(c("etapa", "ideb_observado"))) |>
    dplyr::collect()
  ideb_mun <- eduBR_tbl(con, "ideb") |>
    dplyr::filter(.data$co_municipio == .env$mun_cod) |>
    dplyr::select(dplyr::any_of(c("etapa", "ideb_observado"))) |>
    dplyr::collect()
  ideb_uf <- eduBR_tbl(con, "ideb") |>
    dplyr::filter(.data$sg_uf == .env$uf) |>
    dplyr::select(dplyr::any_of(c("etapa", "ideb_observado"))) |>
    dplyr::collect()

  media_etapa <- function(df) {
    vapply(
      ideb_etapas,
      function(e) {
        v <- df$ideb_observado[df$etapa == e]
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

  rede <- unname(lab$rede[as.character(esc$tp_dependencia[[1L]])])
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

  structure(
    list(
      perfil = perfil,
      escola = list(
        codigo_inep = codigo_inep,
        nome = esc$no_entidade[[1L]],
        rede = rede,
        municipio = esc$no_municipio[[1L]],
        uf = uf
      ),
      infra_rotulos = infra[flags],
      ano = ano
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
  cmp <- comparar(x)
  infra <- cmp[cmp$dimensao == "Infraestrutura", , drop = FALSE]
  tem <- infra$item[!is.na(infra$escola) & infra$escola == 1]
  falta <- infra$item[!is.na(infra$escola) & infra$escola == 0]
  if (length(tem)) cat("Tem:", paste(tem, collapse = ", "), "\n")
  if (length(falta)) cat("Não tem:", paste(falta, collapse = ", "), "\n")
  for (i in seq_len(nrow(cmp))) {
    r <- cmp[i, , drop = FALSE]
    if (r$dimensao != "Infraestrutura" && !is.na(r$escola)) {
      cat(sprintf(
        "%s: %s (município %s, estado %s)\n",
        r$item, fmt_num(r$escola), fmt_num(r$municipio), fmt_num(r$estado)
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
