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
  espec.R         especificar_regressao(), ler_espec()
  regressao.R     executar_regressao()
  saida.R         coeficientes(), metricas()
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
| `ideb` | `clean.ideb_notas_escolas` |
| `inse` | `clean.inse` |
| `clusters` | `analytics.clustering_metadata` |
| `similaridade` | `analytics.municipio_similaridade` |

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
- `coeficientes(x)` / `metricas(x)` achatam as list-cols.
- Report/exemplo: `analysis/regressoes_censo.yaml` + `regressoes_censo.Rmd`.
- **Pegadinha YAML**: `y`/`n`/`yes`/`no` viram lógicos — aspas se forem
  nome de coluna.

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

> Feito nesta rodada: agrupamento por **macrorregião**
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
