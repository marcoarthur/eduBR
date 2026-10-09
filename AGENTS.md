# AGENTS.md

## Project: eduBR

Pacote R de **alto nível** para explorar a base pública de educação do
**EduMaps** — Censo Escolar, IDEB, IBGE e OpenStreetMap — armazenada em
PostgreSQL (PostGIS).

O `eduBR` esconde os nomes físicos de `schema.tabela` por trás de **objetos
de domínio S3** (`escola`, `municipio`, `rede`, `indicador`, `censo`, `ideb`,
`cluster`) com consulta **preguiçosa** (`dbplyr`).

Stack: **R (S3 / dbplyr / DBI / RPostgres) / PostgreSQL (PostGIS) / testthat /
roxygen2**.

> O repo irmão **EduMaps** (`~/Projects/leaflet`, GitHub
> `marcoarthur/edumaps`) contém backend (Perl/Mojolicious), frontend
> (Svelte/Leaflet), pipeline (Sqitch) e a curadoria do `eduBR`.

## Repo layout

```
R/
  conexao.R       conecta(), eduBR_dbConnect()
  catalogo.R      eduBR_catalogo(), catalogo(), eduBR_tbl(), registrar_relacao()
  objeto.R        new_eduBR() + métodos S3 do genérico "eduBR"
  escola.R        escolas(), escola()
  municipio.R     municipios(), municipio()
  rede.R          redes(), rede_municipio()
  indicador.R     indicadores(), scores()
  censo.R         censo_escolar(), censo_docentes(), censo_matriculas()
  censo_docentes.R  docentes_rede()
  ideb.R          ideb()
  cluster.R       clusters()
  similaridade.R  municipios_similares(), escolas_similares()
  ideb_regiao.R   ideb_regiao()
  tendencia.R     tendencia_regiao()
  inse.R          inse()
  ideb_inse.R     ideb_inse()
  regressao_inse.R  regressao_inse()
  regiao.R        helpers de macrorregião (UF -> região)
  gestor.R        gestores(), perfil_gestor()
  perfil.R        perfil_escola(), comparar(), resumo_escola(), exportar()
  covariaveis.R   covariaveis_escola()
  desempenho.R    features_escola(), classificar_desempenho()
  floresta.R      dividir_dados(), treinar_floresta(), metricas_floresta() ...
  pca.R           pca_perfil()
  geo.R           as_sf()
  dicionario.R    dicionario(), rotular()
  espec.R         especificar_regressao(), ler_espec(), ler_especs() (camada declarativa)
  regressao.R     executar_regressao() (motor por cortes)
  saida.R         coeficientes(), metricas()
  coletar.R       coletar() (materialização com limite)
  ellmer_tools.R  ferramentas_edubr(): núcleo (envelope, serialização,
                  tetos, timeout, erros, handles, registro das tools)
  ellmer_tools_escola.R     tools da gestora (perfil, resumo, similares...)
  ellmer_tools_pesquisa.R   tools da pesquisadora (ideb, redes, covariáveis...)
  ellmer_tools_regressao.R  especificar/executar_regressao, coeficientes...
  ellmer_tools_ml.R         features, classificação, floresta, PCA
  ellmer_ledger.R   ledger() e orçamento da sessão
  ellmer_personas.R prompt_persona(), registrar_tools()
  ellmer_chat.R     chat_edubr() (provedores anthropic | ollama)
inst/prompts/     prompts de sistema por persona (<persona>.md)
vignettes/        ellmer.Rmd (transcrições gravadas, eval = FALSE)
man/              Rd gerados por roxygen2 (não editar à mão)
tests/testthat/   testes unitários + smoke opcional (+ smoke com LLM)
analysis/         reports R Markdown (fora do build; HTML gitignored)
docs/             personas/ (curadoria) e ellmer.md (matriz pergunta × tool)
plans/            planos de trabalho (ellmer-tools.md)
memory.md         decisões e lições entre sessões
tools/
  sync-rstudio.sh   rsync do repo p/ o RStudio Server (rstudio.dev)
  rstudio-dest.sh   destino no container (um diretório por worktree)
  test-container.sh testes/check no container como rsuser (opcional)
  tunnel-ollama.sh  túnel SSH reverso do Ollama local para o container
DESCRIPTION       metadados e dependências
NAMESPACE         gerado por roxygen2 (não editar à mão)
```

## Commit conventions (git-message)

```
<type>(<scope>): <subject>
```

Types: `feat`, `fix`, `test`, `refactor`, `docs`, `chore`, `perf`
Scopes: `edubr`, `conexao`, `catalogo`, `objeto`, `dominio`, `tests`,
`docs`

