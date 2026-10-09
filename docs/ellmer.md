# Camada `ellmer`: matriz pergunta × tool

Rastreio de **quais perguntas das personas** de curadoria
(`docs/personas/`) cada ferramenta de `ferramentas_edubr()` responde, e do
que **não** é coberto (com o motivo). Os prompts de sistema que levam essa
matriz ao modelo estão em `inst/prompts/<persona>.md`
(`prompt_persona()`); o registro das tools e o prompt são anexados ao chat
por `registrar_tools()` ou `chat_edubr(persona = ...)`.

Plano e decisões: `plans/ellmer-tools.md` (D15, D17, chunk 6).

Legenda do status: **coberto** (a tool responde), **parcial** (responde
com ressalva), **não coberto** (fora das tools; motivo ao lado), **n/a**
(pergunta sobre o pacote em R que não se aplica ao chat).

## Tools por persona

Gerado a partir de `eduBR_tools_registro()` (conferido em
`tests/testthat/test-ellmer-personas.R`; atualize os dois juntos).

<!-- tools-por-persona:inicio -->
- **gestora-escolar** (6): `catalogo`, `perfil_escola`, `resumo_escola`, `serie_ideb_escola`, `escolas_similares`, `scores_escola`
- **pesquisadora-educacional** (16): `catalogo`, `perfil_escola`, `municipios`, `redes_municipio`, `docentes_rede`, `ideb`, `tendencia_ideb_regiao`, `covariaveis_escola`, `perfil_gestor`, `especificar_regressao`, `executar_regressao`, `coeficientes`, `metricas`, `ideb_agregado`, `regressao_escolas`, `listar_handles`
- **especialista-ml** (19): `catalogo`, `scores_escola`, `indicadores_escola`, `ideb`, `tendencia_ideb_regiao`, `covariaveis_escola`, `especificar_regressao`, `executar_regressao`, `coeficientes`, `metricas`, `regressao_escolas`, `listar_handles`, `features_escola`, `classificar_desempenho`, `dividir_dados`, `treinar_floresta`, `importancia_floresta`, `metricas_floresta`, `pca_perfil`
<!-- tools-por-persona:fim -->

## Gestora escolar

