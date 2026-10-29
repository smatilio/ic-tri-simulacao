# Parametros do estudo de simulacao. Todos os scripts leem daqui: para rodar
# outro cenario, altere somente este arquivo.
config <- list(
  seed = 15,

  # Desenho da simulacao
  n_ind    = 1000,   # individuos
  n_itens  = 30,     # itens
  p_uso    = 0.9,    # proporcao de individuos que usam a maquina
  delta_hm = 0.5,    # efeito humano-maquina
  delta_h  = 0.1,    # efeito humano (comum a todos)

  # Amostrador do Stan (as cadeias rodam em paralelo)
  stan = list(
    chains        = 4,
    iter_warmup   = 1000,
    iter_sampling = 1000
  )
)
