# Aceite pesquisadora-educacional (ollama qwen3.5:9b) 2026-10-09 08:09 -03

## Pergunta 1 (249.1 s)

> No Acre, rede municipal, o IDEB do fundamental I se associa a ter biblioteca e ao número de docentes? Separe por localização urbana/rural.

- CALL `covariaveis_escola`({"uf":"AC","rede":"Municipal","n":10})
  - RESULT `covariaveis_escola`: {"dados":[{"co_entidade":"12034886","sg_uf":"AC","co_municipio":1200500,"tp_dependencia":3,"tp_localizacao":2,"in_agua_rede_publica":0,"in_energia_rede_publica":1,"in_esgoto_rede_publica":0,"in_biblioteca":0,"in_laboratorio_informatica":0,"in_quadra_esportes":0,"in_refeitorio":0,"in_internet":0,"in_banda_larga":null,"in_sala_professor":0,"in_comum_creche":0,"in_comum_pre":1,"in_comum_fund_ai":1,"in_comum_fund_af":1,"in_comum_medio_medio":0,"in_comum_medio_integrado":0,"in_comum_eja_fund":1,"in_comum_eja_medio":0,"rede":"Municipal","localizacao":"Rural","docentes":6,"matriculas":88,"ideb_fund_i":null,"ideb_fund_ii":null,"ideb_medio":null},{"co_entidade":"12035050","sg_uf":"AC","co_municipio":1200500,"tp_dependencia":3,"tp_localizacao":1,"in_agua_rede_publica":1,"in_energia_rede_publica":1,"in_esgoto_rede_publica":0,"in_biblioteca":0,"in_laboratorio_informatica":0,"in_quadra_esportes":0,"in_refeitorio":1,"in_internet":0,"in_banda_larga":null,"in_sala_professor":1,"in_comum_creche":1,"in_comum_pre":0,"in_comum_fund_ai":0,"in_comum_fund_af":0,"in_comum_medio_medio":0,"in_comum_medio_integrado":0,"in_comum_eja_fund":0,"in_comum_eja_medio":0,"rede":"Municipal","localizacao":"Urbana","docentes":2,"matriculas":61,"ideb_fund_i":null,"ideb_fund_ii":null,"ideb_medio":null},{"co_entidade":"12043249","sg_uf":"AC","co_municipio":1200500,"tp_dependencia":3,"tp_localizacao":2,"in_agua_rede_publica":0,"in_energia_rede_publica":1,"in_esgoto_rede_publica":0,"in_biblioteca":0,"in_laboratorio_inf [...]
- CALL `ideb`({"uf":"AC","rede":"Municipal","etapa":"fundamental_i","ano":2023,"n":50})
  - RESULT `ideb`: {"dados":[{"id_escola":"12000132","sg_uf":"AC","co_municipio":1200203,"no_municipio":"Cruzeiro do Sul","no_escola":"ESCOLA 21 DE ABRIL","rede":"Municipal","ano":2023,"etapa":"fundamental_i","aprovacao_si_4":94.7,"aprovacao_1":94.4,"aprovacao_2":92.3,"aprovacao_3":93.3,"aprovacao_4":93.9,"nota_matematica":202.9,"nota_portugues":189.94,"nota_media":5.29,"ideb_observado":5,"ideb_projecao":null},{"id_escola":"12000248","sg_uf":"AC","co_municipio":1200203,"no_municipio":"Cruzeiro do Sul","no_escola":"ESC ANTONIO FERREIRA GOMES","rede":"Municipal","ano":2023,"etapa":"fundamental_i","aprovacao_si_4":95.7,"aprovacao_1":90.9,"aprovacao_2":94.1,"aprovacao_3":96.7,"aprovacao_4":97.1,"nota_matematica":183.73,"nota_portugues":186.5,"nota_media":4.86,"ideb_observado":4.7,"ideb_projecao":null},{"id_escola":"12000396","sg_uf":"AC","co_municipio":1200203,"no_municipio":"Cruzeiro do Sul","no_escola":"ESC CORAZITA NEGREIROS","rede":"Municipal","ano":2023,"etapa":"fundamental_i","aprovacao_si_4":96,"aprovacao_1":98.7,"aprovacao_2":93.2,"aprovacao_3":90.9,"aprovacao_4":97.3,"nota_matematica":191.27,"nota_portugues":190.66,"nota_media":5.08,"ideb_observado":4.9,"ideb_projecao":null},{"id_escola":"12000558","sg_uf":"AC","co_municipio":1200203,"no_municipio":"Cruzeiro do Sul","no_escola":"ESC EMIDIO BRAGA DE VASCONCELOS","rede":"Municipal","ano":2023,"etapa":"fundamental_i","aprovacao_si_4":95.5,"aprovacao_1":92.9,"aprovacao_2":93.8,"aprovacao_3":100,"aprovacao_4":88.9,"nota_matematica":200.3,"nota_ [...]

### Resposta



## Ledger

            timestamp               tool
1 2026-10-09 08:06:11 covariaveis_escola
2 2026-10-09 08:06:19               ideb
                                                                      args
1                                    {"uf":"AC","rede":"Municipal","n":10}
2 {"uf":"AC","etapa":"fundamental_i","rede":"Municipal","ano":2023,"n":50}
  n_linhas duracao_ms erro
1       10       1189 <NA>
2       50        206 <NA>

## Checks

List of 4
 $ n_resultados   : int 2
 $ nomes_fisicos  : int 0
 $ denormais_int64: int 0
 $ max_n_ledger   : num 50
