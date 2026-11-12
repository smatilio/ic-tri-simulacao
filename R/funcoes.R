# Funcoes usadas nos scripts


# Simulacao ------------------------------------------------------------------

# Probabilidade de acerto no 2PL
calcular_p <- function(theta, a, b) {
  eta <- sweep(outer(a, theta, "*"), MARGIN = 1, STATS = a * b, FUN = "-")
  plogis(eta)   # itens x individuos
}

# Sorteia as respostas 0/1 (individuos x itens)
simular_x <- function(p) {
  t(matrix(rbinom(length(p), 1, as.vector(p)),
           nrow = nrow(p), ncol = ncol(p)))
}

# Simula os parametros e as respostas nos tempos 0, 1 e 2
# (nao mudar a ordem dos sorteios, muda os dados da seed)
simular_dados <- function(n_ind, n_itens, p_uso, delta_hm, delta_h, phi_max = 1, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Parametros verdadeiros
  theta_0 <- rnorm(n_ind)
  it      <- rbinom(n_ind, 1, p_uso)              # 1 = usa a maquina
  phi     <- runif(n_ind, -phi_max, phi_max)      # phi verdadeiro, sem multiplicar por it
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
  dados_stan <- list(N = n_ind, J = n_itens, X0 = x_0, X1 = x_1, X2 = x_2, I = it,
                     phi_max = phi_max)
  list(verdadeiros = verdadeiros, dados_stan = dados_stan)
}

# Dados em tabela, uma linha por pessoa e tempo
dados_em_tabela <- function(sim) {
  d <- sim$dados_stan
  respostas <- list(d$X0, d$X1, d$X2)
  tab <- do.call(rbind, lapply(seq_along(respostas), function(k) {
    x <- respostas[[k]]
    colnames(x) <- paste0("item", seq_len(ncol(x)))
    data.frame(individuo = seq_len(nrow(x)), I = d$I, tempo = k - 1, x)
  }))
  tab <- tab[order(tab$individuo, tab$tempo), ]
  rownames(tab) <- NULL
  tab
}


# Pasta da simulacao ---------------------------------------------------------

# Nome tirado do config: so o que mudou em relacao a simulacao base,
# ex: base, phi0.5, N10000_J100
nome_simulacao <- function(config) {
  # valores da base (nao mudar, senao os nomes das pastas antigas perdem o sentido)
  base <- c(n_ind = 1000, n_itens = 30, p_uso = 0.9, delta_hm = 0.5, delta_h = 0.1,
            phi_max = 1, seed = 15, stan.chains = 4, stan.iter_warmup = 1000,
            stan.iter_sampling = 1000)
  siglas <- c(n_ind = "N", n_itens = "J", p_uso = "uso", delta_hm = "hm", delta_h = "h",
              phi_max = "phi", seed = "seed", stan.chains = "cadeias",
              stan.iter_warmup = "warmup", stan.iter_sampling = "amostras")

  valores <- as.numeric(unlist(config)[names(base)])
  if (anyNA(valores)) stop("Falta algum valor no config.R")
  mudou <- valores != base
  num <- function(x) format(x, scientific = FALSE, trim = TRUE)
  nome <- if (any(mudou)) paste0(siglas[mudou], sapply(valores[mudou], num), collapse = "_") else "base"
  if (length(config$rotulo) && nzchar(config$rotulo)) nome <- paste0(nome, "_", config$rotulo)
  nome
}

pasta_simulacao <- function(config) file.path("output", nome_simulacao(config))

# Salva os valores usados, a data e o commit do codigo
salvar_info <- function(config, pasta) {
  git <- function(...) tryCatch(system2("git", c(...), stdout = TRUE, stderr = FALSE),
                                error = function(e) character(0),
                                warning = function(w) character(0))
  commit <- git("rev-parse", "--short", "HEAD")
  if (length(commit) == 0) commit <- "?"
  if (length(git("status", "--porcelain", "R", "scripts", "stan")) > 0)
    commit <- paste(commit, "(com alteracoes sem commit)")
  valores <- unlist(config)
  writeLines(c(paste("simulacao:", basename(pasta)),
               paste("data:", format(Sys.time(), "%Y-%m-%d %H:%M")),
               paste("commit:", commit),
               "",
               paste(names(valores), "=", valores)),
             file.path(pasta, "config.txt"))
}


# Recuperacao ----------------------------------------------------------------

# Correlacao, vies e RMSE entre verdadeiro e estimado
avaliar_recuperacao <- function(verdadeiro, estimado) {
  c(correlacao = cor(verdadeiro, estimado),
    vies = mean(estimado - verdadeiro),
    RMSE = sqrt(mean((estimado - verdadeiro)^2)))
}

# Cobertura do IC de 90%
cobertura <- function(verdadeiro, resumo)
  mean(verdadeiro >= resumo$q5 & verdadeiro <= resumo$q95)


# Graficos -------------------------------------------------------------------

# Traceplot de d_hm e d_h com o valor verdadeiro tracejado
salvar_traceplot <- function(fit, verd, arquivo) {
  d <- posterior::as_draws_df(fit$draws(c("d_hm", "d_h")))
  nomes <- c("delta[hm]", "delta[h]")
  cadeias <- data.frame(
    cadeia   = factor(rep(d$.chain, 2)),
    iteracao = rep(d$.iteration, 2),
    valor    = c(d$d_hm, d$d_h),
    par      = factor(rep(nomes, each = nrow(d)), levels = nomes)
  )
  verdadeiro <- data.frame(par = factor(nomes, levels = nomes),
                           valor = c(verd$delta_hm, verd$delta_h))
  p <- ggplot2::ggplot(cadeias, ggplot2::aes(iteracao, valor, colour = cadeia)) +
    ggplot2::geom_line(linewidth = 0.3, alpha = 0.6) +
    ggplot2::geom_hline(data = verdadeiro, ggplot2::aes(yintercept = valor),
                        linetype = "dashed", inherit.aes = FALSE) +
    ggplot2::facet_grid(par ~ ., scales = "free_y", switch = "y",
                        labeller = ggplot2::label_parsed) +
    ggplot2::scale_colour_brewer(palette = "Dark2") +
    ggplot2::guides(colour = ggplot2::guide_legend(override.aes = list(linewidth = 1.5, alpha = 1))) +
    ggplot2::labs(x = "Iteração", y = NULL, colour = "Cadeia") +
    ggplot2::theme_classic(base_family = "sans") +
    ggplot2::theme(strip.placement = "outside", strip.background = ggplot2::element_blank(),
                   strip.text.y.left = ggplot2::element_text(angle = 0, size = 13))
  ggplot2::ggsave(arquivo, p, width = 8, height = 5, dpi = 150, bg = "white")   # sem bg fica transparente no GitHub
  p
}
