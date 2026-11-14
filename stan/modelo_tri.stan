// Mesmo modelo estatistico do original, escrito para calcular mais rapido:
// - os 3 tempos sao empilhados: 1 chamada de regressao logistica por item
//   (em vez de 3 chamadas por item com vetores pequenos)
// - bernoulli_logit_glm tem gradiente escrito a mao, mais barato que o automatico
// - reduce_sum reparte os itens entre threads (threads_per_chain no cmdstanr)
functions {
  // Soma a log-verossimilhanca dos itens start..end.
  // Yfatia[k] sao as 3N respostas do item (start + k - 1), nos tempos 0, 1 e 2.
  real soma_parcial(array[,] int Yfatia, int start, int end,
                    matrix T, vector a, vector b) {
    real lp = 0;
    for (k in 1:(end - start + 1)) {
      int j = start + k - 1;
      lp += bernoulli_logit_glm_lpmf(Yfatia[k] | T, -a[j] * b[j], rep_vector(a[j], 1));
    }
    return lp;
  }
}
data {
  int<lower=1> N;
  int<lower=1> J;
  array[N, J] int<lower=0, upper=1> X0;
  array[N, J] int<lower=0, upper=1> X1;
  array[N, J] int<lower=0, upper=1> X2;
  vector<lower=0, upper=1>[N] I;
}
transformed data {
  // Y[j] = respostas do item j: tempo 0, depois tempo 1, depois tempo 2
  array[J, 3 * N] int Y;
  for (j in 1:J) {
    Y[j, 1:N]           = X0[:, j];
    Y[j, (N + 1):(2 * N)]     = X1[:, j];
    Y[j, (2 * N + 1):(3 * N)] = X2[:, j];
  }
  // Pedacos grandes: poucas fatias por cadeia, pouco custo de gerenciamento
  int grainsize = max(1, J %/% 4);
}
parameters {
  vector[N] theta0;
  vector<lower=0>[J] a;
  vector[J] b;
  real<lower=0> d_hm;
  real d_h;
  vector<lower=-1, upper=1>[N] phi;
}
transformed parameters {
  // Fora do bloco model para continuar disponiveis na saida,
  // como no modelo original (theta1 e theta2 por pessoa).
  vector[N] theta1 = theta0 + d_hm * (I .* phi) + d_h;
  vector[N] theta2 = theta1 + d_hm * (I .* square(phi)) + d_h;
}
model {
  theta0 ~ std_normal();
  a ~ lognormal(0, 0.5);
  b ~ normal(0, 5);
  d_hm ~ normal(0, 1);               // half-normal (d_hm > 0)
  d_h ~ normal(0, 1);

  matrix[3 * N, 1] T = to_matrix(append_row(theta0, append_row(theta1, theta2)));
  target += reduce_sum(soma_parcial, Y, grainsize, T, a, b);
}
