# R/censo_docentes.R
#
# Perfil docente agregado por rede e território. Cruza `clean.censo_docentes`
# com `clean.censo_escolas` por (nu_ano_censo, co_entidade) e agrupa por
# rede (tp_dependencia), UF, município, região e localização. A consulta é
# preguiçosa; filtros e agregação empurrados para o SQL antes do collect.

# Colunas de contagem de docentes por dimensão (nomes em minúsculas como no banco).
.eduBR_colunas_docente <- function() {
  c(
    # Total e por etapa
    "qt_doc_bas", "qt_doc_inf", "qt_doc_inf_cre", "qt_doc_inf_pre",
    "qt_doc_fund", "qt_doc_fund_ai", "qt_doc_fund_af", "qt_doc_med",
    "qt_doc_med_prop", "qt_doc_prof", "qt_doc_eja", "qt_doc_esp",
    # Formação
    "qt_doc_bas_esco_ef", "qt_doc_bas_esco_em", "qt_doc_bas_esco_sup_grad",
    "qt_doc_bas_esco_sup_grad_licen", "qt_doc_bas_esco_sup_grad_slicen",
    "qt_doc_bas_esco_sup_pos_espec", "qt_doc_bas_esco_sup_pos_mestra",
    "qt_doc_bas_esco_sup_pos_douto", "qt_doc_bas_esco_sup_pos_nenhum",
    # Vínculo
    "qt_doc_bas_vinculo_concur", "qt_doc_bas_vinculo_contra",
    "qt_doc_bas_vinculo_terceir", "qt_doc_bas_vinculo_clt",
    # Especialização
    "qt_doc_bas_espec_cre", "qt_doc_bas_espec_pre_escola",
    "qt_doc_bas_espec_anos_iniciais", "qt_doc_bas_espec_anos_finais",
    "qt_doc_bas_espec_ens_medio", "qt_doc_bas_espec_eja",
    "qt_doc_bas_espec_ed_especial", "qt_doc_bas_espec_bil_surdos",
    "qt_doc_bas_espec_ed_indigena", "qt_doc_bas_espec_campo",
    "qt_doc_bas_espec_ambiental", "qt_doc_bas_espec_dir_humanos",
    "qt_doc_bas_espec_div_sexual", "qt_doc_bas_espec_dir_adolesc",
    "qt_doc_bas_espec_afro", "qt_doc_bas_espec_gestao",
    "qt_doc_bas_espec_educ_tic", "qt_doc_bas_espec_outros",
    "qt_doc_bas_espec_nenhum",
    # Disciplinas
    "qt_doc_bas_disc_lingua_port", "qt_doc_bas_disc_educ_fisica",
    "qt_doc_bas_disc_artes", "qt_doc_bas_disc_lingua_ing",
    "qt_doc_bas_disc_lingua_espa", "qt_doc_bas_disc_lingua_franc",
    "qt_doc_bas_disc_lingua_outra", "qt_doc_bas_disc_libras",
    "qt_doc_bas_disc_lingua_indig", "qt_doc_bas_disc_port_seg_lingua",
    "qt_doc_bas_disc_matematica", "qt_doc_bas_disc_ciencias",
    "qt_doc_bas_disc_fisica", "qt_doc_bas_disc_quimica",
    "qt_doc_bas_disc_biologia", "qt_doc_bas_disc_historia",
    "qt_doc_bas_disc_geografia", "qt_doc_bas_disc_sociologia",
    "qt_doc_bas_disc_filosofia", "qt_doc_bas_disc_est_sociais",
    "qt_doc_bas_disc_est_sociais_soci", "qt_doc_bas_disc_info_computacao",
    "qt_doc_bas_disc_ensino_religioso", "qt_doc_bas_disc_profissiona",
    "qt_doc_bas_disc_estagio_super", "qt_doc_bas_disc_pedagogicas",
    "qt_doc_bas_disc_projeto_de_vida", "qt_doc_bas_disc_outras",
    "qt_doc_bas_libras",
    # Demografia
    "qt_doc_bas_fem", "qt_doc_bas_masc", "qt_doc_bas_nd",
    "qt_doc_bas_branca", "qt_doc_bas_preta", "qt_doc_bas_parda",
    "qt_doc_bas_amarela", "qt_doc_bas_indigena",
    "qt_doc_bas_0_24", "qt_doc_bas_25_29", "qt_doc_bas_30_39",
    "qt_doc_bas_40_49", "qt_doc_bas_50_54", "qt_doc_bas_55_59",
    "qt_doc_bas_60_mais", "qt_doc_bas_pcd",
    # Localização zona
    "qt_doc_bas_zr_urb", "qt_doc_bas_zr_rur", "qt_doc_bas_zr_na",
    # Tipo docente
    "qt_doc_bas_docente", "qt_doc_bas_auxiliar", "qt_doc_bas_profi_monitor",
    "qt_doc_bas_tradutor_libras", "qt_doc_bas_titular_ead",
    "qt_doc_bas_tutor_aux_ead", "qt_doc_bas_guia_interprete",
    "qt_doc_bas_apoio_pcd", "qt_doc_bas_instrutor_ep"
  )
}



