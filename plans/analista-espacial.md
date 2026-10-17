# Plano: persona Analista Espacial de Vulnerabilidade Territorial

## Objetivo

Adicionar a persona `analista-espacial` à camada `ellmer` do `eduBR`, para
descrever os indicadores socioeconômicos do entorno escolar, compará-los com
escolas de referência e testar associações com o IDEB. A persona deve apoiar
gestores públicos com respostas curtas, rastreáveis e sem alegações causais.

Este plano cobre a integração da persona, o acesso aos componentes do bloco B
do IVET e as ferramentas necessárias para comparação e regressão. Não inclui
implementar fórmula nova do IVET, carregar dados no EduMaps, construir mapas
ou inferir vulnerabilidade individual de estudantes.

## Auditoria e contratos observados

- A camada `ellmer` restringe personas em `eduBR_personas()` e filtra as
  ferramentas pelo registro `eduBR_tools_registro()`. `chat_edubr()` e
  `prompt_persona()` já consomem essa lista; não precisam de um provedor novo.
- As ferramentas existentes `perfil_escola`, `municipios`, `redes_municipio`,
  `covariaveis_escola` e `regressao_escolas` podem ser concedidas à persona.
- `regressao_escolas` usa internamente `covariaveis_escola()` e não recebe
  dados ou preditores do IVET. Portanto, ela não pode executar a regressão
  descrita no rascunho sem uma extensão ou ferramenta composta específica.
- O catálogo é a única rota para consultar a relação de entorno; o código novo
  não deve referenciar seu nome físico fora do catálogo e dos testes de
  contrato.
- Inspeção somente de leitura em `edumaps_container` (17/10/2026): a relação
  contém 470.448 linhas para 156.816 escolas, com uma linha por escola ×
  `nu_ano_censo` × `raio_m`; o ambiente tem o ano 2025 e raios de 500, 1.000 e
  2.000 m. As três linhas por escola não podem ser tratadas como observações
  independentes numa análise.
- A coluna `versao` está em `ivet-v1.1`. `renda_resp_media` está NULL em todas
  as 470.448 linhas. Os campos de analfabetismo, água, esgoto, lixo e banheiro
  têm cobertura parcial. O retorno precisa preservar NULL por componente e
  incluir versão, raio, cobertura e contagem de observações válidas.
- `nu_ano_censo = 2025` identifica o recorte escolar da relação; as variáveis
  de território vêm dos setores do Censo 2022. O prompt e os metadados devem
  distinguir ano escolar, referência dos dados setoriais e data de cálculo.
- A renda do responsável é nominal em R$/mês, não renda per capita. Ausência
  de renda é dado indisponível, nunca renda zero nem vulnerabilidade zero.
- O backend implementa e versiona a transformação do IVET. Esta feature deve
  expor os componentes documentados da fonte sem recalcular ou chamar um
  componente isolado de “escore IVET” quando a dimensão oficial não estiver
  disponível na relação.

## Decisões propostas

1. Usar `raio_m = 1000` como padrão da tool, permitindo 500, 1.000 e 2.000 m
   explicitamente. O raio usado sempre aparece nos filtros e no contexto do
   resultado; comparações e regressões usam um único raio por execução.
2. Criar uma função de domínio lazy para acessar os componentes por escola,
   com filtro por código INEP, ano escolar e raio. Registrar uma chave de
   domínio semântica no catálogo e projetar somente as colunas necessárias
   antes da materialização.
3. Devolver os componentes brutos do bloco B, seus metadados metodológicos e
   de cobertura. Incluir analfabetismo, renda do responsável e os indicadores
   de saneamento disponíveis (água, esgoto, lixo e banheiro); preservar NULL.
   Não calcular um escore agregado no `eduBR` nesta entrega.
4. Acrescentar uma ferramenta agregada para comparação por município/rede e
   UF/rede. Ela calcula estatísticas entre escolas no banco, para o mesmo ano
   e raio, e devolve `n` válido por componente. Chamar a média de “média das
   escolas”, sem confundi-la com uma média ponderada por população ou área.
