# Skill: postgres-postgis

## Purpose
Auxiliar na leitura do schema PostgreSQL/PostGIS que o pacote **eduBR**
acessa, para inspeção e para bater com as relações do catálogo.

## Conexão

```bash
PGPASSWORD=senhaboa123 psql -h ubatexu.lan -U devel -d edumaps_dev
```

Sqitch target: `dev_super`. No pacote, a conexão vem de
`~/.pg_service.conf` via `conecta(service = "edumaps")` — as credenciais
acima são só para inspeção manual.

## Schemas

- `clean.*` — views limpas com dados do INEP, Censo, IBGE e OSM.
- `analytics.*` — MVs agregadas (ranking, rede escolar, clusters,
  similaridade).
- `staging.*` — tabelas temporárias dos jobs de análise R.
- `public.*` — funções utilitárias, event_store.

## Relações usadas pelo catálogo do eduBR

| domínio | schema.tabela | tipo |
|---|---|---|
| `escolas` | `clean.escolas` | tabela/view |
| `municipios` | `clean.municipios_sp` | view |
| `ibge` | `clean.dados_ibge` | tabela |
| `populacao` | `clean.populacao_municipal` | tabela |
| `redes` | `analytics.mv_rede_escolas` | matview |
| `indicadores` | `analytics.ranking_escola` | tabela (vazia em dev) |
| `scores` | `clean.mv_escolas_scores` | matview |
| `censo_escolas` | `clean.censo_escolas` | tabela (~214 mil linhas) |
| `censo_docentes` | `clean.censo_docentes` | tabela |
| `censo_matriculas` | `clean.censo_matriculas` | tabela |
| `ideb` | `clean.ideb_notas_escolas` | tabela (~814 mil linhas) |
| `clusters` | `analytics.clustering_metadata` | tabela |
| `similaridade` | `analytics.municipio_similaridade` | tabela (vazia em dev) |

## Chaves e tipos (atenção aos mistos)

- `clean.escolas.codigo_inep` → `bigint`.
- `clean.municipios_sp.codigo_ibge` → `varchar`.
- `analytics.ranking_escola.id_escola` / `clean.ideb_notas_escolas.id_escola`
  → conforme a relação.
- `school_indicators.co_entidade` / `clean.censo_*.co_entidade` → `bigint`.
- `clean.censo_*.nu_ano_censo` → `integer`.
- Não há `co_municipio` em `clean.escolas`; ele existe em
  `clean.school_indicators`. Por isso o join escola→município hoje é por
  **nome** (lacuna registrada na curadoria).

## Filtros frequentes

```sql
-- Rede administrativa
-- tp_dependencia = 1 (Federal), 2 (Estadual), 3 (Municipal), 4 (Privada)
-- tp_localizacao = 1 (Urbana), 2 (Rural)
-- IDEB: ideb_fund_i, ideb_fund_ii, ideb_medio, ano_ideb
-- Anos do censo: nu_ano_censo IN (2020,2021,2022,2023,2024,2025)
```

## Materialized Views

```sql
-- Deploy:  CREATE MATERIALIZED VIEW analytics.mv_foo AS SELECT ...;
-- Refresh: CREATE OR REPLACE FUNCTION analytics.refresh_foo() ... REFRESH ...
-- Index:   CREATE UNIQUE INDEX ON analytics.mv_foo (col1, col2);
-- Verify:  COUNT(*) em pg_matviews + pg_proc

-- Verificar MVs:
SELECT matviewname, ispopulated FROM pg_matviews
WHERE schemaname IN ('clean','analytics');

-- Contar registros:
SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables
WHERE schemaname IN ('clean','analytics') ORDER BY n_live_tup DESC LIMIT 20;
```

## PostGIS / GeoJSON

```sql
-- Coluna geometry: SRID 4674 (SIRGAS 2000). O eduBR a devolve como
-- pq_geometry (WKB cru); não há as_sf() ainda (lacuna da curadoria).
SELECT ST_AsGeoJSON(geometry)::json FROM clean.escolas WHERE ...;

-- Em json_build_object, qualifique colunas com alias (ex.: me.coluna)
-- para evitar ambiguidade em JOINs (coluna 'municipio' vs alias).
```

## Encoding

- Dados limpos: valores capitalizados (Estadual/Federal/Municipal/Privada).
- Double-encoding em coluna `text`:
  `SELECT convert_from(convert_to(col, 'LATIN1'), 'UTF8') FROM ...;`
