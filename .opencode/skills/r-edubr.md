# Skill: r-edubr

## Purpose
Auxiliar no desenvolvimento do pacote R **eduBR** (`~/Projects/eduBR`),
biblioteca de alto nível que expõe objetos de domínio S3 sobre a base
pública do EduMaps.

## Arquitetura

```
R/
  conexao.R       conecta(), eduBR_dbConnect()
  catalogo.R      eduBR_catalogo(), catalogo(), eduBR_tbl()
  objeto.R        new_eduBR() + métodos S3 do genérico "eduBR"
  escola.R        escolas(), escola()
  municipio.R     municipios(), municipio()
  rede.R          redes()
  indicador.R     indicadores(), scores()
  censo.R         censo_escolar(), censo_docentes(), censo_matriculas()
  ideb.R          ideb()
  cluster.R       clusters()
  similaridade.R  municipios_similares()
  ideb_regiao.R   ideb_regiao()
  tendencia.R     tendencia_regiao()
  inse.R          inse()
  ideb_inse.R     ideb_inse()
  regressao_inse.R  regressao_inse()
  regiao.R        eduBR_mutate_regiao(), eduBR_filtrar_regiao()
  espec.R         especificar_regressao(), ler_espec(), ler_especs()
  regressao.R     executar_regressao()
  saida.R         coeficientes(), metricas()
  coletar.R       coletar() (materializacao com limite)
  desempenho.R    features_escola(), classificar_desempenho(), limites_desempenho()
  floresta.R      dividir_dados(), treinar_floresta(), importancia_floresta(),
                  predizer_floresta(), metricas_floresta(), print.eduBR_floresta()
  gestor.R        gestores(), perfil_gestor() (perfil modal de diretores)
  perfil.R        perfil_escola(), comparar(), resumo_escola(), exportar()
  covariaveis.R   covariaveis_escola()
  similaridade.R  municipios_similares(), escolas_similares() (k-NN no banco)
  censo_docentes.R docentes_rede()
  pca.R           pca_perfil()
  geo.R           as_sf()
  dicionario.R    dicionario(), rotular()
  ellmer_tools.R          núcleo da camada LLM: limites, sessão, envelope,
                          serialização, anti-vazamento, timeout, erros,
                          handles, eduBR_tools_registro(), ferramentas_edubr()
  ellmer_tools_escola.R   perfil_escola, resumo_escola, serie_ideb_escola,
                          escolas_similares, scores_escola, indicadores_escola
  ellmer_tools_pesquisa.R municipios, redes_municipio, docentes_rede, ideb,
                          tendencia_ideb_regiao, covariaveis_escola, perfil_gestor
  ellmer_tools_regressao.R especificar_regressao, executar_regressao,
                          coeficientes, metricas, listar_handles
  ellmer_tools_ml.R       features_escola, classificar_desempenho,
                          dividir_dados, treinar_floresta,
                          importancia_floresta, metricas_floresta, pca_perfil
  ellmer_ledger.R         ledger(), orçamento (chamadas/linhas), CSV opcional
  ellmer_personas.R       prompt_persona(), registrar_tools()
  ellmer_chat.R           chat_edubr() (anthropic | ollama)
inst/prompts/   <persona>.md — prompts de sistema (lidos por prompt_persona())
vignettes/      ellmer.Rmd — 3 cenários com transcrições reais (eval = FALSE)
```

Todo objeto é uma lista com `tbl` (consulta `dbplyr`), `con` (conexão) e
`meta` (descrição/filtros), com classe S3 `c("<dominio>", "eduBR")`:

```r
new_eduBR <- function(tbl, classe, con = NULL, meta = list()) {
  structure(list(tbl = tbl, con = con, meta = meta), class = c(classe, "eduBR"))
}
```

Os genéricos (`consulta()`, `conexao()`, `as_tibble()`, `print()`,
`summary()`) são registrados **uma única vez** em `objeto.R`, com métodos
para `eduBR`. Não crie métodos por domínio sem necessidade real.

## Catálogo (domínio → schema.tabela)

