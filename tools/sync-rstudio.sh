#!/usr/bin/env bash
#
# tools/sync-rstudio.sh
#
# Sincroniza o working tree do eduBR para o RStudio Server (rstudio.dev),
# cujo acesso SSH e como root. Por isso os arquivos chegam como root e, ao
# final, o dono e corrigido para rsuser:rsuser.
#
# Sem --delete: arquivos criados no container (ex.: analises usando o
# pacote) NAO sao apagados. O rsync apenas adiciona/atualiza.
#
# Uso manual:  tools/sync-rstudio.sh
# Automatico:  chamado por .git/hooks/post-commit
#
# Destino: tools/rstudio-dest.sh (worktree principal -> projetos/eduBR;
# cada git worktree -> projetos/eduBR-wt-<nome>; EDUBR_SYNC_DEST sobrepoe).

set -euo pipefail

HOST="rstudio.dev"
SRC="$(git rev-parse --show-toplevel)/"
DEST="$("${SRC}tools/rstudio-dest.sh")"

echo "==> rsync ${SRC} -> ${HOST}:${DEST}"
ssh "$HOST" "mkdir -p '$DEST'"

rsync -rlptz --no-owner --no-group \
  --exclude='.git/' \
  --exclude='.Rproj.user/' \
  --exclude='.Rhistory' \
  --exclude='.RData' \
  --exclude='analysis/*.html' \
  --exclude='analysis/*.pdf' \
  --exclude='analysis/*_files/' \
  "$SRC" "${HOST}:${DEST}/"

echo "==> chown -R rsuser:rsuser ${DEST}"
ssh "$HOST" "chown -R rsuser:rsuser '$DEST'"

echo "==> sincronizado"
