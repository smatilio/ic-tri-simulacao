# Funcoes usadas nos scripts


# Stan -----------------------------------------------------------------------

# Quantas threads por cadeia, sem passar do numero de cores
threads_por_cadeia <- function(n_cadeias, n_threads = NA) {
  if (!is.na(n_threads) && n_threads >= 1) return(as.integer(n_threads))
  cores <- parallel::detectCores(logical = FALSE)
  if (is.na(cores) || cores < 1) cores <- parallel::detectCores()
  max(1L, as.integer(cores %/% n_cadeias))
}

# Compila o modelo com suporte a threads (reduce_sum)
compilar_modelo_stan <- function(arquivo) {
  cmdstanr::cmdstan_model(
    arquivo,
    cpp_options = list(stan_threads = TRUE)
  )
}

# Chute inicial a partir do 2PL do mirt no tempo 0 (warmup mais curto na pratica)
inits_a_partir_do_mirt <- function(x_0, n_ind, n_itens = ncol(x_0)) {
  if (!requireNamespace("mirt", quietly = TRUE)) {
    message("mirt nao encontrado; Stan comeca sem chute inicial.")
    return(NULL)
  }
  colnames(x_0) <- paste0("item", seq_len(ncol(x_0)))
  mod0 <- mirt::mirt(x_0, 1, itemtype = "2PL", verbose = FALSE)
  pars <- mirt::coef(mod0, IRTpars = TRUE, simplify = TRUE)$items
  theta0 <- as.numeric(mirt::fscores(mod0, method = "EAP")[, 1])
  function(chain_id) {
    list(
      theta0 = theta0,
      a      = pmax(as.numeric(pars[, "a"]), 0.05),
      b      = as.numeric(pars[, "b"]),
      d_hm   = 0.3,
      d_h    = 0.1,
      phi    = runif(n_ind, -0.2, 0.2)
    )
  }
}

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


# Diagnosticos ---------------------------------------------------------------

tema_diag <- function() {
  ggplot2::theme_classic(base_family = "sans") +
    ggplot2::theme(strip.placement = "outside", strip.background = ggplot2::element_blank(),
                   strip.text.y.left = ggplot2::element_text(angle = 0, size = 13))
}

virgula <- function(x, d = 2) formatC(x, format = "f", digits = d, decimal.mark = ",")

# Uma cadeia de um parametro, como vetor
cadeia <- function(fit, par, ch) as.vector(fit$draws(par)[, ch, 1])

# Autocorrelacao "na mao": correlacao da cadeia com ela mesma deslocada k passos
autocor_na_mao <- function(x, k) {
  n <- length(x)
  cor(x[1:(n - k)], x[(k + 1):n])
}

# ACF de cada cadeia, separada (emendar as cadeias cria saltos que nao existem)
acf_por_cadeia <- function(fit, pars, lag_max = 30) {
  d <- fit$draws(pars)
  do.call(rbind, lapply(pars, function(p) do.call(rbind, lapply(seq_len(dim(d)[2]), function(ch) {
    r <- acf(as.vector(d[, ch, p]), lag.max = lag_max, plot = FALSE)$acf[, 1, 1]
    data.frame(par = p, cadeia = ch, lag = 0:lag_max, acf = r)
  }))))
}

# Autocorrelacao nos lags 1, 5 e 10 e ESS de d_hm e d_h, por cadeia
tabela_autocorrelacao <- function(fit) {
  pars <- c("d_hm", "d_h")
  a <- acf_por_cadeia(fit, pars, lag_max = 10)
  tab <- do.call(rbind, lapply(split(a, list(a$par, a$cadeia)), function(x)
    data.frame(par = x$par[1], cadeia = x$cadeia[1],
               lag1 = x$acf[x$lag == 1], lag5 = x$acf[x$lag == 5], lag10 = x$acf[x$lag == 10])))
  ess <- fit$summary(pars, "ess_bulk")
  tab$ess_bulk <- ess$ess_bulk[match(tab$par, ess$variable)]
  tab <- tab[order(match(tab$par, pars), tab$cadeia), ]
  rownames(tab) <- NULL
  tab
}

