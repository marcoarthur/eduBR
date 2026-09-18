# analysis/capturar_dados_rf.R
#
# Captura o snapshot dos dados usados pelo report de classificacao por Random
# Forest (`analysis/classificacao_desempenho_rf.Rmd`): features de todas as
# escolas publicas (fundamental I e II) + UF por escola + niveis por tercis.
# Sem isso, a coleta ao vivo (~86 mil linhas) fica cara e o enlace do
# container de teste com o banco e instavel.
#
# Uso (retry ate sucesso):
#   Rscript analysis/capturar_dados_rf.R

suppressMessages({ library(eduBR); library(dplyr) })

con <- conecta(service = "edumaps")
dados <- coletar(features_escola(con), avisar = FALSE)

escolas_uf <- coletar(
  dplyr::tbl(con, dbplyr::in_schema("clean", "ideb_notas_escolas")) |>
    dplyr::mutate(id_escola = as.character(id_escola)) |>
    dplyr::select(id_escola, sg_uf) |>
    dplyr::distinct(),
  avisar = FALSE
)

dados <- left_join(dados, escolas_uf, by = c("co_entidade" = "id_escola")) |>
  classificar_desempenho()

saveRDS(dados, "analysis/dados_classificados_rf.rds",
        compress = "xz")
cat(sprintf("snapshot ok: %d x %d (etapas: %s)\n",
    nrow(dados), ncol(dados), paste(unique(dados$etapa), collapse = ", ")))