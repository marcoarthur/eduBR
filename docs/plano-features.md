# Plano de features futuras

> Backlog grande destacado nas rodadas de curadoria (`docs/personas/`),
> detalhado para implementação futura. Itens pequenos já entregues não
> aparecem aqui. Ordem sugerida no fim.

## F1 — `as_sf()` / suporte PostGIS

- **Origem**: pesquisadora P4 (lacuna, [alta]), 1ª–3ª rodadas.
- **Objetivo**: devolver a geometria (SRID 4674) como `sf`, permitindo mapa
  regional direto a partir de `escolas()`/`municipios()`/`censo_escolar()`.
- **Desenho**: genérico `as_sf(x)` com método `as_sf.eduBR()`: coleta o
  necessário (via `coletar()`, respeitando filtros/`colunas=`) e converte a
  coluna `geometry` (WKB cru, hoje `pq_geometry`) com `sf::st_as_sfc()`.
  `sf` em `Suggests` (nunca em `Imports`); sem `sf`, erro PT-BR orientando
  a instalação.
- **Aceite**: `escolas(con, uf = "SP") |> as_sf()` plota com `ggplot2::geom_sf()`.
- **Riscos**: dependência de sistema do `sf` (GDAL/GEOS/PROJ) — checar
  `devtools::check()` 0/0/0 e disponibilidade no container `rstudio.dev`.
- **Esforço**: médio.

## F2 — `perfil_escola()` / `comparar()`

- **Origem**: gestora G2 (lacuna, [alta]); ML M5-follow-up ([média], quer
  covariáveis além do modelo bivariado).
- **Objetivo**: "foto" de uma escola vs médias do município/estado —
  infraestrutura (flags `in_*` de `censo_escolas`), IDEB e perfil docente.
- **Desenho**: `perfil_escola(con, codigo_inep)` devolve lista
  (`escola`, `media_municipio`, `media_estado`); `comparar()` formata o
  resumo legível em PT-BR (aproveita para G4). Agregações no banco; lado
  município por **código** via `censo_escolas.co_municipio` (não pelo nome
  — restrição P1). Rótulos via `dicionario()` (+ F7 `rotular()`).
- **Aceite**: gestora vê a escola, a posição relativa e entende sem R.
- **Riscos**: definir o conjunto de médias (muitas flags); NA do IDEB por
  município × rede (usar a cobertura da EDA `rede_professor`).
- **Esforço**: médio. **Depende de**: F7 (`rotular()`).

## F3 — `escolas_similares()` (benchmark escolar)

- **Origem**: gestora G3 (lacuna, [média]); tech-lead aponta PgVector.
- **Objetivo**: "quais escolas são parecidas com a minha?".
- **Desenho em fases**: fase 1 — k-NN em R sobre `analytics.escola_features`
  (já existe, ~77 features), distância padronizada, sem dependência nova;
  fase 2 — similaridade vetorial no banco (PgVector), quando o pipeline
  EduMaps oferecer.
- **Aceite**: `escolas_similares(con, codigo_inep, n = 5)` devolve vizinhas
  com distância e critérios.
- **Riscos**: `municipio_similaridade` está vazia em dev — não reaproveitar
  sem dados; fase 1 precisa de recorte (UF/rede) para não coletar tudo.
- **Esforço**: médio (fase 1); grande (fase 2, envolve outro repo).

## F4 — origem e recálculo dos `scores()`

- **Origem**: ML M3 ([média]).
- **Objetivo**: documentar a fórmula/carga de `clean.mv_escolas_scores` e,
  se viável, oferecer recálculo.
- **Desenho**: descobrir o job SQL no repo EduMaps; documentar no Rd de
  `scores()`; avaliar `recalcular_scores()` apenas se a fórmula for
  determinística a partir de tabelas versionadas.
- **Aceite**: Rd conta de onde vem cada score; ou função de recálculo com teste.
- **Riscos**: depende de artefato de outro repo; pode virar só-docs.
- **Esforço**: pequeno–médio. **Bloqueio parcial**: repo EduMaps.

## F5 — métricas do modo logístico (AUC, McFadden)

- **Origem**: ML M16 ([média]).
- **Objetivo**: `metricas()` ganhar `auc` e `mcfadden` no modo logístico.
- **Desenho**: em `R/saida.R`, AUC pelo método de postos (sem dependência,
  como já faz `metricas_floresta()` com `auc_macro`) e pseudo-R² de
  McFadden a partir do `glm` (`1 - deviance/null.deviance`). Testes com
  fixture determinística.