5. Acrescentar uma base lazy de modelagem que una os componentes do IVET ao
   IDEB por escola, com um raio selecionado e sem multiplicar linhas. Uma tool
   composta nova reutiliza `especificar_regressao()` e
   `executar_regressao()`; não altera silenciosamente o comportamento de
   `regressao_escolas`.
6. Associar a pessoa `analista-espacial` a `perfil_escola`,
   `covariaveis_escola`, `municipios`, `redes_municipio`, `regressao_escolas`
   e às novas ferramentas de IVET. A regressão geral permanece disponível
   para covariáveis existentes; a regressão com IVET usa a ferramenta
   composta dedicada.

## Chunks de implementação

| Chunk | Conteúdo | Critério de aceite |
|---|---|---|
| 1. Acesso de domínio | Registrar a relação de entorno no catálogo; criar função lazy/documentada com filtros de escola, ano e raio; selecionar componentes e proveniência; nenhuma coleta ampla. | Testes validam classe, SQL/filtros, raio permitido, preservação de NULL, versão e erro para escola/raio sem linha. |
| 2. Tool de escola e contexto | Criar `ivet_socioeconomico` e uma tool de comparação agregada por município/rede e UF/rede; validação anterior ao dbplyr; envelope JSON, teto, timeout e anti-vazamento existentes. | Mock cobre sucesso, parâmetros inválidos, sem linha e componente NULL; comparação informa raio, período, `n` válido por variável e estatística claramente nomeada. |
| 3. Base e regressão | Criar função lazy que junta IVET, cadastro escolar e IDEB por chave; criar tool composta para ajustar regressão usando o motor declarativo. Filtrar por um raio, edição do IDEB, rede/território e limite da sessão. | Teste garante no máximo uma linha por escola no recorte, não usa escola/IDEB como preditor por engano, reporta `n` após remoção de ausências e não retorna regressão se não houver observações suficientes. |
| 4. Persona e documentação | Adicionar `analista-espacial` a `eduBR_personas()`, documentação roxygen, `inst/prompts/analista-espacial.md`, perfil/memória em `docs/personas/analista-espacial.md`, registro das tools, bloco gerado em `docs/ellmer.md` e matriz pergunta × tool. | Testes conferem prompt encontrado, lista de ferramentas, ausência de nomes físicos e consistência automática da matriz. |
| 5. Smoke e aceite | Adicionar smoke condicionado a `EDUBR_SMOKE`; validar no banco disponível e gravar transcrições de aceite com Ollama ou Anthropic, sem credenciais no repositório. | Perguntas de escola, comparação territorial e associação ao IDEB usam a tool correta; prosa coincide com os valores, raio, ano de referência, `n` e ausências retornados. |

## Prompt de sistema proposto

```markdown
# Persona: Analista Espacial de Vulnerabilidade Territorial

## Papel
Você é analista sênior de dados geoespaciais e políticas educacionais. Seu
tom é analítico, cético e orientado a evidências. Descreva o entorno da escola
com os componentes disponíveis, informe fontes, referência temporal, raio e
metodologia. Não atribua características territoriais a cada estudante.

## Objetivo
Ajudar gestores públicos a entender quais características observadas no
entorno escolar se destacam e como se associam ao desempenho, sem inferir
causalidade.

## Uso das ferramentas
- Use `ivet_socioeconomico` para os componentes do entorno de uma escola.
- Use a ferramenta de contexto IVET para comparar médias entre escolas da
  mesma rede no município e na UF, no mesmo raio e período.
- Use `perfil_escola` para contexto e comparação do IDEB da escola.
- Use `covariaveis_escola` e `regressao_escolas` para covariáveis já existentes.
- Use a ferramenta de regressão IVET para associar componentes territoriais e
  IDEB. Informe unidade, raio, referência, `n` e limites do modelo.
- Use `municipios` e `redes_municipio` para contexto municipal e de rede.
- Para mapas, descreva que o usuário pode usar `as_sf()` em R; não afirme que
  as ferramentas produziram um mapa.

## Resposta
Apresente resumo executivo, componentes do entorno, comparação com a rede,
associação com o IDEB quando estimável, fatores em destaque e limitações.
Use números e rótulos exatamente como vieram das ferramentas.

## Regras
- Não use linguagem causal; regressão e correlação são associações.
- Não calcule nem nomeie um escore oficial do IVET a partir de componentes
  brutos.
- Trate NULL como dado ausente, nunca como zero. Diga quais componentes não
  puderam ser avaliados.
- Distinga o ano do cadastro escolar do ano de referência dos setores e da
  versão da transformação.
- Sempre informe o raio de influência e o `n` usado em médias/modelos.
- Não confunda média simples entre escolas com agregação ponderada por área,
  população ou número de alunos.
- Números em português do Brasil; sem inventar valores ou fontes.
```

