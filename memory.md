# memory.md — decisões do pacote `eduBR`

Registro curto de decisões que valem entre sessões. Detalhes de
implementação ficam no código; memória de curadoria fica em
`docs/personas/`.

## 2026-09-28 — personas de curadoria moram neste repo

- **Decisão**: perfis + memória das 3 personas (`pesquisadora-educacional`,
  `especialista-ml`, `gestora-escolar`) vivem em `docs/personas/` **aqui**.
- **Histórico**: trazido de `~/Projects/leaflet/docs/personas/` em
  2026-09-28, integral (todas as rodadas). Lá **nada foi apagado** —
  remoção eventual é decisão do dev do repo EduMaps.
- **Exceção**: `tech-lead.md` é curadoria do acervo EduMaps, não do `eduBR`;
  fica só no leaflet.
- **Consequências**: `AGENTS.md` e a skill `r-edubr` apontam para o caminho
  local; `docs/` está no `.Rbuildignore` (fora do build, como `analysis/`).

## 2026-09-28 — redes × perfil docente

- Novo: `rede_municipio()` (filtros UF/região/rede sobre
  `analytics.mv_rede_escolas`) e `docentes_rede()` (join
  `censo_docentes ⋈ censo_escolas` por código, agregação no banco,
  projeção via `colunas=`); EDA em `analysis/rede_professor.Rmd`.
- Reuso obrigatório dos helpers de `gestor.R`/`regiao.R`
  (`eduBR_codigos_rede`, `eduBR_case_when_lookup`, `eduBR_mutate_regiao`):
  nada de duplicar lookup de rede/localização.
- Lição: `names()` em `tbl_sql` devolve slots internos — derivar colunas de
  variáveis determinísticas, nunca inspecionar a tabela lazy.

## 2026-09-29 — 3ª rodada pesquisadora + 5ª ML

- `rede` normalizada via `codigo_rede` (a MV traz minúscula; o join da EDA
  não casava — verificado 4/4, 0 NA); `integer64` documentado no Rd em vez
  de conversão silenciosa.
- `coletar(n=)` + aviso já existiam (memória da 4ª rodada do ML estava
  desatualizada); `dicionario()` cobre rótulos (tipos/ano seguem abertos).
- ~~`co_municipio` em `escolas()` é inviável~~ — **superado em
  2026-10-09**: `clean.censo_escolas` é a **fonte de verdade das escolas**
  (cadastro do Censo, 214 mil escolas em 2025, com `co_entidade`,
  `co_municipio`, rede, localização e geometria). `clean.escolas` foi a
  primeira ingestão do EduMaps, incompleta (158 mil escolas, sem código do
  município; ~1,4 mil não estão no Censo). `escolas()`/`escola()` agora
  leem `censo_escolas`; o domínio `escolas` do catálogo fica só como
  legado. Não usar `clean.escolas` em código novo.
- Restam (roadmap na skill): `as_sf()`, `perfil_escola()`/`comparar()`,
  `escolas_similares()`, origem dos `scores()`, logístico (AUC/McFadden),
  `ler_especs()`, INSE histórico, avisos `ideb_inse()`.

## 2026-09-29 — fila de issues #6–#16

- Entregues: #7 `as_sf()`, #8 `escolas_similares()` (fase 1), #9 origem dos
  `scores()` (docs), #12 `rotular()`, #13 `registrar_relacao()`,
  #14 parcial (anos em `ideb_inse()`, dados bloqueados), #15 avisos.
  Já existiam: #10 (AUC/McFadden), #11 (`ler_especs()`).
- **Decisão #16 (`integer64`)**: manter o tipo do banco + documentar no Rd
  (feito em `docentes_rede()`/`rede_municipio()`/`redes()`); sem coerção
  silenciosa para `numeric` — esconderia a precisão real e quebraria a
  simetria com o Postgres.

## 2026-10-07/08 — rodadas de curadoria #20–#58 (resumo)

