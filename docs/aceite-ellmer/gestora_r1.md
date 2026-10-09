# Aceite gestora-escolar (ollama qwen3.5:9b) 2026-10-09 07:55 -03

## Pergunta 1 (48.9 s)

> Como está a infraestrutura da escola 13078070 comparada ao município?

- CALL `perfil_escola`({"escola_id":"13078070"})
  - RESULT `perfil_escola`: {"dados":[{"dimensao":"Infraestrutura","item":"Água de rede pública","escola":1,"municipio":0.386363636363636,"estado":0.273822366055376,"dif_municipio":0.613636363636364,"ofertada":null},{"dimensao":"Infraestrutura","item":"Energia de rede pública","escola":1,"municipio":0.954545454545455,"estado":0.715390147428982,"dif_municipio":0.0454545454545454,"ofertada":null},{"dimensao":"Infraestrutura","item":"Esgoto de rede pública","escola":1,"municipio":0.0681818181818182,"estado":0.118302768788206,"dif_municipio":0.931818181818182,"ofertada":null},{"dimensao":"Infraestrutura","item":"Biblioteca","escola":0,"municipio":0.0681818181818182,"estado":0.243617403811579,"dif_municipio":-0.0681818181818182,"ofertada":null},{"dimensao":"Infraestrutura","item":"Laboratório de informática","escola":0,"municipio":0.181818181818182,"estado":0.171700827040633,"dif_municipio":-0.181818181818182,"ofertada":null},{"dimensao":"Infraestrutura","item":"Quadra de esportes","escola":1,"municipio":0.0681818181818182,"estado":0.177454153182309,"dif_municipio":0.931818181818182,"ofertada":null},{"dimensao":"Infraestrutura","item":"Refeitório","escola":1,"municipio":0.340909090909091,"estado":0.422689679971233,"dif_municipio":0.659090909090909,"ofertada":null},{"dimensao":"Infraestrutura","item":"Internet","escola":1,"municipio":0.409090909090909,"estado":0.667026249550521,"dif_municipio":0.590909090909091,"ofertada":null},{"dimensao":"Infraestrutura","item":"Banda larga","escola":1,"municipio":0.3888888 [...]

### Resposta

Aqui está a comparaçãoda infraestrutura da Escola Municipal Prof Norma Silva de Oliveira (13078070) com o município de Boa Vista do Ramos (AM):

## Infraestrutura da escola vs. município

| Item | Escola tem? | Escolas do município que têm* | Como está comparada ao município |
|------|-------------|------------------------------|----------------------------------|
| Água de rede pública | ✅ Sim | Apenas 39% | Muito à frente (+61 pontos) |
| Energia de rede pública | ✅ Sim | 95% | Na média (+5 pontos) |
| Esgoto de rede pública | ✅ Sim | Apenas 7% | Muito à frente (+93 pontos) ⬆️ |
| Biblioteca | ❌ Não tem | Apenas 7% | A maioria do município também não tem |
| Laboratório de informática | ❌ Não tem | 18% | Abaixo da média da rede (-18 pontos) ⬇️ |
| Quadra de esportes | ✅ Sim | Apenas 7% | Muito à frente (+93 pontos) ⬆️ |
| Refeitório | ✅ Sim | 34% | À frente (+66 pontos) ⬆️ |
| Internet | ✅ Sim | 41% | Muito à frente (+59 pontos) ⬆️ |
| Banda larga | ✅ Sim | 39% | Muito à frente (+61 pontos) ⬆️ |
| Sala dos professores | ✅ Sim | 27% | Muito à frente (+73 pontos) ⬆️ |

*\*Fração das escolas do município que têm o recurso em atividade.*

### Resumo rápido:
- **Forças da escola:** tem recursos que apenas 40–39% das escolas do município possuem (internet, banda larga, esgoto, quadra).
- **Ponto de atenção:** não tem biblioteca nem laboratório de informática — itens raros no município todo.

A comparação mostra onde a escola está acima ou abaixo da média do município (usando dados do Censo Escolar 2025 e IDEB 2023 para os recortes que aplicam).

## Pergunta 2 (37.8 s)

> Quais escolas são parecidas com a 13078070 para trocar experiência?

- CALL `escolas_similares`({"escola_id":"13078070"})
  - RESULT `escolas_similares`: {"dados":[{"co_entidade":"27054128","escola":"ESCOLA MUNICIPAL DE ENSINO FUNDAMENTAL MANOEL GONCALVES DA SILVA","municipio":"Rio Largo","uf":"AL","rede":"Municipal","etapa":"fundamental_ii","distancia":5.22545492100325},{"co_entidade":"31015474","escola":"EM DEPUTADO ABELARD PEREIRA","municipio":"Carandaí","uf":"MG","rede":"Municipal","etapa":"fundamental_i","distancia":5.5932663845386},{"co_entidade":"22141588","escola":"ESCOLA MUNICIPAL POETA DA COSTA E SILVA","municipio":"Teresina","uf":"PI","rede":"Municipal","etapa":"fundamental_ii","distancia":5.70190143853352},{"co_entidade":"35245227","escola":"ANTONIO DUARTE NOGUEIRA DOUTOR EMEF","municipio":"Barrinha","uf":"SP","rede":"Municipal","etapa":"fundamental_i","distancia":5.74374290657589},{"co_entidade":"50016130","escola":"EM FRANCISCO MEIRELES","municipio":"Dourados","uf":"MS","rede":"Municipal","etapa":"fundamental_i","distancia":5.78395560086599}],"metadados":{"grao":"escola vizinha × etapa","filtros":{"escola_id":"13078070","n":5,"etapa":null,"publica":true},"n":5,"n_total":5,"truncado":false,"aviso":null,"handle":null,"colunas_omitidas":[]},"erro":null}

### Resposta

## Escolas parecidas com a sua (para trocar experiências)

Estas são as 5 escolas mais parecidas com a **ESC MUNICIPAL PROF NORMA SILVA DE OLIVEIRA** (13078070), consideradas pelo seu perfil (infraestrutura, porte, docentes e gestão). Quanto menor o número na coluna "distância", mais parecidas elas são.

| Distância | Escola | Município | UF | Etapa |
|-----------|--------|-----------|----|-------|
| 5,23 | ESCOLA MUNICIPAL DE ENSINO FUNDAMENTAL MANOEL GONÇALVES DA SILVA | Rio Largo | AL | Fundamental II |
| 5,59 | EM DEPUTADO ABELARD PEREIRA | Carandaí | MG | Fundamental I |
| 5,70 | ESCOLA MUNICIPAL POETA DA COSTA E SILVA | Teresina | PI | Fundamental II |
| 5,74 | ANTONIO DUARTE NOGUEIRA DOUTOR EMEF | Barrinha | SP | Fundamental I |
| 5,78 | EM FRANCISCO MEIRELES | Dourados | MS | Fundamental I |

### Como usar essa lista:
- **Distância mais baixa = maior similaridade:** as escolas com número menor são mais parecidas (mesmo porte e infraestrutura).
- **Trocas de experiência válidas:** todas estão nos anos iniciais (Fund. I ou II), então podem trocar práticas pedagógicas, gestão escolar e recursos didáticos.
- **Dica:** priorize as de maior distância no mesmo estado (AL, PI) para trocar com quem vive a mesma realidade regional, ou vá aos outros estados quando houver parceria já estabelecida.

Precisa dos dados de infraestrutura ou IDEB de alguma delas para comparar o desempenho também? É só pedir!

## Ledger

            timestamp              tool                     args n_linhas
1 2026-10-09 07:54:14     perfil_escola {"escola_id":"13078070"}       14
2 2026-10-09 07:55:06 escolas_similares {"escola_id":"13078070"}        5
  duracao_ms erro
1       2189 <NA>
2      20049 <NA>

## Checks

List of 4
 $ n_resultados   : int 2
 $ nomes_fisicos  : int 0
 $ denormais_int64: int 0
 $ max_n_ledger   : num 14