- **Aceite**: `metricas()` em spec logística traz `auc` + `mcfadden`.
- **Esforço**: pequeno. **Depende de**: nada.

## F6 — `ler_especs()` (YAML multi-análise)

- **Origem**: ML 4ª rodada ([média]).
- **Objetivo**: ler um YAML com lista `analises:` → lista nomeada de specs.
- **Desenho**: em `R/espec.R`, reaproveita `ler_espec()` por item; nomes via
  `id` ou `analise_<i>`; erro PT-BR quando faltar `analises:`. Segue o
  exemplo `analysis/regressoes_censo.yaml`.
- **Aceite**: teste com YAML de 2+ análises gerando 2 specs executáveis.
- **Esforço**: pequeno. **Depende de**: nada.

## F7 — `rotular()` + dicionário de tipos/ano

- **Origem**: ML M2 ([alta] rótulos — entregue via `dicionario()`); tipos/ano
  seguem [média] (pesquisadora P2).
- **Objetivo**: aplicar rótulos pós-`collect` e expor tipos/ano por relação.
- **Desenho**: `rotular(df, ...)` mapeia códigos→rótulo usando `dicionario()`;
  estender o dicionário com `tipo`/`ano_referencia` por domínio do catálogo
  (tabela estática em `R/dicionario.R`, sem query).
- **Aceite**: `rotular()` cobre as 3 variáveis do dicionário; doc lista
  tipo/ano das relações do catálogo.
- **Esforço**: pequeno. **Depende de**: `dicionario()` (pronto).

## F8 — `registrar_relacao()` (extensão do catálogo)

- **Origem**: ML M4 ([média]).
- **Objetivo**: registrar domínio → `schema.tabela` sem reescrever o pacote.
- **Desenho**: registro em sessão (env interno ou `options()`), com validação
  (esquema/tabela existem? via `DBI::dbExistsTable`) e precedência
  documentada sobre `eduBR_catalogo()`; erro PT-BR em conflito/nome
  inválido. Testes sem banco (mock de `eduBR_tbl`).
- **Aceite**: relação customizada acessível via objeto eduBR com filtros lazy.
- **Riscos**:(Name)space de nomes e precedência precisam de decisão explícita.
- **Esforço**: pequeno–médio. **Depende de**: nada.

## F9 — painel INSE × IDEB temporal

- **Origem**: ML M9/M11 ([média]).
- **Objetivo**: prever `ideb_t` com `inse_{t-1}` (hoje só há INSE 2023).
- **Desenho**: código (`ideb_inse()` parametrizado por anos) é o menor
  pedaço; o grosso é **carga de SAEBs anteriores** no pipeline.
- **Aceite**: `regressao_inse()` com `ano_base`/`ano_alvo` + report.
- **Riscos**: **bloqueado por dados** (repo EduMaps/pipeline).
- **Esforço**: grande (fora deste repo, na prática).

## F10 — avisos em `ideb_inse()` (contemporaneidade e 1:n)

- **Origem**: ML M11/M12 ([baixa]).
- **Objetivo**: avisar associação contemporânea e cardinalidade 1:n por etapa.
- **Desenho**: `message()`/`warning()` PT-BR em `ideb_inse()` + seção no Rd;
  sem mudança de comportamento.
- **Aceite**: teste de snapshot da mensagem.
- **Esforço**: mínimo. **Depende de**: nada.

## F11 — normalizar `integer64`

- **Origem**: ML M8 ([baixa]; documentado no Rd).
- **Objetivo**: decidir se `as_tibble.eduBR()` coage `integer64`→`numeric`.
- **Desenho**: exige decisão (coerção silenciosa esconde precisão do banco;
  alternativa é manter + documentar, estado atual). Se coagir: só colunas
  de contagem, com teste de precisão até 2^53.
- **Aceite**: decisão registrada aqui; se implementado, teste sem banco.
- **Esforço**: mínimo–pequeno. **Depende de**: decisão explícita.

## Ordem sugerida

1. Quick wins: F5, F6, F10, F7 (semanas, sem dependências).
2. Médio: F8, F4, F2 (após F7), F3-fase 1.
3. Pesado/externo: F1 (checar `sf` no container primeiro), F9 (dados),
   F3-fase 2 (PgVector), F11 (após decisão).
