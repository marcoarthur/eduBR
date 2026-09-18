# R/desempenho.R
#
# Features no nivel da escola para modelagem de desempenho em exames
# nacionais (SAEB). Le a MV analytics.escola_features (materializacao de
# analytics.prepare_school_data: censo 2025, IDEB/INSE 2023) e gera o alvo
# de classificacao alto/medio/baixo pela nota media de matematica e portugues,
# com tercis globais dentro de cada etapa.

#' Features escolares para modelagem de desempenho
#'
#' Le a MV `analytics.escola_features` (materialização de
#' `analytics.prepare_school_data()`, com censo 2025 e IDEB/INSE 2023), que
#' reúne, por escola e etapa, infraestrutura, matrículas, docentes, gestão,
#' INSE e razões derivadas, junto da nota média SAEB (`nota_media`, média de
#' matemática e português). A consulta é preguiçosa (filtros aplicados antes
#' do `collect`); use [classificar_desempenho()] para criar o alvo.
#'
#' @param con Conexão criada por [conecta()].
#' @param etapa Etapas incluídas; por padrão `fundamental_i` e
#'   `fundamental_ii`. Use `NULL` para todas (inclui `ensino_medio`).
#' @param publica Mantém apenas escolas públicas (`tp_dependencia` 1–3)?
#'   Padrão `TRUE`.
#'
#' @return Objeto S3 de classe `eduBR_features` (consulta preguiçosa).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' counts <- features_escola(con, etapa = "fundamental_i")
#' }
#'
#' @export
features_escola <- function(con, etapa = c("fundamental_i", "fundamental_ii"),
                            publica = TRUE) {
  etapas_validas <- c("fundamental_i", "fundamental_ii", "ensino_medio")
  if (is.null(etapa)) {
    etapa <- etapas_validas
  }
  if (!is.character(etapa) || length(etapa) == 0L ||
      any(!etapa %in% etapas_validas)) {
    stop(
      "`etapa` deve conter apenas: fundamental_i, fundamental_ii, ensino_medio.",
      call. = FALSE
    )
  }
  if (!is.logical(publica) || length(publica) != 1L || is.na(publica)) {
    stop("`publica` deve ser TRUE ou FALSE.", call. = FALSE)
  }

  tb <- eduBR_tbl(con, "escola_features")
  tb <- dplyr::filter(tb, .data$etapa %in% .env$etapa)
  if (publica) {
    tb <- dplyr::filter(tb, .data$tp_dependencia %in% c(1L, 2L, 3L))
  }
  new_eduBR(
    tb, "eduBR_features", con,
    list(descricao = "Features escolares para modelagem de desempenho")
  )
}

#' Classifica o desempenho escolar em alto/médio/baixo
#'
#' Cria o alvo de classificação a partir de uma coluna de nota (padrão
#' `nota_media`, média SAEB de matemática e português). Por padrão os cortes
#' são os **terços globais** da nota dentro de cada grupo (etapa); cortes
#' alternativos podem ser passados em `cortes`.
#'
#' @param dados `data.frame` com a coluna de nota.
#' @param nota Nome da coluna de nota usada como base.
#' @param grupo Nome da coluna usada para agrupar o cálculo dos terços.
#'   Se ausente (ou `NULL`), os terços são globais a `dados`.
#' @param cortes Opcional. Pode ser `NULL` (terços por grupo), um vetor
#'   numérico com os dois pontos de corte (aplicado a todos os grupos) ou uma
#'   lista nomeada `grupo = c(corte1, corte2)`.
#' @param rotulos Rótulos dos três níveis, do menor para o maior.
#'
#' @return Um `tibble` com a coluna adicional `nivel` (fator ordenado). Os
#'   cortes usados ficam no atributo `limites_desempenho`; acesse com
#'   [limites_desempenho()].
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' d <- classificar_desempenho(features_escola(con))
#' limites_desempenho(d)
#' }
#'
#' @export
classificar_desempenho <- function(dados, nota = "nota_media", grupo = "etapa",
                                   cortes = NULL,
                                   rotulos = c("baixo", "medio", "alto")) {
  if (!is.data.frame(dados)) {
    stop("`dados` deve ser um data.frame.", call. = FALSE)
  }
  if (!nota %in% names(dados)) {
    stop(sprintf("coluna `%s` inexistente em `dados`.", nota), call. = FALSE)
  }
  if (length(rotulos) != 3L || anyDuplicated(rotulos)) {
    stop("`rotulos` deve ter 3 rotulos distintos.", call. = FALSE)
  }
  x <- dados[[nota]]

  if (is.null(grupo) || !grupo %in% names(dados)) {
    g <- rep("geral", nrow(dados))
  } else {
    g <- as.character(dados[[grupo]])
  }

  # limites <- lista nomeada por grupo com os dois pontos de corte
  if (is.null(cortes)) {
    pedacos <- split(x, g)
    limites <- lapply(pedacos, function(v) {
      q <- stats::quantile(v, probs = c(1 / 3, 2 / 3), na.rm = TRUE)
      unname(q)
    })
  } else if (is.numeric(cortes) && length(cortes) == 2L) {
    grupos_unicos <- unique(g)
    limites <- stats::setNames(
      replicate(length(grupos_unicos), sort(unname(cortes)), simplify = FALSE),
      grupos_unicos
    )
  } else if (is.list(cortes)) {
    for (nm in names(cortes)) {
      ck <- cortes[[nm]]
      if (!is.numeric(ck) || length(ck) != 2L) {
        stop(
          sprintf("`cortes$%s` deve ser um vetor numerico de 2 posicoes.", nm),
          call. = FALSE
        )
      }
    }
    limites <- lapply(cortes, sort)
    cobertos <- unique(g) %in% names(limites)
    if (!all(cobertos)) {
      warning(
        paste(
          "grupos sem cortes em `cortes:`",
          paste(unique(g)[!cobertos], collapse = ", ")
        ),
        call. = FALSE
      )
    }
  } else {
    stop(
      "`cortes` deve ser NULL, um vetor numerico de 2 cortes ou uma lista por grupo.",
      call. = FALSE
    )
  }

  nivel <- rep(NA_character_, length(x))
  for (nm in names(limites)) {
    q <- limites[[nm]]
    ix <- g == nm & !is.na(x)
    nivel[ix] <- ifelse(
      is.na(x[ix]), NA_character_,
      ifelse(x[ix] < q[1], rotulos[1],
        ifelse(x[ix] < q[2], rotulos[2], rotulos[3])
      )
    )
  }

  out <- tibble::as_tibble(dados)
  out$nivel <- factor(nivel, levels = rotulos, ordered = TRUE)
  attr(out, "limites_desempenho") <- limites
  out
}

#' Cortes usados na classificação de desempenho
#'
#' Devolve os pontos de corte (por grupo) usados por [classificar_desempenho()]
#' no objeto classificado.
#'
#' @param x Objeto retornado por [classificar_desempenho()].
#'
#' @return Uma lista nomeada (por grupo) com vetores de 2 cortes, ou `NULL`
#'   quando o objeto não foi classificado.
#'
#' @examples
#' \dontrun{
#' d <- classificar_desempenho(features_escola(con))
#' limites_desempenho(d)
#' }
#'
#' @export
limites_desempenho <- function(x) {
  lim <- attr(x, "limites_desempenho")
  if (length(lim) == 1L) lim[[1L]] else lim
}