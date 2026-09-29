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
