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
  regiao.R        helpers de macrorregião (UF -> região)
  espec.R         especificar_regressao(), ler_espec() (camada declarativa)
  regressao.R     executar_regressao() (motor por cortes)
  saida.R         coeficientes(), metricas()
man/              Rd gerados por roxygen2 (não editar à mão)
tests/testthat/   testes unitários + smoke opcional
analysis/         reports R Markdown (fora do build; HTML gitignored)
tools/sync-rstudio.sh  rsync do repo p/ o RStudio Server (rstudio.dev)
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

```r
# de dentro do repo, no R
devtools::test()                                 # unitários (sem banco)
EDUBR_SMOKE=1 Rscript -e 'devtools::test()'      # + smoke contra o [edumaps]
devtools::document()                             # regenera NAMESPACE/man
devtools::check()                                # antes de PR
```

O smoke (`tests/testthat/test-smoke.R`) é pulado sem `EDUBR_SMOKE=1`.
Testes unitários **não** tocam o banco.

## Sincronização com o RStudio Server (rstudio.dev)

O RStudio Server roda no container `rstudio.dev` (`ubatexu.lan:2024`, SSH
como `root`), acessível na web em `ubatexu.lan:8787`. O pareamento é um
`rsync` do working tree para `/home/rsuser/projetos/eduBR`.

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
`~/Projects/leaflet/docs/personas/` (repo EduMaps). Diferente das skills
(instruções estáticas), usam um **modelo com memória**: registram inputs e
mantêm um loop de perguntas → respostas → follow-ups.

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
2. **Execução**: implementar e validar (`devtools::test()` / `check()`).
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

## Code style

- Docs e comentários em **PT-BR**; identificadores em inglês.
- Encoding UTF-8.
- Sem comentários supérfluos; priorizar legibilidade.
