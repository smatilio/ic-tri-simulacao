library(cmdstanr)
source("R/config.R")
source("R/funcoes.R")

sim  <- readRDS("output/simulacao.rds")
dados <- sim$dados_stan
verd  <- sim$verdadeiros

mod <- cmdstan_model("stan/modelo_tri.stan")

fit <- mod$sample(
  data            = dados,
  chains          = config$stan$chains,
  parallel_chains = config$stan$chains,
  iter_warmup     = config$stan$iter_warmup,
  iter_sampling   = config$stan$iter_sampling,
  seed            = config$seed
)

fit$save_object("output/fit_stan.rds")

# 1. Diagnosticos de convergencia
fit$diagnostic_summary()
fit$summary(c("d_hm", "d_h"))      # compara com verd$delta_hm e verd$delta_h

# 2. Recuperacao
theta0_hat <- fit$summary("theta0")$mean       # EAP
a_hat      <- fit$summary("a")$mean
b_hat      <- fit$summary("b")$mean
phi_hat    <- fit$summary("phi")$mean
usa        <- verd$it == 1                     # phi so faz sentido para quem usa

resultado_stan <- rbind(
  theta = avaliar_recuperacao(verd$theta_0, theta0_hat),
  a     = avaliar_recuperacao(verd$a, a_hat),
  b     = avaliar_recuperacao(verd$b, b_hat),
  phi   = avaliar_recuperacao(verd$phi[usa], phi_hat[usa])
)
print(round(resultado_stan, 3))

saveRDS(resultado_stan, "output/resultado_stan.rds")

# 3. Graficos de recuperacao
png("output/recuperacao_stan.png", width = 1200, height = 1000, res = 120)
par(mfrow = c(2, 2))
plot(verd$theta_0, theta0_hat, pch = 16, cex = 0.4,
     xlab = "theta_0 verdadeiro", ylab = "EAP (Stan)"); abline(0, 1, col = "red")
plot(verd$a, a_hat, pch = 16,
     xlab = "a verdadeiro", ylab = "a estimado"); abline(0, 1, col = "red")
plot(verd$b, b_hat, pch = 16,
     xlab = "b verdadeiro", ylab = "b estimado"); abline(0, 1, col = "red")
plot(verd$phi[usa], phi_hat[usa], pch = 16, cex = 0.4,
     xlab = "phi verdadeiro", ylab = "phi estimado"); abline(0, 1, col = "red")
par(mfrow = c(1, 1))
dev.off()

# 4. Cobertura dos intervalos de 90%
cobertura_stan <- c(
  theta = cobertura(verd$theta_0, fit$summary("theta0")),
  a     = cobertura(verd$a,       fit$summary("a")),
  b     = cobertura(verd$b,       fit$summary("b")),
  phi   = cobertura(verd$phi[usa], fit$summary("phi")[usa, ])
)
print(round(cobertura_stan, 3))

# 5. Trajetoria completa: theta_1 e theta_2
theta1_hat <- fit$summary("theta1")$mean
theta2_hat <- fit$summary("theta2")$mean
print(round(rbind(
  theta1 = avaliar_recuperacao(verd$theta_1, theta1_hat),
  theta2 = avaliar_recuperacao(verd$theta_2, theta2_hat)
), 3))

# 6. Cadeias e posteriori de d_hm e d_h
library(bayesplot)
mcmc_trace(fit$draws(c("d_hm", "d_h")))
mcmc_hist(fit$draws(c("d_hm", "d_h")))