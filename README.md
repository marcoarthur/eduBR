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
censo_gestor(con, escola_id = "35012345")
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

# camada declarativa: mesma regressao para muitos recortes
espec <- especificar_regressao(
  outcome = "ideb_observado", predictors = "nota_media",
  cuts = c("sg_uf", "etapa"), fonte = "ideb", filtro = list(ano = 2023)
)
res <- executar_regressao(con, espec)
coeficientes(res)
metricas(res)
# ou a partir de um YAML: espec <- ler_espec("analysis/regressoes_censo.yaml")
especs <- ler_especs("analysis/regressoes_multi.yaml")  # lista "analises:"

# Random Forest de desempenho (alto/medio/baixo, terços por etapa)
d <- features_escola(con, etapa = c("fundamental_i", "fundamental_ii"))
d <- coletar(classificar_desempenho(d), avisar = FALSE)
partes <- dividir_dados(d)
rf <- treinar_floresta(partes$treino)        # ranger, probabilidade + importancia
importancia_floresta(rf)                     # reducao de dimensao (top-k)
pred <- predizer_floresta(rf, partes$teste)
metricas_floresta(rf, partes$teste)          # acuracia, F1/AUC macro, baseline

# materializar (com limite, para exploracao)
coletar(escolas(con, uf = "SP"), n = 100)

# perfil modal dos diretores (censo_gestor 2025, cruzado com censo_escolas)
g <- gestores(con)                    # contagens por escola + rede/regiao/UF
p <- perfil_gestor(g, corte = "rede") # categoria modal + concentracao por dimensao
p$modal
p$proporcoes
perfil_gestor(g, corte = "uf", unidade = "escola")  # sensibilidade por escola

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
  gestor.R        gestores(), perfil_gestor() (perfil modal de diretores)
  espec.R         especificar_regressao(), ler_espec(), ler_especs()
  regressao.R     executar_regressao() (motor por cortes)
  saida.R         coeficientes(), metricas()
  coletar.R       coletar() (materializacao com limite)
  desempenho.R    features_escola(), classificar_desempenho(), limites_desempenho()
  floresta.R      dividir_dados(), treinar_floresta(), importancia_floresta(),
                  predizer_floresta(), metricas_floresta()
```

## Relatórios

R Markdowns (→ HTML) em `analysis/`:

```r
rmarkdown::render("analysis/tendencia_ideb_regiao.Rmd")  # tendência (2005–2023)
rmarkdown::render("analysis/regressao_inse_regiao.Rmd")   # IDEB ~ INSE (2023)
rmarkdown::render("analysis/regressoes_censo.Rmd")        # camada declarativa
rmarkdown::render("analysis/classificacao_desempenho_rf.Rmd")  # RF alto/médio/baixo
rmarkdown::render("analysis/perfil_gestor.Rmd")                # perfil modal de diretores
```

## Testes

Rodar **apenas no container de teste** (`rstudio.dev`, como `rsuser`) — nunca
na máquina local:

```r
devtools::test()                 # testes unitarios (sem banco)
EDUBR_SMOKE=1 devtools::test()   # + smoke contra o [edumaps] real
```

## Licença

MIT.
