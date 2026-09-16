# R/regiao.R
#
# Macrorregioes do IBGE derivadas da UF. O mapa e estatico (27 UFs) e
# aplicado direto no SQL via `case_when`, evitando o join por municipio
# (`co_municipio` e `integer` na tabela do IDEB enquanto `codigo_ibge` e
# `varchar(7)`, com zeros a esquerda).

# Anexa `nome_regiao` e `sigla_regiao` a uma consulta (tbl ou data.frame).
eduBR_mutate_regiao <- function(tb) {
  tb <- dplyr::mutate(
    tb,
    nome_regiao = dplyr::case_when(
      .data$sg_uf %in% c("RO", "AC", "AM", "RR", "PA", "AP", "TO") ~ "Norte",
      .data$sg_uf %in% c(
        "MA", "PI", "CE", "RN", "PB", "PE", "AL", "SE", "BA"
      ) ~ "Nordeste",
      .data$sg_uf %in% c("MG", "ES", "RJ", "SP") ~ "Sudeste",
      .data$sg_uf %in% c("PR", "SC", "RS") ~ "Sul",
      .data$sg_uf %in% c("MS", "MT", "GO", "DF") ~ "Centro-oeste",
      TRUE ~ NA_character_
    )
  )
  dplyr::mutate(
    tb,
    sigla_regiao = dplyr::case_when(
      .data$nome_regiao == "Norte" ~ "N",
      .data$nome_regiao == "Nordeste" ~ "NE",
      .data$nome_regiao == "Sudeste" ~ "SE",
      .data$nome_regiao == "Sul" ~ "S",
      .data$nome_regiao == "Centro-oeste" ~ "CO",
      TRUE ~ NA_character_
    )
  )
}

# Filtra por macrorregiao aceitando o nome ("Sudeste") ou a sigla ("SE").
eduBR_filtrar_regiao <- function(tb, regiao) {
  alvo <- toupper(regiao)
  dplyr::filter(
    tb,
    toupper(.data$nome_regiao) == .env$alvo | .data$sigla_regiao == .env$alvo
  )
}
