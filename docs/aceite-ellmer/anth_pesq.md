# Aceite pesquisadora-educacional (anthropic claude-sonnet-5, thinking=FALSE) 2026-10-09 14:44 -03

## Pergunta 1 (19.7 s)

> No Acre, rede municipal, o IDEB do fundamental I se associa a ter biblioteca e ao número de docentes? Separe por localização urbana/rural.

- CALL `regressao_escolas`({"outcome":"ideb_fund_i","predictors":["in_biblioteca","docentes"],"uf":"AC","rede":"Municipal","cuts":["localizacao"]})
  - RESULT `regressao_escolas`: {"dados":[{"localizacao":"Rural","termo":"(Intercept)","estimativa":4.57928907454762,"erro_padrao":0.352317133118706,"estatistica":12.997633790931,"p_valor":6.06394824826967e-16},{"localizacao":"Rural","termo":"in_biblioteca","estimativa":-0.541035351070682,"erro_padrao":0.582319556969924,"estatistica":-0.929103865042653,"p_valor":0.358408481482662},{"localizacao":"Rural","termo":"docentes","estimativa":0.000810088036073301,"erro_padrao":0.0314188508155124,"estatistica":0.0257835030577674,"p_valor":0.979558224888359},{"localizacao":"Urbana","termo":"(Intercept)","estimativa":5.11036737972871,"erro_padrao":0.280774058377566,"estatistica":18.2009955237981,"p_valor":2.35018883922997e-30},{"localizacao":"Urbana","termo":"in_biblioteca","estimativa":-0.599372110900232,"erro_padrao":0.300329667939393,"estatistica":-1.99571395997143,"p_valor":0.0493261471231232},{"localizacao":"Urbana","termo":"docentes","estimativa":0.0311309775164018,"erro_padrao":0.0179269741684981,"estatistica":1.73654389323024,"p_valor":0.0862695356746402}],"metadados":{"grao":"corte × termo do modelo","filtros":{"outcome":"ideb_fund_i","predictors":["in_biblioteca","docentes"],"cuts":"localizacao","uf":"AC","rede":"Municipal","ano":null,"ano_ideb":null,"modelo":"linear"},"n":6,"n_total":6,"truncado":false,"aviso":"758 de 885 linhas do recorte foram descartadas por `null` no desfecho ou nos preditores (ex.: escolas sem IDEB na etapa).","handle":"regressao_1","colunas_omitidas":[],"contexto":{"formula":"ideb_fun [...]

### Resposta

## IDEB Fundamental I × biblioteca e docentes — rede Municipal, Acre

**Recorte**: escolas municipais do Acre, Censo Escolar 2025, IDEB edição 2023, etapa fundamental I. Do total de 885 escolas municipais no recorte, **758 foram descartadas** por não terem nota de IDEB nessa etapa (ou valor faltante nos preditores) — sobraram **127 escolas com modelo** (43 rurais, 84 urbanas). Essa perda grande de observações é um limite importante de cobertura a ter em mente.

### Rural (n=43)
| Termo | Estimativa | Erro-padrão | p-valor |
|---|---|---|---|
| Intercepto | 4,58 | 0,35 | <0,001 |
| in_biblioteca | −0,54 | 0,58 | 0,358 |
| docentes | 0,0008 | 0,031 | 0,980 |

- R² = 0,022 (praticamente nulo); o modelo como um todo não é significativo (p=0,642).
- **Nenhum dos dois preditores tem associação estatisticamente significativa** com o IDEB fundamental I nas escolas rurais.

### Urbana (n=84)
| Termo | Estimativa | Erro-padrão | p-valor |
|---|---|---|---|
| Intercepto | 5,11 | 0,28 | <0,001 |
| in_biblioteca | −0,60 | 0,30 | **0,049** |
| docentes | 0,031 | 0,018 | 0,086 |

- R² = 0,073 (baixo, mas o modelo conjunto é significativo: p=0,046).
- `in_biblioteca` tem coeficiente **negativo e significativo a 5%** (−0,60 pontos de IDEB para escolas com biblioteca, mantendo docentes fixo).
- `docentes` tem associação positiva, mas só marginal (p=0,086, no limiar de 10%).

### Leitura e ressalvas
- **Isto é associação, não causalidade.** O sinal negativo de "ter biblioteca" é contraintuitivo e provavelmente reflete confusão com outros fatores não controlados (ex.: escolas maiores/mais complexas tendem a ter biblioteca e podem ter outras características associadas a IDEB mais baixo; seleção de quais escolas têm nota calculada).
- O R² é muito baixo em ambos os cortes — biblioteca e número de docentes explicam pouquíssimo da variação do IDEB nessas amostras.
- **n pequeno** (43 e 84 escolas) torna as estimativas instáveis; o corte rural não tem nenhum coeficiente significativo.
- A perda de 758 de 885 linhas por falta de nota de IDEB é um viés de cobertura relevante — as 127 escolas com nota podem não representar bem o conjunto de escolas municipais do Acre.

Fonte: `regressao_escolas` (handle `regressao_1`), Censo Escolar 2025 + IDEB 2023, UF=AC, rede=Municipal, corte por `localizacao`.

## Ledger

            timestamp              tool
1 2026-10-09 14:44:29 regressao_escolas
                                                                                                                   args
1 {"outcome":"ideb_fund_i","predictors":["in_biblioteca","docentes"],"cuts":"localizacao","uf":"AC","rede":"Municipal"}
  n_linhas duracao_ms erro
1        6       2456 <NA>

## Checks

List of 4
 $ n_resultados   : int 1
 $ nomes_fisicos  : int 0
 $ denormais_int64: int 0
 $ max_n_ledger   : num 6