**Fonte única de verdade**: `eduBR_catalogo()` em `R/catalogo.R`. As funções
de alto nível nunca citam `schema.tabela` direto — sempre via
`eduBR_tbl(con, "<dominio>")`.

| domínio | schema.tabela |
|---|---|
| `escolas` | `clean.escolas` (legado: 1ª ingestão, incompleta; não usar) |
| `municipios` | `clean.municipios_sp` |
| `ibge` | `clean.dados_ibge` |
| `populacao` | `clean.populacao_municipal` |
| `redes` | `analytics.mv_rede_escolas` |
| `indicadores` | `analytics.ranking_escola` |
| `scores` | `clean.mv_escolas_scores` |
| `censo_escolas` | `clean.censo_escolas` |
| `censo_docentes` | `clean.censo_docentes` |
| `censo_matriculas` | `clean.censo_matriculas` |
| `censo_gestor` | `clean.censo_gestor` |
| `ideb` | `clean.ideb_notas_escolas` |
| `inse` | `clean.inse` |
| `clusters` | `analytics.clustering_metadata` |
| `similaridade` | `analytics.municipio_similaridade` |
| `escola_features` | `analytics.escola_features` |

Ao adicionar uma relação: registrar em `eduBR_catalogo()` **e** documentar a
função de acesso correspondente.

## Padrão de função de domínio

Filtros são aplicados **na consulta lazy** (antes de materializar), com
`.data$`/`.env$` (importados de `rlang`):

```r
escolas <- function(con, municipio = NULL, uf = NULL) {
  tb <- eduBR_tbl(con, "escolas")
  if (!is.null(municipio)) {
    tb <- dplyr::filter(tb, .data$municipio == .env$municipio)
  }
  if (!is.null(uf)) {
    tb <- dplyr::filter(tb, .data$uf == .env$uf)
  }
  new_eduBR(tb, "eduBR_escola", con,
            list(descricao = "Escolas (identificacao e localizacao)"))
}
```

Colunas usadas nos filtros existentes (confira no banco antes de assumir):

| Função | Filtros | Coluna |
|---|---|---|
| `escolas()` | `municipio`, `uf`, `co_municipio`, `ano`, `ativas` | `municipio`, `uf`, `co_municipio` (de `censo_escolas`) |
| `escola()` | `codigo_inep` | `codigo_inep` |
| `municipios()` | `uf` | `sigla_estado` |
| `municipio()` | `codigo_ibge` | `codigo_ibge` |
| `redes()` | `municipio` | `co_municipio` |
| `indicadores()` | `escola_id`, `indicador` | `id_escola`, `indicador_id` |
| `scores()` | `escola_id` | `co_entidade` |
| `censo_*()` | `escola_id` | `co_entidade` |
| `ideb()` | `escola_id`,`uf`,`municipio`,`etapa`,`rede`,`ano` | `id_escola`,`sg_uf`,`no_municipio`,`etapa`,`rede`,`ano` |
| `ideb_regiao()` | `regiao`,`uf`,`etapa`,`rede`,`ano` | deriva `nome_regiao`/`sigla_regiao` de `sg_uf` |
| `inse()` | `uf`,`municipio`,`ano`,`rede`,`classificacao` | `sg_uf`,`no_municipio`,`nu_ano_saeb`,`tp_tipo_rede`,`inse_classificacao` |
| `ideb_inse()` | `regiao`,`uf`,`etapa`,`rede` | join `ideb` ⋈ `inse` por `id_escola` e `ano = nu_ano_saeb` |
| `clusters()` | `run_id` | `run_id` |

## Modelagem

**Tendência temporal (`tendencia_regiao`)**

- `ideb_regiao()` é o acesso canônico ao IDEB com macrorregião anexada
  (mapa UF→região via `case_when`, sem join por município).
- `tendencia_regiao(con, etapa, rede)` agrega no banco
  (`mean(ideb_observado)` por região/ano/etapa), materializa (~150 linhas) e
  ajusta `parsnip::linear_reg()` por região×etapa, devolvendo um
  `eduBR_tendencia` (list-cols: `modelo`, `coeficientes`, `metricas`,
  `predicoes`).
- Report em `analysis/tendencia_ideb_regiao.Rmd`.

