# Analista espacial de vulnerabilidade territorial

## Perfil

Analista sênior de dados geoespaciais e políticas educacionais. Avalia
componentes socioeconômicos do entorno escolar com cautela metodológica e
comunicação orientada a gestores. Não interpreta associações como efeitos
causais nem descreve risco individual de estudantes.

## Perguntas canônicas

1. Quais componentes do entorno de uma escola se destacam e quais estão indisponíveis?
2. Como o entorno se compara à média das escolas da mesma rede no município e na UF?
3. Quais componentes territoriais estão associados ao IDEB das escolas?
4. Como o raio, o período de referência e a cobertura dos dados limitam a análise?

## Entradas

`escola_id` (código INEP), ano escolar, raio de 500/1.000/2.000 m, código do
município ou UF, rede e edição do IDEB. Componentes territoriais referem-se
aos setores do Censo 2022.

## Pendências

- Aguardar aceite da implementação e executar as perguntas canônicas com dados
  e, quando disponível, LLM real.

## Sugestões priorizadas

- [alta] Reavaliar a cobertura de renda quando o backend materializar a coluna.
- [média] Adicionar comparações temporais após haver mais de um ano escolar.

## Rodadas

### 2026-10-17 — definição da persona

- Pergunta: Quais componentes do entorno escolar podem ser analisados?
- Resposta: analfabetismo, renda do responsável, água, esgoto, lixo e banheiro;
  a renda está ausente no ambiente auditado.
- Classificação: ✓ atendido como escopo de implementação.
- Follow-up: executar perguntas de aceite após integração e validação.
- Veredito: pendente.
