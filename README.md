# Simulação em TRI: efeito humano-máquina

Este repositório reúne o estudo de simulação da minha Iniciação Científica em Teoria de Resposta ao Item (TRI), orientada pelo Prof. Gabriel Assunção. A ideia é verificar se, a partir das respostas a um mesmo teste aplicado em três momentos, é possível recuperar o efeito do uso de uma máquina sobre a habilidade das pessoas.

Na simulação atual (configurada em [`R/config.R`](R/config.R), com `seed = 15`), o cenário `base` gera as respostas de 1.000 pessoas a 30 itens. Troque `cenario` para `medio` (2.000 × 50) ou `grande` (4.000 × 80) para testar o desempenho com mais pessoas e mais itens. Os parâmetros são estimados de duas formas: com o pacote mirt, ajustando o 2PL só com as respostas do tempo 0, e com um modelo bayesiano em Stan, que usa os três tempos ao mesmo tempo e estima os efeitos diretamente.

O ajuste em Stan levava cerca de 20 minutos no cenário base. Com o modelo reescrito para calcular mais rápido (ver [Otimização do Stan](#otimização-do-stan)), leva cerca de 7.

## Modelo

Cada pessoa *i* responde aos mesmos *J* itens nos tempos *t* = 0, 1, 2, segundo o modelo logístico de dois parâmetros (2PL):

```math
P(X_{ijt} = 1) = \mathrm{logit}^{-1}\big(a_j\,(\theta_{it} - b_j)\big)
```

De um tempo para o outro, a habilidade muda por um efeito comum a todos ($\delta_h$) e, para quem usa a máquina ($I_i = 1$), por um efeito que varia de pessoa para pessoa, dado por $\delta_{hm}$ e $\phi_i$:

```math
\begin{aligned}
\theta_{i1} &= \theta_{i0} + \delta_{hm}\, I_i\, \phi_i + \delta_h \\
\theta_{i2} &= \theta_{i1} + \delta_{hm}\, I_i\, \phi_i^2 + \delta_h
\end{aligned}
```

A tabela abaixo traz os valores usados para gerar os dados e as priors do modelo em Stan, que estão em [`stan/modelo_tri.stan`](stan/modelo_tri.stan). As distribuições seguem a parametrização do R e do Stan: N(média, desvio-padrão) e lognormal(meanlog, sdlog).

| Símbolo | Significado | Valor na simulação | Prior no Stan |
|---|---|---|---|
| $\theta_{i0}$ | habilidade inicial | $N(0, 1)$ | $N(0, 1)$ |
| $I_i$ | 1 se a pessoa usa a máquina | Bernoulli(0,9) | — (observado) |
| $\phi_i$ | quanto a pessoa se beneficia (ou se prejudica) com a máquina | $U(-1, 1)$ | $U(-1, 1)$ |
| $\delta_{hm}$ | efeito humano-máquina | 0,5 | half-normal(0, 1) |
| $\delta_h$ | efeito humano, comum a todos | 0,1 | $N(0, 1)$ |
| $a_j$ | discriminação do item | lognormal(0; 0,18) | lognormal(0; 0,5) |
| $b_j$ | dificuldade do item | $N(0, 1)$ | $N(0, 5)$ |

O gráfico abaixo mostra os valores verdadeiros de $\theta$ na simulação base. Em cima está a habilidade nos tempos 1 e 2 contra a do tempo 0, em azul para quem usa a máquina e em vermelho para quem não usa. Embaixo está a mudança de um tempo para o outro entre quem usa a máquina; a linha vermelha marca a mudança de quem não usa, que é sempre $\delta_h$ = 0,1. Do tempo 0 para o 1, quem usa a máquina muda entre −0,4 e 0,6, dependendo do sinal de $\phi_i$. Do tempo 1 para o 2 todos ganham, porque o efeito depende de $\phi_i^2$, mas a maioria ganha pouco. Perto da variação de $\theta$ entre as pessoas, essas mudanças são pequenas, e os pontos ficam perto da diagonal.

![Habilidade verdadeira nos três tempos e mudança entre eles](output/base/thetas_verdadeiros.png)

## Como reproduzir

As funções e os parâmetros da simulação ficam em `R/`, o modelo em `stan/` e a execução está dividida em três scripts numerados em `scripts/`. O projeto usa R 4.5 e CmdStan 2.40 (no Windows, também é preciso o [Rtools](https://cran.r-project.org/bin/windows/Rtools/) para compilar o modelo). Ao abrir `ic-tri-simulacao.Rproj` no RStudio, o [renv](https://rstudio.github.io/renv/) é ativado sozinho e usa as versões de pacotes registradas no `renv.lock`; no Windows, o `.Rprofile` guarda essa biblioteca em `%LOCALAPPDATA%\R\renv\library`, fora da pasta do projeto. Com o projeto aberto, basta rodar:

```r
renv::restore()                          # instala os pacotes do renv.lock (só na primeira vez)
# cmdstanr::install_cmdstan()            # se ainda não tiver o CmdStan

source("scripts/01_simulacao.R")         # gera os dados e cria a pasta da simulação em output/
source("scripts/02_recuperacao_mirt.R")  # 2PL no tempo 0 com mirt
source("scripts/03_recuperacao_stan.R")  # Stan: cerca de 7 min no cenário base (4 cadeias em paralelo)
source("scripts/04_diagnosticos.R")      # cadeias separadas, autocorrelação, erro de Monte Carlo, ESS dos phi e theta verdadeiros
source("scripts/05_comparar_modelos.R")  # opcional: compara a velocidade do modelo original e do otimizado
```

Antes de rodar o 01, escolha o cenário em `R/config.R` (`base`, `medio` ou `grande`).

Cada simulação grava seus resultados numa pasta própria dentro de `output/`, junto com um `config.txt` que registra os valores, a data e o commit do código usados. Por enquanto só existe a `output/base/`, que é a simulação deste README: 1.000 pessoas, 30 itens, 90% usando a máquina, $\delta_{hm}$ = 0,5, $\delta_h$ = 0,1, $\phi_i$ entre −1 e 1 e `seed = 15`. Uma simulação nova leva no nome só o que muda em relação à base; se apenas o $\phi_i$ passar a ir de −0,5 a 0,5, por exemplo, a pasta será `output/phi0.5/`. O primeiro script não sobrescreve uma simulação que já existe; para refazê-la, é preciso apagar a pasta.

O ajuste completo do Stan (`fit_stan.rds`, cerca de 120 MB) passa do limite do GitHub, por isso fica fora do Git e é criado de novo pelo terceiro script.

## Resultados e discussão (uma réplica, `seed = 15`)

O ajuste do Stan convergiu sem transições divergentes, com $\hat{R}$ máximo de 1,009 e tamanho efetivo de amostra (ESS) mínimo perto de 500, em alguns $b_j$. Os dois efeitos globais foram bem recuperados: o efeito humano-máquina ($\delta_{hm}$, valor verdadeiro 0,5) teve média a posteriori de 0,492, com intervalo de credibilidade de 90% de 0,422 a 0,561, e o efeito humano ($\delta_h$, valor verdadeiro 0,1) ficou em 0,101, de 0,081 a 0,121.

![Traceplot das cadeias de δhm e δh no Stan, uma cadeia por painel](output/base/traceplot_cadeias.png)

No traceplot, cada uma das quatro cadeias aparece num painel, e todas oscilam em torno dos valores verdadeiros (linhas tracejadas), sem tendência. O $\delta_{hm}$ mistura mais devagar que o $\delta_h$: a correlação entre sorteios vizinhos fica perto de 0,6 no $\delta_{hm}$ e abaixo de 0,2 no $\delta_h$, e o ESS é de 557 contra 1.770. Isso provavelmente acontece porque o $\delta_{hm}$ multiplica o $\phi_i$ de cada pessoa, que é mal identificado. Para os outros parâmetros, a tabela compara as estimativas com os valores verdadeiros (correlação, viés e RMSE) e mostra, no Stan, a cobertura dos intervalos de 90%.

| Parâmetro | Método | Correlação | Viés | RMSE | Cobertura |
|---|---|---:|---:|---:|---:|
| $\theta_0$ | mirt | 0,917 | −0,037 | 0,412 | — |
| $\theta_0$ | Stan | 0,959 | −0,038 | 0,292 | 0,901 |
| $a$ | mirt | 0,870 | 0,040 | 0,100 | — |
| $a$ | Stan | 0,966 | 0,010 | 0,045 | 0,967 |
| $b$ | mirt | 0,994 | −0,032 | 0,101 | — |
| $b$ | Stan | 0,998 | −0,041 | 0,065 | 0,933 |
| $\phi$ (só quem usa a máquina) | Stan | 0,504 | 0,032 | 0,506 | 0,882 |

![Recuperação dos parâmetros no Stan](output/base/recuperacao_stan.png)

A comparação de $\theta_0$, $a$ e $b$ favorece o Stan, que usa os três tempos, enquanto o mirt só tem o tempo 0. Já o efeito individual da máquina ($\phi_i$, no gráfico de baixo à direita) é mal identificado: com 30 itens, o erro de medida de $\theta$ (cerca de 0,3) é da mesma ordem que o efeito individual máximo da máquina (0,5), então as estimativas de $\phi_i$ ficam puxadas para zero. As priors ainda são provisórias e podem ser alteradas posteriormente.

## Otimização do Stan

O modelo em [`stan/modelo_tri.stan`](stan/modelo_tri.stan) foi reescrito pelo Andrei para calcular mais rápido, sem mudar a verossimilhança nem as priors. As respostas dos três tempos de cada item são empilhadas num vetor só, a verossimilhança usa `bernoulli_logit_glm`, que já tem o gradiente pronto, e o `reduce_sum` permite dividir os itens entre threads. O modelo anterior ficou em `stan/modelo_tri_original.stan`, e o script `05_comparar_modelos.R` mede o tempo de cada cálculo de gradiente nos dois (medido no computador do Andrei):

| Cenário | Original | Otimizado | Ganho |
|---|---:|---:|---:|
| `base` (1.000 × 30) | 15,0 ms | 5,8 ms | 2,6× |
| `medio` (2.000 × 50) | 107,7 ms | 38,5 ms | 2,8× |
| `grande` (4.000 × 80) | 358,1 ms | 118,0 ms | 3,0× |

Usar duas threads por cadeia não deixou o ajuste mais rápido nesses cenários. No ajuste completo do cenário base, o tempo caiu de 19,9 para 6,6 minutos.

Para conferir que o modelo continua o mesmo, a simulação base foi ajustada de novo com a versão otimizada, em `output/base_otimizado/`. As métricas de recuperação mudaram no máximo 0,001, o $\delta_{hm}$ ficou em 0,489 (de 0,417 a 0,560) e o $\delta_h$ em 0,102 (de 0,082 a 0,121). Nos 2.062 parâmetros, as diferenças entre as médias a posteriori dos dois ajustes ficaram dentro do esperado pelo erro de Monte Carlo.

O ajuste otimizado também começa as cadeias perto da solução do mirt no tempo 0 (`usar_init_mirt` em `R/config.R`). Como as quatro cadeias partem do mesmo ponto em $\theta_0$, $a$ e $b$, o $\hat{R}$ fica menos exigente; a opção pode ser desligada no `config.R`.

## Autor

Atilio Souza Mantovani