**INSE transversal (`regressao_inse`)**

- O INSE (`clean.inse`) só existe em **2023** e só cobre **públicas** — o
  modelo é um corte transversal, não uma tendência.
- `ideb_inse()` faz `inner_join` de `ideb` (2023) com `inse` por `id_escola`
  e `ano = nu_ano_saeb`, anexando `media_inse`/`inse_classificacao` e a
  região.
- `regressao_inse(con, etapa, rede)` ajusta `ideb_observado ~ media_inse`
  **no nível da escola** por região×etapa; devolve `eduBR_regressao_inse`
  (mesmas list-cols).
- Report em `analysis/regressao_inse_regiao.Rmd`.
- Ambos os reports rodam com `rmarkdown::render()` (`.Rbuildignore` tem
  `^analysis$`) e exigem `parsnip`/`broom`/`tidyr`/`purrr` (Suggests).

**Camada declarativa (`espec.R` + `regressao.R` + `saida.R`)**

- `especificar_regressao(outcome, predictors, cuts, modelo, fonte, filtro, id)`
  ou `ler_espec(caminho)` (YAML) → `eduBR_espec`. `modelo` ∈
  {`"linear"`, `"logistico"`}. `filtro` = lista nomeada de igualdades.
- `executar_regressao(con, espec, dados = NULL)` roda a **mesma regressão
  para cada combinação de `cuts`**; fonte via `fonte` (domínio do catálogo,
  resolve em `eduBR_tbl()`) **ou** `dados` (objeto eduBR/`tbl` — precedência).
  Projeta só `outcome`+`predictors`+`cuts` **antes do `collect`** (pushdown;
  a base remota é lenta). Logístico converte o desfecho para fator.
  Devolve `eduBR_regressoes` (list-cols `modelo`/`coeficientes`/`metricas`/
  `predicoes` + `n`).
- `coeficientes(x)` / `metricas(x)` achatam as list-cols e devolvem **tabela
  limpa** (só cortes + coefs/métricas).
- `ler_especs(caminho)` lê um YAML com lista `analises:` → lista nomeada de
  specs (`id` ou `analise_<i>`).
- Modo logístico: o desfecho é coagido a fator; `metricas()` ganha `auc`
  (método de postos, sem dependência) e `mcfadden` (pseudo-R²).
- Exploração: `coletar(x, n = ...)` materializa com limite (`head`/`LIMIT`);
  sem `n`, **avisa** que está coletando tudo (silencie com `avisar = FALSE`).
- Report/exemplo: `analysis/regressoes_censo.yaml` + `regressoes_multi.yaml`
  + `regressoes_censo.Rmd`.
- **Pegadinha YAML**: `y`/`n`/`yes`/`no` viram lógicos — aspas se forem
  nome de coluna.

**Random Forest de desempenho (`desempenho.R` + `floresta.R`)**

- `features_escola(con, etapa = c("fundamental_i", "fundamental_ii"), publica = TRUE)`
  materializa (lazy) a MV `analytics.escola_features` (~80 colunas; ~77
  features; curricula: infra, contagens, razões, gestão, INSE), filtrando
  `tp_dependencia` ∈ {1,2,3} (públicas). **Não tem UF** — anexar depois com
  `clean.ideb_notas_escolas` por `id_escola == co_entidade`.
- `classificar_desempenho(dados, nota = "nota_media", grupo = "etapa")` define
  os níveis `baixo/medio/alto` por **terços globais dentro de cada grupo**;
  `limites_desempenho(x)` devolve vetor simples (1 grupo) ou lista nomeada.
- `treinar_floresta(dados, alvo = "nivel", features = NULL)` ajusta **ranger**
  (`classification=TRUE`, `probability=TRUE`, `importance="permutation"`). As
  exclusões padrão incluem **identificadores espaciais** (`sg_uf`, `uf`,
  `sg_regiao`, `regiao`, `co_municipio`, `co_uf`, `no_municipio`) — UF é
  rótulo de agregação, **nunca** preditor. Métricas: `acuracia`, `f1_macro`,
  `auc_macro` (ranking/Wilcoxon por classe, sem dependência), `baseline_acerto`
  (classe dominante); atributos `confusao`, `f1_classe`, `auc_classe`.
