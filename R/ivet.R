# Componentes territoriais do IVET e bases escolares associadas.

eduBR_ivet_componentes <- function() {
  c("pct_analfabeto", "renda_resp_media", "pct_agua_sem_rede",
    "pct_esgoto_inadequado", "pct_lixo_inadequado", "pct_sem_banheiro")
}

eduBR_validar_raio_ivet <- function(raio_m) {
  if (!is.numeric(raio_m) || length(raio_m) != 1L || is.na(raio_m) ||
      !raio_m %in% c(500, 1000, 2000)) {
    stop("`raio_m` deve ser 500, 1000 ou 2000 metros.", call. = FALSE)
  }
  as.integer(raio_m)
}

#' Componentes socioeconômicos do entorno escolar
#'
#' Consulta preguiçosa os componentes disponíveis do bloco B do IVET para uma
#' escola, ano escolar e raio. A renda e os demais valores ausentes permanecem
#' `NA`; esta função não calcula um escore agregado.
#'
#' @param con Conexão criada por [conecta()].
#' @param escola_id Código INEP da escola (8 dígitos).
#' @param ano Ano do cadastro escolar (padrão 2025).
#' @param raio_m Raio em metros: 500, 1000 (padrão) ou 2000.
#' @return Objeto lazy de classe `eduBR_ivet`.
#' @export
ivet_socioeconomico <- function(con, escola_id, ano = 2025L, raio_m = 1000L) {
  if (is.numeric(escola_id) && length(escola_id) == 1L && !is.na(escola_id)) {
    escola_id <- format(escola_id, scientific = FALSE, trim = TRUE)
  }
  if (!is.character(escola_id) || length(escola_id) != 1L || is.na(escola_id) ||
      !grepl("^[0-9]{8}$", escola_id)) {
    stop("`escola_id` deve ser um c\u00f3digo INEP de 8 d\u00edgitos.", call. = FALSE)
  }
  if (!is.numeric(ano) || length(ano) != 1L || is.na(ano) ||
      ano != round(ano) || ano < 1995 || ano > 2100) {
    stop("`ano` deve ser um ano escolar inteiro v\u00e1lido.", call. = FALSE)
  }
  raio_m <- eduBR_validar_raio_ivet(raio_m)
  tb <- eduBR_tbl(con, "ivet_entorno") |>
    dplyr::filter(.data$co_entidade == .env$escola_id,
                  .data$nu_ano_censo == .env$ano,
                  .data$raio_m == .env$raio_m) |>
    dplyr::select(dplyr::all_of(c(
      "co_entidade", "nu_ano_censo", "raio_m", "n_setores",
      "n_setores_suprimidos", "area_influencia_km2", "area_coberta_km2",
      "cobertura_pct", "versao", "computado_em", "pop_total",
      eduBR_ivet_componentes()
    )))
  new_eduBR(tb, "eduBR_ivet", con, list(
    descricao = sprintf("Componentes do entorno (Censo escolar %s, raio %s m)",
                        ano, raio_m),
    ano = as.integer(ano), referencia_setorial = 2022L, raio_m = raio_m,
    escola_id = escola_id
  ))
}

