# Taxa de sucesso da camada ellmer (Ollama `qwen3.5:9b`)

Medido em 2026-10-09 com `tools/taxa-sucesso-ellmer.R` no container, Ollama
via túnel. **Resultado parcial**: a rodada com N = 5 foi interrompida a
pedido do dono do repo (temperatura crítica do laptop que roda o Ollama) —
o ML não chegou a rodar nela. A tabela junta essa rodada (gestora 5,
pesquisadora 3) com o teste anterior de N = 1 (um de cada cenário). Daqui
em diante o script aceita no máximo **N = 2**.

| Cenário | Persona | Sucesso (critério estrito) | Cadeia de tools completa | Tempo por execução |
|---|---|---|---|---|
| gestora | gestora-escolar | **6/6** | 6/6 | 68–81 s |
| pesquisadora | pesquisadora-educacional | **1/4** | 4/4 | 63–79 s |
| ml | especialista-ml | **1/1** | 1/1 | 58 s |

Critério estrito de sucesso: tools esperadas na ordem, **nenhuma chamada com
erro**, resposta não vazia e o número-chave da tool presente na resposta
(gestora: fração municipal de um item de infraestrutura; pesquisadora:
coeficiente de `in_biblioteca` na área urbana; ML: acurácia).

## Leitura

- **Gestora** é estável: as 2 perguntas sempre chamam `perfil_escola` e
  `escolas_similares` e citam os números da tool.
- **Pesquisadora** sempre chega à regressão
  (`covariaveis_escola → especificar_regressao → executar_regressao →
  coeficientes`), mas tropeça no caminho: no teste N = 1 inventou
  argumentos (`atividade`, `ativo`, `su`) que o ellmer recusou — registrados
  no ledger como `argumento_recusado` (#75) — e não citou o coeficiente; em
  2 execuções da rodada interrompida chamou `especificar_regressao` duas
  vezes (a primeira com erro, corrigida pelo próprio modelo), o que o
  critério estrito conta como falha.
- **ML** completou o fluxo com `raciocinio = "desligado"` (#70), mas com
  N = 1 a taxa não é conclusiva.
- Pico de contexto observado: gestora ~6,8k, pesquisadora até ~14,8k, ML
  ~13,4k tokens (janela de 16.384).

## Como reproduzir

```bash
tools/tunnel-ollama.sh abrir
ssh rstudio.dev "su - rsuser -c 'cd /home/rsuser/projetos/eduBR && \
  N=2 PROVEDOR=ollama SAIDA=/tmp/taxa/ollama Rscript tools/taxa-sucesso-ellmer.R'"
```

`CENARIOS=gestora,pesquisadora,ml` escolhe um subconjunto; `PROVEDOR=anthropic`
mede o outro provedor (pendente: #73). Ao terminar, descarregue o modelo do
Ollama (`keep_alive = 0`) para o laptop esfriar.

## Pesquisadora com a tool composta (#81), 2026-10-09

Com `regressao_escolas` (recorte → especificação → execução → coeficientes
e métricas numa chamada), N = 2: **2/2** no critério estrito (antes 1/4),
mediana 47 s, pico de contexto ~12k tokens; nas duas execuções o modelo
chamou só `regressao_escolas` e citou o coeficiente de `in_biblioteca`
(urbana −0,599, p = 0,049). Detalhes: `taxa-pesquisadora-81.csv`.
