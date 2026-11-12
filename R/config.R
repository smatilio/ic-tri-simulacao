# Parametros da simulacao
config <- list(
  seed = 15,

  # Cenario
  n_ind    = 1000,   # individuos
  n_itens  = 30,     # itens
  p_uso    = 0.9,    # proporcao de individuos que usam a maquina
  delta_hm = 0.5,    # efeito humano-maquina
  delta_h  = 0.1,    # efeito humano (comum a todos)
  phi_max  = 1,      # phi ~ U(-phi_max, phi_max)

  # Vai no fim do nome da pasta, para quando muda o codigo e nao os valores
  rotulo = "",

  # Stan
  stan = list(
    chains        = 4,
    iter_warmup   = 1000,
    iter_sampling = 1000
  )
)
