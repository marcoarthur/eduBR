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
| `ideb()` | `escola_id` | `id_escola` |
| `clusters()` | `run_id` | `run_id` |

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

- `[alta]` join escola→município **por código** (`co_municipio`), hoje só
  por nome — expor chave ou helper.
- `[alta]` `coletar(x, n=)` / limite + aviso de custo na materialização.
- `[alta]` `dicionario()`/`rotular()` p/ categóricas do Censo
  (`tp_dependencia`, `tp_localizacao`).
- `[alta]` `as_sf()` / suporte PostGIS para a geometria.
- `[alta]` `perfil_escola()`/`comparar()` (escola vs média município/estado).
- `[média]` projeção/`select` no acesso; `escolas_similares()`; documentar
  origem dos `scores()`; `print` amigável em PT-BR.