Máx. 50 chars no subject. Mensagem de commit em **PT-BR**.

## Running tests

Testes rodam **localmente** no host de desenvolvimento `ubaxala` (regra
revista em 2026-10-09). A regra antiga, "só no container", existia por
causa do laptop anterior, de CPU fraca; o `ubaxala` é robusto e tem o
ambiente completo: R 4.6.1, dbplyr 2.6.0, `ellmer` 0.5.0, `sf`, `ranger`,
`qpdf` e o serviço `edumaps` no `~/.pg_service.conf`. O `document()` local
não gera diferença no `man/` (o do container reformata).

```bash
devtools::test()                                        # unitários (sem banco)
EDUBR_SMOKE=1 Rscript -e 'devtools::test()'             # + smoke (banco real)
EDUBR_SMOKE=1 Rscript -e 'devtools::test(filter = "ellmer")'
EDUBR_LLM_SMOKE=ollama Rscript -e 'devtools::test(filter = "ellmer-chat")'
_R_CHECK_SYSTEM_CLOCK_=FALSE Rscript -e 'devtools::check()'
devtools::document()                                    # NAMESPACE/man
```

Referência (`ubaxala`, 2026-10-09): suíte completa com smoke de 9 a
16 min; só `ellmer` com smoke ≈ 4 min; `check` ≈ 1 min. O tempo do
smoke é de **rede**, não de CPU: o `ubaxala` alcança o banco por Wi-Fi
(≈ 0,25 MB/s medidos). O smoke nacional de `perfil_gestor` (≈ 190 mil
linhas) leva de 50 a mais de 120 s aqui, contra 6 s no container, e pode
estourar o `timeout_s = 120` do teste. Se só esse teste falhar por
"tempo limite atingido", confirme no container.

O container `rstudio.dev` passa a ser **opcional**: serve para conferir a
compatibilidade com o RStudio Server, que tem **dbplyr 2.5.0** (o 2.5 não
traduz tudo o que o 2.6 traduz; ver "Lições"). Rode lá quando mexer em
tradução dbplyr nova ou antes de um PR com mudança grande de SQL:

```bash
tools/test-container.sh                    # devtools::test() (unitários, sem banco)
tools/test-container.sh --smoke            # + EDUBR_SMOKE=1 (banco real)
tools/test-container.sh --filter ellmer    # só test-*ellmer*.R
tools/test-container.sh --llm ollama       # + smoke com LLM real (túnel aberto)
tools/test-container.sh --llm anthropic    # idem, com ANTHROPIC_API_KEY no rsuser
tools/test-container.sh --check            # devtools::check() (constrói a vignette)
tools/test-container.sh --no-sync ...      # sem rsync antes
```

- Unitários **não** tocam o banco; o smoke (`test-smoke.R`,
  `test-ellmer-smoke.R`) é pulado sem `EDUBR_SMOKE=1` e o do LLM
  (`test-ellmer-chat.R`) sem `EDUBR_LLM_SMOKE`.
- `devtools::document()` regenera `NAMESPACE`/`man/` — rode localmente.
- `check` esperado: 0 erros, 0 notas e 2 warnings pré-existentes
  (não-ASCII em `R/pca.R`/`R/perfil.R`; link `eduBR_tbl`). A vignette
  exige o executável `qpdf` (instalado no `ubaxala` e no container em
  2026-10-09; sem ele, warning
  "'qpdf' is needed"). Se os serviços de hora (worldtimeapi) estiverem
  fora do ar, aparece a NOTE "unable to verify current time" — ambiental;
  confirme com `_R_CHECK_SYSTEM_CLOCK_=FALSE`.

## Sincronização com o RStudio Server (rstudio.dev)

O RStudio Server roda no container `rstudio.dev` (`ubatexu.lan:2024`, SSH
como `root`), acessível na web em `ubatexu.lan:8787`. O pareamento é um
`rsync` do working tree para `/home/rsuser/projetos/eduBR` (cada `git
worktree` vai para o próprio `/home/rsuser/projetos/eduBR-wt-<nome>`, dado
por `tools/rstudio-dest.sh`; `EDUBR_SYNC_DEST` sobrepõe).

```bash
tools/sync-rstudio.sh      # manual (de qualquer lugar dentro do repo)
```

- **Sem `--delete`**: o que for criado no container (ex.: análises usando o
  pacote) **não** é apagado; o rsync só adiciona/atualiza.
- Os arquivos chegam como `root`; o script corrige o dono ao final
  (`chown -R rsuser:rsuser`, não `chmod`).
