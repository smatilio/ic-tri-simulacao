library(cmdstanr)
source("R/config.R")
source("R/funcoes.R")

# Pasta da simulacao e ajuste do Stan (precisa ter rodado o 03)
pasta   <- pasta_simulacao(config)
arq_fit <- file.path(pasta, "fit_stan.rds")
if (!file.exists(arq_fit)) stop("Nao achei ", arq_fit, ". Rode o 03 antes.")
fit  <- readRDS(arq_fit)
verd <- readRDS(file.path(pasta, "simulacao.rds"))$verdadeiros

# Autocorrelacao na mao (cadeia com ela mesma deslocada) x acf(), cadeia 1 do d_hm
x <- cadeia(fit, "d_hm", 1)
data.frame(lag    = c(1, 5, 10),
           na_mao = sapply(c(1, 5, 10), autocor_na_mao, x = x),
           acf    = acf(x, lag.max = 10, plot = FALSE)$acf[c(2, 6, 11)])

# d_hm e d_h: autocorrelacao e ESS por cadeia, traceplot e ACF com as cadeias separadas
tab_acf <- tabela_autocorrelacao(fit)
print(tab_acf, digits = 3)
write.csv2(tab_acf, file.path(pasta, "autocorrelacao.csv"), row.names = FALSE)
salvar_traceplot_cadeias(fit, verd, file.path(pasta, "traceplot_cadeias.png"))
salvar_acf_cadeias(fit, file.path(pasta, "acf_cadeias.png"))

# phi: ESS de quem usa a maquina e cadeias de 3 que ficaram perto e 3 longe do verdadeiro
ess_phi <- salvar_ess_phi(fit, verd, file.path(pasta, "ess_phi.png"))
summary(ess_phi)
escolhidos <- escolher_phi(fit, verd)
escolhidos
salvar_cadeias_phi(fit, escolhidos, config$phi_max, file.path(pasta, "cadeias_phi.png"))
salvar_acf_phi(fit, escolhidos, file.path(pasta, "acf_phi.png"))

# Theta verdadeiro nos tres tempos
salvar_thetas_verdadeiros(verd, file.path(pasta, "thetas_verdadeiros.png"))