#' Perfil docente agregado por rede e território
#'
#' Cruza `clean.censo_docentes` com `clean.censo_escolas` por
#' `(nu_ano_censo, co_entidade)`, anexa a rede (via `tp_dependencia`), a
#' localização, a UF e a macrorregião, e devolve a consulta preguiçosa
#' agrupada pelo nível territorial solicitado.
#'
#' As colunas devolvidas são as contagens de docentes (`qt_doc_bas_*`) somadas
#' por grupo, mais as chaves de agrupamento (`rede`, `sg_uf`, `co_municipio`,
#' `no_municipio`, `nome_regiao`, `sigla_regiao`, `localizacao`).
#'
#' @details As contagens chegam como `integer64` (somas de `bigint` no
#'   Postgres): carregue `bit64` para imprimi-las corretamente.
#'
#' @param con Conexão criada por [conecta()].
#' @param ano Ano do censo (padrão `2025`).
#' @param rede Filtro pelas redes. Aceita códigos (1–4), nomes
#'   (`"Federal"`, `"Estadual"`, `"Municipal"`, `"Privada"`) ou
#'   `"publica"`/`"privada"`.
#' @param uf Filtro opcional pela sigla da UF (ex.: `"SP"`).
#' @param regiao Filtro opcional pela macrorregião (nome ou sigla).
#' @param localizacao Filtro opcional pela localização (`1` urbana, `2` rural,
#'   ou `"urbana"`/`"rural"`).
#' @param nivel Nível de agregação territorial: `"municipio"` (padrão),
#'   `"uf"`, `"regiao"` ou `"brasil"`.
#' @param colunas Subconjunto de colunas de contagem a incluir. `NULL` (padrão)
#'   traz todas as colunas `qt_doc_bas_*`. Passe vetor de nomes para projetar
#'   apenas o necessário antes do `collect`.
#'
#' @return Objeto S3 de classe `eduBR_docentes_rede` (consulta preguiçosa).
#'
#' @examples
#' \dontrun{
#' con <- conecta()
#' # Docentes por rede e município (Brasil todo)
#' docentes_rede(con, nivel = "municipio")
#' # Apenas rede municipal no Nordeste, só formação
#' docentes_rede(con, rede = "Municipal", regiao = "Nordeste",
#'               colunas = c("qt_doc_bas", "qt_doc_bas_esco_sup_grad",
#'                           "qt_doc_bas_esco_sup_pos_mestra"))
#' }
#'
#' @export
docentes_rede <- function(con, ano = 2025L, rede = NULL, uf = NULL,
                          regiao = NULL, localizacao = NULL,
                          nivel = c("municipio", "uf", "regiao", "brasil"),
                          colunas = NULL) {
  nivel <- rlang::arg_match(nivel)

  lab <- eduBR_rotulos()

  # Colunas da escola para o join
  cols_escola <- c(
    "nu_ano_censo", "co_entidade", "tp_dependencia",
    "tp_localizacao", "sg_uf", "co_uf", "no_municipio", "co_municipio"
  )

  # Tabela de docentes: seleciona apenas colunas de contagem + chaves
  # usa any_of para tolerar colunas ausentes (ex.: em testes com fixtures parciais)
  cols_doc <- c("nu_ano_censo", "co_entidade", "qt_doc_bas")
  if (!is.null(colunas)) {
    cols_doc <- c(cols_doc, intersect(colunas, .eduBR_colunas_docente()))
  } else {
    cols_doc <- c(cols_doc, .eduBR_colunas_docente())
  }

  tb_d <- eduBR_tbl(con, "censo_docentes") |>
    dplyr::select(dplyr::any_of(cols_doc))

  # Tabela de escolas: apenas chaves + atributos territoriais
  tb_e <- eduBR_tbl(con, "censo_escolas") |>
    dplyr::select(dplyr::all_of(cols_escola))

  # Join por (ano, escola)
  tb <- dplyr::inner_join(
    tb_d, tb_e,
    by = c("nu_ano_censo" = "nu_ano_censo", "co_entidade" = "co_entidade")
  )

  # Ano
  tb <- dplyr::filter(tb, .data$nu_ano_censo == .env$ano)

  # Rede (tp_dependencia -> rótulo)
  tb <- dplyr::mutate(
    tb,
    rede = !!eduBR_case_when_lookup("tp_dependencia", lab$rede),
    localizacao = !!eduBR_case_when_lookup("tp_localizacao", lab$localizacao)
  )

  # Região (via helper existente)
  tb <- eduBR_mutate_regiao(tb)

  # Filtros opcionais
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

  # Agrupamento por nível territorial
  grupo_vars <- switch(
    nivel,
    municipio = c("rede", "sg_uf", "co_municipio", "no_municipio",
                  "nome_regiao", "sigla_regiao", "localizacao"),
    uf = c("rede", "sg_uf", "nome_regiao", "sigla_regiao", "localizacao"),
    regiao = c("rede", "nome_regiao", "sigla_regiao", "localizacao"),
    brasil = c("rede", "localizacao")
  )

  # Sumariza contagens no banco. Deriva de `cols_doc` (determinístico):
  # inspecionar a tabela lazy aqui seria frágil (`names()` num tbl_lazy
  # devolve os slots internos "src"/"lazy_query", não as colunas).
  contagem_vars <- setdiff(cols_doc, c("nu_ano_censo", "co_entidade"))

  tb <- tb |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grupo_vars))) |>
    dplyr::summarise(
      dplyr::across(dplyr::any_of(contagem_vars), ~ sum(.x, na.rm = TRUE)),
      .groups = "drop"
    )

  new_eduBR(
    tb, "eduBR_docentes_rede", con,
    list(
      descricao = sprintf("Perfil docente agregado por %s (Censo %d)", nivel, ano),
      ano = ano,
      nivel = nivel,
      filtros = list(rede = rede, uf = uf, regiao = regiao,
                     localizacao = localizacao)
    )
  )
}

