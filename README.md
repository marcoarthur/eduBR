# eduBR

> Biblioteca R de alto nível para explorar a base pública de educação do
> **EduMaps** — Censo Escolar, IDEB, IBGE e OpenStreetMap — armazenada em
> PostgreSQL.

O `eduBR` esconde os nomes físicos de schema e tabela por trás de **objetos
de domínio (S3)**: você trabalha com `escola`, `municipio`, `rede`,
`indicador`, `censo`, `ideb` e `cluster`, não com `clean.censo_escolas` ou
`analytics.ranking_escola`.

## Instalação

```r
# a partir do repositório local
devtools::install("caminho/para/eduBR")
```

## Conexão

A conexão usa um *service* do libpq (`~/.pg_service.conf`), mantendo
credenciais fora do código:

```r
library(eduBR)

con <- conecta(service = "edumaps")   # padrao: "edumaps"
# con <- conecta(service = "edumaps_local")  # dentro da rede dos containers

DBI::dbListTables(con)
DBI::dbDisconnect(con)
```

## Uso

As funções de acesso devolvem objetos com consulta **preguiçosa** (lazy):
nada é buscado até você materializar com `as_tibble()`.

```r
con <- conecta()

# escolas de um municipio
escolas(con, municipio = "Ubatuba")
escola(con, "35012345")

# municipios de SP
municipios(con, uf = "SP")
municipio(con, "3555406")

# indicadores e scores por escola
indicadores(con, indicador = "infraestrutura")
scores(con, escola_id = "35012345")

# censo, ideb, clusters e similaridade
censo_escolar(con, escola_id = "35012345")
censo_docentes(con, escola_id = "35012345")
censo_matriculas(con, escola_id = "35012345")
ideb(con, escola_id = "35012345")
ideb(con, uf = "SP", etapa = "fundamental_ii", ano = 2019)
clusters(con)
municipios_similares(con)

# IDEB por macrorregiao e tendencia (regressao linear por regiao x etapa)
ideb_regiao(con, regiao = "Sudeste", etapa = "fundamental_ii")
tendencia_regiao(con)

# INSE (nivel socioeconomico, corte 2023) e regressao transversal
inse(con, uf = "SP", rede = 3)
ideb_inse(con, regiao = "Nordeste", etapa = "fundamental_ii")
regressao_inse(con)

# materializar
library(dplyr)
escolas(con, uf = "SP") |> as_tibble()
escolas(con, uf = "SP") |> consulta() |> count(municipio)
```

## Catálogo

Para ver a que `schema.tabela` cada nome de domínio corresponde:

```r
catalogo()
```

## Estrutura

```
R/
  conexao.R     conecta(), educBR_dbConnect()
  catalogo.R    mapeamento dominio -> schema.tabela
  objeto.R      construtor S3 + print/summary/as_tibble/consulta/conexao
  escola.R      escolas(), escola()
  municipio.R   municipios(), municipio()
  rede.R        redes()
  indicador.R   indicadores(), scores()
  censo.R       censo_escolar(), censo_docentes(), censo_matriculas()
  ideb.R        ideb()
  cluster.R     clusters()
  similaridade.R  municipios_similares()
  ideb_regiao.R   ideb_regiao()
  tendencia.R     tendencia_regiao()
  inse.R          inse()
  ideb_inse.R     ideb_inse()
  regressao_inse.R  regressao_inse()
  regiao.R        helpers de macrorregiao (UF -> regiao)
```

## Relatórios

R Markdowns (→ HTML) em `analysis/`:

```r
rmarkdown::render("analysis/tendencia_ideb_regiao.Rmd")  # tendência (2005–2023)
rmarkdown::render("analysis/regressao_inse_regiao.Rmd")   # IDEB ~ INSE (2023)
```

## Testes

```r
devtools::test()                 # testes unitarios (sem banco)
EDUBR_SMOKE=1 devtools::test()   # + smoke contra o [edumaps] real
```

## Licença

MIT.
