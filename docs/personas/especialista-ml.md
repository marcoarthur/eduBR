# Persona: Especialista em Machine Learning

> Curadoria do pacote `eduBR` (este repo).
> Este arquivo é **perfil + memória**: a cada rodada, acrescente entradas em
> "Entradas" (mais recente no topo), atualize "Pendências" e "Sugestões".
> Histórico trazido de `~/Projects/leaflet/docs/personas/` em 2026-09-28;
> a curadoria passa a viver aqui (lá nada foi apagado — decisão do dev de lá).

## Perfil

- **Papel**: cientista de dados sênior; domina `tidymodels`/`mlr3` e já
  aplicou de k-means/GMM a gradient boosting e modelos multinível
  (hierárquicos) em bases públicas. Foco em **reprodutibilidade** e em
  **ausência de vazamento**.
- **Objetivo com o `eduBR`**: obter as tabelas já tipadas e "preguiçosas" o
  suficiente para compor features em `dplyr`/`dbplyr` e treinar modelos
  (predição de desempenho, clusterização, efeitos por escola/município).
- **Funções que mais usa**: `conecta()`, `consulta()`, `as_tibble()`,
  `scores()`, `indicadores()`, `censo_escolar()`, `censo_docentes()`,
  `censo_matriculas()`, `clusters()`, `catalogo()`.
- **Critérios de avaliação**: (1) fronteira lazy→`collect` explícita e
  controlável; (2) tipos corretos (numérico vs fator) e tratamento de NA;
  (3) sem pré-processamento/vazamento implícito; (4) extensibilidade sem
  reescrever `conecta`/catálogo; (5) performance previsível.

## Perguntas canônicas

1. O acesso preguiçoso (`consulta()`) deixa eu **compor features sem baixar
   tudo**? Onde está a fronteira lazy → `collect`?
2. Como trato NA e variáveis categóricas de **alta cardinalidade**
   (`tp_dependencia`, `tp_localizacao`)? Há dicionário de rótulos?
3. Os `scores()` compostos já vêm prontos? Posso **recalcular/reproduzir**?
4. Consigo **estender** o pacote (novas relações/pipelines) sem reescrever
   `conecta()`/catálogo?

## Entradas

### 2026-10-09 — 12ª rodada (verificação de #81)