# Traceplot de d_hm e d_h com um painel por cadeia
salvar_traceplot_cadeias <- function(fit, verd, arquivo) {
  d <- posterior::as_draws_df(fit$draws(c("d_hm", "d_h")))
  nomes <- c("delta[hm]", "delta[h]")
  cadeias <- data.frame(
    cadeia   = factor(paste("Cadeia", rep(d$.chain, 2))),
    iteracao = rep(d$.iteration, 2),
    valor    = c(d$d_hm, d$d_h),
    par      = factor(rep(nomes, each = nrow(d)), levels = nomes)
  )
  verdadeiro <- data.frame(par = factor(nomes, levels = nomes),
                           valor = c(verd$delta_hm, verd$delta_h))
  p <- ggplot2::ggplot(cadeias, ggplot2::aes(iteracao, valor, colour = cadeia)) +
    ggplot2::geom_line(linewidth = 0.3) +
    ggplot2::geom_hline(data = verdadeiro, ggplot2::aes(yintercept = valor),
                        linetype = "dashed", inherit.aes = FALSE) +
    ggplot2::facet_grid(par ~ cadeia, scales = "free_y", switch = "y",
                        labeller = ggplot2::labeller(par = ggplot2::label_parsed)) +
    ggplot2::scale_colour_brewer(palette = "Dark2", guide = "none") +
    ggplot2::labs(x = "Iteração", y = NULL) +
    tema_diag()
  ggplot2::ggsave(arquivo, p, width = 11, height = 5, dpi = 150, bg = "white")
  p
}

