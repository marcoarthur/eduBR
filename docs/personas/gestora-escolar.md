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

### 2026-10-08 — 3ª rodada (verificação de #21, #23, #25, #26, #27)

Foco: conferir as entregas contra o `edumaps_dev` com a escola 13078070 e
uma segunda escola (EMEF Eurico Leite de Morais, Adamantina/SP).

**G4 (revisita) — saída legível.**
- Resposta: `print(escola(con, "13078070"))` mostra
  `<eduBR_escola> Escola INEP 13078070`, "20 colunas", prévia de 1 linha e a
  dica de `coletar()`; **sem SQL, usuário ou host**. Ainda aparecem tipos
  técnicos na prévia (`<chr>`, `<int64>`, `geometry <pq_gmtry>`).
- Status: **✓ atendido** (#23).

**G2 (revisita) — comparação na mesma edição.**
- Resposta: "IDEB fund. I (2023): 3,6 (município 4,1, estado 5,0)" — mesma
  edição e mesma rede; a escola agora aparece **abaixo** do município (antes
  o 3,9 misturado sugeria o contrário). Perfil em 10 s.
- Status: **✓ atendido** (#21).

**G5 (revisita) — "melhoramos no IDEB?" e resumo de uma linha.**
- Resposta: o `print` traz "em 2021: 3,5 (+0,1)" e a linha
  "Fund. I, Fund. II, EJA · 962 matrículas · Urbana"; `resumo_escola(p)`
  devolve uma linha com rede, etapas, matrículas, docentes e
  `ideb_*`/`ano_*`/`var_*`. Na escola de Adamantina: 6,6 em 2023,
  "em 2021: 5,8 (+0,8)".
- Status: **✓ atendido** (#26).

**G3 (revisita) — benchmark.**
- Resposta: `escolas_similares(con, "13078070", n = 5)` em **11 s** (antes
  3,8 min), sem aviso, com nome, município, UF e rede das vizinhas.
- Status: **✓ atendido** (#25).

**G7 — dá para seguir o README sozinha?**
- Resposta: a seção "Minha escola (passo a passo)" tem as mesmas chamadas
  usadas nesta rodada, com a saída esperada e a dica de exportar para
  planilha (`write.csv`).
- Status: **✓ atendido** (#27).

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

- [x] `perfil_escola()` / `comparar()` na mesma edição e rede (#21).
- [x] `escolas_similares()` rápido e identificado (#25).
- [x] `print` legível, sem host/SQL (#23).
- [x] Evolução do IDEB e resumo de uma linha (#26).
- [x] Exemplo com escola real no README (#27).

## Sugestões priorizadas

- **[baixa]** Na prévia do `print`, esconder tipos técnicos (`<int64>`,
  `<pq_gmtry>`) e a coluna `geometry`.
- **[baixa]** Exportação pronta para planilha (ex.: `exportar(p, "x.csv")`)
  em vez de `write.csv()`.

## Veredito

- **Aprova** (2026-10-08, 3ª rodada): vê a escola numa linha, compara com
  município/estado na mesma edição, acompanha a evolução do IDEB, encontra
  escolas parecidas em segundos e segue o README sem programar. Restam só
  ajustes cosméticos ([baixa]).
- **Aprova com ressalvas** (2026-10-07, 2ª rodada): a comparação com
  município/estado e o benchmark agora existem e o `print` do perfil é
  legível. Ressalvas: o IDEB do perfil mistura edições (#21), o `print`
  genérico ainda expõe SQL/host (#23) e o benchmark é lento e cru (#25).
- **Aprova com ressalvas** (2026-09-15): dá para "ver a minha escola", mas
  sem comparação com o painel da cidade/estado nem benchmark, e a saída
  ainda não é amigável para quem não programa.