**M37 — `regressao_escolas` no modo logístico (direto, sem LLM).**
- Resposta: `in_internet ~ in_biblioteca + docentes` (AC, rede municipal,
  `modelo = "logistico"`) → n = 885, AUC 0,843, McFadden 0,316, com os
  coeficientes em `dados` e as métricas no `contexto`; desfecho contínuo
  (`ideb_fund_i`) em modo logístico → `parametro_invalido` ("exige desfecho
  binário… 48 valores distintos") sem coletar. A tool também está no prompt
  da ML como caminho preferido.
- Status: **✓ atendido**.

### 2026-10-09 — 11ª rodada (verificação de #70, #72, #74, #75)

Tools no banco sem LLM + transcrições de hoje (`ml_r4`, `ml_r5`).

**M34 — `raciocinio = "desligado"` (#70).**
- Resposta: `chat_edubr()` tem o argumento; com ele o fluxo completo
  (`features_escola → … → metricas_floresta`) fechou em 57–65 s com
  resposta (`ml_r4`, `ml_r5`).
- Status: **✓ atendido**.

**M35 — totais por classe e ganho em pontos (#74).**
- Resposta: `metricas_floresta` devolve `totais_classe` (ex.: baixo 99
  real/125 predito/76 acertos; os totais somam o teste e os acertos/n dão
  a acurácia 0,592) e a descrição explica "pontos percentuais". No chat
  (`ml_r5`) o modelo usou os totais corretos (198/201/200) e escreveu
  "+27,2 pontos" — exatamente o que errava na 10ª rodada. Ainda produziu
  um parágrafo confuso sobre tipos de erro.
- Status: **✓ atendido**, com ressalva de redação.

**M36 — auditoria de chamadas recusadas (#75) e taxa (#72).**
- Resposta: recusas do ellmer entram no ledger como
  `argumento_recusado` (testado com o `CallbackManager` real; foi o que
  revelou os argumentos inventados da pesquisadora). Taxa do ML: 1/1 —
  inconclusiva (a rodada maior foi interrompida pelo limite térmico).
- Status: **✓ atendido** (taxa pendente de mais execuções, N ≤ 2).

### 2026-10-09 — 10ª rodada (pergunta ao chat, camada `ellmer`)

Foco: o fluxo de classificação pedido em linguagem natural a um LLM
(`chat_edubr("ollama")`, `qwen3.5:9b`,
`ferramentas_edubr(con, persona = "especialista-ml")`), com o modelo
escolhendo os argumentos. Transcrições: `docs/aceite-ellmer/ml_r1.md` …
`ml_r3.md`.

**M32 — "Treine uma floresta aleatória para classificar o desempenho
(terços da nota) das escolas públicas do fundamental II, com amostra
reprodutível, e avalie contra o baseline."**
- Tentativa 1: `features_escola(etapa = ["fundamental_ii"])` recusada com
  "`etapa` inválida: fundamental_ii" — **bug da camada**: o ellmer converte
  `type_array(type_enum())` em fator e o validador só aceitava texto.
  Corrigido com teste.
- Tentativa 2 (após a correção, com raciocínio): `features_escola` →
  `classificar_desempenho` e o turno terminou só com raciocínio (resposta
  vazia; o pedido de continuação falhou com HTTP 400 do Ollama).
- Tentativa 3 (mesma pergunta, raciocínio desligado com
  `api_args = list(reasoning_effort = "none")`), 49 s:
  `features_escola(etapa = ["fundamental_ii"], publica = true,
  n_por_etapa = 3000, semente = 2023)` → `classificar_desempenho(dados_1,
  nota = "nota_media", grupo = "etapa")` → `dividir_dados(dados_2, prop =
  0.8, semente = 2023)` → `treinar_floresta(treino_1, trees = 250,
  min_node_size = 5, semente = 2023)` → `metricas_floresta(floresta_1,
  teste_1)`.
- Conferido: 3.000 de 31.078 escolas; cortes 4,73/5,35; treino 2.401,
  teste 599; acurácia 0,608 × baseline 0,336; F1 macro 0,602; AUC macro
  0,778; F1 por classe 0,68/0,49/0,64 — iguais ao retorno. Nota fora dos
  preditores (vazamento) e teste da mesma divisão.
- Erros do modelo: denominadores da matriz de confusão inventados
  (253/245/607; o real é 198/201/200); "ganho de 27%" para 0,27 ponto;
  chama de "mais graves" os erros entre classes vizinhas; "%%" na
  formatação. Não chamou `importancia_floresta`.
- Status: **✓ atendido** (com ressalvas: só sem raciocínio; prosa com
  contas erradas).

### 2026-10-08 — 9ª rodada (verificação de #48 e efeito dos `*_score`)

**M31 — componentes nulos e scores redundantes.**
- Resposta: amostra de 4.000 escolas (fund. II): `pca_perfil()` descarta 4
  componentes de variância nula e avisa que `infra_essencial_score`,
  `espacos_pedagogicos_score`, `tecnologia_score` e `acessibilidade_score`
  são combinação linear de outras colunas (dos `in_*`).
- Efeito de manter vs tirar os scores: 61 componentes nos dois casos; PC1
  17,1% vs 16,2% (correlação dos scores de PC1 = 0,989) e PC2 6,7% vs 6,4%
  (correlação 0,944). Sem os scores, PC2 passa a ser puxado por
  `equipamentos_por_aluno`, `prop_mat_medio` e laboratório de ciências em
  vez de `espacos_pedagogicos_score`. O reforço muda pouco o PC1 e
  moderadamente o PC2.
- Status: **✓ atendido** (#48) — sugestão [baixa] sobre os scores.

### 2026-10-08 — 8ª rodada (verificação de #37, #40 e da PCA)

**M28 — covariáveis para modelo multivariado.**
- Resposta: `covariaveis_escola(con, uf = "SP", rede = "Municipal")` é
  lazy (prévia em 1,9 s) e alimenta `executar_regressao()`:
  `ideb_fund_i ~ in_biblioteca + in_internet + docentes + matriculas` por
  `localizacao` → Urbana n=4.228 (R² 0,041), Rural n=293 (R² 0,024). O
  tempo variou com a rede (16 s → 66 s); só as colunas do modelo são
  coletadas. Por padrão só escolas ativas (AC: 1.524 ativas de 1.678; 0
  NA em `in_internet` entre as ativas).
- Status: **✓ atendido** (#37).

**M29 — PCA sem códigos categóricos e com sinal estável.**
- Resposta: amostra de 4.000 linhas (fund. II) após `rotular()`: nenhum
  `tp_*` nem `rede`/`localizacao` nos loadings. Reordenar as linhas dá os
  mesmos loadings em PC1–PC10 (|Δ| ≤ 5e-14). Só PC63–PC65 mudam — têm
  variância ~1e-31 (dependências lineares exatas entre features, ex.:
  totais = soma das partes), ou seja, não carregam informação.
- Status: **✓ atendido** — sugestão [baixa] de descartar componentes de
  variância nula.

**M30 — report de PCA.**
- Resposta: `perfil_escola_pca.Rmd` re-renderizado; o texto descreve PC1
  como porte e PC2 como lotação × oferta por aluno, com snapshot datado e
  nota sobre as correções.
- Status: **✓ atendido** (#40).

### 2026-10-08 — 7ª rodada (verificação de #22, #25, #28 e do `integer64`)

**M21 (revisita) — logística com NA.**
- Resposta: `in_internet ~ in_biblioteca + in_laboratorio_informatica`
  (`censo_escolas`, 2025) roda em AC (n=1.524, McFadden 0,104, AUC 0,612)
  e SP (n=30.817, McFadden 0,051, AUC 0,670); métricas calculadas sobre os
  dados limpos do ajuste.
- Status: **✓ atendido** (#22).

**M25 — `integer64` na PCA.**
- Resposta: amostra de 3.000 linhas de `features_escola(etapa =
  "fundamental_ii")`: os 4 `*_score` chegam como `integer64` e agora
  **entram** nos loadings de `pca_perfil()` (antes caíam como "sem
  variância"). 2.856 escolas × 67 componentes (24,4% em PC1–PC2).
- Status: **✓ atendido** (junto da #25). Atenção: o report
  `perfil_escola_pca.Rmd` muda ao re-renderizar.

**M26 — k-NN no banco é o mesmo k-NN?**
- Resposta: SQL vs caminho em R sobre a coleta total (72 mil linhas, 116 s)
  em 4 escolas (3 sorteadas): mesmos ids, |Δdistância| ≤ 4,4e-15; desempate
  determinístico por `co_entidade`.
- Status: **✓ atendido** (#25).

**M27 — reports em PDF com recorte.**
- Resposta: os 7 `.Rmd` têm `pdf_document` (xelatex, `df_print: tibble`,
  código oculto); README documenta `params`. Renderizações verificadas na
  entrega (PR #35): `rede_professor` (AC e Norte), `tendencia_ideb_regiao`
  e `perfil_gestor`.
- Status: **✓ atendido** (#28).

### 2026-10-07 — 6ª rodada (verificação das entregas #8–#16)

Foco: baixar as pendências entregues em lote em 2026-09-29.

**M20 — `coeficientes()`/`metricas()` em tabela limpa.**
- Resposta: regressão `ideb_observado ~ nota_media` por etapa (AC, 2023)
  em 1,2 s; `coeficientes()` (6×6) e `metricas()` (3×13) sem list-cols.
- Status: **✓ atendido**.

**M21 — métricas do modo logístico (AUC/McFadden).**
- Resposta: `in_internet ~ in_biblioteca + in_laboratorio_informatica`
  em `censo_escolas` (2025, AC e SP) **aborta** em `eduBR_auc()` com
  "valor ausente onde TRUE/FALSE necessário" — NA no outcome/predição
  não é tratado. Os testes só cobrem dados completos.
- Status: **lacuna (bug)** — **#22**.

**M22 — `ler_especs()`.**
- Resposta: YAML com `analises:` (2 specs) → nomes `a1`, `analise_2`; a
  segunda executa. YAML sem a lista dá erro claro.
- Status: **✓ atendido**.

**M23 — extensão do catálogo.**
- Resposta: `registrar_relacao("teste_x", "clean", "inse")` aparece em
  `catalogo()` e resolve em `eduBR_tbl()` (22 colunas); desfaz com
  `desregistrar_relacao()`.
- Status: **✓ atendido**.

**M24 — reprodutibilidade dos `scores()`.**
- Resposta: Rd documenta origem (pipeline EduMaps), escala e bases; sem
  recálculo no pacote (decisão registrada).
- Status: **✓ atendido (documentado)**.

**Observação.** Os comentários de fechamento das issues #8–#13 estão
deslocados (cada um descreve a entrega da issue vizinha); o código existe.

### 2026-09-29 — 5ª rodada (`docentes_rede`, `coletar`, `dicionario`, `integer64`)

Foco: confrontar as funções novas com as pendências de fronteira
lazy→collect (M1/M6/M14), dicionário (M2) e `integer64` (M8).

**M17 — `docentes_rede()` compõe sem baixar tudo? (revisita M1/M6/M14).**
- Resposta: filtros (`uf`/`rede`/ano), projeção (`colunas=`) e `GROUP BY`
  aparecem no SQL; `coletar(q, n = 5)` empurra `LIMIT 5` (1,5 s) e sem `n`
  há aviso ("Materializando a consulta sem limite; use `n =` ou filtre
  antes.").
- Status: **✓ atendido**.

**M18 — `coletar(n=)` existe? (revisita a pendência nº 1).**
- Resposta: sim — `coletar()` com `n` + aviso já está no pacote (a memória
  da 4ª rodada estava desatualizada ao dizer "sem `coletar(n=)`").
- Status: **✓ atendido** — baixa a pendência nº 1.

**M19 — `dicionario()` vs M2.**
- Resposta: `dicionario()` cobre os rótulos de `tp_dependencia`,
  `tp_categoria_escola_privada` e `tp_localizacao`. Tratamento de NA e
  fatores segue do lado do usuário.
- Status: **✓ parcial**.

**M20 — `integer64` (revisita M8).**
- Resposta: as contagens de `docentes_rede()` chegam como `integer64`
  (confirmado: `doc` é `integer64`); sem `bit64`, a impressão sai como
  denormal. Documentado no Rd (`@details`) nesta rodada, em vez de
  normalizar — conversão silenciosa esconderia a precisão real do banco.
- Status: **documentado** (normalização segue [baixa]).

### 2026-09-15 — 4ª rodada (camada declarativa de regressão)

Foco: avaliar o motor genérico (`especificar_regressao()`/`ler_espec()` +
`executar_regressao()` + `coeficientes()`/`metricas()`) e o exemplo
`analysis/regressoes_censo.{yaml,Rmd}`.

**M13 — reproduzível e em escala?**
- Resposta: mesma spec → coeficientes **idênticos** (`all.equal` TRUE). Uma
  spec em YAML (`ideb_observado ~ nota_media`, cortes `[sg_uf, etapa]`,
  ano 2023) gerou **81 modelos** sem loop manual, objeto `eduBR_regressoes`
  (list-cols `modelo`/`coeficientes`/`metricas`/`predicoes` + `n`).
- Status: **✓ atendido** — resolve a escala combinatória de recortes.

**M14 — fronteira lazy→collect (revisita de M1/M6).**
- Resposta: agora há **pushdown de colunas** — o SQL é
  `SELECT "ideb_observado", "nota_media", "etapa" FROM clean.ideb_notas_escolas
  WHERE ano=2023 AND sg_uf='SP'` (só o necessário). Mas continua
  materializando o conjunto filtrado inteiro; segue **sem `coletar(n=)`**.
- Status: **✓ parcial** (melhora de transferência; sem limite/aviso).

**M15 — fonte agnóstica.**
- Resposta: `fonte` resolve qualquer domínio do catálogo via `eduBR_tbl()`;
  `dados=` aceita objeto eduBR (ex.: `ideb_regiao()`), permitindo compor
  recortes antes de modelar. Boa separação acesso × modelagem.
- Status: **✓ atendido**.

**M16 — modo logístico.**
- Resposta: o desfecho é coagido a **fator** automaticamente (evita o erro do
  `parsnip`). Porém `broom::glance` devolve `null.deviance`/`AIC`/`BIC` e
  **não** traz `r.squared`, AUC nem pseudo-R².
- Status: **sugestão**.
- Follow-up: expor métricas de classificação (AUC via `yardstick`/manual;
  R² de McFadden) no resumo.

**Observações extras da rodada.**
- `coeficientes()`/`metricas()` achatam a list-col pedida, mas **mantêm as
  outras** (`modelo`/`predicoes`) — ruído; poderiam devolver tabela limpa.
- `ler_espec()` lê **uma** spec; não há `ler_especs()` para YAML com lista
  `analises:` (o caso "muitas análises num arquivo").
- **YAML**: `outcome: y` vira `logical TRUE` (pegadinha documentada no Rd).
- Base remota teve picos de lentidão (~2k linhas/s); o pushdown ajuda, mas
  não há como limitar linhas na exploração.

### 2026-09-15 — 3ª rodada (INSE e regressão transversal)

Foco: avaliar `inse()` / `ideb_inse()` / `regressao_inse()` e o report
`analysis/regressao_inse_regiao.Rmd`.

**M9 — cobertura e natureza do INSE.**
- Resposta: `clean.inse` tem **só 2023** (`nu_ano_saeb`), 69.756 escolas,
  `tp_tipo_rede` ∈ {1,2,3} (federal/estadual/municipal) — **sem privadas**.
  `media_inse` sem NA (2,21–6,65). O join `ideb_inse()` devolve 97.521 linhas
  (2023), 68.937 escolas distintas, sem `Privada`.
- Status: **✓** com ressalva de escopo (corte 2023, só públicas).
- Follow-up: não há série histórica de INSE → o painel INSE×IDEB depende de
  carga de SAEBs anteriores.

**M10 — reprodutibilidade da regressão transversal.**
- Resposta: `regressao_inse(con, etapa)` devolve `eduBR_regressao_inse`; duas
  execuções com coeficientes **idênticos** (`all.equal` TRUE). Nível escola
  (fund. II: 31.084 escolas). Gradientes (IDEB/INSE) por região: CO 1,22 >
  SE 1,13 > N 1,09 > S 1,03 > **NE 0,61**.
- Status: **✓ atendido**.

**M11 — vazamento/contemporaneidade.**
- Resposta: INSE e IDEB são **do mesmo ano (2023)** → é associação
  **contemporânea**, não uma configuração de predição (sem holdout temporal).
  Para previsão, o correto seria INSE defasado (`t-1`) prevendo o IDEB de
  `t`.
- Status: **observação/sugestão**.
- Follow-up: marcar no report/README que é associação, e prever `ideb_t` com
  `inse_{t-1}` quando houver histórico.

**M12 — cardinalidade do join (1:n por etapa).**
- Resposta: 68.937 escolas → 97.521 linhas (~1,4/school): uma escola entra
  uma vez por etapa do IDEB, repetindo `media_inse`. Nos modelos por
  região×etapa isso é correto; se alguém agrupar etapas sem cuidado, duplica
  escolas.
- Status: **observação**.
- Follow-up: documentar/avisar o 1:n de `ideb_inse()` (por etapa).

**Observações extras da rodada.**
- Join por `id_escola` (bigint nos dois lados) — sem o problema de tipo do
  `co_municipio`×`codigo_ibge`; foi limpo.
- `regressao_inse()` materializa o corte inteiro (~97 mil linhas) por não
  haver `coletar(n=)`; aqui é necessário para o ajuste, mas reforça a
  pendência de controle de materialização.
- `eduBR_catalogo()` segue interno (M4) e `catalogo()` já lista `inse`.

### 2026-09-15 — 2ª rodada (tendência do IDEB e report)

Foco: avaliar o novo fluxo de modelagem (`ideb_regiao()` +
`tendencia_regiao()`) e o report de tendência por região.

**M5 — a tendência é reproduzível?**
- Resposta: `tendencia_regiao(con, etapa, rede)` devolve um
  `eduBR_tendencia` (tibble 5×9 em `fundamental_ii`) com list-cols
  `modelo`, `coeficientes`, `metricas`, `predicoes`. Duas execuções
  produzem coeficientes **idênticos** (`all.equal` TRUE); motor `lm` via
  `parsnip::linear_reg()`. O report
  (`analysis/tendencia_ideb_regiao.Rmd`) é parametrizado (`etapa`, `rede`).
- Status: **✓ atendido** (ressalva: é tendência linear bivariada, por design).
- Follow-up: a persona quer covariáveis (rede, infraestrutura) — quando o
  pacote expuser `perfil_escola()`/features, estender o report.

**M6 — compor features sem baixar tudo (revisita de M1).**
- Resposta: `consulta(ideb_regiao(con, etapa="fundamental_ii"))` é
  `tbl_sql`; `group_by/summarise` antes do `collect` reduz **322.831 linhas
  → 50** no banco. A fronteira lazy→collect é controlável **se** se compõe a
  query. O risco persiste no `as_tibble()` direto (sem limite/aviso).
- Status: **✓ parcial**.
- Follow-up: `coletar(x, n=)`/`cabeça()` + aviso de custo quando o objeto
  não foi filtrado/agregado.

**M7 — categóricas do IDEB.**
- Resposta: no IDEB, `rede` (`Municipal/Estadual/Federal/Privada`) e
  `etapa` (`fundamental_i/ii`, `ensino_medio`) já vêm como texto legível —
  não precisa de dicionário nesse fluxo. Os códigos crus
  (`tp_dependencia`, `tp_localizacao`) seguem no Censo.
- Status: **✓ para o IDEB** (lacuna de dicionário persiste no Censo).

**M8 — `integer64` em agregações `bigint`.**
- Resposta: `count()`/agregações que devolvem `bigint` chegam como
  `integer64`; sem `bit64` carregado imprimem como denormal
  (ex.: `1.6e-318` para 322.831) — risco de leitura errada.
- Status: **sugestão**.
- Follow-up: normalizar (`as.numeric`) nas funções de contagem ou documentar.

**Observações extras da rodada.**
- `pdflatex`/`tinytex` disponíveis: o report dá para exportar em **PDF**,
  hoje só HTML (preferência do usuário).
- Região derivada da UF (mapa `case_when`), então **não** resolve o join
  escola→município por código — são lacunas distintas.

### 2026-09-15 — 1ª rodada (perguntas canônicas)

**M1 — fronteira lazy → collect.**
- Resposta: `consulta(x)` devolve `tbl_sql` (lazy) e `as_tibble(x)` faz o
  `collect`. O default é materializar **tudo**: `ideb()` tem 814.448 linhas,
  `censo_escolas` 214.192, e `escolas(uf="SP")` levou ~40 s para 28.710
  linhas. Não há `n`/amostra nem aviso.
- Status: **lacuna**.
- Follow-up: API de amostragem/limite (ex.: `coletar(x, n=)` ou
  `cabeça(x)`) e aviso de custo na materialização total.

**M2 — NA e categóricas de alta cardinalidade.**
- Resposta: `tp_dependencia` e `tp_localizacao` são `smallint` (códigos
  1..4), sem rótulo nem fator — o usuário precisa do dicionário do Censo
  fora do pacote. Não há função de dicionário.
- Status: **sugestão**.
- Follow-up: expor `dicionario()`/`rotular()` para as categóricas do Censo.

**M3 — scores prontos e reprodutíveis.**
- Resposta: `scores()` lê `clean.mv_escolas_scores` (matview pré-calculada,
  9 colunas; populada). Os valores vêm prontos, mas **não há função para
  recalcular** nem documentação da fórmula/origem no pacote.
- Status: **sugestão**.
- Follow-up: documentar a origem dos scores e/ou oferecer recálculo.

**M4 — extensibilidade.**
- Resposta: `catalogo()` é público (só leitura), mas `eduBR_catalogo()` e
  `eduBR_tbl()` são **internos**; não há ponto de extensão para registrar
  uma relação nova.
- Status: **sugestão**.
- Follow-up: expor um `registrar_relacao()`/overrides do catálogo.

**Observações extras da rodada.**
- `escola()`/`scores()` aceitam `escola_id` como string **e** como número
  (o Postgres faz o cast), então não trava por tipo — bom.
- `municipios_similares()` está **vazia** em dev (0 linhas).

## Pendências

- [x] Amostragem/limite na materialização (`coletar(n=)` + aviso existem).
- [x] Dicionário/rótulos para categóricas do Censo (`dicionario()`).
- [x] `integer64` documentado; decisão: sem coerção silenciosa (#16).
- [x] `integer64` tratado como número no k-NN e na PCA.
- [x] Reprodutibilidade dos `scores()` (documentada no Rd).
- [x] Ponto de extensão do catálogo (`registrar_relacao()`).
- [x] Avisos de contemporaneidade/1:n em `ideb_inse()` (#15).
- [x] `ler_especs()` (YAML com `analises:`).
- [x] `coeficientes()`/`metricas()` em tabela limpa.
- [x] AUC no modo logístico robusta a NA (#22).
- [x] Report: export em PDF + parâmetros de recorte (#28).
- [x] Covariáveis do perfil para modelos (#37).
- [x] PCA sem códigos `tp_*`, sinal fixo e report revisado (#40).
- [x] PCA sem componentes nulos e com opção de remover redundantes (#48, #54).
- [x] Raciocínio desligável no chat (#70) e totais por classe (#74).
- [x] Recusas do ellmer no ledger (#75; confirmado com LLM real na
  10ª rodada da pesquisadora).
- [x] Regressão numa chamada também para a ML (#81).
- [ ] Série histórica de INSE (bloqueada por dados no pipeline EduMaps).
- [ ] Repetir M32 com o provedor Anthropic (#73, conta sem créditos).
- [ ] Taxa do fluxo de ML com mais execuções (N ≤ 2 por rodada).
- [ ] Follow-up M33: pelo chat, "quais features importam? retreine só com
  as 20 primeiras e compare".

## Sugestões priorizadas

- **[média]** Carregar SAEBs anteriores (INSE histórico) → painel
  `inse_{t-1}` → `ideb_t` (código pronto; bloqueado no EduMaps).
- **[baixa]** Chat: o modelo local ainda escreve interpretações confusas
  da matriz de confusão; reavaliar com modelo maior (#73, #83).

## Veredito

- **Aprova com ressalvas** (2026-10-09, 12ª rodada): tool composta de
  regressão correta também no modo logístico; ressalvas mantidas (taxa do
  fluxo de ML com N pequeno; Anthropic #73).
- **Aprova com ressalvas** (2026-10-09, 11ª rodada): as correções #70 e
  #74 aparecem no chat (fluxo fecha; totais e ganho corretos); ressalvas:
  taxa ainda com N pequeno e redação confusa ocasional do modelo local.
- **Aprova com ressalvas** (2026-10-09, 10ª rodada, chat com
  `qwen3.5:9b`): o fluxo completo (amostra reprodutível → terços → holdout
  → floresta → métricas contra o baseline) sai de uma pergunta, com
  argumentos escolhidos pelo modelo e sem vazamento; métricas conferem.
  Ressalvas: exigiu corrigir a camada (`etapa` em fator) e desligar o
  raciocínio; a prosa inventa denominadores. Anthropic não testada.

- **Aprova** (2026-10-08, 9ª rodada): saída da PCA sem componentes
  degenerados e com diagnóstico de colinearidade; o efeito dos scores
  redundantes é mensurável e pequeno no eixo principal.
- **Aprova** (2026-10-08, 8ª rodada): covariáveis prontas para modelos
  multivariados, PCA metodologicamente limpa (sem códigos categóricos,
  sinal fixo) e report coerente. Pendência só de dados (INSE histórico).
- **Aprova** (2026-10-08, 7ª rodada): fronteira lazy→collect controlada,
  k-NN empurrado ao banco e equivalente ao de referência, métricas da
  logística robustas a NA, `integer64` tratado e reports reprodutíveis em
  PDF. A única pendência (INSE histórico) é de dados, fora do pacote.
- **Aprova com ressalvas** (2026-10-07, 6ª rodada): extensão do catálogo,
  `ler_especs()`, saídas limpas e origem dos `scores()` verificadas contra o
  banco. Ressalva bloqueante para classificação: o modo logístico quebra
  com NA (#22). Demais: PDF dos reports (#28) e INSE histórico (dados).
- **Aprova com ressalvas** (2026-09-29, 5ª rodada): fronteira lazy→collect
  sob controle (`coletar(n=)` + aviso + pushdown/agregação no banco),
  dicionário de rótulos pronto e `integer64` documentado. Ressalvas:
  métricas para o modo logístico, `ler_especs()` (multi-spec em YAML),
  reprodutibilidade dos `scores()`, extensão do catálogo, INSE histórico e
  avisos de contemporaneidade/1:n em `ideb_inse()`.
