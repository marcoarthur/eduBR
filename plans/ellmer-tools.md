# Plano — camada `ellmer` do `eduBR`

> Status: **implementado** (2026-10-09): chunks 0–6 em `main` (PRs
> #61–#68); chunk 7 (docs + aceite) na branch
> `feat/edubr-ellmer-chunk7-docs`. Proposto em 2026-10-08. Spec de origem: pedido "Tornar `eduBR` consumível por LLMs via
> `ellmer`" (2026-10-08). Decisões tomadas com o dono do repo estão em
> `memory.md` (entrada de 2026-10-08).

## 1. Contexto verificado

- **`ellmer` 0.5.0** está instalado **só no container** `rstudio.dev`
  (R 4.5.3); não há `ellmer` na máquina local. API conferida na instalação:
  `tool(fun, description, ..., arguments, name, convert, annotations)` →
  `ToolDef` (S7); `type_string/number/integer/boolean/enum(values,
  description)/array/object`; `Chat$register_tool()`/`register_tools()`/
  `set_system_prompt()`; `tool_reject(reason)`; `tool_annotations()`.
- **Runtime do LLM** (revisto em 2026-10-08): **dois provedores**, via
  `chat_edubr(provedor = "anthropic" | "ollama")`. Anthropic usa
  `ANTHROPIC_API_KEY` do ambiente do `rsuser` (configurada pelo dono do
  repo, nunca no código). Ollama usa `OLLAMA_BASE_URL` (padrão
  `http://localhost:11434`) e modelo `qwen3.5:9b` (ou
  `EDUBR_OLLAMA_MODELO`); o Ollama roda na máquina do dono do repo e o
  container o alcança por **túnel SSH reverso** (`tools/tunnel-ollama.sh`).
  Modelos locais com *tool calling*: `qwen3.5:9b`, `granite4.1:8b`.
- **Testes**: só no container, como `rsuser` (regra do README; o
  `AGENTS.md` diverge e será corrigido no chunk 7). Unitários sem banco;
  smoke com `EDUBR_SMOKE=1`.
- **PII** (auditoria no banco): `censo_gestor` (65 col.) e `censo_docentes`
  (156 col.) são **só contagens por escola** — nenhum nome/CPF/e-mail.
  `censo_escolas`/`escolas` têm dados **institucionais** (endereço,
  telefone, CEP, CNPJ da escola privada e da mantenedora): **ocultos por
  padrão** nas tools (decisão).
- `docs/` e `analysis/` estão no `.Rbuildignore`; `memory.md` não está (é a
  NOTE pré-existente do `check`).

## 2. Decisões de desenho

| # | Tema | Decisão | Por quê |
|---|---|---|---|
| D1 | Encadeamento (ML/regressão) | **Handles na sessão**: tools que produzem objetos R (dados, espec, regressão, floresta) guardam o objeto num ambiente privado da lista de tools e devolvem um id (`dados_1`, `espec_1`, `regressao_1`, `floresta_1`). | JSON não carrega `eduBR_espec`/`ranger`; some ao fim da sessão (não é memória persistente — não-objetivo respeitado). |
| D2 | Envelope | Toda tool devolve `list(dados, metadados, erro)`; `metadados = list(grao, filtros, n, n_total, truncado, aviso, handle)`. `dados` é uma lista de registros (linhas) já serializável. | Contrato único para o LLM e para os testes. |
| D3 | Serialização | Helper `eduBR_serializar()`: `integer64` → **string** (decisão #16 preservada: o pacote não coage; só a fronteira JSON), `Date`/`POSIXct` → ISO-8601, fator → texto, `NaN`/`Inf` → `NULL`, colunas de geometria removidas. | Restrição da spec + evitar denormais. |
| D4 | Cap de linhas | `n` default 100, **hard cap 1000** (`limites$max_linhas`, nunca acima de 1000); pedidos acima são truncados com `metadados$aviso`. Sempre via `coletar(n = ...)`. | Restrição da spec. |
| D5 | Cap de treino | Coletas **internas** para treinar/regredir têm teto próprio `limites$max_amostra` (default 15.000, máx. 30.000), amostradas de forma estratificada por etapa; nunca devolvidas ao LLM. | O container estoura memória com a base completa (skill `r-edubr`). O hard cap de 1000 vale para o que volta ao LLM. |
| D6 | Timeout | Por chamada: `SHOW statement_timeout` → `SET statement_timeout = <ms>` → executa → restaura o valor anterior (`on.exit`); mais `setTimeLimit(elapsed=)` para a parte em R. Default 30 s (`limites$timeout_s`). | `setTimeLimit()` sozinho não interrompe chamadas em C do driver. |
| D7 | Ledger | Ambiente na lista de tools (`attr(tools, "ledger")`) + acessor exportado `ledger(tools)` → data frame (`timestamp`, `tool`, `args` JSON, `n_linhas`, `duracao_ms`, `erro`). Persistência opcional em `tools::R_user_dir("eduBR", "data")/ledger/` (ou `limites$ledger_arquivo`). | `attr` com data frame seria cópia estática; `inst/` não é gravável no pacote instalado (decisão). |
| D8 | Orçamento | `limites$max_chamadas` (default 50) e `limites$max_linhas_total` (default 10.000); ao estourar, a tool devolve `erro = list(tipo = "limite_excedido", ...)` sem executar. | Spec. |
| D9 | Erros | `tryCatch` em toda tool; classes: `parametro_invalido` (validação/enum/mensagens de `stop()` do pacote), `sem_dados` (0 linhas/escola inexistente), `limite_excedido` (orçamento/timeout), `conexao` (erros DBI/RPostgres — mensagem genérica, **nunca** o texto do Postgres). | Spec; não vazar SQL/host. |
| D10 | Anti-alucinação | Nenhum retorno contém `schema.tabela`: `catalogo` sai sem `schema`/`tabela`; teste varre o JSON de todas as tools contra os valores de `eduBR_catalogo()`. | Spec. |
| D11 | Etapa | Enum com os valores do pacote: `fundamental_i`, `fundamental_ii`, `ensino_medio` (a spec diz `medio`; a camada se adapta ao pacote, não o contrário). | Não-objetivo "não reescrever funções". |
| D12 | Rede no perfil | `perfil_escola()` já compara na **rede da escola** (#21) — a tool não expõe `rede`. | Default da spec não se aplica. |
| D13 | `indicador` | `analytics.ranking_escola` está **vazia** no dev: sem enum possível; a tool `indicadores_escola` usa `type_string` e devolve `sem_dados` com explicação. | Dados, não pacote. |
| D14 | Dependência | `ellmer` em **Suggests** + `rlang::check_installed()`; `jsonlite` em Suggests (testes). | Pacote segue leve para quem não usa LLM. |
| D15 | `registrar_tools()` | **Exportado** (a spec diz "interno"): o usuário/vignette precisa chamá-lo para anexar tools + system prompt da persona ao `chat`. | Sem ele a vignette usaria internos. |
| D16 | Vignette | `eval = FALSE` com transcrições **gravadas** no container (chat real via `chat_edubr()`, Anthropic e/ou Ollama), para o `check` não depender de rede/chave. `knitr`/`rmarkdown` em Suggests + `VignetteBuilder: knitr`. | `check` reprodutível. |
| D18 | Provedores | `chat_edubr()` exportada escolhe o provedor (argumento > `EDUBR_LLM_PROVEDOR` > `anthropic` se houver chave > `ollama`) e registra as tools; smoke com LLM real via `tools/test-container.sh --llm ollama|anthropic`. | Usar Ollama local sem custo e Anthropic quando houver chave. |
| D17 | Prompts | `inst/prompts/<persona>.md` estáticos, escritos a partir de `docs/personas/` (que fica fora do build); `prompt_persona(persona)` lê via `system.file()`. | `docs/` não vai para o pacote instalado. |

## 3. Inventário de tools (cada uma justificada por pergunta de persona)

Persona: **G** gestora, **P** pesquisadora, **M** especialista ML.
Rastreio completo (pergunta → tool) em `docs/ellmer.md` (chunk 6).

| Grupo | Tool | Envolve | Personas | Pergunta de origem |
|---|---|---|---|---|
| catalogo | `catalogo` | `catalogo()` sem schema/tabela | G P M | P2 tipos/ano; M4 extensão; "mapa" antes de decidir |
| escola | `perfil_escola` | `perfil_escola()` + `comparar()` | G P | G2 comparar com município/estado |
| escola | `resumo_escola` | `perfil_escola()` + `resumo_escola()` | G | G1 minha escola numa linha |
| ideb | `serie_ideb_escola` | `ideb(escola_id=)` | G | G5 melhoramos no IDEB? |
| similaridade | `escolas_similares` | `escolas_similares()` | G | G3 benchmark |
| indicador | `scores_escola` / `indicadores_escola` | `scores()` / `indicadores()` | G M | G (funções que usa); M3 scores |
| municipio | `municipios` | `municipios()` (sem geometria) | P | P1 chave por código |
| rede | `redes_municipio` | `rede_municipio()` | P | R1 redes de cada município |
| censo | `docentes_rede` | `docentes_rede()` | P | "perfil docente muda entre regiões?" (R2) |
| censo | `covariaveis_escola` | `covariaveis_escola()` → **handle** + prévia | P M | P3 recorte → tabela para modelagem; M28 |
| ideb | `ideb` | `ideb()` | P M | P2 ano consistente; M7 |
| ideb | `tendencia_ideb_regiao` | `tendencia_regiao()` | P M | M5 tendência reproduzível |
| gestor | `perfil_gestor` | `gestores()` + `perfil_gestor()` | P | perfil por rede/região (report `perfil_gestor`) |
| regressao | `especificar_regressao` | idem → handle | P M | aceite: regressão declarativa |
| regressao | `executar_regressao` | idem (fonte do catálogo **ou** handle de dados) → handle | P M | M13 escala de recortes |
| regressao | `coeficientes` / `metricas` | idem | P M | M20 tabelas limpas |
| ml | `features_escola` | `features_escola()` + amostra (D5) → handle | M | aceite ML |
| ml | `classificar_desempenho` | idem → handle + `limites_desempenho()` | M | aceite ML |
| ml | `dividir_dados` | idem → handles treino/teste | M | aceite ML (holdout, sem vazamento) |
| ml | `treinar_floresta` | idem (`trees` ≤ 500, `num.threads = 2`) → handle | M | aceite ML |
| ml | `importancia_floresta` / `metricas_floresta` | idem | M | aceite ML |
| ml | `pca_perfil` | `pca_perfil(redundantes = "remover")` | M | M29–M31 |
| sessao | `listar_handles` | — | P M | o LLM consulta o que já está na sessão |

Filtro por persona (`ferramentas_edubr(con, persona = ...)`):

- **gestora-escolar**: catalogo, perfil_escola, resumo_escola,
  serie_ideb_escola, escolas_similares, scores_escola. **Sem** ML,
  regressão ou handles.
- **pesquisadora-educacional**: catalogo, perfil_escola, municipios,
  redes_municipio, docentes_rede, ideb, tendencia_ideb_regiao,
  covariaveis_escola, perfil_gestor, regressão (4), listar_handles.
- **especialista-ml**: catalogo, ideb, covariaveis_escola,
  tendencia_ideb_regiao, regressão (4), ml (7), listar_handles.
- `persona = NULL`: todas.

## 4. Chunks de PR (ordem e dependências)

Cada chunk: branch própria, TDD, testes **no container** (`rsuser`), PR
pequeno com revisão humana. Execução por subagente em worktree isolada
(ver chunk 0).

| Chunk | Conteúdo | Depende | Critério de aceite |
|---|---|---|---|
| **0** infra | `tools/sync-rstudio.sh` aceita destino por worktree (`EDUBR_SYNC_DEST`, default derivado do nome da worktree) para não sobrescrever o container entre chunks; script `tools/test-container.sh` (sync + `devtools::test()` como `rsuser`, com `EDUBR_SMOKE` opcional); `^plans$` e `^memory\.md$` no `.Rbuildignore`; `ellmer`/`jsonlite` em Suggests. | — | `tools/test-container.sh` roda a suíte atual verde no container; `check` sem a NOTE de `memory.md`. |
| **1** núcleo | `R/ellmer_ledger.R` (ledger, orçamento, persistência D7/D8); helpers internos: envelope (D2), `eduBR_serializar()` (D3), cap (D4), timeout (D6), classificação de erros (D9), loja de handles (D1); `ferramentas_edubr()` esqueleto + `ledger()`; tool `catalogo`. | 0 | Testes: JSON-serializável, `integer64`→string, cap 10^6 → ≤ hard cap + aviso, ledger conta chamadas/linhas, orçamento aborta com `limite_excedido`, erro de conexão sem texto do Postgres, `catalogo` sem schema/tabela. |
| **2** escola/gestora | tools perfil_escola, resumo_escola, serie_ideb_escola, escolas_similares, scores_escola, indicadores_escola; projeção sem PII (endereço/telefone/CEP/CNPJ). | 1 | Smoke 13078070: perfil e similares respondem; nenhuma coluna PII; filtro `persona = "gestora-escolar"` sem ML. |
| **3** pesquisa | municipios, redes_municipio, docentes_rede, ideb, tendencia_ideb_regiao, covariaveis_escola (handle), perfil_gestor. | 1 | Smoke com cap; enums `uf`(27)/`regiao`/`rede`/`etapa`/`corte`; reuso de `eduBR_codigos_rede`/`eduBR_case_when_lookup`/`eduBR_mutate_regiao` (nenhum lookup novo). |
| **4** regressão | especificar_regressao, executar_regressao (fonte **ou** handle), coeficientes, metricas, listar_handles. | 3 | Teste sem banco com dados em memória; smoke: `ideb_fund_i ~ in_biblioteca + docentes` por `localizacao` via handle de `covariaveis_escola`. |
| **5** ML | features_escola (amostra D5), classificar_desempenho, dividir_dados, treinar_floresta, importancia_floresta, metricas_floresta, pca_perfil. | 4 | Smoke: fluxo completo em amostra pequena dentro do teto de memória; nenhum objeto R vaza para o JSON. |
| **6** personas | `R/ellmer_personas.R`: `prompt_persona()`, `registrar_tools(chat, tools, persona)`; `inst/prompts/*.md` (papel, vocabulário, perguntas típicas → tools, o que não fazer, pegadinhas `integer64` e IDEB só na mesma edição); `docs/ellmer.md` (matriz pergunta × tool com links para `docs/personas/`). | 2–5 | Teste: cada tool citada nos prompts existe; filtro por persona; matriz cobre todas as perguntas canônicas. |
| **7** docs + aceite | `vignettes/ellmer.Rmd` (3 cenários, transcrições gravadas com `chat_edubr()` no container — Ollama via túnel e, com chave, Anthropic); README "Uso com LLM"; `AGENTS.md` (testes só no container + camada ellmer); skill `r-edubr`; `memory.md`. Rodada de curadoria das 3 personas **usando o chat**. | 6 | Critérios de aceite da spec verificados com chat real e registrados em `docs/personas/`. |

### Status dos chunks

| Chunk | PR | Status |
|---|---|---|
| 0 infra | #61 | ✓ mergeado |
| 1 núcleo | #62 | ✓ mergeado |
| 2 escola/gestora | #63 | ✓ mergeado |
| 3 pesquisa | #64 | ✓ mergeado |
| 4 regressão | #65 | ✓ mergeado |
| provedores (D18: `chat_edubr()`, Ollama) | #66 | ✓ mergeado |
| 5 ML | #67 | ✓ mergeado |
| 6 personas | #68 | ✓ mergeado |
| 7 docs + aceite | (esta branch) | ✓ implementado; aguarda revisão |

### Critérios de aceite da spec (verificados em 2026-10-09)

| Critério | Status |
|---|---|
| Gestora responde sem SQL chamando `perfil_escola` e `escolas_similares` (13078070) | ✓ chat real (Ollama); ressalvas de prosa |
| Regressão declarativa por linguagem natural (`covariaveis_escola` → `especificar_regressao` → `executar_regressao` → `coeficientes`/`metricas`) | ✓ após 2 correções da camada; o modelo não chamou `metricas` |
| Fluxo de ML com o LLM escolhendo argumentos (`features_escola` → … → `metricas_floresta`) | ✓ com raciocínio desligado; sem `importancia_floresta`; denominadores inventados na prosa |
| Nenhum retorno com nome físico, `integer64` cru ou acima do teto | ✓ testes + checagem das transcrições (0 ocorrências; máx. 14 linhas nas aceitas) |
| Ledger registra as chamadas | ✓ (argumentos recusados pelo ellmer antes da tool não entram) |
| Vignette com transcrições gravadas, `check` sem nova nota/warning | ✓ (`qpdf` instalado no container) |
| Aceite com Anthropic | **pendente**: conta sem créditos |

Detalhes e lições: `memory.md` (2026-10-09); curadoria com o chat em
`docs/personas/`.

## 5. Riscos e mitigação

- **Custo/limite da API Anthropic**: orçamento por sessão (D8), modelo
  configurável (`chat_edubr(modelo = )`) e Ollama local como alternativa
  sem custo; transcrições gravadas uma vez para a vignette.
- **Tool calling de modelos locais** (8–10B): mais sujeito a erros de
  argumento que o Claude — por isso a validação antes do dbplyr e as
  mensagens `parametro_invalido` acionáveis; o aceite do chunk 7 roda nos
  dois provedores.
- **Rede instável até o banco** (vista em 2026-10-08: quedas e picos de
  latência): timeout + erro `conexao` classificado; smoke tolerante a
  reexecução.
- **Memória do container** no treino: D5 (amostra estratificada,
  `num.threads = 2`, `trees ≤ 500`).

## 6. Fora de escopo (da spec)

Agente com memória entre sessões; SQL cru/`show_query()` ao LLM; reescrita
de funções existentes; `tech-lead.md`/repo `leaflet`; refazer
`perfil_escola()`/`comparar()`/`escolas_similares()`.
