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

## Raciocínio desligado por padrão no Ollama (#94), 2026-10-09

Com `chat_edubr("ollama")` passando a usar `raciocinio = "desligado"` por
padrão (N = 1 por execução; `taxa-r94-a.csv`, `taxa-r94-b.csv`):

| Cenário | Resultado | Observação |
|---|---|---|
| gestora | 1/1 (53 s, antes 68–81 s) | sem regressão |
| pesquisadora | 0/2 no critério estrito, **texto nas 2** | 1ª: respondeu sem chamar tools; 2ª: usou `regressao_escolas`, mas com `rede = "publica"` em vez de Municipal (números de outro recorte) |

O turno **vazio** (motivo da #94) não se repetiu (texto em 3/3); a
pesquisadora ainda erra a escolha de tool/argumento às vezes — limitação
do modelo de 9B, a reavaliar com Anthropic (#73).

## Anthropic vs Ollama (#73), 2026-10-09

Mesmos cenários e critério estrito, `PROVEDOR=anthropic` (`claude-sonnet-5`),
N = 2 (`taxa-anthropic.csv`); transcrições completas em
`anth_gestora.*`, `anth_pesq.*`, `anth_ml.*`.

| Cenário | Anthropic | Ollama `qwen3.5:9b` (melhor configuração) |
|---|---|---|
| gestora | **2/2**, mediana 35 s | 6/6 (raciocínio ligado), 1/1 (desligado) |
| pesquisadora | **2/2**, mediana 20 s (`regressao_escolas`) | 2/2 com `regressao_escolas` e raciocínio ligado; 0/2 com desligado (escolha de tool/argumento) |
| ml | **2/2**, mediana 32 s | 1/1 (desligado) |

Redação (#83): nas transcrições da Anthropic os números conferem com as
tools e não aparecem as frases sem base vistas no Ollama (ex.: "única
escola da região com biblioteca", leitura confusa da matriz de confusão,
"meta nacional de 5,8"). A redação solta é limitação do modelo local, não
dos prompts — nenhum ajuste de prompt foi necessário.

## Gemini, 2026-10-10

`PROVEDOR=gemini` (`gemini-3.7-flash`, padrão do ellmer 0.5.0), N = 2,
mesmo critério estrito (`taxa-gemini.csv`). Chave no **plano gratuito**:
cota de 20 requisições por dia nesse modelo, e um fluxo com tools gasta
várias por pergunta.

| Cenário | Gemini | Observação |
|---|---|---|
| gestora | 0/2 | as duas execuções pararam em HTTP 429 (cota), sem chegar à resposta |
| pesquisadora | 0/2 | #1: HTTP 429; #2: `regressao_escolas` certa, sem erro, resposta completa, mas o número-chave não foi achado no texto pelo critério automático |
| ml | **2/2**, mediana 144 s | fluxo completo + `importancia_floresta` |

Smoke (`EDUBR_LLM_SMOKE=gemini`): `catalogo` chamado e resposta "16" em
11,9 s. Leitura: a integração funciona; a taxa da gestora e da
pesquisadora ficou **sem medida**, porque a cota acabou. Repetir com cota
paga (ou no dia seguinte, um cenário por vez).
