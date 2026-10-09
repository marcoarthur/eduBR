# R/ellmer_tools_composta.R
#
# Tool composta de regressão: faz numa chamada o caminho
# covariaveis_escola -> especificar_regressao -> executar_regressao ->
# coeficientes/metricas. Modelos pequenos (ex.: qwen3.5:9b) se perdem em
# cadeias de 4 tools (curadoria de 2026-10-09, #81); as tools separadas
# continuam disponíveis para quem quiser o passo a passo.

# Função interna de uma tool do eduBR, sem o wrapper (sem envelope, ledger
# ou orçamento próprios): a tool composta chama as etapas direto, na mesma
# sessão. Depende de eduBR_tool_wrapper() guardar `fun` no seu ambiente.
eduBR_tool_funcao <- function(sessao, construtor) {
  get("fun", envir = environment(construtor(sessao)), inherits = FALSE)
}

eduBR_tool_regressao_escolas <- function(sessao) {
  f_cov <- eduBR_tool_funcao(sessao, eduBR_tool_covariaveis_escola)
  f_esp <- eduBR_tool_funcao(sessao, eduBR_tool_especificar_regressao)
  f_exe <- eduBR_tool_funcao(sessao, eduBR_tool_executar_regressao)
  f_coef <- eduBR_tool_funcao(sessao, eduBR_tool_coeficientes)
  f_met <- eduBR_tool_funcao(sessao, eduBR_tool_metricas)

  fun <- function(outcome, predictors, cuts = NULL, uf = NULL, rede = NULL,
                  ano = NULL, ano_ideb = NULL, ativas = NULL,
                  modelo = "linear") {
    cv <- f_cov(uf = uf, rede = rede, ano = ano %||% 2025L,
                ano_ideb = ano_ideb %||% 2023L, ativas = ativas, n = 1L)
    es <- f_esp(outcome = outcome, predictors = predictors, cuts = cuts,
                modelo = modelo, dados_id = cv$handle)
    ex <- f_exe(espec_id = es$handle)
    co <- f_coef(regressao_id = ex$handle)
    me <- f_met(regressao_id = ex$handle)
    eduBR_resultado(
      co$dados,
      grao = co$grao,
      filtros = list(outcome = outcome, predictors = predictors, cuts = cuts,
                     uf = uf, rede = rede, ano = ano, ano_ideb = ano_ideb,
                     modelo = modelo),
      handle = ex$handle,
      aviso = ex$aviso,
      n_padrao = 200L,
      contexto = list(
        formula = ex$contexto$formula,
        modelo = ex$contexto$modelo,
        n_recorte = ex$contexto$n_recorte,
        n_usado = ex$contexto$n_usado,
        cortes = eduBR_registros(ex$dados),
        metricas = eduBR_registros(me$dados),
        dados_id = cv$handle,
        espec_id = es$handle,
        regressao_id = ex$handle
      )
    )
  }
  eduBR_tool(
    sessao, "regressao_escolas", fun,
    descricao = paste0(
      "Regress\u00e3o por escola em UMA chamada (prefira esta ferramenta): monta a ",
      "base escola \u00d7 covari\u00e1veis do recorte (`uf`, `rede`, Censo 2025, ",
      "IDEB 2023, s\u00f3 escolas em atividade), ajusta o desfecho contra os ",
      "preditores para cada combina\u00e7\u00e3o de `cuts` e devolve os COEFICIENTES ",
      "(`dados`: cortes, `termo`, `estimativa`, `erro_padrao`, `p_valor`) e, em ",
      "`metadados.contexto`, as M\u00c9TRICAS por corte (`n`, `r2`, `r2_ajustado`; ",
      "no log\u00edstico `auc`, `mcfadden`), `n_recorte` e `n_usado`. Desfechos: ",
      "`ideb_fund_i`, `ideb_fund_ii`, `ideb_medio` (linear) ou um `in_*` 0/1 ",
      "(log\u00edstico). Preditores t\u00edpicos: `in_biblioteca`, `in_internet`, ",
      "`in_laboratorio_informatica`, `docentes`, `matriculas`. Cortes: ",
      "`localizacao`, `rede`. Escolas sem IDEB s\u00e3o descartadas (avisado). ",
      "Leitura: associa\u00e7\u00e3o, n\u00e3o causalidade; cite a estimativa, o ",
      "p-valor e o `n` de cada corte. Os handles ficam em `contexto` para ",
      "`coeficientes`/`metricas` se precisar de mais detalhes."
    ),
    arguments = list(
      outcome = ellmer::type_string(
        "Desfecho (ex.: \"ideb_fund_i\")."
      ),
      predictors = ellmer::type_array(
        ellmer::type_string("Coluna preditora."),
        "Preditores (ex.: [\"in_biblioteca\", \"docentes\"])."
      ),
      cuts = ellmer::type_array(
        ellmer::type_string("Coluna de corte."),
        "Cortes opcionais (ex.: [\"localizacao\"]): um modelo por valor.",
        required = FALSE
      ),
      uf = eduBR_arg_uf(),
      rede = eduBR_arg_rede(publica = TRUE),
      ano = ellmer::type_integer(
        "Ano do Censo (padr\u00e3o 2025).", required = FALSE
      ),
      ano_ideb = ellmer::type_integer(
        "Edi\u00e7\u00e3o do IDEB (padr\u00e3o 2023).", required = FALSE
      ),
      ativas = ellmer::type_boolean(
        "S\u00f3 escolas em atividade? Padr\u00e3o true.", required = FALSE
      ),
      modelo = ellmer::type_enum(
        eduBR_modelos_regressao(),
        "linear (padr\u00e3o) ou logistico (desfecho 0/1).",
        required = FALSE
      )
    ),
    titulo = "Regress\u00e3o por escola (uma chamada)"
  )
}