- Fluxo: `coletar(features_escola(con))` → `classificar_desempenho()` →
  `dividir_dados()` (estratificado) → `treinar_floresta()` →
  `importancia_floresta()` (tibble `var`/`importancia` desc; guia de redução de
  dimensão) → `predizer_floresta()` (fator `nivel_pred` + `p_<classe>`) →
  `metricas_floresta()`.
- Report/exemplo: `analysis/classificacao_desempenho_rf.Rmd`. `ranger` fica em
  **Suggests** (check 0/0/0); **não** usar `vip` (instalação só no container;
  daria NOTA no check local).
- Ambiente de execução: **container `rstudio.dev` (rsuser)** — o treino usa
  **amostra estratificada de até 15 mil escolas por etapa** (`n_amostra`),
  `num.threads = 2` e `trees = 250`; sem isso o container estoura memória
  (`Killed` por OOM, host ~8 GB) ao treinar com a base completa (41k fund. I).
  Predição/perfil/UF usam a base completa. Render completo ≈ 25–30 min, rodar
  em background (`nohup`) e acompanhar o log.
- Pegadinhas recentes: knitr não renderiza ggplot dentro de listas de `map()`
  — usar `.map(...) |> lapply(print)`; `dplyr::select()` **não** aceita objeto
  S3 eduBR — para joins auxiliares usar `tbl(con, in_schema(...))` direto;
  `co_entidade` é `character` mas `id_escola` é `integer64` — `as.character()`
  antes do join.

**Perfil de gestores (`gestor.R`)**

- `censo_gestor(con)` acessa `clean.censo_gestor` (2025): **contagens por
  escola** (`qt_gest_bas`, `qt_gest_fem`, etc.) — uma linha por escola, não
  por gestor; somar `qt_gest_bas` para o total de diretores (~190k).
- `gestores(con, rede, uf, regiao, localizacao, ano = 2025)` cruza com
  `clean.censo_escolas` por `(nu_ano_censo, co_entidade)` e anexa `rede`,
  `categoria_privada`, `localizacao`, `nome_regiao`/`sigla_regiao` — **lazy**;
  materialize com `coletar()` ou passe direto a `perfil_gestor()`.
  Importante: as colunas da tabela `clean` real são **minúsculas**
  (`nu_ano_censo`, `tp_dependencia`, …), não o `UPPER_CASE` do `.sql` fonte.
- Filtros e rótulos empurrados para o SQL: `eduBR_case_when_lookup(col, lab)`
  constrói `case_when` a partir de um vetor nomeado (código → rótulo) —
  **evite** `.env$vetor[col_sql]` / indexação R dentro de `filter`/`mutate`
  em `tbl` (dbplyr quebra ou gera SQL gigante); e evite `.env$fn(x)` dentro de
  `filter` — pré-compute o resultado e use `.env$var`.
