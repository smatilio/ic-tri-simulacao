# Compara a velocidade do modelo original com a do otimizado.
#
# Medida: tempo por calculo de gradiente (milissegundos). E o passo mais caro do
# MCMC e se repete milhoes de vezes; o tempo total do ajuste e, aproximadamente,
# (numero de gradientes) x (tempo por gradiente). Aqui os passos sao fixos
# (sem adaptacao), entao o numero de gradientes e previsivel e a comparacao e justa.
# Cada variante roda `repeticoes` vezes e fica o menor tempo, porque outros
# programas do computador deixam o tempo mais lento, nunca mais rapido.
#
# Uso: CENARIO=base Rscript scripts/05_comparar_modelos.R   (ou medio, grande)
#      ou defina `cenario` em R/config.R e rode source() no RStudio.

library(cmdstanr)
source("R/config.R")
source("R/funcoes.R")

cenario_env <- Sys.getenv("CENARIO", unset = "")
if (nzchar(cenario_env)) {
  config$n_ind   <- cenarios[[cenario_env]]$n_ind
  config$n_itens <- cenarios[[cenario_env]]$n_itens
  config$cenario <- cenario_env
}

chains      <- 4
n_iter      <- 100          # iteracoes por cadeia (cada uma com ate 2^3 - 1 = 7 gradientes)
repeticoes  <- 3
nucleos     <- parallel::detectCores(logical = FALSE)
threads_max <- max(1L, nucleos %/% chains)

sim   <- simular_dados(config$n_ind, config$n_itens, config$p_uso,
                       config$delta_hm, config$delta_h, seed = config$seed)
dados <- sim$dados_stan

# Mesmo ponto de partida para todas as variantes
set.seed(1)
ponto <- function(id) list(
  theta0 = rnorm(dados$N, 0, 0.5), a = rlnorm(dados$J, 0, 0.2), b = rnorm(dados$J),
  d_hm = 0.4, d_h = 0.2, phi = runif(dados$N, -0.8, 0.8))
inits <- lapply(seq_len(chains), ponto)

mod_orig <- compilar_modelo_stan("stan/modelo_tri_original.stan")
mod_otim <- compilar_modelo_stan("stan/modelo_tri.stan")

variantes <- list(
  list("original (1 thread)",   mod_orig, 1L),
  list("otimizado (1 thread)",  mod_otim, 1L),
  list(sprintf("otimizado (%d threads por cadeia)", threads_max), mod_otim, threads_max)
)

message(sprintf("Cenario '%s': %d pessoas x %d itens | %d cadeias | %d nucleos fisicos",
                config$cenario, dados$N, dados$J, chains, nucleos))

# ms por gradiente, so no trecho de amostragem (sem ler dados nem iniciar o programa)
ms_por_gradiente <- function(modelo, threads) {
  fit <- modelo$sample(
    data = dados, chains = chains, parallel_chains = chains,
    threads_per_chain = threads,
    iter_warmup = 0, iter_sampling = n_iter,
    adapt_engaged = FALSE, step_size = 0.01, max_treedepth = 3,
    init = inits, seed = config$seed, refresh = 0, show_messages = FALSE
  )
  grad <- apply(fit$sampler_diagnostics()[, , "n_leapfrog__"], 2, sum)
  mean(1000 * fit$time()$chains$sampling / grad)
}

linhas <- lapply(variantes, function(v) {
  message(">>> ", v[[1]])
  medidas <- replicate(repeticoes, suppressWarnings(ms_por_gradiente(v[[2]], v[[3]])))
  data.frame(variante = v[[1]], ms_por_gradiente = round(min(medidas), 2))
})

tab <- do.call(rbind, linhas)
tab$aceleracao <- round(tab$ms_por_gradiente[1] / tab$ms_por_gradiente, 2)
tab <- cbind(cenario = config$cenario, n_ind = dados$N, n_itens = dados$J, tab)
print(tab, row.names = FALSE)
write.csv2(tab, sprintf("output/comparacao_%s.csv", config$cenario), row.names = FALSE)
