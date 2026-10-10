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

## Minha escola (passo a passo)

Para quem quer só ver **a sua escola** no painel do município e do estado,
sem escrever SQL. Basta o código INEP da escola (8 dígitos, o mesmo do
Censo Escolar). Exemplo com uma escola real de Boa Vista do Ramos/AM:

```r
library(eduBR)
con <- conecta()

# 1. A foto da escola: infraestrutura, IDEB e docentes vs município/estado
p <- perfil_escola(con, "13078070")
p
#> ESC MUNICIPAL PROF NORMA SILVA DE OLIVEIRA
#> Rede Municipal — Boa Vista do Ramos/AM (Censo 2025)
#> Fund. I, Fund. II, EJA · 962 matrículas · Urbana
#> Tem: Água de rede pública, Energia de rede pública, Esgoto de rede pública, Quadra de esportes, Refeitório, Internet, Banda larga, Sala dos professores
#> Não tem: Biblioteca, Laboratório de informática
#> IDEB fund. I (2023): 3,6 (município 4,1, estado 5,0); em 2021: 3,5 (+0,1)
#> IDEB fund. II (2023): 3,7 (município 3,9, estado 4,1)
#> Docentes: 75 (município 11,2, estado 11,9)
```

Como ler: o IDEB é comparado **na mesma edição** (2023) e com escolas da
**mesma rede** (aqui, municipais). Na infraestrutura, "município 0,07" em
`comparar()` quer dizer que 7% das escolas do município têm o item.

```r
# 2. A mesma comparação em tabela
comparar(p)
exportar(p, "minha_escola.csv")    # abre direto no Excel/LibreOffice
# exportar(p, "minha_escola.xlsx") # abas Comparação e Resumo (pacote writexl)
#>    dimensao       item                    escola municipio estado dif_municipio
#>  4 Infraestrutura Biblioteca                  0     0.0682  0.244       -0.0682
#> 11 IDEB           IDEB fund. I (2023)       3.6     4.07    4.98        -0.467
#> ...

# 3. Uma linha só (útil para juntar várias escolas)
resumo_escola(p)
#>   escola                rede      etapas                 matriculas ideb_fund_i ano_fund_i var_fund_i
#>   ESC MUNICIPAL PROF …  Municipal Fund. I, Fund. II, EJA        962         3.6       2023        0.1

# 4. Evolução do IDEB da escola (todas as edições)
ideb(con, escola_id = "13078070") |> coletar(n = 50)
#>   etapa            ano ideb_observado
#>   fundamental_i   2015            4.5
#>   fundamental_i   2019            4.1
#>   fundamental_i   2021            3.5
#>   fundamental_i   2023            3.6
#>   fundamental_ii  2023            3.7

# 5. Escolas parecidas para trocar experiências (infraestrutura, porte,
#    docentes e gestão — sem usar a nota)
escolas_similares(con, "13078070", n = 3)
#>   co_entidade escola                         municipio uf rede      distancia
#>   27054128    ESCOLA MUNICIPAL DE ENSINO …   Rio Largo AL Municipal      5.23
#>   31015474    EM DEPUTADO ABELARD PEREIRA    Carandaí  MG Municipal      5.59
#>   22141588    ESCOLA MUNICIPAL POETA DA C…   Teresina  PI Municipal      5.70

DBI::dbDisconnect(con)
```

Troque `"13078070"` pelo código da sua escola. Os números acima são do
banco de desenvolvimento em 2026-10-07 e mudam com novas cargas.

## Uso

As funções de acesso devolvem objetos com consulta **preguiçosa** (lazy):
nada é buscado até você materializar com `as_tibble()`.

```r
con <- conecta()

# escolas de um municipio (cadastro do Censo Escolar)
escolas(con, municipio = "Ubatuba")
escolas(con, co_municipio = 3555406, ativas = TRUE)  # por codigo IBGE
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

## Uso com LLM (ellmer)

O `eduBR` pode ser consultado em linguagem natural por um LLM com
[ellmer](https://ellmer.tidyverse.org): as funções viram **ferramentas**
(tools) que devolvem JSON sem SQL, sem nomes físicos de tabela e sem dados
pessoais, com teto de linhas, timeout e orçamento por sessão. Requer os
pacotes `ellmer` e `jsonlite` (Suggests).

```r
library(eduBR)
con <- conecta()

