# Benchmark reproduzível da resolução de Leontief

Este benchmark isola a escolha algébrica que domina a transformação de
Leontief: formar a inversa explicitamente, resolver o sistema completo sem
inversa ou resolver somente o bloco produtivo. Ele usa uma matriz anual real,
reconstruída dos artefatos publicados e da fonte preparada, e não uma matriz
aleatória ou sintética.

## Protocolo

O comando de referência é:

```powershell
./scripts/run-experiment.ps1 -Id leontief-055 -Executable Rscript `
  -ArgumentList @('--vanilla', 'scripts/benchmark_leontief.R',
    '--method', 'wiodr16', '--channel', 'stable', '--year', '2013',
    '--repetitions', '5', '--poll-ms', '25') -Preserve
```

No Linux, o equivalente em bash é (argumentos do programa após `--`):

```bash
bash scripts/run-experiment.sh -Id leontief-055 -Executable Rscript -Preserve \
  -- --vanilla scripts/benchmark_leontief.R --method wiodr16 --channel stable \
  --year 2013 --repetitions 5 --poll-ms 25
```

O lançador cria `temp/leontief-055/`, configura os temporários dos processos
filhos e grava os resultados em `results/leontief-benchmark/` dentro da campanha.
O identificador deve ser novo; consulte `local-campaigns.md` para encerrar e limpar
campanhas. No Linux, o lançador em bash acima registra a campanha
automaticamente. O script requer
`fst`, `jsonlite` e `processx`. Ele não usa
`ps` diretamente; `ps` pode aparecer como dependência transitiva de
`processx`.

O protocolo é deliberadamente estreito:

1. O processo coordenador lê, em blocos, `source_data/wiodr16/m_io.fst`, o
   indicador `k_depreciation` do `m_io` publicado e os indicadores de trabalho
   e produto do `sea_sectors` publicado.
2. Para o ano escolhido, ele reconstrói
   `C = (consumo intermediário + depreciação) / produto bruto`, com o mesmo
   filtro produtivo do método, e então `M = t(I - C)`.
3. A fixture completa e a fixture produtiva são serializadas sem compressão em
   um diretório temporário exclusivo. Seus MD5 são registrados em
   `fixture.csv`.
4. Cada combinação de estratégia e repetição inicia um processo R novo, com
   `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, `MKL_NUM_THREADS` e
   `VECLIB_MAXIMUM_THREADS` iguais a `1`. As repetições são sequenciais.
5. O tempo reportado cobre somente o núcleo algébrico, depois da leitura da
   fixture. O pico de memória cobre todo o processo filho. No Windows, é o pico
   do *working set* informado pelo sistema operacional; nas demais plataformas,
   é o RSS disponível. O processo é consultado a cada 25 ms.
6. Depois das medições, o coordenador compara as três soluções e recupera
   `lambda` publicado por `gross_output.s.mv / gross_output.s.us`. Essas
   comparações não entram no tempo medido.

O parâmetro `--method` aceita `wiodr13`, `wiodr16`, `wiodr16v09` e
`zerodep_2`, desde que exista uma geração completa publicada do método. Os dois
últimos continuam sujeitos ao opt-in experimental na criação dessa geração. No
caso WIOD13, qualquer fluxo não zero sobre produto zero só é substituído depois
que suas coordenadas coincidem exatamente com o allowlist persistido em
`_anomalies.csv`; isso permite também reconstruir a fixture assinada de 2006
sem enfraquecer a política de denominadores zero.

As três estratégias são:

| Estratégia | Operação medida | Dimensão WIOD16 |
| --- | --- | ---: |
| `explicit_inverse_full` | `solve(M) %*% l` | 2.464 |
| `direct_solve_full` | `solve(M, l)` | 2.464 |
| `direct_solve_productive` | `solve(M[p,p], l[p])` | 1.716 |

