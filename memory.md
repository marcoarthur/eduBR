# memory.md — decisões do pacote `eduBR`

Registro curto de decisões que valem entre sessões. Detalhes de
implementação ficam no código; memória de curadoria fica em
`docs/personas/`.

## 2026-09-28 — personas de curadoria moram neste repo

- **Decisão**: perfis + memória das 3 personas (`pesquisadora-educacional`,
  `especialista-ml`, `gestora-escolar`) vivem em `docs/personas/` **aqui**.
- **Histórico**: trazido de `~/Projects/leaflet/docs/personas/` em
  2026-09-28, integral (todas as rodadas). Lá **nada foi apagado** —
  remoção eventual é decisão do dev do repo EduMaps.
- **Exceção**: `tech-lead.md` é curadoria do acervo EduMaps, não do `eduBR`;
  fica só no leaflet.
- **Consequências**: `AGENTS.md` e a skill `r-edubr` apontam para o caminho
  local; `docs/` está no `.Rbuildignore` (fora do build, como `analysis/`).

## 2026-09-28 — redes × perfil docente

- Novo: `rede_municipio()` (filtros UF/região/rede sobre
  `analytics.mv_rede_escolas`) e `docentes_rede()` (join
  `censo_docentes ⋈ censo_escolas` por código, agregação no banco,
  projeção via `colunas=`); EDA em `analysis/rede_professor.Rmd`.
- Reuso obrigatório dos helpers de `gestor.R`/`regiao.R`
  (`eduBR_codigos_rede`, `eduBR_case_when_lookup`, `eduBR_mutate_regiao`):
  nada de duplicar lookup de rede/localização.
- Lição: `names()` em `tbl_sql` devolve slots internos — derivar colunas de
  variáveis determinísticas, nunca inspecionar a tabela lazy.

## 2026-09-29 — 3ª rodada pesquisadora + 5ª ML

- `rede` normalizada via `codigo_rede` (a MV traz minúscula; o join da EDA
  não casava — verificado 4/4, 0 NA); `integer64` documentado no Rd em vez
  de conversão silenciosa.
- `coletar(n=)` + aviso já existiam (memória da 4ª rodada do ML estava
  desatualizada); `dicionario()` cobre rótulos (tipos/ano seguem abertos).
- `co_municipio` em `escolas()` é inviável (`clean.escolas` não tem a
  coluna) — documentado, não reabrir sem mudança de carga.
- Restam (roadmap na skill): `as_sf()`, `perfil_escola()`/`comparar()`,
  `escolas_similares()`, origem dos `scores()`, logístico (AUC/McFadden),
  `ler_especs()`, INSE histórico, avisos `ideb_inse()`.

## 2026-09-29 — fila de issues #6–#16

- Entregues: #7 `as_sf()`, #8 `escolas_similares()` (fase 1), #9 origem dos
  `scores()` (docs), #12 `rotular()`, #13 `registrar_relacao()`,
  #14 parcial (anos em `ideb_inse()`, dados bloqueados), #15 avisos.
  Já existiam: #10 (AUC/McFadden), #11 (`ler_especs()`).
- **Decisão #16 (`integer64`)**: manter o tipo do banco + documentar no Rd
  (feito em `docentes_rede()`/`rede_municipio()`/`redes()`); sem coerção
  silenciosa para `numeric` — esconderia a precisão real e quebraria a
  simetria com o Postgres.

## 2026-10-07/08 — rodadas de curadoria #20–#58 (resumo)

- Comparações do perfil usam **mesma edição e mesma rede** do IDEB (#21);
  município/estado contam só escolas **em atividade**
  (`tp_situacao_funcionamento == 1`) em `perfil_escola()` e
  `covariaveis_escola()`.
- PCA: códigos `tp_*` fora, sinal fixo, componentes de variância nula
  descartados; os `*_score` são soma exata dos `in_*` (report usa
  `redundantes = "remover"`).
- `integer64` vira número **só** onde o cálculo exige (k-NN, PCA); a saída
  das funções de acesso mantém o tipo do banco (#16 segue valendo).
- **Testes rodam só no container `rstudio.dev` como `rsuser`** (regra do
  README); o `AGENTS.md` ainda diz o contrário e será corrigido.

## 2026-10-08 — camada `ellmer` (plano em `plans/ellmer-tools.md`)

- **Runtime**: `chat_anthropic()` no container; a chave
  (`ANTHROPIC_API_KEY`) é configurada pelo dono do repo no ambiente do
  `rsuser`, nunca no código. `ellmer` 0.5.0 existe só no container.
- **Handles na sessão** para encadear objetos R (dados, espec, regressão,
  floresta): o LLM recebe ids, não objetos; somem ao fim da sessão.
- **Ledger** persistido (quando pedido) em
  `tools::R_user_dir("eduBR", "data")`, não em `inst/`.
- **PII**: gestor/docentes são só contagens (sem nome/CPF); endereço,
  telefone, CEP e CNPJ de `censo_escolas`/`escolas` ficam **ocultos** nas
  tools por padrão.
- Tools devolvem `integer64` como **string** (fronteira JSON), sem mudar o
  tipo nas funções do pacote; `etapa` usa os valores do pacote
  (`ensino_medio`, não `medio`).

## 2026-10-08 — versões divergentes entre máquina local e container

- O container `rstudio.dev` tem **dbplyr 2.5.0**; a máquina local, 2.6.0.
  `n_distinct(x, na.rm = TRUE)` traduz no 2.6 e **quebra** no 2.5
  (`unused argument`): `perfil_escola()` ficou quebrada no container de
  #30 até o chunk 2 da camada ellmer, sem ninguém ver, porque a validação
  era local.
- **Lição**: validar sempre no container (`tools/test-container.sh`, com
  `--smoke` quando a mudança toca SQL); não confiar em execução local.