# ferramentas filtradas para uma persona (gestora-escolar,
# pesquisadora-educacional ou especialista-ml)
tools <- ferramentas_edubr(con, persona = "gestora-escolar")

# Anthropic: ANTHROPIC_API_KEY no ~/.Renviron (nunca no código)
chat <- chat_edubr("anthropic", tools = tools)
# Google Gemini: GEMINI_API_KEY (ou GOOGLE_API_KEY) no ~/.Renviron
chat <- chat_edubr("gemini", tools = tools)
# Ollama local (OLLAMA_BASE_URL; padrão http://localhost:11434, modelo qwen3.5:9b)
chat <- chat_edubr("ollama", tools = tools)

chat$chat("Como está a infraestrutura da escola 13078070 comparada ao município?")
ledger(tools)   # o que o modelo chamou, com que argumentos, linhas e tempo
```

O chat já sai com o prompt de sistema da persona (`prompt_persona()`); para
um chat criado à parte, use `registrar_tools(chat, tools)`. No container
`rstudio.dev`, o Ollama da máquina do desenvolvedor é alcançado por túnel
SSH reverso (`tools/tunnel-ollama.sh abrir`).

Cenários reais gravados (gestora, pesquisadora e especialista em ML) com a
leitura crítica de cada resposta estão na vignette
`vignette("ellmer", package = "eduBR")`; a matriz pergunta × ferramenta, em
[`docs/ellmer.md`](docs/ellmer.md).

## Catálogo

Para ver a que `schema.tabela` cada nome de domínio corresponde — com a
granularidade, a chave de junção (e o tipo no banco) e os anos
disponíveis:

```r
catalogo()
catalogo()[, c("dominio", "chave", "tipo_chave", "coluna_ano", "anos")]
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
  ellmer_*.R      camada LLM: ferramentas_edubr(), chat_edubr(),
                  registrar_tools(), prompt_persona(), ledger()
inst/prompts/     prompts de sistema por persona
vignettes/        ellmer.Rmd (uso com LLM, transcrições gravadas)
```

## Relatórios

R Markdowns em `analysis/` (HTML por padrão; PDF opcional):

```r
rmarkdown::render("analysis/tendencia_ideb_regiao.Rmd")  # tendência (2005–2023)
rmarkdown::render("analysis/regressao_inse_regiao.Rmd")   # IDEB ~ INSE (2023)
rmarkdown::render("analysis/regressoes_censo.Rmd")        # camada declarativa
rmarkdown::render("analysis/classificacao_desempenho_rf.Rmd")  # RF alto/médio/baixo
rmarkdown::render("analysis/perfil_gestor.Rmd")                # perfil modal de diretores
```

Cada report também sai em **PDF** (xelatex; o código fica oculto) e aceita
recortes via `params` (veja o cabeçalho YAML de cada `.Rmd`):

```r
rmarkdown::render(
  "analysis/rede_professor.Rmd",
  output_format = "pdf_document",
  params = list(uf = "AC")          # ou regiao = "Nordeste", rede = "Municipal"
)
```

## Testes

Rodar **localmente**, na máquina de desenvolvimento (com `edumaps` no
`~/.pg_service.conf` para o smoke):

```bash
Rscript -e 'devtools::test()'                       # unitarios (sem banco)
EDUBR_SMOKE=1 Rscript -e 'devtools::test()'         # + smoke contra o [edumaps]
EDUBR_LLM_SMOKE=ollama Rscript -e 'devtools::test(filter = "ellmer-chat")'  # ou anthropic, gemini
Rscript -e 'devtools::check()'                      # inclui a vignette (exige qpdf)
```

Opcional: conferir a compatibilidade com o RStudio Server (`rstudio.dev`,
dbplyr 2.5.0), sincronizando o working tree e rodando lá:

```bash
tools/test-container.sh                  # testes unitarios (sem banco)
tools/test-container.sh --smoke          # + smoke contra o [edumaps] real
tools/test-container.sh --filter ellmer  # so os testes da camada ellmer
tools/test-container.sh --llm ollama     # + smoke com LLM real (tunel aberto)
tools/test-container.sh --llm anthropic  # idem, com ANTHROPIC_API_KEY
tools/test-container.sh --check          # devtools::check() (inclui a vignette)
```

## Licença

MIT.