O benchmark mede a estratégia algébrica, não toda a auditoria de produção. A
execução normal também estima condicionamento, reutiliza uma fatoração LU,
calcula erros residual e reverso, pode fazer refinamento iterativo e constrói o
certificado de estabilidade descrito em
[`scientific-validation.md`](scientific-validation.md).

## Resultado de referência

A execução abaixo foi feita em 15 de agosto de 2026, com R 4.6.1, Windows 11
x64, BLAS padrão de uma thread e a fixture real `wiodr16/2013`. Cada linha
resume cinco processos novos.

| Estratégia | Tempo mediano, s (mín.–máx.) | Pico mediano, MiB | Aceleração | Redução de RSS |
| --- | ---: | ---: | ---: | ---: |
| Inversa explícita, sistema completo | 2,83 (2,83–2,87) | 262,08 | 1,00x | — |
| Resolução direta, sistema completo | 1,12 (1,11–1,13) | 169,45 | 2,53x | 35,3% |
| Resolução direta, bloco produtivo | 0,38 (0,36–0,39) | 121,78 | 7,45x | 53,5% |

As diferenças numéricas máximas foram:

| Comparação | Máxima absoluta | Máxima relativa |
| --- | ---: | ---: |
| Inversa explícita × resolução direta completa | `1,31006316905768e-14` | `9,51615934723129e-15` |
| Resolução direta completa × bloco produtivo | `0` | `0` |
| Bloco produtivo × `lambda` publicado | `1,57651669496772e-14` | `2,72226661160441e-14` |

Esses valores são evidência da máquina de referência, não limites normativos.
O critério normativo é a política de erro e condicionamento do cálculo. Em uma
máquina diferente, compare principalmente as estratégias dentro da mesma
execução e conserve os arquivos brutos.

## Memória estrutural

Somente a carga numérica de um arranjo denso de `double`, sem cabeçalhos,
fatorações ou cópias temporárias, ocupa:

| Objeto | Bytes | MiB |
| --- | ---: | ---: |
| 15 inversas completas, `15 x 2464 x 2464` | 728.555.520 | 694,80 |
| 15 inversas produtivas, `15 x 1716 x 1716` | 353.358.720 | 336,99 |
| Um sistema completo | 48.570.368 | 46,32 |
| Um sistema produtivo | 23.557.248 | 22,47 |

O pico observado inclui o interpretador, a fixture, a fatoração e cópias da
biblioteca linear. Por isso ele não deve ser confundido com a conta acima.

Para realizar a economia na execução completa, não basta resolver o bloco
produtivo no fim: a transformação deve construir um bloco anual por vez,
resolvê-lo, registrar os diagnósticos e liberá-lo. Manter simultaneamente o
arranjo completo `anos x entradas x saídas`, uma cópia transposta ou uma pilha
de inversas anula grande parte do ganho. Também se deve evitar paralelizar anos
densos sem um orçamento explícito de memória, porque cada trabalhador retém
sua própria fatoração.

A transformação atual segue esse desenho para os coeficientes: uma primeira
passagem anual valida atomicamente o perfil de denominadores zero e uma segunda
reconstrói, resolve e descarta cada bloco produtivo. As matrizes de fonte e de
resultado das quais esses blocos são extraídos continuam sendo custos do
cálculo completo; por isso o pico do benchmark de kernel não é uma previsão do
pico de toda a execução.

## Artefatos produzidos

O diretório de saída contém:

- `raw.csv`: uma linha por processo, com tempo e pico de RSS;
- `summary.csv`: mediana, mínimo, máximo, aceleração e redução de RSS;
- `accuracy.csv`: comparações numéricas não cronometradas;
- `fixture.csv`: método, ano, caminhos, tamanhos, dimensões, MD5 das fixtures,
  plataforma e intervalo de amostragem;
- `array-sizes.csv`: carga teórica dos arranjos densos;
- `session-info.txt`: versão de R e pacotes efetivamente carregados.

Conserve os seis arquivos ao publicar uma nova medição. Uma comparação só é
válida se método, ano, dimensões, MD5 das fixtures, número de repetições,
política de threads e plataforma estiverem explícitos.
