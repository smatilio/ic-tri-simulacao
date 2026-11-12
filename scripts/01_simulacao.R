rm(list = ls())
source("R/config.R")
source("R/funcoes.R")

# Cada simulacao tem sua pasta em output/, com o nome tirado do config
pasta <- pasta_simulacao(config)
if (dir.exists(pasta)) stop("A simulacao ", basename(pasta), " ja existe. Mude algum valor no config.R ou apague a pasta.")

# Simulacao
sim <- simular_dados(
  n_ind    = config$n_ind,
  n_itens  = config$n_itens,
  p_uso    = config$p_uso,
  delta_hm = config$delta_hm,
  delta_h  = config$delta_h,
  phi_max  = config$phi_max,
  seed     = config$seed
)
verd  <- sim$verdadeiros
dados <- sim$dados_stan

# Conferindo
stopifnot(all(dim(dados$X0) == c(config$n_ind, config$n_itens)),
          all(dim(dados$X1) == c(config$n_ind, config$n_itens)),
          all(dim(dados$X2) == c(config$n_ind, config$n_itens)))

mean(verd$it)                                        # perto de config$p_uso
c(mean(dados$X0), mean(dados$X1), mean(dados$X2))    # proporcao de acertos por tempo
tapply(verd$theta_1 - verd$theta_0, verd$it, mean)   # ganho medio no tempo 1, por grupo
tapply(verd$theta_2 - verd$theta_0, verd$it, mean)   # ganho medio no tempo 2, por grupo
cor(rowMeans(dados$X0), verd$theta_0)                # escore bruto x theta, tem que dar alta

# Graficos
cores <- ifelse(verd$it == 1, "blue", "red")
plot(verd$theta_0, verd$theta_1, col = cores, pch = 16, cex = 0.5,
     xlab = "Habilidade no tempo 0", ylab = "Habilidade no tempo 1")
abline(0, 1)
plot(verd$theta_0, verd$theta_2, col = cores, pch = 16, cex = 0.5,
     xlab = "Habilidade no tempo 0", ylab = "Habilidade no tempo 2")
abline(0, 1)

# Salvando
dir.create(pasta, recursive = TRUE)
saveRDS(sim, file.path(pasta, "simulacao.rds"))
write.csv2(dados_em_tabela(sim), file.path(pasta, "dados_simulados.csv"), row.names = FALSE)   # para abrir no Excel
salvar_info(config, pasta)                           # valores usados, data e commit