- Exclui `.git/`, `.Rproj.user/`, `.Rhistory`, `.RData` e os HTML gerados.
- **Automação**: `.git/hooks/post-commit` é um symlink para o script e
  sincroniza a cada commit. O hook não é versionado — reinstale após clonar:

  ```bash
  ln -sf ../../tools/sync-rstudio.sh .git/hooks/post-commit
  ```

No container, o pacote fica em `/home/rsuser/projetos/eduBR`; importe com
`devtools::load_all("~/projetos/eduBR")` ou `devtools::install(...)`.

## Camada `ellmer` (LLM)

Expõe o `eduBR` a LLMs via [ellmer](https://ellmer.tidyverse.org) (0.5.0,
instalado localmente e no container; em `Suggests`):

- `ferramentas_edubr(con, persona = , limites = )` → lista de tools
  (envelope JSON `dados`/`metadados`/`erro`, sem SQL nem `schema.tabela`,
  `integer64` como texto, teto de 1000 linhas por resposta, timeout e
  orçamento por sessão, handles `dados_<k>`/`espec_<k>`/`regressao_<k>`/
  `floresta_<k>`).
- `chat_edubr("anthropic" | "ollama", tools = , persona = )`,
  `registrar_tools(chat, tools)`, `prompt_persona()` e `ledger(tools)`.
- Prompts por persona em `inst/prompts/`; matriz pergunta × tool em
  `docs/ellmer.md`; plano e decisões em `plans/ellmer-tools.md`; vignette
  `vignettes/ellmer.Rmd` (transcrições reais gravadas, `eval = FALSE`).
- **Anthropic**: `ANTHROPIC_API_KEY` no `~/.Renviron` do `rsuser` (nunca
  no código). **Ollama**: roda na máquina do dono do repo (`qwen3.5:9b`);
  o container o alcança por **túnel SSH reverso**:

  ```bash
  tools/tunnel-ollama.sh abrir    # ou status | fechar
  ```

  Com o túnel aberto, `chat_edubr("ollama")` no container usa
  `http://localhost:11434` (ou `OLLAMA_BASE_URL`).
- Tool nova: `eduBR_tool_<nome>(sessao)` no arquivo do grupo, validação
  antes do dbplyr, `eduBR_resultado()`/`eduBR_abortar()`, entrada em
  `eduBR_tools_registro()` com as personas, linha no prompt da persona e
  em `docs/ellmer.md` (os testes de personas conferem a consistência).
  Detalhes na skill `r-edubr` ("Camada ellmer").

## Database

- Alvo dev: `edumaps_dev` em `ubatexu.lan` (user: `devel`).
- Conexão pelo pacote: `conecta(service = "edumaps")` via
  `~/.pg_service.conf` (credenciais **nunca** no código).
- Inspeção manual: `PGPASSWORD=... psql -h ubatexu.lan -U devel -d edumaps_dev`
- Relações: `clean.*` (dados limpos), `analytics.*` (MVs agregadas),
  `staging.*` (temporárias dos jobs R).
- Detalhes de schema/tipos/códigos: skill `postgres-postgis`.

## Key conventions (R)

- Todo acesso passa pelo catálogo `eduBR_catalogo()` (domínio →
  `schema.tabela`) e por `eduBR_tbl()`; não citar `schema.tabela` direto.
- Objetos: lista `list(tbl, con, meta)` com classe `c("<dominio>", "eduBR")`.
- Filtros aplicados na consulta **lazy** com `.data$`/`.env$` (rlang).
- Métodos S3 registrados uma vez, em `objeto.R`.
- Argumentos inválidos → `stop(..., call. = FALSE)`, mensagens em PT-BR.
- Documentação roxygen2 (`markdown = TRUE`); `NAMESPACE`/`man/` só via
  `devtools::document()`.
- Dependências declaradas em `DESCRIPTION` (`Imports` ordenado).

## Camada declarativa de regressão

- `especificar_regressao()`/`ler_espec()` criam um `eduBR_espec`;
  `executar_regressao(con, espec, dados = NULL)` roda a mesma regressão para
  cada combinação de `cuts`.
- Fonte agnóstica: `fonte` (domínio do catálogo) ou `dados` (objeto eduBR).
  **Projeta só as colunas necessárias antes do `collect`** — a base remota é
  lenta.
- `coeficientes()`/`metricas()` achatam as list-cols. Exemplos em
  `analysis/regressoes_censo.yaml` + `regressoes_censo.Rmd`.
- `ler_especs()` lê um YAML com lista `analises:`; `coletar(x, n=)` materializa
  com limite e avisa quando não há `n` (evita o `collect` total implícito).
