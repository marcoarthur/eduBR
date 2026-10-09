# Aceite especialista-ml (anthropic claude-sonnet-5, thinking=FALSE) 2026-10-09 14:45 -03

## Pergunta 1 (34.7 s)

> Treine uma floresta aleatória para classificar o desempenho (terços da nota) das escolas públicas do fundamental II, com amostra reprodutível, e avalie contra o baseline.

- CALL `features_escola`({"etapa":["fundamental_ii"],"publica":true,"semente":2023})
  - RESULT `features_escola`: {"dados":[{"etapa":"fundamental_ii","n_amostra":3000,"n_populacao":31078,"n_com_nota":3000}],"metadados":{"grao":"etapa (resumo da amostra escola × etapa)","filtros":{"etapa":["fundamental_ii"],"publica":true,"n_por_etapa":3000,"semente":2023},"n":1,"n_total":1,"truncado":false,"aviso":"Amostra guardada em dados_1 (3000 linhas escola × etapa, 80 colunas); a mesma semente devolve as mesmas escolas. Próximo passo: `classificar_desempenho(dados_id = \"dados_1\")`.","handle":"dados_1","colunas_omitidas":[],"contexto":{"handle":"dados_1","semente":2023,"n_linhas":3000,"n_colunas":80,"colunas_desempenho":["nota_media"],"colunas":["co_entidade","tp_localizacao","tp_dependencia","in_agua_potavel","in_energia_rede_publica","in_esgoto_rede_publica","in_cozinha","in_banheiro","in_banheiro_pne","in_refeitorio","in_biblioteca","in_laboratorio_ciencias","in_laboratorio_informatica","in_quadra_esportes","in_patio_coberto","in_parque_infantil","in_computador","in_internet","in_banda_larga","in_equip_multimidia","in_equip_lousa_digital","in_desktop_aluno","in_tablet_aluno","in_acessibilidade_rampas","in_acessibilidade_corrimao","in_acessibilidade_elevador","in_acessibilidade_pisos_tateis","in_acessibilidade_sinal_sonoro","qt_salas_utilizadas","qt_prof_administrativos","qt_prof_servicos_gerais","qt_prof_seguranca","qt_desktop_aluno","qt_comp_portatil_aluno","qt_tablet_aluno","qt_mat_bas","qt_mat_inf","qt_mat_fund","qt_mat_med","qt_mat_bas_int","qt_doc_bas","qt_doc_bas_fem","qt_doc_bas_esco_sup [...]
- CALL `classificar_desempenho`({"dados_id":"dados_1"})
  - RESULT `classificar_desempenho`: {"dados":[{"etapa":"fundamental_ii","nivel":"baixo","n":993},{"etapa":"fundamental_ii","nivel":"medio","n":1005},{"etapa":"fundamental_ii","nivel":"alto","n":1002}],"metadados":{"grao":"etapa × nivel","filtros":{"dados_id":"dados_1","nota":"nota_media","grupo":"etapa"},"n":3,"n_total":3,"truncado":false,"aviso":"Base classificada em dados_2 (coluna `nivel`: baixo < corte_baixo_medio <= medio < corte_medio_alto <= alto, terços dentro de `etapa`). Próximo passo: `dividir_dados(dados_id = \"dados_2\")`.","handle":"dados_2","colunas_omitidas":[],"contexto":{"handle":"dados_2","nota":"nota_media","grupo":"etapa","n_classificadas":3000,"n_sem_nota":0,"limites":[{"grupo":"fundamental_ii","corte_baixo_medio":4.73,"corte_medio_alto":5.35}]}},"erro":null}
- CALL `dividir_dados`({"dados_id":"dados_2","semente":2023})
  - RESULT `dividir_dados`: {"dados":[{"parte":"treino","nivel":"baixo","n":795,"prop":0.331112036651395},{"parte":"treino","nivel":"medio","n":804,"prop":0.334860474802166},{"parte":"treino","nivel":"alto","n":802,"prop":0.334027488546439},{"parte":"teste","nivel":"baixo","n":198,"prop":0.330550918196995},{"parte":"teste","nivel":"medio","n":201,"prop":0.335559265442404},{"parte":"teste","nivel":"alto","n":200,"prop":0.333889816360601}],"metadados":{"grao":"parte × nivel","filtros":{"dados_id":"dados_2","prop":0.8,"semente":2023},"n":6,"n_total":6,"truncado":false,"aviso":"Treino em treino_1, teste em teste_1 (estratificado por `nivel`). Treine com `treinar_floresta(treino_id = \"treino_1\")` e avalie SÓ no teste com `metricas_floresta(teste_id = \"teste_1\")`.","handle":"treino_1","colunas_omitidas":[],"contexto":{"treino_id":"treino_1","teste_id":"teste_1","n_treino":2401,"n_teste":599,"prop":0.8,"semente":2023}},"erro":null}
- CALL `treinar_floresta`({"treino_id":"treino_1"})
  - RESULT `treinar_floresta`: {"dados":[{"n_arvores":250,"n_features":77,"n_treino":2401,"min_node_size":5,"erro_oob_brier":0.337597225170272,"tempo_s":3.32}],"metadados":{"grao":"modelo","filtros":{"treino_id":"treino_1","trees":250,"semente":2023},"n":1,"n_total":1,"truncado":false,"aviso":"Floresta guardada em floresta_1. Fora dos preditores por vazamento (definem ou medem o desempenho): nota_media. Avalie com `metricas_floresta(floresta_id = \"floresta_1\", teste_id = \"teste_1\")`.","handle":"floresta_1","colunas_omitidas":[],"contexto":{"handle":"floresta_1","features":["tp_localizacao","tp_dependencia","in_agua_potavel","in_energia_rede_publica","in_esgoto_rede_publica","in_cozinha","in_banheiro","in_banheiro_pne","in_refeitorio","in_biblioteca","in_laboratorio_ciencias","in_laboratorio_informatica","in_quadra_esportes","in_patio_coberto","in_parque_infantil","in_computador","in_internet","in_banda_larga","in_equip_multimidia","in_equip_lousa_digital","in_desktop_aluno","in_tablet_aluno","in_acessibilidade_rampas","in_acessibilidade_corrimao","in_acessibilidade_elevador","in_acessibilidade_pisos_tateis","in_acessibilidade_sinal_sonoro","qt_salas_utilizadas","qt_prof_administrativos","qt_prof_servicos_gerais","qt_prof_seguranca","qt_desktop_aluno","qt_comp_portatil_aluno","qt_tablet_aluno","qt_mat_bas","qt_mat_inf","qt_mat_fund","qt_mat_med","qt_mat_bas_int","qt_doc_bas","qt_doc_bas_fem","qt_doc_bas_esco_sup_grad","qt_doc_bas_esco_sup_pos_espec","qt_doc_bas_vinculo_concur","qt_gest_bas_esco_sup_grad [...]
- CALL `metricas_floresta`({"floresta_id":"floresta_1","teste_id":"teste_1"})
  - RESULT `metricas_floresta`: {"dados":[{"acuracia":0.607679465776294,"baseline_acerto":0.335559265442404,"ganho_sobre_baseline":0.27212020033389,"f1_macro":0.602464719889803,"auc_macro":0.778329572247358,"n_teste":599}],"metadados":{"grao":"modelo avaliado no teste","filtros":{"floresta_id":"floresta_1","teste_id":"teste_1"},"n":1,"n_total":1,"truncado":false,"aviso":null,"handle":null,"colunas_omitidas":[],"contexto":{"floresta_id":"floresta_1","teste_id":"teste_1","confusao":[{"real":"baixo","predito":"baixo","n":151},{"real":"medio","predito":"baixo","n":57},{"real":"alto","predito":"baixo","n":36},{"real":"baixo","predito":"medio","n":39},{"real":"medio","predito":"medio","n":90},{"real":"alto","predito":"medio","n":41},{"real":"baixo","predito":"alto","n":8},{"real":"medio","predito":"alto","n":54},{"real":"alto","predito":"alto","n":123}],"totais_classe":[{"classe":"baixo","n_real":198,"n_predito":244,"acertos":151},{"classe":"medio","n_real":201,"n_predito":170,"acertos":90},{"classe":"alto","n_real":200,"n_predito":185,"acertos":123}],"f1_classe":{"baixo":0.683257918552036,"medio":0.485175202156334,"alto":0.638961038961039},"auc_classe":{"baixo":0.840147106980025,"medio":0.687573439335983,"alto":0.807268170426065}}},"erro":null}

### Resposta

## Resumo — Random Forest para desempenho (terços) no fundamental II

**Recorte e reprodutibilidade**
- Amostra: `features_escola` — fundamental II, só escolas públicas, Censo/SAEB mais recentes agregados, `semente=2023`, `n_por_etapa=3000` (população total: 31.078 escolas; amostra com nota: 3.000/3.000 → handle `dados_1`).
- Alvo: `classificar_desempenho` sobre `nota_media`, terços dentro de `fundamental_ii` → cortes em **4,73** e **5,35**; classes balanceadas (993 baixo / 1005 médio / 1002 alto) → `dados_2`.
- Holdout: `dividir_dados`, `prop=0.8`, `semente=2023`, estratificado → treino 2.401 / teste 599 (`treino_1`/`teste_1`), proporções de classe preservadas (~33% cada).

**Treino**
- `treinar_floresta`: 250 árvores, `min_node_size=5`, `semente=2023`, 77 features (infraestrutura, matrículas, docentes, INSE, razões derivadas etc.).
- `nota_media` foi corretamente excluída por vazamento (é a variável que define a classe).
- Erro OOB (Brier): 0,338 → `floresta_1`.

**Avaliação no teste (`teste_1`, nunca usado no treino)**
- Acurácia: **0,608**
- Baseline (sempre a classe dominante): **0,336**
- Ganho sobre o baseline: **+0,272** (27,2 pontos percentuais)
- F1 macro: 0,602 | AUC macro (one-vs-rest): 0,778

**Por classe**
| Classe | n_real | acertos | F1 | AUC |
|---|---|---|---|---|
| baixo | 198 | 151 | 0,683 | 0,840 |
| médio | 201 | 90 | 0,485 | 0,688 |
| alto | 200 | 123 | 0,639 | 0,807 |

**Leitura**
- O modelo aprendeu algo real: acurácia quase o dobro do baseline (~33%→61%) e AUC macro bem acima de 0,5.
- Classes extremas (baixo/alto) são bem separadas (F1 e AUC altos); a classe **médio** é a mais confundida (F1 = 0,485), como esperado — fronteiras de terços adjacentes são as mais difíceis.
- Erros graves (baixo↔alto) são raros: só 36 "alto" previstos como "baixo" e 8 "baixo" previstos como "alto", de 599 — a maior parte da confusão é entre classes vizinhas (médio com baixo/alto).
- Isto é **associação preditiva** (infraestrutura, docentes, INSE etc. associados à nota), não relação causal; e vale só para este corte (públicas, fundamental II, amostra de 3.000 escolas, semente 2023).

Posso complementar com `importancia_floresta` para ver quais variáveis mais pesam (ex.: INSE costuma dominar), e testar se reduzir dimensão mantém a performance.

## Ledger

            timestamp                   tool
1 2026-10-09 14:45:16        features_escola
2 2026-10-09 14:45:20 classificar_desempenho
3 2026-10-09 14:45:23          dividir_dados
4 2026-10-09 14:45:30       treinar_floresta
5 2026-10-09 14:45:33      metricas_floresta
                                                      args n_linhas duracao_ms
1 {"etapa":"fundamental_ii","publica":true,"semente":2023}        1        770
2                                   {"dados_id":"dados_1"}        3        148
3                    {"dados_id":"dados_2","semente":2023}        6         20
4                                 {"treino_id":"treino_1"}        1       4151
5        {"floresta_id":"floresta_1","teste_id":"teste_1"}        1        116
  erro
1 <NA>
2 <NA>
3 <NA>
4 <NA>
5 <NA>

## Checks

List of 4
 $ n_resultados   : int 5
 $ nomes_fisicos  : int 0
 $ denormais_int64: int 0
 $ max_n_ledger   : num 6
