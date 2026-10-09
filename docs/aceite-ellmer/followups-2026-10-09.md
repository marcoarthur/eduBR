# Follow-ups da curadoria pelo chat (2026-10-09)

Ollama `qwen3.5:9b` via túnel, uma execução por pergunta. Saída bruta: ledger e resposta (cortada em 1.800 caracteres na exibição). Conferência dos números em `docs/personas/` (gestora 9ª, pesquisadora 11ª, ML 13ª rodadas).

```text

######## G19a (gestora-escolar, 31.0 s)
           tool                     args n_linhas erro
1 resumo_escola {"escola_id":"13078070"}        1 <NA>
Para a **Esc. Municipal Prof Norma Silva de Oliveira**, em Boa Vista do Ramos (AM), os resultados são:

| Etapa | IDEB 2023 | Melhorou? | Variação |
|-------|-----------|-----------|----------|
| Fundamental I | 3,6 | ✅ Sim | +0,1 ponto |
| Fundamental II | 3,7 | ❓ Sem dado* | — |
| Ensino Médio | — | — | — (não ofertada no Censo atual) |

---

### O que isso significa:

- **Fundamental I:** A escola **melhorou 0,1 ponto** na edição de 2023 em relação à edição anterior.
  
- **Fundamental II:** Não temos informação da variação na edição mais recente com nota da escola (isso acontece quando poucas escolas têm alunos avaliados naquela etapa).

- **Ensino Médio:** A etapa não é ofertada no Censo atual — o item aparece como histórico ("ofertada = false").

---

### Resumo para a gestora:
A escola tem evolução positiva no Fundamental I. No Fundamental II, precisaria de mais tempo para acumular resultados consistentes na edição de referência. 

######## G19b (gestora-escolar, 27.4 s)
               tool                     args n_linhas erro
1 escolas_similares {"escola_id":"15535762"}        5 <NA>
Encontrei **5 escolas parecidas** com a sua (INEP 15535762), todas do ensino médio, para você trocar experiências:

| Ordem | Escola | Município | UF | Parecida com |
|-------|--------|-----------|-----|--------------|
| 1ª | ESCOLA QUILOMBOLA LUZIA MARIA DA CONCEICAO | Croatá | CE | 4,15 pontos |
| 2ª | EE IVAN MATTAR SOUKEF | Delta | MG | 4,17 pontos |
| 3ª | ESCOLA ESTADUAL NOSSA SENHORA DE GUADALUPE | Santarém | PA | 4,19 pontos |
| 4ª | CENTRO DE ENSINO JOSUE MONTELLO | São Luís | MA | 4,22 pontos |
| 5ª | ESCOLA ESTADUAL PROFA MARIETA EMMI | Santa Izabel do Pará | PA | 4,24 pontos |

Todas são **escolas estaduais** de ensino médio. A primeira (em Croatá-CE) é a mais parecida com a sua. 

Use essas escolas como referência para trocar boas práticas! 🏫 

######## R19 (pesquisadora-educacional, 76.3 s)
                   tool
1    covariaveis_escola
2 especificar_regressao
3 especificar_regressao
4    executar_regressao
5          coeficientes
6              metricas
                                                                                                                                                                 args
1                                                                                                                   {"uf":"AC","rede":"publica","ativas":true,"n":10}
2 {"outcome":"ideb_fund_i","predictors":["in_biblioteca","docentes"],"cuts":"rede","fonte":"escolas","dados_id":"dados_1","filtro":[{"coluna":"sg_uf","valor":"AC"}]}
3                                                              {"outcome":"ideb_fund_i","predictors":["in_biblioteca","docentes"],"cuts":"rede","dados_id":"dados_1"}
4                                                                                                                                              {"espec_id":"espec_1"}
5                                                                                                                              {"regressao_id":"regressao_1","n":100}
6                                                                                                                              {"regressao_id":"regressao_1","n":100}
  n_linhas               erro
1       10               <NA>
2        0 parametro_invalido
3        1               <NA>
4        3               <NA>
5        6               <NA>
6        2               <NA>
## Regressão para escolas públicas do Acre (Fundamental I: IDEB)

### Resumo dos cortes por rede (preditores: *in_biblioteca* e *docentes*)

| Rede     | Nº escolas com IDEB | R²       | R² ajustado  | Modelo válido |
|----------|---------------------|----------|--------------|---------------|
| Estadual | 96                  | 0.0104   | -0.0109      | Sim           |
| Municipal| 127                 | 0.0870   | 0.0723       | Sim           |
| Federal  | 1                  | —        | —            | Não (n ≤ #preditores+1) |

> **Nota:** Das 1.484 escolas públicas do Acre, apenas 224 tinham IDEB F1 registrado em Censo 2025; o restante foi descartado pela presença de `null` no desfecho ou nos preditores.

---

### Coeficientes (variáveis independentes) — interpretação associativa

| Rede     | Intercepto (IDEB predito) | Biblioteca (*in_biblioteca*) | Docentes |
|----------|---------------------------|-------------------------------|----------|
| **Estadual** | 5.787 ± 0.206, *p* < 1e-47 | **-0.373 ± 0.517, p = 0.472** (não significativo) | **+0.0064 ± 0.0106, p = 0.544** (não significativo) |
| **Municipal**| 4.553 ± 0.224, *p* < 1e-41 | **-0.487 ± 0.283, p = 0.088** (quase a 10%) | **+0.0504 ± 0.0157, p = 0.0017** (*) |

- Coeficientes **positivos** para *docentes* indicam maior IDEB ao aumentar o número de docentes (mantendo as demais variáveis constantes).
- O sinal negativo para *biblioteca* sugere que ter biblioteca é associado a menor IDEB, mas só é significativo em redes municipais e apenas a nível 10%.

---

### Leitura substantiva por rede

| Rede     | R²         | Significância do modelo (teste F) | Observação |
|----------|------------|------------------------------------|-------------|
| Estadual | 0.0104     | *p* = 0.616                         | Mode 

######## M33 (especialista-ml, 77.2 s)
                    tool
1        features_escola
2 classificar_desempenho
3          dividir_dados
4       treinar_floresta
5      metricas_floresta
6   importancia_floresta
7       treinar_floresta
8      metricas_floresta
                                                                                                                                                                                                                                                                                                                                                                                                                                                                 args
1                                                                                                                                                                                                                                                                                                                                                                                         {"etapa":"fundamental_ii","publica":true,"n_por_etapa":5000,"semente":2023}
2                                                                                                                                                                                                                                                                                                                                                                                                          {"dados_id":"dados_1","nota":"nota_media","grupo":"etapa"}
3                                                                                                                                                                                                                                                                                                                                                                                                                    {"dados_id":"dados_2","prop":0.8,"semente":2023}
4                                                                                                                                                                                                                                                                                                                                                                                               {"treino_id":"treino_1","trees":250,"min_node_size":5,"semente":2023}
5                                                                                                                                                                                                                                                                                                                                                                                                                   {"floresta_id":"floresta_1","teste_id":"teste_1"}
6                                                                                                                                                                                                                                                                                                                                                                                                                                 {"floresta_id":"floresta_1","n":20}
7 {"treino_id":"treino_1","trees":250,"min_node_size":5,"semente":2023,"features":["media_inse","pc_nivel_1","pc_nivel_2","pc_nivel_3","pc_nivel_4","pc_nivel_5","pc_nivel_6","pc_nivel_7","pc_nivel_8","equipamentos_por_aluno","qt_doc_bas_esco_sup_grad","espacos_pedagogicos_score","qt_doc_bas_esco_sup_pos_espec","qt_comp_portatil_aluno","prop_mat_integral","qt_mat_bas","qt_mat_bas_int","qt_desktop_aluno","funcionarios_nd_por_aluno","qt_tablet_aluno"]}
8                                                                                                                                                                                                                                                                                                                                                                                                                   {"floresta_id":"floresta_2","teste_id":"teste_1"}
  n_linhas erro
1        1 <NA>
2        3 <NA>
3        6 <NA>
4        1 <NA>
5        1 <NA>
6       20 <NA>
7        1 <NA>
8        1 <NA>
## Comparação final

| Modelo | Features | Acurácia | F1 macro | AUC macro | Ganho sobre baseline |
|--------|----------|----------|----------|-----------|---------------------|
| **Floresta original** | 77 features | 56,5% | 56,2% | 75,5% | +23,0 p.p. |
| **Floresta reduzida** (top 20) | 20 features | 55,5% | 55,1% | 74,1% | +22,0 p.p. |

## Conclusões

✅ **A redução de dimensionalidade foi bem-sucedida:**
- Perdui apenas **1 ponto percentual** em acurácia (de 56,5% → 55,5%)
- Mantive quase todo o ganho sobre o baseline (+23,0 vs +22,0 p.p.)
- Tempo de treino reduziu de **6,4s para 2,6s** (~60% mais rápido)

⚠️ **A perda pequena é expectável:** features como `qt_tablet_aluno` (pos. 21, importância 0,0023) e outras menos importantes contribuíam pouco. As **top 20 capturam a essência** da variabilidade do desempenho.

📌 **Features mais informativas:**
1. **Contexto socioeconômico** domina: `media_inse` (0,034), `pc_nivel_7`, `pc_nivel_6`, etc.
2. **Infraestrutura tecnológica`: `equipamentos_por_aluno`, `qt_comp_portatil_aluno`.
3. **Recursos educacionais**: `espacos_pedagogicos_score`, `qt_doc_bas_esco_sup_grad/pos_espec`.

Se quiser, posso verificar quais outras features aparecem entre as 21-77 para decidir se valeria a pena incluir algumas extras por categoria de interesse (ex: todos os indicadores de infraestrutura física). 
Warning message:
Response was truncated because it hit the `max_tokens` limit.
ℹ Increase `max_tokens` to allow the model to generate the full response. 
```
