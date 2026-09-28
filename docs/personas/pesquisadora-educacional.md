# Persona: Pesquisadora em Política Educacional

> Curadoria do pacote `eduBR` (este repo).
> Este arquivo é **perfil + memória**: a cada rodada, acrescente entradas em
> "Entradas" (mais recente no topo), atualize "Pendências" e "Sugestões".
> Histórico trazido de `~/Projects/leaflet/docs/personas/` em 2026-09-28;
> a curadoria passa a viver aqui (lá nada foi apagado — decisão do dev de lá).

## Perfil

- **Papel**: economista da educação, doutora em políticas públicas; usa
  microdados do Censo Escolar, IDEB e IBGE para estudar desigualdades
  regionais e avaliar efeitos de infraestrutura/rede sobre o desempenho.
- **Objetivo com o `eduBR`**: montar bases de análise por
  escola/município/região — já tipadas e prontas para `tidymodels` — sem
  decorar `schema.tabela` nem escrever SQL.
- **Perguntas de pesquisa típicas**: "municípios de porte/região semelhantes
  têm oferta parecida?", "quanto da variação do IDEB se associa à
  infraestrutura, controlando por rede?", "como o perfil docente muda entre
  regiões?".
- **Funções que mais usa**: `conecta()`, `escolas()`, `municipios()`,
  `redes()`, `rede_municipio()`, `docentes_rede()`, `indicadores()`,
  `scores()`, `ideb()`, `censo_escolar()`, `clusters()`,
  `municipios_similares()`, `catalogo()`.
- **Critérios de avaliação**: (1) as chaves de join entre entidades são
  explícitas e confiáveis (código, não nome); (2) os tipos/ano são
  consistentes; (3) um recorte (UF/município) vira uma tabela pronta para
  modelagem; (4) a geometria permite análise/mapa regional.

## Perguntas canônicas

1. Consigo juntar `escola → município → IBGE/população` **por código**,
   sem adivinhar nomes de chave?
2. As variáveis vêm no tipo certo (numérico vs texto) e com o **ano**
   consistente entre censo, IDEB e indicadores?
3. Um recorte de UF/município vira uma tabela pronta para `tidymodels`?
4. A geometria dos municípios permite gerar um mapa para análise regional?

## Entradas

### 2026-09-28 — 2ª rodada (redes × perfil docente)

Foco: avaliar `rede_municipio()` / `docentes_rede()` e o report
`analysis/rede_professor.Rmd` (pedido da rodada: redes de cada município
cruzadas com o perfil docente por rede, em todas as dimensões do Censo).

**R1 — redes de cada município com filtros.**
- Resposta: `rede_municipio(con, uf = "SP", rede = "Municipal")` devolve
  645 linhas × 36 colunas em **~0,3 s**, com filtros `uf`/`regiao`/`rede`
  empurrados para o SQL (`WHERE sg_uf IN ('SP')` + `codigo_rede IN (3)`,
  confirmado no `sql_render`). Agregações posteriores (p. ex. `group_by(rede)`
  → cobertura nacional) também rodam no banco.
- Status: **✓ atendido**.
- Ressalva: a coluna `rede` da MV vem em **minúscula** (`municipal`), fora
  do padrão capitalizado do pacote (`Municipal`, cf. `eduBR_rotulos()` e a
  saída de `docentes_rede()`/`gestores()`). Quem juntar as duas fontes por
  `rede` precisa normalizar a caixa.
- Follow-up: normalizar o rótulo `rede` em `rede_municipio()` para o padrão
  do pacote (ou documentar a diferença)?

**R2 — perfil docente cruzado por rede.**
- Resposta: `docentes_rede(con, nivel = "brasil", colunas = <formação>)`
  devolve 8 linhas (4 redes × urbana/rural) em **~2,5 s**. % docentes com
  superior: Federal 98,8% > Estadual 95,7% > Municipal 88,6% > Privada
  82,0% — a pergunta "como o perfil docente muda entre redes?" é
  respondível direto, incluindo vínculo, especialização, disciplina e
  demografia (todas as dimensões `qt_doc_bas_*` do Censo).
- Status: **✓ atendido**.

**R3 — join por código (revisita de P1).**
- Resposta: o join `censo_docentes ⋈ censo_escolas` é por
  **código** (`nu_ano_censo`, `co_entidade`) e a saída de `docentes_rede()`
  expõe `co_municipio` (integer) ao lado de `no_municipio` — o caminho
  docente→município agora flui por código, sem adivinhar nomes. Porém
  `escolas()` segue **sem** `co_municipio` (só nome + UF).
- Status: **✓ parcial** (resolve para docentes/gestores; lacuna persiste
  em `escolas()`).
- Follow-up: expor `co_municipio` em `escolas()` fecha o P1 de vez?

