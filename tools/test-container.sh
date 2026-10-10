#!/usr/bin/env bash
#
# tools/test-container.sh
#
# Roda os testes (e opcionalmente o check) do eduBR no container
# rstudio.dev, como rsuser. Opcional desde 2026-10-09: os testes rodam
# localmente no host de desenvolvimento (ver AGENTS.md); use este script
# para conferir a compatibilidade com o dbplyr 2.5.0 do RStudio Server.
# Sincroniza antes o working tree para o destino da worktree atual
# (tools/rstudio-dest.sh).
#
# Uso:
#   tools/test-container.sh                  # devtools::test()
#   tools/test-container.sh --smoke          # + EDUBR_SMOKE=1 (banco real)
#   tools/test-container.sh --filter ellmer  # so test-*ellmer*.R
#   tools/test-container.sh --check          # devtools::check() (sem testes)
#   tools/test-container.sh --llm ollama     # + smoke com LLM real
#                                            #   (ollama: tunel aberto, ver
#                                            #   tools/tunnel-ollama.sh;
#                                            #   anthropic: ANTHROPIC_API_KEY
#                                            #   no ambiente do rsuser)
#   tools/test-container.sh --no-sync ...    # nao sincroniza antes

set -euo pipefail

HOST="rstudio.dev"
SRC="$(git rev-parse --show-toplevel)/"
DEST="$("${SRC}tools/rstudio-dest.sh")"

smoke=""
llm=""
filtro=""
check=0
sync=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --smoke) smoke="EDUBR_SMOKE=1"; shift ;;
    --llm)
      case "$2" in
        ollama|anthropic|gemini) llm="EDUBR_LLM_SMOKE=$2"; shift 2 ;;
        *) echo "--llm aceita ollama, anthropic ou gemini" >&2; exit 2 ;;
      esac
      ;;
    --filter) filtro="$2"; shift 2 ;;
    --check) check=1; shift ;;
    --no-sync) sync=0; shift ;;
    *) echo "opcao desconhecida: $1" >&2; exit 2 ;;
  esac
done

if [[ ! "$filtro" =~ ^[A-Za-z0-9_|.-]*$ ]]; then
  echo "--filter aceita so letras, numeros, _ . - |" >&2
  exit 2
fi

if [[ "$sync" == 1 ]]; then
  "${SRC}tools/sync-rstudio.sh"
fi

if [[ "$check" == 1 ]]; then
  expr="devtools::check(error_on = 'never', quiet = TRUE)"
  # O container nao alcanca as APIs de hora; sem isto o check pode dar a
  # NOTE "unable to verify current time" (ambiente, nao pacote).
  smoke="${smoke} _R_CHECK_SYSTEM_CLOCK_=FALSE"
elif [[ -n "$filtro" ]]; then
  expr="devtools::test(filter = '${filtro}', reporter = 'summary')"
else
  expr="devtools::test(reporter = 'summary')"
fi

echo "==> ${HOST}:${DEST} (rsuser) ${smoke} ${llm} ${expr}"
ssh "$HOST" "su - rsuser -c \"cd '${DEST}' && TZ=America/Sao_Paulo ${smoke} ${llm} Rscript -e \\\"${expr}\\\"\""