Fonte: [`personas/gestora-escolar.md`](personas/gestora-escolar.md)
([perguntas canônicas](personas/gestora-escolar.md#perguntas-canônicas),
[entradas](personas/gestora-escolar.md#entradas)).

### Perguntas canônicas

| ID | Pergunta | Tool(s) | Status |
|---|---|---|---|
| G1 | Como vejo os indicadores da **minha escola** numa linha, sem digitar SQL? | `resumo_escola` | coberto |
| G2 | Dá para comparar com a **média do município/estado** (infraestrutura e IDEB)? | `perfil_escola` | coberto (mesma edição e rede do IDEB) |
| G3 | Quais escolas são **mais parecidas** com a minha (benchmark)? | `escolas_similares` | coberto |
| G4 | A saída é **legível para não-técnico** (nome da escola, rótulos claros, sem jargão/SQL)? | todas (envelope sem SQL/`schema.tabela`) + prompt da gestora (linguagem simples) | coberto |

### Rodadas e follow-ups

| Origem | Pergunta | Tool(s) | Status |
|---|---|---|---|
| 1ª rodada, G1 follow-up | Resumo (rede, etapa, porte) em vez da linha crua? | `resumo_escola` | coberto |
| 2ª rodada, G5 | Melhoramos no IDEB? | `resumo_escola` (`var_*`) → `serie_ideb_escola` | coberto |
| 3ª rodada, G7 | Dá para seguir o README sozinha? | — | n/a (o chat substitui o passo a passo em R) |
| 4ª rodada, G8 | Prévia sem jargão técnico? | todas (rótulos, `integer64` como texto) | coberto |
| 4ª rodada, G9 | O município conta as escolas certas (só em atividade)? | `perfil_escola` | coberto |
| 4ª rodada, G10 / 5ª, G15 | Levar o perfil para a planilha (CSV/XLSX)? | — | não coberto: tools são só leitura e não gravam arquivos; usar `exportar()` em R (o modelo pode montar uma tabela curta na resposta) |
| 5ª rodada, G11/G12 | Minha escola estadual com ensino médio e comparação | `perfil_escola`, `resumo_escola` | coberto (`ofertada`/`oferta_*` sinalizam etapa não ofertada, #53) |
| 5ª rodada, G14 | Escolas parecidas para escola só de ensino médio | `escolas_similares` | coberto (padrão nas etapas da própria escola; `etapa = "ensino_medio"` explícito, #52) |
| Perfil | "Em que a escola é mais forte ou mais frágil?" (`scores()`) | `scores_escola` | coberto |
| Perfil | Posição da escola em ranking (`indicadores()`) | — | não coberto: a base de ranking está vazia no dev; a tool `indicadores_escola` fica só com a especialista-ml |
| Perfil | `redes()` / `municipios_similares()` | — | não coberto para a gestora: fora do foco "minha escola"; similaridade de municípios vazia no dev |

## Pesquisadora educacional

Fonte: [`personas/pesquisadora-educacional.md`](personas/pesquisadora-educacional.md)
([perguntas canônicas](personas/pesquisadora-educacional.md#perguntas-canônicas),
[entradas](personas/pesquisadora-educacional.md#entradas)).

### Perguntas canônicas

| ID | Pergunta | Tool(s) | Status |
|---|---|---|---|
| P1 | Consigo juntar `escola → município → IBGE/população` **por código**, sem adivinhar nomes de chave? | `covariaveis_escola` (`co_municipio`) + `municipios` (`codigo_ibge`); `redes_municipio`, `ideb`, `docentes_rede` também trazem o código | parcial: `co_municipio` em `escolas()` bloqueado na carga; população/IBGE sem tool (domínio `ibge` vazio no dev) |
| P2 | As variáveis vêm no tipo certo (numérico vs texto) e com o **ano** consistente entre censo, IDEB e indicadores? | `catalogo` (chave, tipo, coluna de ano, anos) | coberto (`integer64` vira texto na fronteira JSON; prompt orienta converter) |
| P3 | Um recorte de UF/município vira uma tabela pronta para `tidymodels`? | `covariaveis_escola` (handle `dados_<k>`) → `especificar_regressao` → `executar_regressao` | coberto (a base fica na sessão; o modelo recebe só prévia/handle, teto de 1000 linhas por resposta) |
| P4 | A geometria dos municípios permite gerar um mapa para análise regional? | — | não coberto: as tools removem a geometria (D3); mapas via `as_sf()` em R |

### Rodadas e follow-ups

| Origem | Pergunta | Tool(s) | Status |
|---|---|---|---|
| Perfil | Municípios de porte/região semelhantes têm oferta parecida? | `municipios` + `redes_municipio` | parcial: comparação descritiva por UF/região; `similaridade` de municípios vazia no dev |
| Perfil | Quanto da variação do IDEB se associa à infraestrutura, controlando por rede? | `covariaveis_escola` → `especificar_regressao` → `executar_regressao` → `coeficientes` / `metricas` | coberto (associação, não causa) |
| Perfil / 2ª rodada, R2 | Como o perfil docente muda entre regiões/redes? | `docentes_rede` | coberto |
| 2ª rodada, R1 | Redes de cada município com filtros (UF/região/rede) | `redes_municipio` | coberto |
| 2ª rodada, R3 | Join docente → município por código | `docentes_rede` (`nivel = "municipio"`) | coberto |
| 2ª rodada, R4 | Projeção de colunas antes de coletar | `docentes_rede` (`colunas`) | coberto |
| 3ª rodada, R5 | Rótulo `rede` normalizado entre fontes | `redes_municipio`, `docentes_rede` | coberto |
| 3ª rodada, R6 | Dicionário de rótulos | — | coberto indiretamente: as tools já devolvem `rede`/`localizacao` rotuladas; não há tool de dicionário |
| 3ª rodada, R7 | EDA renderiza com cobertura do IDEB | — | n/a (report em R) |
| 4ª/5ª/6ª rodadas, R8/R11/R15 | `as_sf()` para mapas | — | não coberto: sem geometria nas tools |
| 4ª/5ª rodadas, R9/R12 | Tipo/ano de referência das relações | `catalogo` | coberto |
| 5ª rodada, R13 | Ano consistente nas comparações | `perfil_escola` (`ano_ideb`), `ideb` (`ano`) | coberto |
| R10/R14/R16/R17 | Join escola → município por código | `covariaveis_escola` | parcial: `co_municipio` em `escolas()` segue bloqueado na carga |
| Funções que usa | Perfil dos gestores por rede/região | `perfil_gestor` | coberto |
| Funções que usa | Tendência do IDEB por região | `tendencia_ideb_regiao` | coberto |
| Funções que usa | Retomar bases/modelos já criados | `listar_handles` | coberto (só na sessão) |
| 1ª rodada, extra | Perguntas de ranking (`indicadores()`) | — | não coberto: ranking vazio no dev |
| Funções que usa | `clusters()` | — | não coberto: sem tool (fora do inventário do plano) |

## Especialista em ML

Fonte: [`personas/especialista-ml.md`](personas/especialista-ml.md)
([perguntas canônicas](personas/especialista-ml.md#perguntas-canônicas),
[entradas](personas/especialista-ml.md#entradas)).

### Perguntas canônicas

| ID | Pergunta | Tool(s) | Status |
|---|---|---|---|
| M1 | O acesso preguiçoso (`consulta()`) deixa eu **compor features sem baixar tudo**? Onde está a fronteira lazy → `collect`? | `features_escola` (amostra no banco), `covariaveis_escola` (consulta preguiçosa no handle), `executar_regressao` (conta antes de coletar) | coberto (fronteira nas tools; o modelo nunca recebe a base inteira) |
| M2 | Como trato NA e variáveis categóricas de **alta cardinalidade** (`tp_dependencia`, `tp_localizacao`)? Há dicionário de rótulos? | `covariaveis_escola` (rótulos), `classificar_desempenho` (remove sem nota), `treinar_floresta`, `pca_perfil` (sem `tp_*`) | parcial: sem tool de dicionário |
| M3 | Os `scores()` compostos já vêm prontos? Posso **recalcular/reproduzir**? | `scores_escola` | parcial: prontos e documentados; recálculo fora do pacote (decisão) |
| M4 | Consigo **estender** o pacote (novas relações/pipelines) sem reescrever `conecta()`/catálogo? | `catalogo` (lista o que existe) | não coberto: `registrar_relacao()` não é exposta ao modelo (só leitura; sem SQL cru) |

### Rodadas e follow-ups

| Origem | Pergunta | Tool(s) | Status |
|---|---|---|---|
| Aceite ML | Classificação de desempenho sem vazamento | `features_escola` → `classificar_desempenho` → `dividir_dados` → `treinar_floresta` → `importancia_floresta` / `metricas_floresta` | coberto (nota da classe recusada como preditor; teste com escolas do treino recusado) |
| 2ª rodada, M5 | Tendência reproduzível | `tendencia_ideb_regiao` | coberto |
| 2ª rodada, M6 | Compor features sem baixar tudo | `features_escola` | coberto |
| 2ª rodada, M7 | Categóricas do IDEB | `ideb` | coberto |
| M8/M20/M25 | `integer64` | todas (texto na fronteira JSON) | coberto (prompt orienta converter) |
| 3ª rodada, M9 | Cobertura do INSE | `catalogo`; `features_escola` (`media_inse`) | parcial: INSE histórico não existe (dados) |
| 3ª rodada, M10 | Regressão IDEB × INSE reproduzível | `especificar_regressao` → `executar_regressao` | parcial: `regressao_inse()` não é tool; a regressão declarativa cobre o caso |
| 3ª rodada, M11 | Vazamento/contemporaneidade INSE × IDEB | prompt (INSE é contexto, não alvo) | não coberto: INSE histórico (`inse_{t-1}`) bloqueado no pipeline |
| 3ª rodada, M12 | Cardinalidade 1:n por etapa | `features_escola` (escola × etapa) | coberto (prompt alerta) |
| 4ª rodada, M13 | Reproduzível e em escala (cortes) | `especificar_regressao` (`cuts`) → `executar_regressao` | coberto |
| 4ª rodada, M14 | Pushdown de colunas / limite | `executar_regressao` | coberto (conta no banco e recusa acima de `max_amostra`) |
| 4ª rodada, M15 | Fonte agnóstica | `especificar_regressao` (`fonte` ou `dados_id`) | coberto |
| M16/M21 | Logística com AUC/McFadden (e NA) | `metricas` | coberto |
| 5ª rodada, M17–M19 | `docentes_rede`, `coletar(n=)`, `dicionario()` | — | não coberto para a persona (`docentes_rede` é da pesquisadora); `coletar(n=)` é o teto de linhas das tools |
| 6ª rodada, M22 | `ler_especs()` (YAML com várias análises) | `especificar_regressao` (uma por chamada) | não coberto: YAML não é exposto; o modelo declara as specs uma a uma |
| 6ª rodada, M23 | Extensão do catálogo | — | não coberto (ver M4) |
| 6ª rodada, M24 | Origem dos `scores()` | `scores_escola` | coberto (descrição da tool) |
| 7ª rodada, M26 | k-NN no banco | — | não coberto para a persona (`escolas_similares` é da gestora) |
| 7ª rodada, M27 | Reports em PDF | — | n/a (reports em R) |
| 8ª rodada, M28 | Covariáveis para modelo multivariado | `covariaveis_escola` → `especificar_regressao` → `executar_regressao` → `coeficientes` / `metricas` | coberto |
| 8ª/9ª rodadas, M29–M31 | PCA sem `tp_*`, sinal estável, sem componentes nulos/redundantes | `pca_perfil` | coberto |
| 1ª rodada, M3 extra | Ranking de indicadores | `indicadores_escola` | não coberto: ranking vazio no dev (a tool responde `sem_dados`) |
| Sessão | Retomar objetos | `listar_handles` | coberto (só na sessão) |
| Funções que usa | IDEB por recorte | `ideb` | coberto |

## Aceite com chat real (2026-10-09)

Perguntas feitas a um LLM (`chat_edubr("ollama")`, `qwen3.5:9b`, banco de
desenvolvimento), com a transcrição em `aceite-ellmer/` e a curadoria nas
entradas de 2026-10-09 de cada persona. "Tools chamadas" são as escolhidas
pelo modelo, na ordem.

| Persona | Pergunta | Tools chamadas | Resultado |
|---|---|---|---|
| Gestora (G16) | Infraestrutura da 13078070 × município | `perfil_escola` | coberto; números conferem |
| Gestora (G17) | Escolas parecidas com a 13078070 | `escolas_similares` | coberto; lista confere, conselhos do modelo errados |
| Pesquisadora (R18) | IDEB fund. I × biblioteca e docentes, AC municipal, por localização | `covariaveis_escola` → `especificar_regressao` → `executar_regressao` → `coeficientes` | coberto após 2 correções da camada (1 de 6 execuções); sem `metricas` |
| ML (M32) | Floresta para terços da nota, fund. II público, contra o baseline | `features_escola` → `classificar_desempenho` → `dividir_dados` → `treinar_floresta` → `metricas_floresta` | coberto com raciocínio desligado; sem `importancia_floresta`; contas da prosa erradas |

O que o aceite mudou nesta matriz:

- `covariaveis_escola` passou a informar quantas escolas da base têm IDEB
  por etapa (a prévia costuma vir toda nula) e qual tool usa o handle
  (`especificar_regressao(dados_id =)`).
- `features_escola` aceita `etapa` vinda do chat (array de enum, que o
  ellmer converte em fator).
- Perguntas que pedem números derivados (porcentagens, totais por classe,
  ganhos relativos) continuam **parciais** com modelos pequenos: as tools
  devolvem os valores certos, mas o modelo erra ao recalcular. Conferir
  sempre contra o ledger/retorno.
- Anthropic: não testado (conta sem créditos).

## Taxa de sucesso

Ver [`docs/aceite-ellmer/taxa-sucesso.md`](aceite-ellmer/taxa-sucesso.md) (Ollama `qwen3.5:9b`, 2026-10-09: gestora 6/6, pesquisadora 1/4 no critério estrito com cadeia completa 4/4, ML 1/1). Script: `tools/taxa-sucesso-ellmer.R` (máximo N = 2).
