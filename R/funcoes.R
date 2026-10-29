# Funcoes usadas nos scripts


# Simulacao ------------------------------------------------------------------

# Probabilidade de acerto no 2PL: P = logit^-1(a * (theta - b))
calcular_p <- function(theta, a, b) {
  eta <- sweep(outer(a, theta, "*"), MARGIN = 1, STATS = a * b, FUN = "-")
  plogis(eta)   # itens x individuos
}

# Sorteia as respostas 0/1 (individuos x itens)
simular_x <- function(p) {
  t(matrix(rbinom(length(p), 1, as.vector(p)),
           nrow = nrow(p), ncol = ncol(p)))
}

# Gera os parametros verdadeiros e as respostas nos tempos 0, 1 e 2.
# Obs: nao mudar a ordem dos sorteios, senao a mesma seed gera outros dados.
simular_dados <- function(n_ind, n_itens, p_uso, delta_hm, delta_h, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Parametros verdadeiros
  theta_0 <- rnorm(n_ind)
  it      <- rbinom(n_ind, 1, p_uso)     # 1 = usa a maquina
  phi     <- runif(n_ind, -1, 1)         # phi verdadeiro, sem multiplicar por it
  a       <- rlnorm(n_itens, 0, 0.18)
  b       <- rnorm(n_itens, 0, 1)

  # Tempo 0
  x_0 <- simular_x(calcular_p(theta_0, a, b))

  # Tempo 1
  theta_1 <- theta_0 + delta_hm * it * phi + delta_h
  x_1 <- simular_x(calcular_p(theta_1, a, b))

  # Tempo 2
  theta_2 <- theta_1 + delta_hm * it * phi^2 + delta_h
  x_2 <- simular_x(calcular_p(theta_2, a, b))

  verdadeiros <- list(theta_0 = theta_0, theta_1 = theta_1, theta_2 = theta_2,
                      it = it, phi = phi, a = a, b = b,
                      delta_hm = delta_hm, delta_h = delta_h)
  dados_stan <- list(N = n_ind, J = n_itens, X0 = x_0, X1 = x_1, X2 = x_2, I = it)
  list(verdadeiros = verdadeiros, dados_stan = dados_stan)
}


# Recuperacao ----------------------------------------------------------------

# Correlacao, vies e RMSE entre verdadeiro e estimado
avaliar_recuperacao <- function(verdadeiro, estimado) {
  c(correlacao = cor(verdadeiro, estimado),
    vies = mean(estimado - verdadeiro),
    RMSE = sqrt(mean((estimado - verdadeiro)^2)))
}

# Proporcao dos valores verdadeiros dentro do IC de 90% (q5 e q95 do summary)
cobertura <- function(verdadeiro, resumo)
  mean(verdadeiro >= resumo$q5 & verdadeiro <= resumo$q95)
