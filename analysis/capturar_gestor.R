# analysis/capturar_gestor.R
#
# Captura o snapshot dos microdados de gestores usado pelo report
# `analysis/perfil_gestor.Rmd`: contagens de gestores por escola
# (`clean.censo_gestor`, 2025) cruzadas com `clean.censo_escolas` (rede,
# localização, UF/região). Sem o snapshot, a coleta ao vivo (~190 mil linhas)
# fica cara e o enlace do container de teste com o banco é instável.
#
# Uso (retry até sucesso):
#   Rscript analysis/capturar_gestor.R

suppressMessages({ library(eduBR); library(dplyr) })

con <- conecta(service = "edumaps")
dados <- coletar(gestores(con), avisar = FALSE)

saveRDS(dados, "analysis/dados_gestores.rds", compress = "xz")
cat(sprintf("snapshot ok: %d escolas x %d colunas (%d gestores)\n",
    nrow(dados), ncol(dados), sum(dados$qt_gest_bas, na.rm = TRUE)))

DBI::dbDisconnect(con)