## Perguntas de aceite

1. “Quais indicadores do entorno da escola 13078070 se destacam no raio de
   1.000 m? O que está indisponível?” Esperado: componentes da escola, versão,
   referência, cobertura e transparência sobre a renda nula.
2. “Como o entorno dessa escola se compara às escolas municipais do município
   e da UF?” Esperado: resolver município/rede por código e comparar as médias
   escolares no mesmo raio e período, com `n` por variável.
3. “A renda média dos responsáveis está associada ao IDEB?” Esperado: avisar
   que a renda não está materializada no ambiente atual e não ajustar uma
   regressão vazia ou substituir NULL por zero. Repetir com componentes
   disponíveis apenas se a pergunta permitir essa mudança, reportando `n`.
4. “Quais fatores do entorno se associam ao IDEB das escolas municipais de
   Ubatuba?” Esperado: usar regressão IVET por código municipal, raio e edição;
   descrever associações, ausência de causalidade e limitações temporais.

## Dependências e riscos

- A renda requer o refresh/loader do backend. A tool continua útil sem renda,
  mas a regressão que a usa não pode ser aceita enquanto a coluna estiver toda
  NULL no ambiente.
- A relação observada tem três raios por escola. O raio deve ser filtrado
  antes de qualquer agregação ou join com IDEB/covariáveis.
- O tamanho nacional torna inadequado materializar a relação inteira. Filtros,
  projeções e agregações precisam ser traduzidos pelo dbplyr no banco.
- O ano escolar 2025 e o Censo setorial 2022 têm significados distintos; ambos
  devem aparecer nos metadados e na redação.
- A média por escola não é uma medida oficial municipal do IVET nem é ponderada
  por área/população. A saída precisa conservar essa distinção.

## Fora de escopo

- Calcular/publicar um escore oficial do IVET dentro do `eduBR`.
- Carregar setores censitários ou atualizar a renda no EduMaps.
- Gerar mapas ou expor geometrias às tools.
- Interpretar associação como efeito causal ou como medida individual de
  vulnerabilidade dos alunos.
```

## Arquivos previstos na execução

- `R/catalogo.R` e novo arquivo de domínio em `R/`.
- Novo grupo de tools de IVET e registro em `R/ellmer_tools.R`.
- `R/ellmer_personas.R` (documentação da persona) e metadados em
  `R/ellmer_tools.R`.
- `inst/prompts/analista-espacial.md`.
- `docs/personas/analista-espacial.md` e `docs/ellmer.md`.
- Testes unitários de domínio, tools, personas/registro e smoke opcional.
- `NAMESPACE` e `man/` via `devtools::document()` se a nova função de domínio
  for exportada.

## Sequência de validação na execução

1. `devtools::test(filter = "ellmer")` e testes novos do domínio.
2. Smoke restrito ao código INEP/raio conhecidos em
   `service = "edumaps_container"`; conferir NULLs e `versao` reais antes do
   aceite.
3. `EDUBR_LLM_SMOKE=ollama` ou aceite Anthropic autorizado, registrando
   ledger/transcrição sanitizados em `docs/aceite-ellmer/`.
4. `devtools::document()` e `devtools::check()`; confirmar compatibilidade
   dbplyr 2.5 no container se a consulta incluir tradução nova.

## Decisões para aprovação

- Confirmar o raio padrão de 1.000 m (proposta deste plano).
- Confirmar que a primeira entrega será exploratória, com componentes brutos,
  sem calcular o escore agregado oficial do IVET.
- Confirmar a inclusão da comparação agregada e da regressão IVET como escopo
  desta feature. Ambas são necessárias para cumprir a estrutura de resposta
  prometida no prompt.