#' Comparar componentes do entorno entre escolas
#'
#' Resume médias simples entre escolas da mesma rede em um município ou UF.
#' Cada componente informa seu próprio número de observações válidas.
#'
#' @param con Conexão criada por [conecta()].
#' @param co_municipio Código IBGE do município (opcional).
#' @param uf Sigla da UF (opcional).
#' @param rede Rede escolar (padrão Municipal).
#' @param ano Ano escolar.
#' @param raio_m Raio em metros.
#' @return Consulta lazy com uma linha e estatísticas por componente.
#' @export
ivet_contexto_socioeconomico <- function(con, co_municipio = NULL, uf = NULL,
                                         rede = "Municipal", ano = 2025L,
                                         raio_m = 1000L) {
  if (is.null(co_municipio) && is.null(uf)) {
    stop("Informe `co_municipio` ou `uf`.", call. = FALSE)
  }
  raio_m <- eduBR_validar_raio_ivet(raio_m)
  escolas <- eduBR_tbl(con, "censo_escolas") |>
    dplyr::filter(.data$nu_ano_censo == .env$ano)
  if (!is.null(co_municipio)) {
    escolas <- dplyr::filter(escolas, .data$co_municipio == .env$co_municipio)
  }
  if (!is.null(uf)) escolas <- dplyr::filter(escolas, .data$sg_uf == .env$uf)
  if (!is.null(rede)) {
    codigos <- eduBR_codigos_rede(rede)
    escolas <- dplyr::filter(escolas, .data$tp_dependencia %in% .env$codigos)
  }
  base <- escolas |>
    dplyr::select("co_entidade") |>
    dplyr::inner_join(
      eduBR_tbl(con, "ivet_entorno") |>
        dplyr::filter(.data$nu_ano_censo == .env$ano,
                      .data$raio_m == .env$raio_m),
      by = "co_entidade"
    )
  exprs <- lapply(eduBR_ivet_componentes(), function(nm) {
    rlang::expr(mean(.data[[!!nm]], na.rm = TRUE))
  })
  names(exprs) <- paste0("media_", eduBR_ivet_componentes())
  ns <- lapply(eduBR_ivet_componentes(), function(nm) {
    rlang::expr(sum(dplyr::if_else(
      !is.na(.data[[!!nm]]), 1L, 0L
    )))
  })
  names(ns) <- paste0("n_", eduBR_ivet_componentes())
  tb <- base |>
    dplyr::summarise(!!!exprs, !!!ns, n_escolas = dplyr::n(), .groups = "drop")
  new_eduBR(tb, "eduBR_ivet_contexto", con, list(
    ano = ano, referencia_setorial = 2022L, raio_m = raio_m,
    co_municipio = co_municipio, uf = uf, rede = rede
  ))
}

#' Covariáveis escolares e componentes do entorno
#'
#' Une, sem multiplicar escolas, o cadastro escolar e seus componentes do
#' entorno (um único raio) às covariáveis e ao IDEB da função
#' [covariaveis_escola()].
#'
#' @param con Conexão criada por [conecta()].
#' @param ano Ano do Censo Escolar.
#' @param ano_ideb Edição do IDEB.
#' @param uf Filtro opcional por UF.
#' @param rede Filtro opcional pela rede.
#' @param co_municipio Filtro opcional pelo código IBGE do município.
#' @param ativas Só escolas em atividade.
#' @param raio_m Raio em metros.
#' @return Consulta lazy de classe `eduBR_covariaveis_ivet`.
#' @export
covariaveis_ivet_escola <- function(con, ano = 2025L, ano_ideb = 2023L,
                                    uf = NULL, rede = NULL, co_municipio = NULL,
                                    ativas = TRUE,
                                    raio_m = 1000L) {
  raio_m <- eduBR_validar_raio_ivet(raio_m)
  cv <- consulta(covariaveis_escola(
    con, ano = ano, ano_ideb = ano_ideb, uf = uf, rede = rede,
    ativas = ativas
  ))
  if (!is.null(co_municipio)) {
    cv <- dplyr::filter(cv, .data$co_municipio == .env$co_municipio)
  }
  iv <- eduBR_tbl(con, "ivet_entorno") |>
    dplyr::filter(.data$nu_ano_censo == .env$ano,
                  .data$raio_m == .env$raio_m) |>
    dplyr::select("co_entidade", dplyr::all_of(eduBR_ivet_componentes()))
  tb <- dplyr::inner_join(cv, iv, by = "co_entidade")
  new_eduBR(tb, "eduBR_covariaveis_ivet", con, list(
    ano = ano, ano_ideb = ano_ideb, raio_m = raio_m, uf = uf, rede = rede,
    co_municipio = co_municipio
  ))
}
