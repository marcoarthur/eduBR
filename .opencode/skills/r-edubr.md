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
| `escolas` | `clean.escolas` |
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
| `escolas()` | `municipio`, `uf` | `municipio`, `uf` |
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

## Conexão

`conecta(service = "edumaps")` valida o argumento e delega a
`eduBR_dbConnect()` — indireção interna que chama `DBI::dbConnect()` e
permite **teste sem banco** (mock). Nunca hardcode host/senha.

## Testes

```r
devtools::test()                  # unitários (sem banco)
EDUBR_SMOKE=1 Rscript -e 'devtools::test()'   # + smoke contra o [edumaps]
```

- testthat 3ª edição (`Config/testthat/edition: 3`).
- Testes de domínio **não** tocam o banco: verifique classe, `$tbl`/
  `consulta()` e SQL gerado (`dbplyr::sql_render()`), com uma conexão falsa
  ou `mockery`/`local_mocked_bindings()` sobre `eduBR_dbConnect()`.
- O smoke (`test-smoke.R`) é pulado via `skip_if(Sys.getenv("EDUBR_SMOKE") == "")`.

## Tooling

- **Roxygen2** com `markdown = TRUE`; todo `export()` gera entrada em
  `NAMESPACE` e `man/*.Rd` — nunca editar esses arquivos à mão.
- Após mudar docs: `devtools::document()`.
- Antes de PR: `devtools::test()` e `devtools::check()`.
- Dependências: `DESCRIPTION` → `Imports` (`DBI`, `RPostgres`, `dplyr`,
  `dbplyr`, `tibble`, `rlang`); dev em `Suggests`.
- Comentários/docs em **PT-BR**; mensagens de erro em PT-BR com
  `call. = FALSE`.

## Roadmap de melhorias (backlog das personas)

Pendências abertas na curadoria (`docs/personas/` do repo leaflet):

> Feito nesta rodada: **perfil modal de diretores** (Censo Escolar 2025) —
> `censo_gestor()` + `gestores()` (join com `censo_escolas`, rótulos no SQL) e
> `perfil_gestor()` (9 dimensões, unidade gestor/escola, Herfindahl; report
> `analysis/perfil_gestor.Rmd` com snapshot).
>
> Feito na rodada anterior: **Random Forest de desempenho escolar** (alto/médio/baixo
> por terços de `nota_media` do SAEB/IDEB, escolas públicas fund. I/II) com
> `features_escola()`/`classificar_desempenho()`, floresta com importância por
> permutação (`desempenho.R`/`floresta.R`) e report
> `analysis/classificacao_desempenho_rf.Rmd`.
>
> Feito na rodada anterior: agrupamento por **macrorregião**
> (`ideb_regiao()`), a modelagem de **tendência** (`tendencia_regiao()`) e a
> **transversal com INSE** (`inse()`/`ideb_inse()`/`regressao_inse()`), com
> reports em `analysis/`. Isso **não** resolve o join escola→município por
> código — a região é derivada da UF.

- `[alta]` join escola→município **por código** (`co_municipio`), hoje só
  por nome — expor chave ou helper.
- `[alta]` `coletar(x, n=)` / limite + aviso de custo na materialização.
- `[alta]` `dicionario()`/`rotular()` p/ categóricas do Censo
  (`tp_dependencia`, `tp_localizacao`).
- `[alta]` `as_sf()` / suporte PostGIS para a geometria.
- `[alta]` `perfil_escola()`/`comparar()` (escola vs média município/estado).
- `[média]` projeção/`select` no acesso; `escolas_similares()`; documentar
  origem dos `scores()`; `print` amigável em PT-BR.
