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

### 2026-10-09 — 11ª rodada (follow-up R19 pelo chat)

**R19 — "No Acre, escolas públicas: o IDEB do fundamental I se associa a
ter biblioteca e ao número de docentes, separando por rede? Informe o R²
e o n de cada rede."** (1 execução, 76 s)
- Resposta: o modelo **não** usou `regressao_escolas` (indicada no prompt)
  e foi pelo passo a passo: a 1ª `especificar_regressao` misturou
  `fonte` e `dados_id` (`parametro_invalido`), a 2ª acertou; depois
  `executar_regressao`, `coeficientes` e `metricas`. Números conferidos
  contra `regressao_escolas` direto: 1.484 escolas no recorte, 224 usadas;
  Estadual n 96, R² 0,0104; Municipal n 127, R² 0,0870; docentes na
  municipal +0,0504 (p 0,0017); biblioteca não significativa; Federal sem
  modelo (n 1) — **tudo igual**.
- Ressalva: a resposta foi **cortada** no meio de uma tabela (aviso do
  ellmer: limite de `max_tokens`), provavelmente porque o raciocínio
  ligado consumiu o orçamento de saída.
- Status: **✓ atendido** com ressalvas (resposta truncada; tool composta
  ignorada).

### 2026-10-09 — 10ª rodada (verificação de #81 e #82)

