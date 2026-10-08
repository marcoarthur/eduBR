#!/usr/bin/env bash
#
# tools/rstudio-dest.sh
#
# Imprime o diretorio de destino no container rstudio.dev para o working
# tree atual. A worktree principal usa /home/rsuser/projetos/eduBR; cada
# worktree adicional (git worktree) ganha o seu proprio diretorio
# (/home/rsuser/projetos/eduBR-wt-<nome>), para que chunks em paralelo nao
# sobrescrevam os arquivos uns dos outros. EDUBR_SYNC_DEST sobrepoe tudo.

set -euo pipefail

BASE="/home/rsuser/projetos/eduBR"

if [[ -n "${EDUBR_SYNC_DEST:-}" ]]; then
  echo "$EDUBR_SYNC_DEST"
  exit 0
fi

git_dir="$(cd "$(git rev-parse --git-dir)" && pwd)"
common_dir="$(cd "$(git rev-parse --git-common-dir)" && pwd)"

if [[ "$git_dir" == "$common_dir" ]]; then
  echo "$BASE"
else
  nome="$(basename "$(git rev-parse --show-toplevel)")"
  echo "${BASE}-wt-${nome//[^A-Za-z0-9._-]/_}"
fi
