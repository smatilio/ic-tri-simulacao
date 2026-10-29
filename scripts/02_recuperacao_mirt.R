library(mirt)
source("R/funcoes.R")

# 1. Carregar os dados simulados e os valores verdadeiros
sim <- readRDS("output/simulacao.rds")

x_0     <- sim$dados_stan$X0
theta_0 <- sim$verdadeiros$theta_0
a       <- sim$verdadeiros$a
b       <- sim$verdadeiros$b

# 2. Ajustar o modelo 2PL com as respostas do tempo 0
colnames(x_0) <- paste0("item", 1:ncol(x_0))
mod0 <- mirt(x_0, 1, itemtype = "2PL", verbose = FALSE)

# 3. Extrair as estimativas
theta_hat0 <- fscores(mod0, method = "EAP")[, 1]
pars  <- coef(mod0, IRTpars = TRUE, simplify = TRUE)$items
a_hat <- pars[, "a"]
b_hat <- pars[, "b"]

# 4. Medidas de recuperação (avaliar_recuperacao() em R/funcoes.R)
resultado <- rbind(
  theta = avaliar_recuperacao(theta_0, theta_hat0),
  a     = avaliar_recuperacao(a, a_hat),
  b     = avaliar_recuperacao(b, b_hat)
)
print(round(resultado, 3))

# 5. Gráficos de recuperação
par(mfrow = c(1, 3))
plot(theta_0, theta_hat0, pch = 16, cex = 0.5,
     xlab = "theta_0 verdadeiro", ylab = "EAP (mirt)"); abline(0, 1, col = "red")
plot(a, a_hat, pch = 16,
     xlab = "a verdadeiro", ylab = "a estimado"); abline(0, 1, col = "red")
plot(b, b_hat, pch = 16,
     xlab = "b verdadeiro", ylab = "b estimado"); abline(0, 1, col = "red")
par(mfrow = c(1, 1))

# Salvar a tabela de recuperacao do mirt
saveRDS(resultado, "output/resultado_mirt.rds")      # para usar no R depois
write.csv2(round(resultado, 3), "output/resultado_mirt.csv")   # para abrir no Excel