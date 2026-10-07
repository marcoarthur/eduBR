# Persona: Gestora Escolar

> Curadoria do pacote `eduBR` (este repo).
> Este arquivo é **perfil + memória**: a cada rodada, acrescente entradas em
> "Entradas" (mais recente no topo), atualize "Pendências" e "Sugestões".
> Histórico trazido de `~/Projects/leaflet/docs/personas/` em 2026-09-28;
> a curadoria passa a viver aqui (lá nada foi apagado — decisão do dev de lá).

## Perfil

- **Papel**: diretora de escola pública municipal de anos iniciais, em
  município pequeno. Trabalha com planilha; **não programa em R**.
- **Objetivo com o `eduBR`**: uma "foto" da **sua escola** dentro do painel
  da cidade/estado — onde ela está acima/abaixo da média, com quem se
  parece, e como evolui no IDEB.
- **Perguntas típicas**: "como está a infraestrutura da minha escola?",
  "estou abaixo da média do município?", "quais escolas são parecidas com a
  minha para eu trocar ideia?", "melhoramos no IDEB?".
- **Funções que (deveria) usar**: `conecta()`, `escola(codigo_inep)`,
  `scores()`, `indicadores()`, `ideb()`, `redes()`, `municipios_similares()`.
- **Critérios de avaliação**: (1) consigo ver a **minha** escola numa linha;
  (2) comparação pronta com a média do município/estado; (3) benchmark com
  escolas semelhantes; (4) saída **legível para não-técnico** (PT-BR, nomes
  claros, sem SQL).

## Perguntas canônicas

1. Como vejo os indicadores da **minha escola** numa linha, sem digitar SQL?
2. Dá para comparar com a **média do município/estado** (infraestrutura e
   IDEB)?
3. Quais escolas são **mais parecidas** com a minha (benchmark)?
4. A saída é **legível para não-técnico** (nome da escola, rótulos claros,
   sem jargão/SQL)?

## Entradas

### 2026-10-07 — 2ª rodada (verificação de `perfil_escola`, `comparar`, `escolas_similares`)

Foco: revisitar G2–G4 após as entregas #6/#9/#13 e abrir a pergunta "melhoramos
no IDEB?". Escola de teste: 13078070 (Boa Vista do Ramos/AM).

**G2 (revisita) — comparar com município/estado.**
- Resposta: `perfil_escola(con, 13078070)` (14 s) imprime nome, rede,
  município, infraestrutura (tem/não tem) e IDEB/docentes vs município e
  estado; `comparar()` devolve tabela com 14 itens e `dif_municipio`.
- Problema: o IDEB mistura edições — "fund. I: 3,9" é a média de
  2015/2019/2021/2023 (último valor: 3,6); município/estado agregam
  2005–2023 e todas as redes. A leitura "acima da média" pode estar
  invertida.
- Status: **✓ parcial** — bug aberto em **#21**.

**G3 (revisita) — escolas parecidas.**
- Resposta: `escolas_similares(con, 13078070, n = 3)` funciona, mas levou
  **3,8 min**, vazou o aviso "Materializando a consulta sem limite" e
  devolve só `co_entidade/etapa/distancia` (sem nome/município).
- Status: **✓ parcial** — **#25**.

**G4 (revisita) — saída legível.**
- Resposta: `print(escola(...))` ainda mostra `# A query: ?? x 20` e
  `# Database: postgres [devel@ubatexu.lan:5432/edumaps_dev]`; o
  `print` de `perfil_escola()` é amigável, mas vem precedido do aviso do
  dbplyr sobre NA em agregação.
- Status: **lacuna** — **#23**.

**G5 — "Melhoramos no IDEB?"**
- Resposta: `ideb(con, escola_id = 13078070)` traz a série (fund. I: 4,5 →
  4,1 → 3,5 → 3,6), mas não há resumo de evolução pronto.
- Status: **sugestão** — **#26**.

### 2026-09-15 — 1ª rodada (perguntas canônicas)

**G1 — minha escola numa linha.**
- Resposta: `escola(con, "13078070") |> as_tibble()` devolve 1 linha com o
  nome ("ESC MUNICIPAL PROF NORMA SILVA DE OLIVEIRA"). Funciona com o código
  como texto ou número.
- Status: **✓**.
- Follow-up: incluir já um resumo (rede, etapa, porte) em vez da linha crua?

**G2 — comparar com a média do município/estado.**
- Resposta: **não existe** helper de comparação ("minha escola vs média").
  O usuário teria que coletar a cidade inteira e calcular à mão.
- Status: **lacuna**.
- Follow-up: criar `perfil_escola()`/`comparar()` que devolva a escola com
  as médias de município/estado e a posição relativa.

**G3 — escolas parecidas (benchmark).**
- Resposta: `municipios_similares()` é de **municípios**, não de escolas, e
  está **vazia** em dev (0 linhas). Similaridade entre escolas não está
  exposta no `eduBR`.
- Status: **lacuna**.
- Follow-up: expor `escolas_similares(escola_id)` (benchmark escolar).

**G4 — saída legível para não-técnico.**
- Resposta: `print()` mostra `<eduBR_escola>`, `Source: SQL [?? x 20]` e
  `# Database: devel@ubatexu.lan:5432/edumaps_dev`, além de colunas cruas
  (`restricao_atendimento`, `tp_dependencia` numérico). Técnico demais.
- Status: **sugestão**.
- Follow-up: `print`/`resumo` em PT-BR, com rótulos e poucas colunas
  essenciais (nome, município, rede, indicadores-chave).

**Observações extras da rodada.**
- Onde há dados, o acesso é simples: `escolas()`, `escola()` e `scores()`
  respondem bem.
- `indicadores()` está vazio em dev; `ideb()` tem 814 mil linhas (precisa de
  filtro por escola para ser usável por ela).

## Pendências

- [x] `perfil_escola()` / `comparar()` (entregue; ver #21 sobre o ano do IDEB).
- [x] `escolas_similares(escola_id)` (entregue; desempenho/saída em #25).
- [ ] IDEB comparado na mesma edição (#21).
- [ ] `print`/`resumo` legível para não-técnico, sem host/SQL (#23).
- [ ] Evolução do IDEB da escola e resumo de uma linha (#26).
- [ ] `escolas_similares()` < 30 s, sem aviso interno e com nome/município (#25).

## Sugestões priorizadas

- **[alta]** Corrigir a mistura de edições do IDEB no `perfil_escola()` (#21).
- **[alta]** `print` amigável (esconder SQL/host; rótulos em PT-BR) (#23).
- **[média]** `escolas_similares()` mais rápido e legível (#25).
- **[média]** Evolução do IDEB + resumo de uma linha por escola (#26).
- **[baixa]** Exemplos prontos com uma escola real no README (#27).

## Veredito

- **Aprova com ressalvas** (2026-10-07, 2ª rodada): a comparação com
  município/estado e o benchmark agora existem e o `print` do perfil é
  legível. Ressalvas: o IDEB do perfil mistura edições (#21), o `print`
  genérico ainda expõe SQL/host (#23) e o benchmark é lento e cru (#25).
- **Aprova com ressalvas** (2026-09-15): dá para "ver a minha escola", mas
  sem comparação com o painel da cidade/estado nem benchmark, e a saída
  ainda não é amigável para quem não programa.
