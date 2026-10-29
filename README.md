# Simulação em TRI: efeito humano-máquina

Projeto de Iniciação Científica: estudo de simulação em Teoria de Resposta ao Item (TRI) para ver se, a partir das respostas a um mesmo teste aplicado em três momentos, é possível recuperar o efeito do uso de uma máquina sobre a habilidade das pessoas.

Os dados são gerados com parâmetros conhecidos e estimados de duas formas:

- **mirt**: 2PL ajustado só com as respostas do tempo 0, como referência;
- **Stan**: modelo bayesiano com os três tempos, que estima os efeitos diretamente.

## Modelo

Cada pessoa *i* responde aos mesmos *J* itens nos tempos *t* = 0, 1, 2, segundo o modelo logístico de dois parâmetros (2PL):

```math
P(X_{ijt} = 1) = \operatorname{logit}^{-1}\big(a_j\,(\theta_{it} - b_j)\big)
```

A habilidade muda entre os tempos conforme o uso da máquina:

```math
\begin{aligned}
\theta_{i1} &= \theta_{i0} + \delta_{hm}\, I_i\, \phi_i + \delta_h \\
\theta_{i2} &= \theta_{i1} + \delta_{hm}\, I_i\, \phi_i^2 + \delta_h
\end{aligned}
```

| Símbolo | Significado | Valor na simulação |
|---|---|---|
| $\theta_{i0}$ | habilidade inicial | $N(0, 1)$ |
| $I_i$ | 1 se a pessoa usa a máquina | Bernoulli(0,9) |
| $\phi_i$ | quanto a pessoa se beneficia (ou se prejudica) com a máquina | $U(-1, 1)$ |
| $\delta_{hm}$ | efeito humano-máquina | 0,5 |
| $\delta_h$ | efeito humano, comum a todos | 0,1 |
| $a_j$ | discriminação do item | lognormal(0; 0,18) |
| $b_j$ | dificuldade do item | $N(0, 1)$ |

Cenário atual: 1.000 pessoas, 30 itens e `seed = 15` (definidos em [`R/config.R`](R/config.R)).

## Estrutura

```
.
├── R/
│   ├── config.R                  # parâmetros da simulação
│   └── funcoes.R                 # simular_dados() e métricas de recuperação
├── scripts/
│   ├── 01_simulacao.R            # gera os dados → output/simulacao.rds
│   ├── 02_recuperacao_mirt.R     # 2PL no tempo 0 com mirt
│   └── 03_recuperacao_stan.R     # modelo longitudinal com Stan
├── stan/
│   └── modelo_tri.stan           # modelo bayesiano
├── output/                       # resultados gerados pelos scripts
├── renv.lock                     # versões exatas dos pacotes R
└── ic-tri-simulacao.Rproj
```

## Como reproduzir

Requisitos: R 4.5, CmdStan 2.40 e, no Windows, o [Rtools](https://cran.r-project.org/bin/windows/Rtools/) (para compilar o modelo Stan).

1. Clone o repositório e abra `ic-tri-simulacao.Rproj` no RStudio. O [renv](https://rstudio.github.io/renv/) é ativado automaticamente.
2. Instale os pacotes nas versões registradas no `renv.lock`:
   ```r
   renv::restore()
   ```
3. Se ainda não tiver o CmdStan:
   ```r
   cmdstanr::install_cmdstan()
   ```
4. Rode os scripts em ordem, a partir da raiz do projeto:
   ```r
   source("scripts/01_simulacao.R")
   source("scripts/02_recuperacao_mirt.R")
   source("scripts/03_recuperacao_stan.R")   # 15 a 20 min (4 cadeias em paralelo)
   ```

O `output/fit_stan.rds` (cerca de 120 MB) fica fora do Git porque passa do limite do GitHub; o script 03 cria o arquivo de novo.

No Windows, o `.Rprofile` deixa os pacotes do renv em `%LOCALAPPDATA%\R\renv\library`, fora do OneDrive.

## Resultados (uma réplica, `seed = 15`)

Efeitos globais (Stan: média a posteriori e intervalo de credibilidade de 90%):

| Parâmetro | Verdadeiro | Estimado | IC 90% |
|---|---:|---:|---:|
| $\delta_{hm}$ | 0,5 | 0,489 | [0,418; 0,560] |
| $\delta_h$ | 0,1 | 0,101 | [0,081; 0,121] |

Recuperação dos parâmetros (correlação, viés e RMSE entre o verdadeiro e o estimado; cobertura do intervalo de 90%):

| Parâmetro | Método | Correlação | Viés | RMSE | Cobertura |
|---|---|---:|---:|---:|---:|
| $\theta_0$ | mirt | 0,917 | −0,037 | 0,412 | — |
| $\theta_0$ | Stan | 0,959 | −0,037 | 0,292 | 0,905 |
| $a$ | mirt | 0,870 | 0,040 | 0,100 | — |
| $a$ | Stan | 0,967 | 0,012 | 0,045 | 0,967 |
| $b$ | mirt | 0,994 | −0,032 | 0,101 | — |
| $b$ | Stan | 0,998 | −0,039 | 0,065 | 0,933 |
| $\phi$ (só quem usa a máquina) | Stan | 0,504 | 0,032 | 0,506 | 0,885 |

Como o Stan usa os três tempos e o mirt só o tempo 0, a comparação favorece o Stan. No ajuste do Stan não houve transições divergentes, o $\hat{R}$ máximo foi 1,007 e o ESS mínimo ficou perto de 515.

![Recuperação dos parâmetros no Stan](output/recuperacao_stan.png)

## Limitações e próximos passos

- O φ de cada pessoa é mal identificado: com 30 itens, o erro de medida de θ (cerca de 0,3) é da mesma ordem que o efeito individual da máquina (no máximo 0,5), então as estimativas de φ ficam puxadas para zero.
- Os resultados são de uma réplica só. O próximo passo é fazer réplicas Monte Carlo e variar o cenário (N, J, proporção de usuários, valores de δ) com `simular_dados()`.
- As priors ainda são provisórias e vão ser definidas com o Prof. Gabriel.

## Autor

Atilio Souza Mantovani, com orientação do Prof. Gabriel Assunção.
