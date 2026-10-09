# Aceite especialista-ml (ollama qwen3.5:9b, thinking=FALSE) 2026-10-09 11:11 -03

## Pergunta 1 (57.3 s)

> Treine uma floresta aleatória para classificar o desempenho (terços da nota) das escolas públicas do fundamental II, com amostra reprodutível, e avalie contra o baseline.

- CALL `features_escola`({"etapa":["fundamental_ii"],"publica":true,"semente":2023,"n_por_etapa":3000})
  - RESULT `features_escola`: {"dados":[{"etapa":"fundamental_ii","n_amostra":3000,"n_populacao":31078,"n_com_nota":3000}],"metadados":{"grao":"etapa (resumo da amostra escola × etapa)","filtros":{"etapa":["fundamental_ii"],"publica":true,"n_por_etapa":3000,"semente":2023},"n":1,"n_total":1,"truncado":false,"aviso":"Amostra guardada em dados_1 (3000 linhas escola × etapa, 80 colunas); a mesma semente devolve as mesmas escolas. Próximo passo: `classificar_desempenho(dados_id = \"dados_1\")`.","handle":"dados_1","colunas_omitidas":[],"contexto":{"handle":"dados_1","semente":2023,"n_linhas":3000,"n_colunas":80,"colunas_desempenho":["nota_media"],"colunas":["co_entidade","tp_localizacao","tp_dependencia","in_agua_potavel","in_energia_rede_publica","in_esgoto_rede_publica","in_cozinha","in_banheiro","in_banheiro_pne","in_refeitorio","in_biblioteca","in_laboratorio_ciencias","in_laboratorio_informatica","in_quadra_esportes","in_patio_coberto","in_parque_infantil","in_computador","in_internet","in_banda_larga","in_equip_multimidia","in_equip_lousa_digital","in_desktop_aluno","in_tablet_aluno","in_acessibilidade_rampas","in_acessibilidade_corrimao","in_acessibilidade_elevador","in_acessibilidade_pisos_tateis","in_acessibilidade_sinal_sonoro","qt_salas_utilizadas","qt_prof_administrativos","qt_prof_servicos_gerais","qt_prof_seguranca","qt_desktop_aluno","qt_comp_portatil_aluno","qt_tablet_aluno","qt_mat_bas","qt_mat_inf","qt_mat_fund","qt_mat_med","qt_mat_bas_int","qt_doc_bas","qt_doc_bas_fem","qt_doc_bas_esco_sup [...]
- CALL `classificar_desempenho`({"dados_id":"dados_1","nota":"nota_media","grupo":"etapa"})
  - RESULT `classificar_desempenho`: {"dados":[{"etapa":"fundamental_ii","nivel":"baixo","n":993},{"etapa":"fundamental_ii","nivel":"medio","n":1005},{"etapa":"fundamental_ii","nivel":"alto","n":1002}],"metadados":{"grao":"etapa × nivel","filtros":{"dados_id":"dados_1","nota":"nota_media","grupo":"etapa"},"n":3,"n_total":3,"truncado":false,"aviso":"Base classificada em dados_2 (coluna `nivel`: baixo < corte_baixo_medio <= medio < corte_medio_alto <= alto, terços dentro de `etapa`). Próximo passo: `dividir_dados(dados_id = \"dados_2\")`.","handle":"dados_2","colunas_omitidas":[],"contexto":{"handle":"dados_2","nota":"nota_media","grupo":"etapa","n_classificadas":3000,"n_sem_nota":0,"limites":[{"grupo":"fundamental_ii","corte_baixo_medio":4.73,"corte_medio_alto":5.35}]}},"erro":null}
- CALL `dividir_dados`({"dados_id":"dados_2","prop":0.8,"semente":2023})
  - RESULT `dividir_dados`: {"dados":[{"parte":"treino","nivel":"baixo","n":795,"prop":0.331112036651395},{"parte":"treino","nivel":"medio","n":804,"prop":0.334860474802166},{"parte":"treino","nivel":"alto","n":802,"prop":0.334027488546439},{"parte":"teste","nivel":"baixo","n":198,"prop":0.330550918196995},{"parte":"teste","nivel":"medio","n":201,"prop":0.335559265442404},{"parte":"teste","nivel":"alto","n":200,"prop":0.333889816360601}],"metadados":{"grao":"parte × nivel","filtros":{"dados_id":"dados_2","prop":0.8,"semente":2023},"n":6,"n_total":6,"truncado":false,"aviso":"Treino em treino_1, teste em teste_1 (estratificado por `nivel`). Treine com `treinar_floresta(treino_id = \"treino_1\")` e avalie SÓ no teste com `metricas_floresta(teste_id = \"teste_1\")`.","handle":"treino_1","colunas_omitidas":[],"contexto":{"treino_id":"treino_1","teste_id":"teste_1","n_treino":2401,"n_teste":599,"prop":0.8,"semente":2023}},"erro":null}
- CALL `treinar_floresta`({"treino_id":"treino_1","trees":250,"min_node_size":5,"semente":2023})
  - RESULT `treinar_floresta`: {"dados":[{"n_arvores":250,"n_features":77,"n_treino":2401,"min_node_size":5,"erro_oob_brier":0.337597225170272,"tempo_s":3.28}],"metadados":{"grao":"modelo","filtros":{"treino_id":"treino_1","trees":250,"semente":2023},"n":1,"n_total":1,"truncado":false,"aviso":"Floresta guardada em floresta_1. Fora dos preditores por vazamento (definem ou medem o desempenho): nota_media. Avalie com `metricas_floresta(floresta_id = \"floresta_1\", teste_id = \"teste_1\")`.","handle":"floresta_1","colunas_omitidas":[],"contexto":{"handle":"floresta_1","features":["tp_localizacao","tp_dependencia","in_agua_potavel","in_energia_rede_publica","in_esgoto_rede_publica","in_cozinha","in_banheiro","in_banheiro_pne","in_refeitorio","in_biblioteca","in_laboratorio_ciencias","in_laboratorio_informatica","in_quadra_esportes","in_patio_coberto","in_parque_infantil","in_computador","in_internet","in_banda_larga","in_equip_multimidia","in_equip_lousa_digital","in_desktop_aluno","in_tablet_aluno","in_acessibilidade_rampas","in_acessibilidade_corrimao","in_acessibilidade_elevador","in_acessibilidade_pisos_tateis","in_acessibilidade_sinal_sonoro","qt_salas_utilizadas","qt_prof_administrativos","qt_prof_servicos_gerais","qt_prof_seguranca","qt_desktop_aluno","qt_comp_portatil_aluno","qt_tablet_aluno","qt_mat_bas","qt_mat_inf","qt_mat_fund","qt_mat_med","qt_mat_bas_int","qt_doc_bas","qt_doc_bas_fem","qt_doc_bas_esco_sup_grad","qt_doc_bas_esco_sup_pos_espec","qt_doc_bas_vinculo_concur","qt_gest_bas_esco_sup_grad [...]
- CALL `metricas_floresta`({"floresta_id":"floresta_1","teste_id":"teste_1"})
  - RESULT `metricas_floresta`: {"dados":[{"acuracia":0.607679465776294,"baseline_acerto":0.335559265442404,"ganho_sobre_baseline":0.27212020033389,"f1_macro":0.602464719889803,"auc_macro":0.778329572247358,"n_teste":599}],"metadados":{"grao":"modelo avaliado no teste","filtros":{"floresta_id":"floresta_1","teste_id":"teste_1"},"n":1,"n_total":1,"truncado":false,"aviso":null,"handle":null,"colunas_omitidas":[],"contexto":{"floresta_id":"floresta_1","teste_id":"teste_1","confusao":[{"real":"baixo","predito":"baixo","n":151},{"real":"medio","predito":"baixo","n":57},{"real":"alto","predito":"baixo","n":36},{"real":"baixo","predito":"medio","n":39},{"real":"medio","predito":"medio","n":90},{"real":"alto","predito":"medio","n":41},{"real":"baixo","predito":"alto","n":8},{"real":"medio","predito":"alto","n":54},{"real":"alto","predito":"alto","n":123}],"totais_classe":[{"classe":"baixo","n_real":198,"n_predito":244,"acertos":151},{"classe":"medio","n_real":201,"n_predito":170,"acertos":90},{"classe":"alto","n_real":200,"n_predito":185,"acertos":123}],"f1_classe":{"baixo":0.683257918552036,"medio":0.485175202156334,"alto":0.638961038961039},"auc_classe":{"baixo":0.840147106980025,"medio":0.687573439335983,"alto":0.807268170426065}}},"erro":null}

### Resposta

## 📊 **Resultado Final: Classificação de Desempenho das Escolas Públicas do Fundamental II**

### ✅ Métricas principais no teste (n=599 escolas):

| Métrica | Valor | Interpretação |
|---|---|---|
| **Acurácia** | **60.8%** | Classifica corretamente ~61% das escolas |
| **Baseline** | **33.6%** | Acurácia de adivinhar sempre a classe mais frequente |
| **Ganho sobre baseline** | **+27.2 pontos** | Modelo aprendeu padrões úteis! |
| **F1 Macro** | **0.602** | Média das F1 das 3 classes (equilíbrio) |
| **AUC Macro** | **0.778** | Capacidade discriminatória geral |

### 🎯 Matriz de Confusão (resumo):

| Real → Predito | Baixo | Médio | Alto | Total |
|---|---|---|---|---|
| **Baixo** | 151 ✅ | 39 | 8 | 198 |
| **Médio** | 57 | 90 ✅ | 54 | 201 |
| **Alto** | 36 | 41 | 123 ✅ | 200 |

### 🔍 Pontos importantes:

1. **Classificação "Baixo"** é a mais bem-sucedida (F1=0.68)
2. **Classificação "Médio"** tem menor F1 (0.49), pois está "no meio" e confundível com as duas outras classes
3. A diferença entre baixo/médio (8+57=65 erros) é maior que médio/alto (54+41=95 acertos totais, mas alguns confusos) — esses erros opostos são mais graves

### ⚠️ Cuidados:

- **Associação, não causalidade**: features correlacionadas dividem a importância
- **n_teste=599** é razoável, mas métricas em cortes pequenos seriam instáveis
- A nota SAEB define a classe e é excluída dos preditores — sem vazamento!
- Reprodutível com `semente=2023`

### 🚀 Próximos passos (opcional):

1. Verificar **importância das features** mais relevantes
2. Comparar **modelos por localizações** (`tp_localizacao`)
3. Ajustar hiperparâmetros se necessário

Quer explorar alguma dessas direções?

## Ledger

            timestamp                   tool
1 2026-10-09 11:10:43        features_escola
2 2026-10-09 11:10:48 classificar_desempenho
3 2026-10-09 11:10:54          dividir_dados
4 2026-10-09 11:11:04       treinar_floresta
5 2026-10-09 11:11:10      metricas_floresta
                                                                         args
1 {"etapa":"fundamental_ii","publica":true,"n_por_etapa":3000,"semente":2023}
2                  {"dados_id":"dados_1","nota":"nota_media","grupo":"etapa"}
3                            {"dados_id":"dados_2","prop":0.8,"semente":2023}
4       {"treino_id":"treino_1","trees":250,"min_node_size":5,"semente":2023}
5                           {"floresta_id":"floresta_1","teste_id":"teste_1"}
  n_linhas duracao_ms erro
1        1        815 <NA>
2        3        157 <NA>
3        6         19 <NA>
4        1       4192 <NA>
5        1        113 <NA>

## Checks

List of 4
 $ n_resultados   : int 5
 $ nomes_fisicos  : int 0
 $ denormais_int64: int 0
 $ max_n_ledger   : num 6