- YAML: `y`/`n`/`yes`/`no` viram lógicos (use aspas se forem nome de coluna).

## Skills

Arquivos de skill em `.opencode/skills/`:

| Skill | Arquivo | Quando usar |
|-------|---------|-------------|
| agent-persona | `agent-persona.md` | Sempre (persona e anti-padrões) |
| r-edubr | `r-edubr.md` | Código R: objetos S3, catálogo, testes, roxygen |
| postgres-postgis | `postgres-postgis.md` | Schema, tipos, PostGIS, código do Censo |

As demais skills do repo EduMaps (`perl-mojolicious`, `sqitch-migrations`,
`frontend-svelte`, `r-analytics`) **não** se aplicam a este pacote.

## Personas de curadoria

O pacote é avaliado por três personas cujos perfis **e memória** ficam em
`docs/personas/` (neste repo; histórico trazido do repo EduMaps em
2026-09-28). Diferente das skills (instruções estáticas), usam um **modelo
com memória**: registram inputs e mantêm um loop de perguntas → respostas
→ follow-ups.

| Persona | Arquivo | Foco |
|---------|---------|------|
| Pesquisadora educacional | `pesquisadora-educacional.md` | ML p/ questões nacionais/regionais/municipais |
| Especialista em ML | `especialista-ml.md` | ML clássico + modelagem avançada |
| Gestora escolar | `gestora-escolar.md` | Acompanhamento da escola vs painel municipal/estadual |

### Protocolo do loop (curadoria)

1. **Ativar**: ler o perfil + memória da persona.
2. **Pendências**: as perguntas da rodada são as canônicas + follow-ups
   abertos.
3. **Responder**: executar o `eduBR` (via `Rscript`, `service = "edumaps"`)
   ou ler o código/README e registrar `Pergunta → Resposta`.
4. **Classificar**: `✓ atendido` / `lacuna` / `sugestão`.
5. **Follow-up**: gerar a próxima pergunta e registrá-la em "Pendências".
6. **Sugestões**: atualizar "Sugestões priorizadas"
   (`[alta]`/`[média]`/`[baixa]`).
7. **Veredito**: ao zerar pendências, registrar `aprova` / `aprova com
   ressalvas` / `reprova` com data.

Cada rodada acrescenta uma entrada datada (mais recente no topo) no arquivo
da persona.

O backlog consolidado dessas rodadas está na skill `r-edubr`
("Roadmap de melhorias").

## Workflow

```
plano → execução → aprovação
```

1. **Plano**: propor e alinhar decisões antes de tocar em código.
2. **Execução**: implementar e validar **localmente**
   (`devtools::test()` com `EDUBR_SMOKE=1`, `devtools::check()`); o
   container é opcional (compatibilidade com dbplyr 2.5).
   Commits em PT-BR seguindo `<type>(<scope>): <subject>`.
3. **Aprovação**: só pedir PR após o aceite explícito da implementação.
4. **PR + merge (via `gh`)**:

   ```bash
   git push -u origin <branch>
   gh pr create --base main --head <branch> \
     --title "<título em PT-BR>" --body "<entregas, testes, validação>"
   gh pr merge <n> --merge --delete-branch
   ```

   Depois: `git checkout main && git fetch origin && git merge --ff-only origin/main`.
5. **Deploy**: o `eduBR` é biblioteca; não há deploy nos containers. A
   instalação é local via `devtools::install()`.

## Lições (ver `memory.md`)

- **Compatibilidade com o container**: o dbplyr 2.5 do RStudio Server não
  traduz tudo o que o 2.6 local traduz (ex.: `n_distinct(x, na.rm =
  TRUE)`); `perfil_escola()` ficou quebrada no container sem ninguém ver.
  Testes locais são o padrão; ao usar tradução dbplyr nova, confirme
  também com `tools/test-container.sh --smoke`.
- **Strings R com acento → `\uXXXX`** (warning de não-ASCII no check). A
  ferramenta Write dos agentes converte `\uXXXX` em acentos: reescape
  depois de escrever e confira (deve sair vazio):
  `git diff origin/main -- R/ | grep '^+' | grep -v '^+\s*#' | grep -P '[^\x00-\x7F]'`.
  `.Rmd`/`.md` podem ter UTF-8.
- **PRs empilhados**: `gh pr merge --delete-branch` no PR base apaga a
  branch e **fecha** o PR filho (que apontava para ela). Faça o merge na
  ordem e mude a base do filho para `main` antes de apagar a branch.

## Code style

- Docs e comentários em **PT-BR**; identificadores em inglês.
- Encoding UTF-8.
- Sem comentários supérfluos; priorizar legibilidade.