**R4 — projeção de colunas (revisita do follow-up de P3).**
- Resposta: o parâmetro `colunas=` projeta antes do `collect` — o SELECT
  cai de **303** refs `qt_doc_*` (sem projeção) para **15** (só formação).
  Combinado ao `coletar(n=)` já existente, o controle de materialização
  está adequado ao fluxo de pesquisa.
- Status: **✓ atendido** — baixa a pendência de projeção.

**P2/P4 — dicionário e geometria.**
- Sem mudança nesta rodada: sem `dicionario()` de tipos/ano e sem `as_sf()`.
- Status: **abertos** (sugestão e lacuna, respectivamente).

**Observações extras da rodada.**
- `ideb_fund_ii` tem NA em municípios sem avaliação (ex.: Adamantina-SP na
  rede municipal) — esperado, mas o report/consulta deveria documentar a
  cobertura (como já faz o report de tendência).
- `qt_doc_bas` chega como `integer64` (ex.: 1.495.329 docentes municipais);
  imprime corretamente com `bit64` carregado, mas herda a ressalva M8 da
  curadoria do ML.

### 2026-09-15 — 1ª rodada (perguntas canônicas)

**P1 — join escola → município por código.**
- Resposta: `clean.escolas` (⇒ `escolas()`) só possui `municipio` (nome) e
  `uf`; **não há código IBGE** na tabela. O código (`co_municipio`) existe
  apenas em `clean.school_indicators` (⇒ `escola`/`indicadores`). Logo, o
  join escola→município é por **nome** hoje — frágil (homônimos/acentos).
- Status: **lacuna**.
- Follow-up: como fazer um join escola→município **por código** de forma
  direta com o `eduBR`? (expor `co_municipio` junto de `escolas()`, ou um
  `escola_municipio()`/`juncao`.)

**P2 — tipos e ano.**
- Resposta: chaves com tipos mistos — `clean.escolas.codigo_inep` é
  `bigint`, `clean.municipios_sp.codigo_ibge` é `varchar`,
  `school_indicators.co_entidade` é `bigint`, `nu_ano_censo` é `integer`.
  Não há dicionário de tipos/anos no pacote.
- Status: **sugestão**.
- Follow-up: o pacote deveria expor/validar os tipos das chaves (e o ano
  de referência de cada relação)?

**P3 — recorte UF → tabela pronta.**
- Resposta: `escolas(con, uf = "SP") |> as_tibble()` devolve 28.710 linhas
  × 20 colunas em **~40 s** (coleta total). Funciona, mas é lento e traz a
  tabela inteira sem projeção de colunas.
- Status: **✓ com ressalva** (performance).
- Follow-up: há uma forma de projetar colunas / amostrar antes de coletar?

**P4 — geometria para mapa.**
- Resposta: a coluna `geometry` é devolvida como `pq_geometry` (WKB cru,
  ex. `0106000020421200...`), não como `sf`. Sem `sf`, não gera mapa direto.
- Status: **lacuna** (GIS adiado por decisão de escopo).
- Follow-up: o `as_sf()`/integração PostGIS está previsto e para quando?

**Observações extras da rodada.**
- `municipios()` cobre 5.573 municípios em 27 UFs (não é só SP, apesar do
  nome físico) — bom para perguntas nacionais.
- `indicadores()` lê `analytics.ranking_escola`, que está **vazia** no dev
  (0 linhas) → perguntas de ranking não são respondíveis hoje (lacuna de
  dados, não do pacote).

## Pendências

- [x] Projeção de colunas antes do `collect` (`colunas=` em `docentes_rede()`).
- [ ] Join escola→município **por código** em `escolas()` (parcial: já flui
  por código via `docentes_rede()`/`gestores()`, que expõem `co_municipio`).
- [ ] `as_sf()` / suporte PostGIS para mapas regionais.
- [ ] Dicionário de tipos/ano das relações.
- [ ] Normalizar o rótulo `rede` de `rede_municipio()` (MV traz minúscula).

## Sugestões priorizadas

- **[alta]** Expor `co_municipio` em `escolas()` para fechar o join por código.
- **[alta]** Suporte `sf`/PostGIS (`as_sf()`) para a geometria.
- **[média]** Documentar tipo e ano de referência das chaves/relações
  (`dicionario()`).
- **[média]** Normalizar `rede` em `rede_municipio()` para o padrão
  capitalizado do pacote.
- **[média]** Documentar cobertura/NA do IDEB por município × rede (a MV
  traz NA onde não houve avaliação).
- **[baixa]** Alinhar `ranking_escola` (dados vazios em dev).

## Veredito

- **Aprova com ressalvas** (2026-09-28): redes por município e perfil
  docente por rede funcionam por código, com projeção de colunas e
  agregação no banco — o fluxo de pesquisa regional/nacional está
  desbloqueado. Ressalvas: `escolas()` segue sem `co_municipio`, e faltam
  `as_sf()`, dicionário de tipos/ano e a normalização do rótulo `rede`.
