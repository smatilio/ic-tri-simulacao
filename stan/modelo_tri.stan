data {
  int<lower=1> N;                              // individuos
  int<lower=1> J;                              // itens
  array[N, J] int<lower=0, upper=1> X0;        // respostas no tempo 0
  array[N, J] int<lower=0, upper=1> X1;        // respostas no tempo 1
  array[N, J] int<lower=0, upper=1> X2;        // respostas no tempo 2
  vector<lower=0, upper=1>[N] I;               // 1 = usa a maquina
}
parameters {
  vector[N] theta0;
  vector<lower=0>[J] a;
  vector[J] b;
  real<lower=0> d_hm;                          // efeito humano-maquina
  real d_h;                                    // efeito humano
  vector<lower=-1, upper=1>[N] phi;
}
transformed parameters {
  vector[N] theta1 = theta0 + d_hm * (I .* phi) + d_h;
  vector[N] theta2 = theta1 + d_hm * (I .* square(phi)) + d_h;
}
model {
  // priors (a definir com o orientador)
  theta0 ~ std_normal();
  a ~ lognormal(0, 0.5);
  b ~ normal(0, 2);
  d_hm ~ normal(0, 1);                         // half-normal, pois d_hm > 0
  d_h ~ normal(0, 1);
  // phi ~ uniform(-1, 1) ja esta implicito nos limites

  // verossimilhanca: uma coluna (item) por vez
  for (j in 1:J) {
    X0[:, j] ~ bernoulli_logit(a[j] * (theta0 - b[j]));
    X1[:, j] ~ bernoulli_logit(a[j] * (theta1 - b[j]));
    X2[:, j] ~ bernoulli_logit(a[j] * (theta2 - b[j]));
  }
}