# ACF de d_hm e d_h por cadeia; a faixa tracejada e o que e compativel com correlacao zero
salvar_acf_cadeias <- function(fit, arquivo, lag_max = 30) {
  a <- acf_por_cadeia(fit, c("d_hm", "d_h"), lag_max)
  n <- dim(fit$draws("d_hm"))[1]
  a$par <- factor(a$par, levels = c("d_hm", "d_h"), labels = c("delta[hm]", "delta[h]"))
  a$cadeia <- factor(paste("Cadeia", a$cadeia))
  p <- ggplot2::ggplot(a, ggplot2::aes(lag, acf)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey50") +
    ggplot2::geom_hline(yintercept = c(-1, 1) * 1.96 / sqrt(n), linetype = "dashed", colour = "#1F78B4") +
    ggplot2::geom_segment(ggplot2::aes(xend = lag, yend = 0), linewidth = 0.6) +
    ggplot2::facet_grid(par ~ cadeia, switch = "y",
                        labeller = ggplot2::labeller(par = ggplot2::label_parsed)) +
    ggplot2::labs(x = "Lag", y = NULL) +
    tema_diag()
  ggplot2::ggsave(arquivo, p, width = 11, height = 5, dpi = 150, bg = "white")
  p
}

# Histograma do ESS dos phi (so quem usa a maquina); 400 e o minimo usual para 4 cadeias
salvar_ess_phi <- function(fit, verd, arquivo) {
  ess <- fit$summary("phi", "ess_bulk")$ess_bulk[verd$it == 1]
  p <- ggplot2::ggplot(data.frame(ess), ggplot2::aes(ess)) +
    ggplot2::geom_histogram(bins = 30, fill = "grey60", colour = "white") +
    ggplot2::geom_vline(xintercept = 400, linetype = "dashed", colour = "#D95F02") +
    ggplot2::labs(x = "ESS do phi de cada pessoa que usa a máquina", y = "Pessoas",
                  subtitle = sprintf("mediana %s | mínimo %s | abaixo de 400: %s%%",
                                     virgula(median(ess), 0), virgula(min(ess), 0),
                                     virgula(100 * mean(ess < 400), 1))) +
    ggplot2::theme_classic(base_family = "sans")
  ggplot2::ggsave(arquivo, p, width = 7, height = 4.5, dpi = 150, bg = "white")
  invisible(ess)
}

# Os k phi mais perto e os k mais longe do verdadeiro (so quem usa a maquina)
escolher_phi <- function(fit, verd, k = 3) {
  usa  <- which(verd$it == 1)
  est  <- fit$summary("phi", "mean")$mean
  ord  <- usa[order(abs(est[usa] - verd$phi[usa]))]
  i    <- c(head(ord, k), rev(tail(ord, k)))
  data.frame(i = i, grupo = rep(c("perto", "longe"), each = k),
             verdadeiro = verd$phi[i], estimado = est[i])
}

rotulo_phi <- function(esc) {
  sprintf("%s: phi[%d]\nverdadeiro %s | estimado %s",
          esc$grupo, esc$i, virgula(esc$verdadeiro), virgula(esc$estimado))
}

# Cadeias dos phi escolhidos, com o valor verdadeiro tracejado
salvar_cadeias_phi <- function(fit, esc, phi_max, arquivo) {
  vars <- sprintf("phi[%d]", esc$i)
  rot  <- rotulo_phi(esc)
  d    <- posterior::as_draws_df(fit$draws(vars))
  long <- do.call(rbind, lapply(seq_along(vars), function(k) data.frame(
    painel = rot[k], cadeia = factor(d$.chain), iteracao = d$.iteration, valor = d[[vars[k]]])))
  long$painel <- factor(long$painel, levels = rot)
  verdadeiro  <- data.frame(painel = factor(rot, levels = rot), valor = esc$verdadeiro)
  p <- ggplot2::ggplot(long, ggplot2::aes(iteracao, valor, colour = cadeia)) +
    ggplot2::geom_line(linewidth = 0.25, alpha = 0.7) +
    ggplot2::geom_hline(data = verdadeiro, ggplot2::aes(yintercept = valor),
                        linetype = "dashed", inherit.aes = FALSE) +
    ggplot2::facet_wrap(~ painel, ncol = 3) +
    ggplot2::scale_y_continuous(limits = c(-phi_max, phi_max)) +
    ggplot2::scale_colour_brewer(palette = "Dark2") +
    ggplot2::labs(x = "Iteração", y = NULL, colour = "Cadeia") +
    ggplot2::theme_classic(base_family = "sans")
  ggplot2::ggsave(arquivo, p, width = 11, height = 6, dpi = 150, bg = "white")
  p
}

# ACF dos phi escolhidos, uma linha por cadeia
salvar_acf_phi <- function(fit, esc, arquivo, lag_max = 30) {
  vars <- sprintf("phi[%d]", esc$i)
  rot  <- rotulo_phi(esc)
  a <- acf_por_cadeia(fit, vars, lag_max)
  a$painel <- factor(rot[match(a$par, vars)], levels = rot)
  a$cadeia <- factor(a$cadeia)
  p <- ggplot2::ggplot(a, ggplot2::aes(lag, acf, colour = cadeia)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey50") +
    ggplot2::geom_line(linewidth = 0.4) +
    ggplot2::geom_point(size = 0.6) +
    ggplot2::facet_wrap(~ painel, ncol = 3) +
    ggplot2::scale_colour_brewer(palette = "Dark2") +
    ggplot2::labs(x = "Lag", y = NULL, colour = "Cadeia") +
    ggplot2::theme_classic(base_family = "sans")
  ggplot2::ggsave(arquivo, p, width = 11, height = 6, dpi = 150, bg = "white")
  p
}

# Theta verdadeiro nos tres tempos e a mudanca de um tempo para o outro
salvar_thetas_verdadeiros <- function(verd, arquivo) {
  usa   <- verd$it == 1
  cores <- ifelse(usa, "blue", "red")
  png(arquivo, width = 1200, height = 1000, res = 120)
  on.exit(dev.off())
  par(mfrow = c(2, 2))
  plot(verd$theta_0, verd$theta_1, col = cores, pch = 16, cex = 0.4,
       xlab = "Habilidade no tempo 0", ylab = "Habilidade no tempo 1"); abline(0, 1)
  legend("topleft", c("usa a máquina", "não usa"), col = c("blue", "red"), pch = 16, bty = "n")
  plot(verd$theta_0, verd$theta_2, col = cores, pch = 16, cex = 0.4,
       xlab = "Habilidade no tempo 0", ylab = "Habilidade no tempo 2"); abline(0, 1)
  hist(verd$theta_1[usa] - verd$theta_0[usa], breaks = 30, col = "lightblue", border = "white",
       main = "", xlab = "Mudança do tempo 0 para o 1", ylab = "Pessoas")
  abline(v = verd$delta_h, col = "red", lwd = 2)
  legend("topright", c("quem usa", "quem não usa (todos iguais)"), fill = c("lightblue", NA),
         border = c("white", NA), col = c(NA, "red"), lwd = c(NA, 2), bty = "n", cex = 0.8)
  hist(verd$theta_2[usa] - verd$theta_1[usa], breaks = 30, col = "lightblue", border = "white",
       main = "", xlab = "Mudança do tempo 1 para o 2", ylab = "Pessoas")
  abline(v = verd$delta_h, col = "red", lwd = 2)
}
