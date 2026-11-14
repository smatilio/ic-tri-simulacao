# Parametros da simulacao
#
# Troque `cenario` para testar mais pessoas e mais itens (pedido do prof).
# "base" reproduz o README: 1000 pessoas e 30 itens.

cenario <- "base"

cenarios <- list(
  base   = list(n_ind = 1000, n_itens = 30),
  medio  = list(n_ind = 2000, n_itens = 50),
  grande = list(n_ind = 4000, n_itens = 80)
)

if (!cenario %in% names(cenarios)) {
  stop("cenario desconhecido. Use: ", paste(names(cenarios), collapse = ", "))
}

config <- list(
  seed    = 15,
  cenario = cenario,

  n_ind    = cenarios[[cenario]]$n_ind,
  n_itens  = cenarios[[cenario]]$n_itens,
  p_uso    = 0.9,    # proporcao de individuos que usam a maquina
  delta_hm = 0.5,    # efeito humano-maquina
  delta_h  = 0.1,    # efeito humano (comum a todos)

  # Stan: o ajuste e a parte lenta.
  # ITER_WARMUP / ITER_SAMPLING no ambiente permitem um teste curto (ex.: 250).
  stan = list(
    modelo            = "stan/modelo_tri.stan",
    chains            = 4,
    iter_warmup       = as.integer(Sys.getenv("ITER_WARMUP", "1000")),
    iter_sampling     = as.integer(Sys.getenv("ITER_SAMPLING", "1000")),
    threads_per_chain = 1,    # 1 = sem paralelismo dentro da cadeia; NA = nucleos fisicos / cadeias
    usar_init_mirt    = TRUE, # comeca o Stan perto da solucao do mirt (tempo 0)
    salvar_fit        = TRUE
  )
)