- Comparações do perfil usam **mesma edição e mesma rede** do IDEB (#21);
  município/estado contam só escolas **em atividade**
  (`tp_situacao_funcionamento == 1`) em `perfil_escola()` e
  `covariaveis_escola()`.
- PCA: códigos `tp_*` fora, sinal fixo, componentes de variância nula
  descartados; os `*_score` são soma exata dos `in_*` (report usa
  `redundantes = "remover"`).
- `integer64` vira número **só** onde o cálculo exige (k-NN, PCA); a saída
  das funções de acesso mantém o tipo do banco (#16 segue valendo).
- ~~Testes rodam só no container `rstudio.dev` como `rsuser`~~ —
  **revisto em 2026-10-09**: a regra existia por causa do laptop anterior
  (CPU fraca). No host atual, `ubaxala` (12 núcleos, 15 GB), os testes,
  o smoke e o `check` rodam **localmente** (ambiente completo: dbplyr
  2.6.0, `ellmer` 0.5.0, `qpdf`). O container fica opcional, para conferir
  a compatibilidade com o dbplyr 2.5.0 do RStudio Server.

## 2026-10-08 — camada `ellmer` (plano em `plans/ellmer-tools.md`)

- **Runtime**: `chat_anthropic()` no container; a chave
  (`ANTHROPIC_API_KEY`) é configurada pelo dono do repo no ambiente do
  `rsuser`, nunca no código. `ellmer` 0.5.0 existia só no container
  (instalado também no `ubaxala` em 2026-10-09).
- **Handles na sessão** para encadear objetos R (dados, espec, regressão,
  floresta): o LLM recebe ids, não objetos; somem ao fim da sessão.
- **Ledger** persistido (quando pedido) em
  `tools::R_user_dir("eduBR", "data")`, não em `inst/`.
- **PII**: gestor/docentes são só contagens (sem nome/CPF); endereço,
  telefone, CEP e CNPJ de `censo_escolas`/`escolas` ficam **ocultos** nas
  tools por padrão.
- Tools devolvem `integer64` como **string** (fronteira JSON), sem mudar o
  tipo nas funções do pacote; `etapa` usa os valores do pacote
  (`ensino_medio`, não `medio`).

## 2026-10-08 — versões divergentes entre máquina local e container

- O container `rstudio.dev` tem **dbplyr 2.5.0**; a máquina local, 2.6.0.
  `n_distinct(x, na.rm = TRUE)` traduz no 2.6 e **quebra** no 2.5
  (`unused argument`): `perfil_escola()` ficou quebrada no container de
  #30 até o chunk 2 da camada ellmer, sem ninguém ver, porque a validação
  era local.
- **Lição**: validar sempre no container (`tools/test-container.sh`, com
  `--smoke` quando a mudança toca SQL); não confiar em execução local.

## 2026-10-08 — provedores de LLM: Anthropic **e** Ollama

- Revisão da decisão de runtime: `chat_edubr()` aceita `"anthropic"`
  (chave só em `ANTHROPIC_API_KEY`) e `"ollama"` (`OLLAMA_BASE_URL`,
  padrão `http://localhost:11434`; modelo padrão `qwen3.5:9b`).
- O Ollama roda na máquina do dono do repo; o container o alcança por
  **túnel SSH reverso** (`tools/tunnel-ollama.sh abrir|status|fechar`) — a
  porta 11434 não é acessível direto da rede do container.
- **Gemini** (2026-10-10): terceiro provedor em `chat_edubr("gemini")`, via
  `ellmer::chat_google_gemini()` (padrão do ellmer: `gemini-3.7-flash`). A
  chave vem só de `GEMINI_API_KEY`/`GOOGLE_API_KEY` no ambiente; sem ela,
  erro, para não cair nas credenciais do Google Cloud nem no login pelo
  navegador. Escolha automática: Anthropic > Gemini > Ollama.
  `raciocinio = "desligado"` não muda nada no Gemini (ajuste por
  `params(reasoning_effort = )`, que o ellmer traduz em `thinkingLevel`).
  Aceite: smoke ok ("16" em 11,9 s); taxa N = 2 com ML 2/2, mas gestora e
  pesquisadora pararam na cota gratuita (20 requisições/dia no
  `gemini-3.7-flash`, HTTP 429). Medir de novo com cota paga.
- **HTTP 429 em PT-BR** (#105): o ellmer não tem gancho para erro de
  requisição (`on_request_end` não dispara em erro) e os métodos do R6 são
  travados. Por isso `chat_edubr()` devolve uma subclasse `EduBRChat` de
  `ellmer::Chat` (recriada com o mesmo provedor, modelo e prompt), em que
  `$chat()`/`$chat_structured()` traduzem `httr2_http_429` em
  `eduBR_cota_esgotada` (erro original como causa). `$stream()` e os
  assíncronos não traduzem. A cota da chave gratuita do Gemini vale para
  o projeto todo, não por modelo.
- Smoke com LLM real: `tools/test-container.sh --llm ollama|anthropic`
  (Ollama com túnel aberto). Primeiro resultado: `qwen3.5:9b` chamou
  `catalogo` e respondeu "16" em ~19 s.

## 2026-10-09 — chunk 7: aceite com chat real, vignette e docs

- **Aceite** (`qwen3.5:9b` via Ollama + túnel; transcrições em
  `docs/aceite-ellmer/`, script `tools/aceite-ellmer.R`): gestora
  (`perfil_escola`, `escolas_similares`), pesquisadora (`covariaveis_escola`
  → `especificar_regressao` → `executar_regressao` → `coeficientes`) e ML
  (`features_escola` → `classificar_desempenho` → `dividir_dados` →
  `treinar_floresta` → `metricas_floresta`) encadeiam as tools com
  argumentos escolhidos pelo modelo. Números das tabelas conferem com as
  tools; a prosa do 9B erra contas derivadas (denominadores inventados,
  "ganho de 27%" em vez de 0,27 ponto, conselhos fora dos dados). Todos
  "atende com ressalvas". **Anthropic não testada**: conta sem créditos
  (HTTP 400 "credit balance is too low").
- **Bugs da camada achados pelo aceite** (corrigidos com teste): o aviso de
  `covariaveis_escola` mandava usar o handle como `dados` em
  `executar_regressao` (argumento inexistente); o ellmer converte
  `type_array(type_enum())` em **fator**, e `features_escola` recusava
  `etapa = ["fundamental_ii"]`. A prévia de covariáveis agora traz a
  contagem de escolas com IDEB (a prévia de 10 linhas vem toda nula e o
  modelo desviava para a tool `ideb`).
- **Lição — o modelo segue o `aviso` ao pé da letra**: o texto de
  "próximo passo" de cada tool precisa nomear a tool e o argumento certos.
- **Lição — janela do Ollama**: 16k tokens (`OLLAMA_CONTEXT_LENGTH`); o
  prompt + 14 tools da pesquisadora já ocupam ~8,5k. Prévias largas
  estouram a janela e o modelo "esquece" a pergunta.
- **Lição — raciocínio do qwen3.5**: com *thinking*, turnos terminam só
  com raciocínio (resposta vazia) e o chat seguinte falha com HTTP 400
  `invalid message content type: <nil>`; o fluxo de ML só completou com
  `api_args = list(reasoning_effort = "none")`. Não mudamos o padrão de
  `chat_edubr()` (a regressão da pesquisadora foi melhor com raciocínio).
- **Check com vignette**: `qpdf` instalado no container (apt) para o
  `--as-cran`; NOTE "unable to verify current time" é ambiental (APIs de
  hora inacessíveis do container).
- `AGENTS.md` corrigido: testes só no container (`tools/test-container.sh`).

## 2026-10-09 — `qpdf` no container

- O container `rstudio.dev` tem `qpdf` (apt, instalado em 2026-10-09 durante
  o chunk 7 da camada ellmer). Sem ele o `check` com vignette dá o warning
  "'qpdf' is needed". **Decisão do dono do repo: manter.**

## 2026-10-09 — limite de repetições com o Ollama

- O Ollama roda no laptop do dono do repo: uma medição com N = 5 levou a
  temperatura a nível crítico e foi interrompida. **Máximo N = 2** por
  cenário (`tools/taxa-sucesso-ellmer.R` recusa N > 2); ao terminar,
  descarregar o modelo (`keep_alive = 0`).
- Taxa parcial (docs/aceite-ellmer/taxa-sucesso.md): gestora 6/6,
  pesquisadora 1/4 (cadeia completa 4/4; falha por chamada com erro
  autocorrigida ou número ausente), ML 1/1.

## 2026-10-09 — aceite com Anthropic

- A conta Anthropic ganhou créditos: `--llm anthropic` verde (5,5 s) e os
  3 cenários 2/2 com `claude-sonnet-5` (taxa e transcrições em
  `docs/aceite-ellmer/`). Fecha #73.
- Redação solta (#83) só aparece no modelo local de 9B: prompts mantidos.
- Testes com Anthropic não aquecem o laptop, mas custam: manter N ≤ 2.
