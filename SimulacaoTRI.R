rm(list = ls())
set.seed(15)

# 1. Dimensoes do experimento
ind   <- 1000
itens <- 30

# 2. Geracao dos parametros verdadeiros
theta_0 <- rnorm(ind)
it      <- rbinom(ind, 1, 0.9)       # 1 = usa a maquina

delta_hm <- 0.5
phi      <- runif(ind, -1, 1)        # phi verdadeiro, sem multiplicar por it
delta_h  <- 0.1

a <- rlnorm(itens, 0, 0.18)
b <- rnorm(itens, 0, 1)

calcular_p <- function(theta, a, b) {
  eta <- sweep(outer(a, theta, "*"), MARGIN = 1, STATS = a * b, FUN = "-")
  plogis(eta)   # itens x individuos
}

simular_x <- function(p) {
  t(matrix(rbinom(length(p), 1, as.vector(p)),
           nrow = nrow(p), ncol = ncol(p)))
}

# 3. Tempo 0
x_0 <- simular_x(calcular_p(theta_0, a, b))

# 4. Tempo 1
theta_1 <- theta_0 + delta_hm * it * phi + delta_h
x_1 <- simular_x(calcular_p(theta_1, a, b))

# 5. Tempo 2
theta_2 <- theta_1 + delta_hm * it * phi^2 + delta_h
x_2 <- simular_x(calcular_p(theta_2, a, b))

# 6. Verificacoes
stopifnot(all(dim(x_0) == c(ind, itens)),
          all(dim(x_1) == c(ind, itens)),
          all(dim(x_2) == c(ind, itens)))

mean(it)                                  # perto de 0,9
c(mean(x_0), mean(x_1), mean(x_2))        # proporcao de acertos por tempo
tapply(theta_1 - theta_0, it, mean)       # ganho medio no tempo 1, por grupo
tapply(theta_2 - theta_0, it, mean)       # ganho medio no tempo 2, por grupo
cor(rowMeans(x_0), theta_0)               # escore bruto deve ser bem correlacionado com theta

# 7. Graficos 
cores <- ifelse(it == 1, "blue", "red")
plot(theta_0, theta_1, col = cores, pch = 16, cex = 0.5,
     xlab = "Habilidade no tempo 0", ylab = "Habilidade no tempo 1")
abline(0, 1)
plot(theta_0, theta_2, col = cores, pch = 16, cex = 0.5,
     xlab = "Habilidade no tempo 0", ylab = "Habilidade no tempo 2")
abline(0, 1)

# 8. Salvar
verdadeiros <- list(theta_0 = theta_0, theta_1 = theta_1, theta_2 = theta_2,
                    it = it, phi = phi, a = a, b = b,
                    delta_hm = delta_hm, delta_h = delta_h)
dados_stan <- list(N = ind, J = itens, X0 = x_0, X1 = x_1, X2 = x_2, I = it)
saveRDS(list(verdadeiros = verdadeiros, dados_stan = dados_stan), "simulacao.rds")