**R22 — regressão numa chamada (#81).**
- Resposta: `regressao_escolas` (AC, rede municipal,
  `ideb_fund_i ~ in_biblioteca + docentes` por `localizacao`) reproduz os
  números do aceite (urbana −0,599, p = 0,049; n 43/84; r² 0,022/0,073)
  em 2,5 s e ~690 tokens. No chat local (N = 2): **2/2** no critério
  estrito (antes 1/4 pela cadeia de 4 tools), mediana 47 s.
- Status: **✓ atendido** — baixa a pendência da regressão pelo chat.

**R23 — pergunta regional pelo chat (#82).**
- Pergunta (1 execução): "Qual o IDEB médio do fundamental I da rede
  municipal em cada região do Brasil em 2023?"
- Resposta: o modelo escolheu `ideb_agregado`; a 1ª chamada usou o
  argumento `level` (em inglês), recusada pelo ellmer e **registrada no
  ledger como `argumento_recusado`** (primeira evidência com LLM real do
  #75); a 2ª, com `nivel = "regiao"`, trouxe as 5 regiões. Números
  idênticos aos da tool (Sul 6,30; Sudeste 6,00; Centro-oeste 5,82;
  Nordeste 5,28; Norte 4,71; escolas com nota conferidas), 44,8 s.
  Ressalva: inventou uma "meta nacional de 5,8" (fora dos dados) e chamou
  o recorte de "Censo 2025" ao lado do IDEB 2023.
- Status: **✓ atendido**, com ressalva de redação (#83).

### 2026-10-09 — 9ª rodada (verificação de #71, #72, #75)

Tools no banco sem LLM + transcrições de hoje + **uma** execução nova do
chat (limite N ≤ 2).

**R20 — o limite de texto protege a janela do modelo (#71)?**
- Resposta: `redes_municipio(uf = "SP")` devolve 13 de 20 linhas (~3,4k
  tokens) com aviso "Resposta reduzida… filtre mais, peça menos linhas ou
  colunas"; `ideb(uf = "SP", ano = 2023, n = 500)` devolve 30 linhas
  (~3,5k) com `truncado`; prévia de `covariaveis_escola` com `n = 50` →
  `parametro_invalido` ("Use um inteiro entre 1 e 20"); o aviso aponta o
  próximo passo com `dados_id`.
- Status: **✓ atendido**. Efeito colateral: tabelas grandes não chegam
  mais ao modelo — perguntas regionais dependem de agregação (ver
  sugestão).

**R21 — a regressão pelo chat fecha (#72)?**
- Resposta: taxa de sucesso **1/4** no critério estrito; a cadeia
  `covariaveis_escola → especificar_regressao → executar_regressao →
  coeficientes` completou **4/4**, mas houve argumentos inventados
  (recusados pelo ellmer e agora visíveis no ledger, #75), chamada repetida
  com erro e coeficiente não citado. Na `pesq_r7` (raciocínio ligado) a
  cadeia completou e a **resposta final foi `HTTP 400 invalid message
  content type`**; numa execução nova com `raciocinio = "desligado"` a
  cadeia completou e o turno terminou com um plano ("Vou rodar a regressão
  sem cortes primeiro…"), sem conclusão.
- Status: **lacuna (modelo local)** — a camada responde certo a cada tool;
  o modelo de 9B não fecha a cadeia de 4 passos com resposta.

### 2026-10-09 — 8ª rodada (pergunta ao chat, camada `ellmer`)

Foco: regressão declarativa pedida em linguagem natural a um LLM
(`chat_edubr("ollama")`, `qwen3.5:9b`,
`ferramentas_edubr(con, persona = "pesquisadora-educacional")`).
Transcrições: `docs/aceite-ellmer/pesq_r1.md` … `pesq_r6.md`.

**R18 — "No Acre, rede municipal, o IDEB do fundamental I se associa a ter
biblioteca e ao número de docentes? Separe por localização urbana/rural."**
- Tentativas 1–5 (mesma pergunta; a 5ª reformulada pedindo prévia curta e
  resposta concisa): **não atendida**. O modelo abria a base com
  `covariaveis_escola`, via a prévia toda com IDEB nulo e ia buscar o IDEB
  em `ideb` (50–100 linhas), estourando a janela de 16k tokens do Ollama;
  em duas, o turno acabou só com raciocínio (resposta vazia), uma delas
  depois de encadear as quatro tools corretamente; sem raciocínio, o
  modelo descreveu a prévia com afirmações inventadas ("IDEB ainda sendo
  consolidado").
- Diagnóstico: **falha da camada** em parte — o aviso da prévia mandava
  usar o handle como `dados` em `executar_regressao` (argumento
  inexistente) e não explicava o IDEB nulo. Corrigido (aviso aponta
  `especificar_regressao(dados_id =)` e traz a contagem de escolas com
  IDEB na base) — e em parte **limite do modelo/runtime** (janela,
  raciocínio).
- Tentativa 6 (pergunta original, após as correções): `covariaveis_escola
  (uf = "AC", rede = "Municipal", ativas = true, n = 10)` →
  `especificar_regressao(outcome = "ideb_fund_i", predictors =
  ["in_biblioteca", "docentes"], cuts = ["localizacao"], dados_id =
  "dados_1")` → `executar_regressao(espec_1)` → `coeficientes`; 85 s.
  Conferido: 885 escolas no recorte, 127 usadas (84 urbanas, 43 rurais);
  biblioteca −0,541 (EP 0,582; p 0,358) rural e −0,599 (EP 0,300; p
  0,049) urbana; docentes +0,0008 (p 0,980) e +0,031 (p 0,086) — todos
  iguais ao retorno. Lê como associação, cita seleção e cobertura do IDEB.
- Ressalvas: não chamou `metricas` (sem R²/n por modelo além do de
  `executar_regressao`); atribuiu a `docentes` a nota de "vínculos" que é
  de `docentes_rede`; diferença de interceptos com sinal ambíguo.
- Status: **✓ atendido** (com ressalvas; 1 de 6 execuções, a única após
  as correções).

### 2026-10-08 — 7ª rodada (pendências externas)

**R17 — houve mudança na carga?**
- Resposta: `clean.escolas` continua sem coluna de código do município e
  `clean.inse` continua só com `nu_ano_saeb` 2023 (consultado no banco).
  Nenhuma entrega do pacote mudou isso; o contorno segue sendo
  `covariaveis_escola()`/`ideb()`/`docentes_rede()`/`gestores()`.
- Status: **bloqueado** (pipeline EduMaps).

### 2026-10-08 — 6ª rodada (verificação de #36 e #37)

**R15 — `as_sf()` com limite e sem aviso.**
- Resposta: `as_sf(municipios(con, uf = "SE"), n = 5)` → 5
  `MULTIPOLYGON` em 1,7 s; `as_sf(escolas(con, uf = "AC"))` → 539 pontos
  em 5,5 s; nenhum aviso de materialização.
- Status: **✓ atendido** (#36).

**R16 — base regional por escola, com chave de município.**
- Resposta: `covariaveis_escola(con, uf = "AC")` traz `co_municipio`
  (22 municípios), `rede`/`localizacao` rotuladas e só escolas ativas
  (1.524; com `ativas = FALSE`, 1.678). Na prática resolve o join
  escola→município por código para análise — mas `escolas()` continua sem
  a coluna.
- Status: **✓ parcial** (P1 contornado via `covariaveis_escola()`;
  `escolas()` segue bloqueada na carga).

### 2026-10-08 — 5ª rodada (verificação de #20, #21, #24)

**R11 (revisita) — `as_sf()` para mapas.**
- Resposta: `as_sf(escolas(con, uf = "AC"))` devolve `sf` (EPSG 4674),
  539 pontos, nenhum vazio, em 0,7 s; `as_sf(municipios(con, uf = "AC"))`
  devolve 22 `MULTIPOLYGON`. Na 1ª medição levou 113 s (rede instável); na
  2ª, 6,6 s — dos quais ~6 s são a conversão do hex em R, que o `sf` faz
  em 0,4 s com resultado idêntico. Ambos emitem o aviso "Materializando a
  consulta sem limite", embora a materialização seja o objetivo.
- Status: **✓ atendido** (#20) — com sugestões de desempenho/aviso.

**R12 (revisita) — tipos/ano das relações.**
- Resposta: `catalogo()` traz `granularidade`, `chave`, `tipo_chave`,
  `coluna_ano` e `anos` (ex.: `ideb` → `id_escola` bigint, `ano` 2005–2023;
  `inse` → `nu_ano_saeb` 2023; `censo_*` → 2025; `ibge`/`indicadores` vazias
  no dev).
- Status: **✓ atendido** (#24).

**R13 (revisita) — ano consistente nas comparações.**
- Resposta: `perfil_escola(..., ano_ideb = 2019)` compara escola,
  município e estado em 2019 ("IDEB fund. I (2019)"), com a edição no
  rótulo.
- Status: **✓ atendido** (#21).

**R14 (revisita) — join escola→município por código.**
- Resposta: `escolas()` segue só com `codigo_inep` (sem `co_municipio`).
- Status: **bloqueado** (carga de `clean.escolas` no EduMaps).

### 2026-10-07 — 4ª rodada (verificação de `as_sf()` e tipos/ano)

Foco: revisitar P1/P2/P4 após as entregas #7 e #13.

**R8 — `as_sf()` para mapas (P4).**
- Resposta: `as_sf(escolas(con, uf = "AC"))` e `as_sf(municipios(con))`
  falham com "método não aplicável para 'as_sf'": o NAMESPACE não registra
  `S3method(as_sf, eduBR)` (o `@export` está no lugar errado em `geo.R`).
  Os testes passam porque rodam dentro do namespace.
- Status: **lacuna (bug)** — **#20**.

**R9 — tipos/ano das relações (P2).**
- Resposta: `catalogo()` continua com só `dominio/schema/tabela`; a #13
  entregou `rotular()` (rotula `rede`/`categoria_privada`/`localizacao`),
  mas não o tipo/ano. Além disso, `perfil_escola()` compara IDEB de
  edições diferentes (#21) — exatamente o risco de ano inconsistente.
- Status: **lacuna** — **#24** (e #21).

**R10 — join escola→município por código (P1).**
- Resposta: `escolas()` segue sem `co_municipio` (só `municipio` texto);
  `ideb()`, `docentes_rede()` e `gestores()` expõem o código.
- Status: **bloqueado** (carga de `clean.escolas` no EduMaps).

### 2026-09-29 — 3ª rodada (verificação: rótulo `rede`, dicionário, EDA)

Foco: verificar as correções da rodada anterior (`rede` normalizada,
`dicionario()`, cobertura do IDEB e apêndice na EDA).

**R5 — `rede` normalizada e join da EDA.**
- Resposta: `rede_municipio()` devolve `Estadual|Federal|Municipal|Privada`
  (derivado de `codigo_rede` no SQL) e o `left_join` com `docentes_rede()`
  casa nas **4 redes, 0 NA** (Federal 584 mun./40.052 doc. … Municipal
  5.569 mun./1.495.329 doc.).
- Status: **✓ atendido** — baixa a pendência de normalização.

**R6 — `dicionario()`.**
- Resposta: `dicionario()` devolve 10 linhas (`tp_dependencia`,
  `tp_categoria_escola_privada`, `tp_localizacao` → rótulos PT-BR),
  consistentes com as colunas derivadas no SQL. Cobre **rótulos**, não
  tipos/ano das relações.
- Status: **✓ parcial** (pendência de dicionário vira "tipos/ano").

**R7 — EDA com cobertura e apêndice.**
- Resposta: `analysis/rede_professor.Rmd` renderiza de ponta a ponta com a
  subseção de cobertura do IDEB por rede e o apêndice do dicionário.
- Status: **✓ atendido**.

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
- [x] Normalizar o rótulo `rede` (derivado de `codigo_rede` no SQL).
- [x] Cobertura/NA do IDEB por município × rede (subseção na EDA).
- [x] `as_sf()` utilizável fora do namespace (#20).
- [x] Tipo/ano de referência no `catalogo()` (#24).
- [x] Mesma edição do IDEB nas comparações (#21).
- [x] `as_sf()` com `n` e sem aviso (#36).
- [x] Prévias enxutas / limite de texto por resposta (#71).
- [x] Taxa de sucesso medida (#72): 1/4 estrito, cadeia completa 4/4.
- [x] Regressão pelo chat com resposta final (tool composta #81: 2/2).
- [x] Perguntas regionais agregadas (#82: `ideb_agregado`).
- [x] Follow-up R19 pelo chat: R² e `n` por rede (números corretos;
  resposta truncada).
- [ ] Join escola→município **por código** em `escolas()` (bloqueado:
  `clean.escolas` não tem a coluna; contornado por `covariaveis_escola()`,
  `ideb()`, `docentes_rede()` e `gestores()`, que trazem `co_municipio`).

## Sugestões priorizadas

- **[média]** `chat_edubr()`: `max_tokens` configurável (com padrão maior
  no Ollama) — a resposta do R19 foi cortada no meio pelo limite de
  saída, com o raciocínio ligado (#89).
- **[baixa]** Chat: o modelo local acrescenta contexto inventado (ex.:
  "meta nacional de 5,8") às respostas agregadas — tratar junto da #83,
  depois da comparação com Anthropic (#73).
- **[média]** `co_municipio` em `clean.escolas` (pedido ao pipeline EduMaps).
- **[baixa]** Alinhar `ranking_escola` (dados vazios em dev).

## Veredito

- **Aprova com ressalvas** (2026-10-09, 11ª rodada): R² e `n` por rede
  corretos pelo chat; ressalvas: resposta truncada pelo limite de saída,
  tool composta ignorada nessa pergunta, `co_municipio` (externa).
- **Aprova com ressalvas** (2026-10-09, 10ª rodada): regressão e
  perguntas regionais agora fecham pelo chat local com números corretos;
  ressalvas: contexto inventado ocasional (#83) e `co_municipio` em
  `escolas()` (externa, EduMaps).
- **Aprova com ressalvas** (2026-10-09, 9ª rodada): tools e limites
  corretos e protegendo a janela do modelo; a regressão pelo chat com o
  modelo local de 9B não fecha com resposta confiável (1/4 estrito) — falta
  validar com Anthropic (#73) ou simplificar o fluxo (tool composta).
- **Aprova com ressalvas** (2026-10-09, 8ª rodada, chat com
  `qwen3.5:9b`): a regressão declarativa sai de uma pergunta em linguagem
  natural, com handles, recortes e leitura não causal, e os coeficientes
  conferem com as ferramentas. Ressalvas: o modelo local só completou o
  fluxo depois de duas correções da camada e falhou em 5 de 6 execuções
  (janela de contexto/raciocínio); não informou R². Anthropic não testada.
  Segue a ressalva externa (`co_municipio` em `clean.escolas`).

- **Aprova com ressalvas** (2026-10-08, 7ª rodada): sem mudança — a única
  ressalva segue externa ao pacote (`co_municipio` em `clean.escolas`).
- **Aprova com ressalvas** (2026-10-08, 6ª rodada): mapas rápidos e sem
  ruído, base escola × covariáveis com código do município. Única ressalva
  é externa: `escolas()` sem `co_municipio` até a carga do EduMaps mudar.
- **Aprova com ressalvas** (2026-10-08, 5ª rodada): mapas, catálogo com
  chave/tipo/ano e comparações na mesma edição verificados contra o banco.
  Ressalvas: `escolas()` sem código do município (bloqueado na carga) e
  desempenho/aviso do `as_sf()` em polígonos grandes.
- **Aprova com ressalvas** (2026-10-07, 4ª rodada): bases por rede/docente
  seguem sólidas, mas o suporte a mapas está quebrado para o usuário (#20)
  e o ano de referência das relações ainda não é explícito (#24, #21).
- **Aprova com ressalvas** (2026-09-29): redes, perfil docente, projeção,
  rótulo `rede`, cobertura do IDEB e dicionário de rótulos verificados
  contra o banco. Ressalvas restantes: `as_sf()` e dicionário de tipos/ano;
  `co_municipio` em `escolas()` é inviável na carga atual (documentado).
