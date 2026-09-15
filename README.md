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
clusters(con)
municipios_similares(con)

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
```

## Testes

```r
devtools::test()                 # testes unitarios (sem banco)
EDUBR_SMOKE=1 devtools::test()   # + smoke contra o [edumaps] real
```

## Licença

MIT.