- `perfil_gestor(dados, corte = "brasil"/"rede"/"regiao"/"uf"/"categoria_privada",
  unidade = "gestor"/"escola", dimensoes = NULL)`:
  - Materializa (coleta) no primeiro passo — toda agregação roda **em R**.
  - 9 dimensões (spec em `eduBR_dimensoes_gestor()`): sexo, cor/raça (com
    `fora = qt_gest_bas_nd` fora do denominador/composição), escolaridade,
    pós-graduação, faixa etária, vínculo (**restrito à pública**), forma de
    acesso, formação continuada em gestão (≥80h, `denominador = "complemento"`),
    deficiência/TEA/superdotação (idem).
  - Devolve `$proporcoes` (longo: `corte, dimensao, categoria, n, denom, prop,
    composicao`), `$modal` (`categoria_modal`, `prop_modal`, `concentracao` =
    Herfindahl) e `$n` (escolas × gestores por corte).
  - `composicao = FALSE` marca categorias fora da composição (ex.: cor "não
    declarada") — o modal filtra por `composicao`.
- Report: `analysis/perfil_gestor.Rmd` (narrativa rede a rede), com snapshot
  `analysis/capturar_gestor.R` (RDS ~190k linhas; sem ele, coleta ao vivo).
  Render **no container** (`rstudio.dev`).
- Pegadinhas recentes: `dplyr::select(tbl_lazy, co_entidade, …)` com nomes
  "pelados" gera NOTE no `R CMD check` — usar `all_of(c(...))` +
  `starts_with()`; **strings com acento no código** (rótulos, mensagens) geram
  WARNING de non-ASCII no check — usar escapes `\uXXXX` (comentários/roxygen
  podem ficar UTF-8); fixture de teste deve cobrir **todas** as colunas de
  contagem de todas as dimensões usadas no teste.

## Camada ellmer (LLM)

Plano e decisões (D1–D18): `plans/ellmer-tools.md`; matriz pergunta ×
tool: `docs/ellmer.md`; uso: vignette `ellmer`. `ellmer` (0.5.0) e
`jsonlite` em **Suggests** (`rlang::check_installed()`).

**Padrões (toda tool segue):**

- **Validação antes do dbplyr**: `eduBR_validar_*()` (UF com 27 siglas,
  rede, etapa, edição bienal, ano do Censo, `n`, lógicos) recusa argumentos
  ruins com `parametro_invalido` e mensagem acionável (o modelo corrige o
  argumento). Nada de mandar valor cru para `filter()`.
- **Envelope único** (`eduBR_resultado()` / `eduBR_abortar(tipo, msg)`):
  a tool devolve uma **string JSON** `{dados, metadados, erro}`;
  `metadados = {grao, filtros, n, n_total, truncado, aviso, handle,
  colunas_omitidas, contexto}`. Erros: `parametro_invalido`, `sem_dados`,
  `limite_excedido`, `conexao` (mensagem genérica; nunca o texto do
  Postgres/host).
- **Serialização** (`eduBR_serializar()`): `integer64` → texto, datas ISO,
  fatores → texto, `NaN`/`Inf` → `null`, geometria removida, colunas PII
  (endereço, telefone, CEP, CNPJ) omitidas e listadas em
  `colunas_omitidas`. `eduBR_anti_vazamento()` garante que nenhum
  `schema.tabela` do catálogo apareça no JSON (teste varre todas as tools).
- **Tetos**: até 1000 linhas por resposta (`eduBR_hard_cap()`, via
  `coletar(n =)`); coletas internas para treino/regressão até
  `limites$max_amostra` (15 000; máx. 30 000), nunca devolvidas ao modelo;
  timeout por chamada (`statement_timeout` + `setTimeLimit`); orçamento da
  sessão (`max_chamadas` 50, `max_linhas_total` 10 000) → `limite_excedido`.
- **Handles** (`eduBR_handle_guardar()/obter()`): objetos R (base lazy,
  espec, regressão, treino/teste, floresta) ficam no ambiente da sessão; o
  modelo recebe `dados_<k>`, `espec_<k>`, `regressao_<k>`, `treino_<k>`,
  `teste_<k>`, `floresta_<k>`. O `aviso` de quem cria um handle deve dizer
  **qual tool e qual argumento** usam o handle a seguir (o aceite mostrou
  que o modelo de 9B segue esse texto ao pé da letra).
- **Ledger**: toda chamada (inclusive recusada) entra em `ledger(tools)`
  com argumentos JSON, linhas, duração e tipo de erro.
- **Personas**: `eduBR_tools_registro()` diz quais personas veem cada tool;
  `ferramentas_edubr(con, persona =)` filtra; `chat_edubr()`/
  `registrar_tools()` anexam o prompt `inst/prompts/<persona>.md`.

**Adicionar uma tool:**

1. `eduBR_tool_<nome>(sessao)` no arquivo do grupo: `fun` valida, chama a
   função de domínio (sem reescrevê-la), devolve `eduBR_resultado(...)`;
   `eduBR_tool(sessao, "<nome>", fun, descricao =, arguments = list(...),
   titulo =)` com `ellmer::type_*()` (enums quando houver domínio fechado).
2. Entrada em `eduBR_tools_registro()` com `personas`.
3. Linha no prompt das personas que a usam (`inst/prompts/`) e na matriz
   `docs/ellmer.md` (bloco gerado `tools-por-persona`).
4. Testes sem banco (`local_mocked_bindings()` na função de domínio):
   envelope, validação, sem vazamento (`expect_sem_vazamento()`); smoke em
   `test-ellmer-smoke.R`. Strings com acento em `\uXXXX`.

**Aceite com chat real (2026-10-09, `qwen3.5:9b` via Ollama)**: as três
personas encadeiam as tools certas com argumentos escolhidos pelo modelo
(gestora: `perfil_escola`, `escolas_similares`; pesquisadora:
`covariaveis_escola` → `especificar_regressao` → `executar_regressao` →
`coeficientes`; ML: `features_escola` → `classificar_desempenho` →
`dividir_dados` → `treinar_floresta` → `metricas_floresta`); números das
tabelas conferem com as tools, mas a prosa do 9B erra contas derivadas.
O aceite achou dois bugs da camada (aviso de `covariaveis_escola` apontando
argumento inexistente; `etapa` em fator recusada — o ellmer converte
`type_array(type_enum())` em **fator**) e motivou a contagem de escolas com
IDEB na prévia. Janela de 16k tokens do Ollama e turnos "só raciocínio"
são os limites do runtime (ML só completou com
`api_args = list(reasoning_effort = "none")`). Anthropic não testada
(conta sem créditos). Transcrições: `docs/aceite-ellmer/`; script:
`tools/aceite-ellmer.R`.

## Conexão

`conecta(service = "edumaps")` valida o argumento e delega a
`eduBR_dbConnect()` — indireção interna que chama `DBI::dbConnect()` e
permite **teste sem banco** (mock). Nunca hardcode host/senha.

## Testes

Só no container `rstudio.dev`, como `rsuser` (dbplyr 2.5 lá × 2.6 local):

```bash
tools/test-container.sh                 # unitários (sem banco)
tools/test-container.sh --smoke         # + EDUBR_SMOKE=1 (banco real)
tools/test-container.sh --llm ollama    # + smoke com LLM (túnel aberto)
tools/test-container.sh --check         # devtools::check() (com vignette)
```

- testthat 3ª edição (`Config/testthat/edition: 3`).
- Testes de domínio **não** tocam o banco: verifique classe, `$tbl`/
  `consulta()` e SQL gerado (`dbplyr::sql_render()`), com uma conexão falsa
  ou `mockery`/`local_mocked_bindings()` sobre `eduBR_dbConnect()`.
- O smoke (`test-smoke.R`, `test-ellmer-smoke.R`) é pulado sem
  `EDUBR_SMOKE`; o do LLM (`test-ellmer-chat.R`) sem `EDUBR_LLM_SMOKE`.

## Tooling

- **Roxygen2** com `markdown = TRUE`; todo `export()` gera entrada em
  `NAMESPACE` e `man/*.Rd` — nunca editar esses arquivos à mão.
- Após mudar docs: `devtools::document()`.
- Antes de PR: `tools/test-container.sh --smoke` e `--check` (0 erros,
  0 notas; 2 warnings pré-existentes: não-ASCII em `R/pca.R`/`R/perfil.R`
  e link `eduBR_tbl`).
- Dependências: `DESCRIPTION` → `Imports` (`DBI`, `RPostgres`, `dplyr`,
  `dbplyr`, `tibble`, `rlang`); dev em `Suggests`.
- Comentários/docs em **PT-BR**; mensagens de erro em PT-BR com
  `call. = FALSE`.

## Roadmap de melhorias (backlog das personas)

Pendências abertas na curadoria (`docs/personas/` deste repo). A rodada
de 2026-10-07 abriu #20–#28, **todas entregues** em 2026-10-07:

> - Bugs: `as_sf()` registrado como S3 (#20); IDEB do `perfil_escola()` na
>   mesma edição e rede (#21); AUC/métricas da logística com NA (#22);
>   `integer64` como número no k-NN e na PCA (junto da #25).
> - `print` amigável sem SQL/host (#23); chave/tipo/ano no `catalogo()`
>   (#24); `escolas_similares()` com k-NN no banco (~4 min → ~10 s) e saída
>   identificada (#25); evolução do IDEB + `resumo_escola()` (#26); README
>   "Minha escola" (#27); reports em PDF com `params` (#28).
>
> Entregue até 2026-09-30: #6–#18 (perfil/comparar, similares fase 1,
> scores, ler_especs, AUC/McFadden, registrar_relacao, rotular, INSE,
> integer64, PCA).

- Rodada de 2026-10-08 verificou #20–#28 (gestora e ML aprovam;
  pesquisadora aprova com ressalvas) e abriu #36–#40, **todas entregues**
  em 2026-10-08: `as_sf()` vetorizado com `n` e sem aviso (#36);
  `covariaveis_escola()` (#37); prévia do `print` sem tipos/geometria (#38);
  `exportar()` CSV/xlsx (#39); report de PCA re-renderizado e revisado
  (#40). Correções no caminho: só escolas ativas no perfil/covariáveis;
  PCA sem códigos `tp_*` e com sinal fixo.
- Rodada de 2026-10-08 (2ª) verificou #36–#40: gestora e ML **aprovam**;
  pesquisadora aprova com ressalva externa (`co_municipio` em
  `clean.escolas`). A sugestão `[baixa]` dela foi entregue: `pca_perfil()`
  descarta componentes de variância nula e aponta colunas redundantes (#48)
  — os `*_score` são combinação exata dos `in_*`.
- Rodada de 2026-10-08 (3ª): gestora e ML **aprovam**; pesquisadora
  aprova com ressalva externa. Sugestões **entregues** no mesmo dia:
  etapas padrão em `escolas_similares()` (#52); IDEB de etapa não ofertada
  sinalizado no perfil (#53); `pca_perfil(excluir =, redundantes =)` e
  report de PCA sem os `*_score` redundantes (#54).
- Camada `ellmer` (2026-10-08/09, PRs #61–#68 + chunk 7): tools por
  persona, ledger, orçamento, `chat_edubr()` (Anthropic/Ollama), prompts,
  vignette e aceite com chat real. Rodada de curadoria **com o chat**
  (2026-10-09): ver `docs/personas/`.
- Backlog da camada ellmer (atualizado na curadoria de 2026-10-09, última):
  - Entregues: raciocínio desligável (#70), prévias enxutas e limite de
    texto por resposta (#71), taxa de sucesso com N ≤ 2 (#72, parcial:
    gestora 6/6, pesquisadora 1/4, ML 1/1), totais por classe (#74),
    recusas do ellmer no ledger (#75).
  - Entregues também: `regressao_escolas`, regressão numa chamada (#81;
    pesquisadora no chat local 1/4 → 2/2), e `ideb_agregado`, IDEB médio
    por UF/região/município (#82).
  - Entregues depois: `top_features` em `importancia_floresta` (#90),
    `max_tokens` configurável (#89), raciocínio desligado por padrão no
    Ollama (#94) e aceite com Anthropic (#73: 2/2 nos três cenários;
    #83 fechada sem mudar o prompt — a redação solta era do modelo 9B).
  - Curadoria de 2026-10-09 (10ª/12ª/14ª): gestora e ML **aprovam**;
    pesquisadora aprova com ressalva externa (`co_municipio`).
  - **[baixa]** Tool de dicionário de rótulos; `registrar_relacao()` segue
    fora (só leitura).
  - Testes com o Ollama local: **N ≤ 2** (limite térmico do laptop).
- `escolas()` com `co_municipio` (2026-10-09): passa a ler
  `clean.censo_escolas`, a fonte de verdade das escolas; `clean.escolas` é
  legado. Curadoria (gestora 11ª, pesquisadora 14ª, ML 15ª): as três
  **aprovam**; sugestão [baixa] entregue (#99): `escolas()` documenta a
  cobertura de coordenadas (~19% das ativas sem ponto no Censo) e
  `as_sf()` informa, por mensagem, quantas geometrias vieram vazias.
- Bloqueados no EduMaps: INSE histórico
  (painel `inse_{t-1}` → `ideb_t`); similaridade vetorial (PgVector).
