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

# Dados em tabela: uma linha por pessoa e tempo, com o indicador I e as respostas
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


# Graficos -------------------------------------------------------------------

# Traceplot de d_hm e d_h com o valor verdadeiro tracejado
# (fundo branco, senao o PNG fica transparente e some no GitHub escuro)
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
  ggplot2::ggsave(arquivo, p, width = 8, height = 5, dpi = 150, bg = "white")
  p
}

# Rank plot de d_hm e d_h: com as cadeias bem misturadas, as linhas ficam perto da tracejada
salvar_rankplot <- function(fit, arquivo) {
  rotulos <- ggplot2::as_labeller(c(d_hm = "delta[hm]", d_h = "delta[h]"),
                                  default = ggplot2::label_parsed)
  p <- bayesplot::mcmc_rank_overlay(fit$draws(c("d_hm", "d_h")), ref_line = TRUE,
                                    facet_args = list(labeller = rotulos)) +
    bayesplot::theme_default(base_family = "sans") +
    ggplot2::labs(x = "Rank", y = NULL, colour = "Cadeia") +
    ggplot2::guides(colour = ggplot2::guide_legend(override.aes = list(linewidth = 1.5)))
  p <- suppressMessages(p + ggplot2::scale_colour_brewer(palette = "Dark2"))
  ggplot2::ggsave(arquivo, p, width = 8, height = 3.5, dpi = 150, bg = "white")
  p
}
