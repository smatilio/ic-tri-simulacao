rm(list = ls())
source("R/config.R")
source("R/funcoes.R")

# 1. Simular os dados (parametros em R/config.R, funcao em R/funcoes.R)
sim <- simular_dados(
  n_ind    = config$n_ind,
  n_itens  = config$n_itens,
  p_uso    = config$p_uso,
  delta_hm = config$delta_hm,
  delta_h  = config$delta_h,
  seed     = config$seed
)
verd  <- sim$verdadeiros
dados <- sim$dados_stan

# 2. Verificacoes
stopifnot(all(dim(dados$X0) == c(config$n_ind, config$n_itens)),
          all(dim(dados$X1) == c(config$n_ind, config$n_itens)),
          all(dim(dados$X2) == c(config$n_ind, config$n_itens)))

mean(verd$it)                                        # perto de config$p_uso
c(mean(dados$X0), mean(dados$X1), mean(dados$X2))    # proporcao de acertos por tempo
tapply(verd$theta_1 - verd$theta_0, verd$it, mean)   # ganho medio no tempo 1, por grupo
tapply(verd$theta_2 - verd$theta_0, verd$it, mean)   # ganho medio no tempo 2, por grupo
cor(rowMeans(dados$X0), verd$theta_0)                # escore bruto deve ser bem correlacionado com theta

# 3. Graficos
cores <- ifelse(verd$it == 1, "blue", "red")
plot(verd$theta_0, verd$theta_1, col = cores, pch = 16, cex = 0.5,
     xlab = "Habilidade no tempo 0", ylab = "Habilidade no tempo 1")
abline(0, 1)
plot(verd$theta_0, verd$theta_2, col = cores, pch = 16, cex = 0.5,
     xlab = "Habilidade no tempo 0", ylab = "Habilidade no tempo 2")
abline(0, 1)

# 4. Salvar
saveRDS(sim, "output/simulacao.rds")
