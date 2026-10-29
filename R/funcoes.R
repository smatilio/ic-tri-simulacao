# Funcoes usadas pelos scripts do estudo de simulacao.
# Carregue com source("R/funcoes.R") a partir da raiz do projeto.


# Simulacao ------------------------------------------------------------------

# Probabilidades de acerto no modelo 2PL, P = logit^-1(a * (theta - b)).
# Devolve uma matriz itens x individuos.
calcular_p <- function(theta, a, b) {
  eta <- sweep(outer(a, theta, "*"), MARGIN = 1, STATS = a * b, FUN = "-")
  plogis(eta)   # itens x individuos
}

# Sorteia as respostas 0/1 a partir das probabilidades de calcular_p().
# Devolve uma matriz individuos x itens.
simular_x <- function(p) {
  t(matrix(rbinom(length(p), 1, as.vector(p)),
           nrow = nrow(p), ncol = ncol(p)))
}

# Gera um conjunto de dados completo: parametros verdadeiros e respostas nos
# tempos 0, 1 e 2. Nao salva arquivos nem faz graficos, entao pode ser chamada
# varias vezes (replicas, cenarios diferentes).
#
# Atencao: a ordem dos sorteios abaixo define os dados gerados por uma seed.
# Mudar essa ordem muda os dados, mesmo com a mesma seed.
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

# Correlacao, vies e RMSE entre os valores verdadeiros e os estimados.
avaliar_recuperacao <- function(verdadeiro, estimado) {
  c(correlacao = cor(verdadeiro, estimado),
    vies = mean(estimado - verdadeiro),
    RMSE = sqrt(mean((estimado - verdadeiro)^2)))
}

# Proporcao de valores verdadeiros dentro do intervalo de credibilidade de 90%.
# `resumo` e a saida de fit$summary(), que tem as colunas q5 e q95.
cobertura <- function(verdadeiro, resumo)
  mean(verdadeiro >= resumo$q5 & verdadeiro <= resumo$q95)
