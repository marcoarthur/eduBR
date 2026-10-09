#!/usr/bin/env bash
#
# tools/tunnel-ollama.sh
#
# Tunel SSH reverso para testes: faz o localhost:11434 do container
# rstudio.dev apontar para o Ollama desta maquina. Assim chat_edubr("ollama")
# funciona no container com os padroes (OLLAMA_BASE_URL nao definida).
#
# Uso:
#   tools/tunnel-ollama.sh abrir     # abre em segundo plano
#   tools/tunnel-ollama.sh status    # mostra se esta aberto e se responde
#   tools/tunnel-ollama.sh fechar    # encerra o tunel

set -euo pipefail

HOST="rstudio.dev"
PORTA="${EDUBR_OLLAMA_PORTA:-11434}"
ESPEC="127.0.0.1:${PORTA}:localhost:${PORTA}"

pid_tunel() {
  pgrep -f -- "-R ${ESPEC} ${HOST}" || true
}

case "${1:-status}" in
  abrir)
    if [[ -n "$(pid_tunel)" ]]; then
      echo "==> tunel ja aberto (pid $(pid_tunel))"
    else
      if ! curl -s -m 5 "http://localhost:${PORTA}/api/tags" > /dev/null; then
        echo "Ollama local nao responde em localhost:${PORTA}." >&2
        exit 1
      fi
      ssh -f -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=60 \
        -R "${ESPEC}" "${HOST}"
      echo "==> tunel aberto (pid $(pid_tunel))"
    fi
    ;;
  fechar)
    pid="$(pid_tunel)"
    if [[ -n "$pid" ]]; then
      kill $pid
      echo "==> tunel fechado"
    else
      echo "==> nenhum tunel aberto"
    fi
    ;;
  status)
    pid="$(pid_tunel)"
    echo "==> tunel: ${pid:-fechado}"
    if ssh "$HOST" "curl -s -m 5 http://localhost:${PORTA}/api/tags" | grep -q models; then
      echo "==> container alcanca o Ollama em localhost:${PORTA}"
    else
      echo "==> container NAO alcanca o Ollama em localhost:${PORTA}"
    fi
    ;;
  *)
    echo "uso: $0 {abrir|status|fechar}" >&2
    exit 2
    ;;
esac
