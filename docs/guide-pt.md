# Guia do WLVDB para economistas

<!-- documentation-revision: wiod-reader-workflows-v2 -->

Português | [English](guide-en.md) | [Início](../README-PT.md) | [Dicionário](results-dictionary-pt.md)

## Entender o projeto

O Banco de Dados de Valores Trabalho Mundiais transforma registros monetários
de produção e comércio em estimativas do trabalho necessário para reproduzir
os bens. Ele ajuda a estudar a distribuição internacional do trabalho, a relação
entre remuneração e reprodução da força de trabalho e transferências associadas
ao comércio. O WLVPanel apresenta os resultados publicados pelo banco.

Para uma primeira leitura, siga esta seção e a [metodologia](#metodologia).
Para trabalhar com dados existentes, vá a [usar os resultados](#usar-os-resultados)
e consulte o dicionário. Para produzir novos resultados, siga
[executar o projeto](#executar-o-projeto). O [mapa do código](#compreender-o-código)
acompanha o mesmo percurso dos dados.

Este guia conecta três tipos de trabalho. A [teoria](theory-pt.md) explica
o significado dos conceitos e por que as contas de insumo-produto permitem
estimá-los; a [metodologia matemática](methodology-pt.md) desenvolve as
equações; as [hipóteses e tarefas pendentes](assumptions-pt.md) identificam
as condições de interpretação das estimativas. Consulte as
[referências em ABNT](references-pt.md) para a literatura metodológica.

| Seu objetivo imediato | O que é necessário | Por onde começar |
| --- | --- | --- |
| Analisar um indicador existente | Uma publicação autenticada dos resultados, R e o dicionário. | [Usar os resultados](#usar-os-resultados). |
| Reproduzir o banco de dados | Código identificado, fontes fixadas, ambiente de pacotes, tempo e armazenamento. | [Escolher o nível de reprodução](#escolher-o-nível-de-reprodução). |
| Melhorar uma fórmula ou ampliar a cobertura | Uma pergunta econômica explícita, uma alteração no código e evidências adequadas à mudança. | [Contribuir com uma melhoria](#contribuir-com-uma-melhoria). |

### Cobertura e limites

| Método executável | Anos | Países/regiões na fonte | Setores | Indicadores publicados |
| --- | --- | --- | --- | --- |
| `wiodr13` | 1995–2009 | 40 países e resto do mundo | 35 | 58 |
| `wiodr16` | 2000–2014 | 43 países e resto do mundo | 56 | 50 |

WIOD significa *World Input-Output Database*, ou Banco Mundial de
Insumo-Produto. Os números 13 e 16 identificam edições da fonte, não o último
ano calculado. A edição WIOD 2013 alcança 2011 na origem, mas o contrato deste
método termina em 2009. A cobertura dos dados de capital WIOD13 cai em
2008–2009. A preparação histórica converte um conjunto fixado de ausências
da fonte em zero; portanto os arquivos podem conter capital e taxas finitos
nesses anos, sem cobertura econômica completa. O WLVPanel exclui 2008–2009
de todas as séries WIOD13 por essa limitação: sua cobertura prática termina
em 2007. Isso é um filtro do painel, não uma máscara geral de `NA` no banco.
Não interprete zeros de compatibilidade como capital observado nulo. A mudança de
classificação setorial entre as edições impede unir as séries por posição ou
pelo nome parecido de um setor. Consulte os rótulos do run e construa uma
correspondência econômica explícita antes de comparar fontes.

Os dois métodos tratam uma hora de trabalho com o mesmo peso. A classificação
entre trabalho produtivo e improdutivo é uma escolha metodológica, registrada
em `methods/<método>/_sectors.csv`, não uma característica natural dos dados.
As estimativas dependem também de imputações para o resto do mundo, dados
complementares da China no WIOD16, composição de capital e tratamento de
anomalias. Os resultados não demonstram, por si sós, uma explicação causal
para diferenças entre países. EXIOBASE e EORA pertencem somente à expansão
futura; métodos alternativos e geração de artigos não são executáveis aqui.

### Glossário antes das fórmulas

| Termo | Significado e identificador |
| --- | --- |
| Insumo-produto | Registro de quanto cada setor fornece aos demais e à demanda final. IO é sua abreviação inglesa. |
| Produto bruto / valor adicionado | Produto bruto inclui insumos intermediários (`gross_output`); valor adicionado os desconta (`gdp`). PIB é produto interno bruto. |
| Contas socioeconômicas | Emprego, horas, remuneração e capital associados aos setores. SEA abrevia *Socio-Economic Accounts*. |
| Pessoas ocupadas / empregados | `emp` inclui assalariados e não assalariados; `empe` inclui empregados. Não são intercambiáveis. |
| Trabalho abstrato | Horas ponderadas pelo multiplicador metodológico (`abstract_labour`), igual a 1 nos métodos atuais. |
| Valor incorporado | Trabalho direto mais trabalho exigido pelos insumos e depreciação (`values`, `value.m.mv`). |
| Capital variável / força de trabalho | Estimativa do valor da cesta financiada pelos salários (`labour_force_value`), não os salários em dólares. |
| Mais-valia / taxa de exploração | Trabalho abstrato dividido pelo valor da força de trabalho, menos 1 (`surplus_value`). A versão produtiva restringe setores. |
| Capital constante / depreciação | Insumos e ativos usados na produção, e parcela anual de desgaste destes; `k_composition` e `k_depreciation` distribuem os ativos por origem e uso. |
| Formação bruta de capital fixo | FBCF, ou GFCF em inglês: investimento que ajuda a distribuir o estoque de capital entre fornecedores. |
| EU KLEMS | Fonte europeia de capital (K), trabalho (L), energia (E), materiais (M) e serviços (S), usada aqui para composição e depreciação do capital. |
| Cesta de consumo | Participações das compras de consumo das famílias, usadas para estimar a reprodução da força de trabalho. |
| Preço direto | Preço proporcional ao trabalho incorporado, convertido por um fator mundial em USD (`.du`). Não é um preço observado. |
| Resto do mundo / mundo | `ROW` é a região residual da fonte; `WWW` é a soma mundial calculada. Somar ambos novamente duplica o total. |
| USD / moeda local | Dólar dos Estados Unidos / moeda de cada país. Câmbio é moeda local por USD. |
| Índice / razão / média ponderada | Índice compara a um ano-base; razão divide duas quantidades; média ponderada dá maior peso aos componentes economicamente maiores. |
| Matriz / arranjo / eixo | Matriz é uma tabela de linhas e colunas; um arranjo acrescenta eixos, como ano e indicador. Um eixo identifica uma dessas dimensões. |
| Vetor / sistema linear | Lista ordenada de números / conjunto de relações de soma e multiplicação entre quantidades a determinar. |
| Módulo / dependência | Função que calcula uma parte do resultado / entrada necessária para essa função. |
| Run / release / canal | Execução publicada imutável / conjunto coerente dessas execuções / nome que seleciona sua versão corrente. |
| Manifesto / checksum / proveniência | Inventário de arquivos / impressão digital calculada dos bytes / registro da origem dos dados, código e ambiente. |
| Contrato / sidecar | Regra verificável de unidades, estrutura ou ciência / arquivo auxiliar que acompanha os valores. |

Os identificadores usam convenções históricas: `.s` costuma indicar total,
`.m` medida média, `.r` razão, `.us` USD, `.mv` magnitude de valor, `.hr`
horas, `.un` contagem ou fator. `.p` e `.u` distinguem componentes produtivos
e improdutivos. `hs`, `ms`, `ls` são alta, média e baixa qualificação. Não
deduza a unidade apenas do sufixo: `.cu` em remunerações é USD constante,
e `.pc` pode ser parcela ou índice. O dicionário resolve todos os casos.

## Metodologia

Cada célula da matriz monetária anual registra uma entrega do setor-país da
**linha** ao comprador da **coluna**. As primeiras colunas são setores
produtores; as seguintes são consumo, investimento e demais categorias de
demanda final. Uma soma de linha mede vendas do fornecedor. Uma soma de
coluna reúne insumos usados pelo comprador. Na matriz de capital, somar uma
coluna recupera o estoque do setor que usa os ativos. Essa orientação deve ser
preservada: transpor a tabela muda o significado econômico.

O cálculo passa por estas operações:

1. **Normalizar:** converter milhões de USD em USD, milhares de pessoas em
   pessoas e milhões de horas em horas. Índices de preço em base 100 passam a
   base 1 na geração normalizada. A conversão fica registrada; não se repete
   na leitura de resultados.
2. **Construir trabalho e capital:** converter remunerações pela razão dos
   totais nacionais de valor adicionado em moeda local e USD. Multiplicar
   horas pelo fator de trabalho complexo. Distribuir capital com composição
   EU KLEMS e investimento WIOD e aplicar a depreciação do ano seguinte.
3. **Calcular trabalho incorporado:** em cada coluna produtiva, dividir
   insumos intermediários mais depreciação pelo produto bruto. A matriz
   resultante, chamada `C`, informa quanto insumo monetário é necessário por
   USD de produto. O vetor `l` informa horas diretas por USD. O vetor
   `lambda` satisfaz `lambda = l + t(C) × lambda`: cada mercadoria incorpora
   seu trabalho direto e o de seus insumos. `t(C)` troca linhas por colunas
   para somar os requisitos do comprador. O programa resolve
   `t(I - C) × lambda = l`, onde `I` mantém cada componente no próprio lugar.
   Não precisa formar a inversa inteira. Somente os setores classificados como
   produtivos entram no sistema; a saída respeita os zeros estruturais.
4. **Estimar cestas e comércio:** multiplicar os fluxos monetários pelo
   `lambda` do fornecedor para obter horas incorporadas. A cesta de consumo
   nacional converte a remuneração em custo de reprodução em horas. Uma cesta
   fixa, de 1995 no WIOD13 e 2000 no WIOD16, fundamenta os índices; os índices
   publicados são depois rebaseados em 2000. Ano da cesta e ano de apresentação
   são conceitos diferentes.
5. **Agregar e validar:** somar extensões (horas, pessoas e montantes), usar
   pesos ou razões de totais para intensidades e taxas, verificar identidades
   econômicas e erros numéricos, e publicar somente o conjunto validado.

Um exemplo de um único setor: se cada USD de produto exige USD 0,20 de insumos
e 0,40 hora direta, cada unidade incorpora `0,40 / (1 - 0,20) = 0,50` hora.
USD 100 de produto representam 50 horas, das quais 40 são diretas e 10
incorporadas nos insumos. É um exemplo didático, sem dados WIOD.

```r
coefficient <- 0.20
direct_hours <- 0.40
embodied_hours <- direct_hours / (1 - coefficient)
stopifnot(abs(embodied_hours - 0.50) < 1e-12)
```

Se os empregados realizam 1.000 horas abstratas e sua cesta exige 400 horas,
a taxa de mais-valia é `1000 / 400 - 1 = 1,5`, exibida como 150%. Isso não
autoriza substituir a cesta em horas pelo salário em USD. A taxa de lucro
apropriado usa `(remuneração do capital - depreciação) / estoque de capital`:
é uma aproximação contábil, distinta da taxa marxiana de mais-valia sobre
capital constante mais variável.

Nas transferências, o fator anual relaciona trabalho incorporado no comércio
aos preços do comércio produtivo mundial. Para cada fluxo, compara-se o valor
representado pelo preço ao trabalho efetivamente incorporado. O saldo nacional
positivo indica recebimento líquido. Na matriz bilateral `m_countries`, a soma
dos fluxos `transfers_productive_values` se anula dentro da tolerância;
`transfers_values`, que inclui setores improdutivos, não tem essa obrigação.
Essa soma de fluxos difere da soma dos saldos nacionais de exportações menos
importações, que se cancelam mundialmente por construção. Preços diretos usam outro fator: produto bruto
mundial em USD dividido pelo produto bruto mundial em horas.

### Hipóteses que afetam a interpretação

O resto do mundo não possui contas completas observadas: os módulos combinam
emprego complementar com horas e intensidade de capital dos países de referência,
além de índices de preço. As remunerações e as contas dos empregados de ROW
permanecem ausentes no método público. No WIOD16, a China recebe horas por trabalhador
derivadas do WIOD13 e todos os ocupados são tratados como empregados. O último
coeficiente disponível é mantido até 2014. Essa correspondência setorial tem um
arquivo histórico autenticado, mas não um script original de reconstrução.
O WIOD13 também aproxima os empregados chineses por todas as pessoas ocupadas,
tanto na contagem de pessoas quanto nas horas; as participações por qualificação
são informações próprias dessa edição, sem equivalente publicado no WIOD16.

Valores negativos conhecidos não são apagados indiscriminadamente. Na alocação
de capital, 24 células de FBCF WIOD13 e 649 WIOD16 são truncadas a zero somente
após conferir posições e magnitudes exatas. O dado bruto permanece intacto.
Há 93 colunas WIOD13 e 120 WIOD16 com distribuição alternativa pela FBCF
nacional. WIOD13 preserva a exceção de capital com sinal de `2006/GBR.23`.
WIOD16 tem exceções próprias de capital, pesos EU KLEMS, Malta e Romênia.
Os [contratos WIOD13](wiodr13.md) e [WIOD16](wiodr16.md) enumeram esses casos;
os relatórios publicados permitem avaliar sua relevância para uma análise.

Uma média simples geralmente não representa uma taxa agregada. Dois setores
com índices 1 e 3 e produtos 10 e 30 têm índice ponderado 2,5. Dois setores
com valores incorporados 20 e 120 horas e produtos 10 e 30 USD têm intensidade
agregada `140 / 40 = 3,5` horas/USD. Câmbios e índices nacionais não recebem
média mundial, porque as moedas e bases econômicas não são comparáveis.

## Usar os resultados

Os dados estão disponíveis no [World Labour Values](https://panel.worldlabourvalues.org/)
e no [LabCidades/UFES](http://labcidades.ufes.br/worldlabourvalues/).
O [percurso de uso](use-results-pt.md) começa pela consulta no navegador e
acompanha seleção, cobertura, interpretação e citação, sem exigir R.
As [fichas por família](indicator-families-pt.md) ajudam a escolher o indicador.

Clonar este repositório fornece código, configurações, documentação e
suplementos versionados; `source_data/` e `results/` não são incluídos no Git.
Uma seleção exportada pelo site é adequada ao trabalho de análise conforme
seus campos e metadados. Ela não deve ser tratada como uma publicação nativa
completa: os exemplos de leitura FST abaixo exigem a árvore de canal, release
e runs referenciados, com manifestos e arquivos auxiliares. Confira o conteúdo
do material obtido antes de escolher o leitor; um CSV ou uma planilha não é
entrada para `read_fst_array()`. O cálculo completo descrito neste guia também
produz a publicação nativa. As fixtures dos testes são ilustrativas.

### Arquivos e unidades

Uma execução publicada, ou *run*, fica em `results/runs/<método>/<run_id>/`.
Uma *release* em `results/releases/<release_id>/` fixa quais runs pertencem
juntos à versão publicada. O canal `stable`, em `results/channels/stable/`,
aponta para a release corrente por marcadores numerados. `stable` é um nome
de seleção, não uma certificação externa. O identificador da execução é
diferente do `result_id`, que identifica o conteúdo estável do resultado.

| Arquivo | Conteúdo e ordem dos eixos |
| --- | --- |
| `sea_sectors.fst` | Ano, indicador, setor, país. Contas setoriais. |
| `sea_countries.fst` | Ano, indicador, país. Agregados nacionais e `WWW`. |
| `m_io*.fst` | Ano, indicador matricial, entrada, saída. Pode estar dividido por períodos; confira os anos de cada arquivo. |
| `m_countries.fst` | Ano, indicador matricial, país de origem, país de destino. Fluxos bilaterais, diagonal doméstica zero. |
| `*.fst.meta` | Dimensões, rótulos e vínculo criptográfico ao arquivo FST. FST é o formato binário de armazenamento de tabelas usado aqui. |
| `_unit_contract.csv` | Unidade armazenada, multiplicador de apresentação, base de índice e regras de agregação efetivamente executadas. |
| `_states.csv` / `_anomalies.csv` | Motivo dos valores ausentes / eventos e tratamentos especiais, incluindo cobertura parcial. |
| `_scientific_checks.csv` / `_leontief_diagnostics.csv` | Identidades econômicas verificadas / estabilidade e precisão do sistema linear. |
| `_gfcf_negative_cells.csv` / `_gfcf_negative_summary.csv` | Células de investimento alteradas na alocação e resumos do efeito. |
| `_method_solutions.csv` / `meta_indicators.RDS` | Seleção dos indicadores / descrições e metadados de apresentação específicos do método. |
| `run_manifest.json` / `release_manifest.json` | Inventários, hashes, identidade e proveniência da execução / da versão publicada. |

CSV é uma tabela de texto (nestes sidecars, separada por ponto e vírgula);
RDS armazena um objeto R e JSON registra campos estruturados legíveis como texto.

Na matriz `m_io`, `values` mede horas abstratas, `k_composition` e
`k_depreciation` medem USD e `consumption_basket` contém participações sem
unidade. O bloco de demanda final da cesta não se aplica. `transfers_values`
mede transferências em horas. As matrizes de capital têm domínio próprio de
colunas: não presuma que todos os indicadores matriciais preencham a mesma
região retangular. O leitor e os metadados preservam a forma efetiva.

Cada indicador está explicado no [dicionário completo](results-dictionary-pt.md).
O valor armazenado 1 de um índice representa 2000 = 1. WIOD13 o apresenta
como 1; WIOD16 usa 100 pontos, conforme o contrato específico. Uma taxa
armazenada 0,25 pode ser exibida como 25%. Aplique
`display_multiplier` uma única vez. Não aplique uma regra adicional baseada
no antigo campo `type`. Valores monetários correntes não descontam inflação;
horas abstratas também dependem das hipóteses do método. Compare sempre mesma
unidade, conceito de trabalho, classificação e versão do contrato.

`NA` é ausência, não zero. `source_missing` identifica ausência declarada da
fonte, `not_applicable` uma operação sem significado naquela coordenada.
`uncomputed` é uma etapa ainda não calculada e não pode ser publicada.
`NaN` e infinitos são erros, não categorias de ausência. Agregações podem usar
componentes disponíveis e registrar cobertura parcial; um grupo inteiro
ausente continua `NA`. Não some países incluindo `WWW`, nem calcule taxas
nacionais pela média de taxas setoriais.

As razões padrão somam numerador e denominador independentemente, de modo
que suas coberturas podem diferir. Por exemplo, taxas mundiais (`WWW`) de
mais-valia das pessoas ocupadas podem incluir horas do ROW sem custos de
reprodução correspondentes, pois a remuneração do ROW está ausente. Examine
a cobertura de cada componente antes de usar a taxa; um resultado finito
não garante populações correspondentes.

### Ler e selecionar dados em R

R é a linguagem utilizada nos cálculos. As instruções abaixo são executadas
na raiz do repositório, depois de instalar os pacotes e ter uma release
publicada. `source()` carrega um arquivo de instruções; `<-` atribui um nome
a um objeto. O bootstrap abaixo cria o ambiente privado chamado `wlv`.
`scripts/main.R` não deve ser carregado diretamente.

```r
source("renv/activate.R")
bootstrap <- new.env(parent = baseenv())
sys.source("scripts/runtime_bootstrap.R", envir = bootstrap)
wlv <- bootstrap$wlv_load_runtime(".")
run_dir <- wlv$wlv_current_result_dir("wiodr13", root = ".", channel = "stable")
countries <- wlv$read_fst_array(file.path(run_dir, "sea_countries.fst"))
dimnames(countries)
gdp <- countries[, "gdp.s.us", "BRA", drop = FALSE]
print(gdp)
units <- read.csv2(file.path(run_dir, "_unit_contract.csv"), stringsAsFactors = FALSE)
units[units$indicator == "gdp.s.us", ]
states <- read.csv2(file.path(run_dir, "_states.csv"), stringsAsFactors = FALSE)
head(states)
```

O leitor resolve a cadeia de manifestos antes de carregar o resultado. Não
escolha o diretório com a data mais recente manualmente. Dentro dos colchetes,
uma posição vazia seleciona todos os anos; os nomes selecionam indicador e
país. `drop = FALSE` conserva os eixos, mesmo ao selecionar um único país.
Use os nomes retornados por `dimnames`, nunca posições supostas. Troque o
método por `wiodr16` para ler a outra fonte.

### Transformar uma série selecionada em tabela de análise

A pergunta inicial é a taxa de mais-valia dos empregados dos setores
classificados como produtivos no Brasil, de 1995 a 2007. O código continua
a sessão anterior, conserva todos os anos para auditoria e marca o recorte
pretendido; a razão armazenada e a porcentagem exibida têm a mesma definição.
O [exemplo completo](use-results-pt.md#ler-uma-publicação-nativa-em-r) relaciona
a série aos estados e às anomalias antes de uma decisão de uso.

```r
indicator <- "surplus_value.empe_p.r.pc"
unit <- unique(units[units$indicator == indicator,
  c("canonical_unit", "display_unit", "display_multiplier")])
stopifnot(nrow(unit) == 1L)
series <- countries[, indicator, "BRA", drop = FALSE]
analysis <- data.frame(
  year = as.integer(dimnames(series)[[1L]]),
  country = "BRA",
  indicator = indicator,
  stored_value = as.vector(series),
  stringsAsFactors = FALSE
)
analysis$display_value <- analysis$stored_value *
  as.numeric(unit$display_multiplier[[1L]])
analysis$display_unit <- unit$display_unit[[1L]]
analysis$in_requested_period <- analysis$year %in% 1995:2007
analysis$wiodr13_coverage_alert <- analysis$year %in% 2008:2009
print(analysis)
```

O sidecar de unidades repete cada indicador para seus níveis de agregação;
`unique()` extrai a definição de exibição comum a esses níveis. O objeto
`analysis` é um data frame comum do R, adequado para gráficos, modelos
estatísticos ou exportação explícita em CSV no seu projeto de análise.
As observações ausentes continuam ausentes. Consulte `_states.csv` e
`_anomalies.csv` antes de interpretar uma série ou descartar linhas.

Este indicador restringe a população aos **empregados de setores produtivos**.
A variante `surplus_value.empe.r.pc` inclui também os setores improdutivos;
`emp` inclui ocupados não assalariados. Essas opções respondem a perguntas
diferentes. Um valor exibido de 150 representa 150%, não 150 horas; a passagem
para 160% equivale a 10 pontos percentuais. Use a taxa nacional publicada,
em vez da média das taxas setoriais. As colunas de recorte não autorizam
inclusão automática: examine estados, anomalias e cobertura dos componentes.
Os anos 2008–2009 continuam na tabela de auditoria, fora do recorte inicial.

### Registrar os dados utilizados na análise

O canal pode selecionar outra release amanhã. Registre o run imutável usado
hoje e preserve os manifestos completos junto à análise:

```r
manifest <- jsonlite::fromJSON(
  file.path(run_dir, "run_manifest.json"), simplifyVector = FALSE)
manifest[c("method", "run_id", "result_id", "parent_run_id")]
manifest$output_contract
str(manifest$result$provenance, max.level = 2L)
```

A proveniência consultada pertence ao cálculo, enquanto o commit do seu
script de análise descreve o que você fez posteriormente com o resultado.
Uma nota de dados adequada identifica ambos, método, anos, códigos dos
indicadores, países/setores, unidades, versões da fonte e do contrato de
unidades, `run_id`, `result_id`, a release correspondente, seleções ou
transformações e data de acesso. Inclua as
[referências bibliográficas](references-pt.md) pertinentes. Cite uma
publicação reproduzida como aquela publicação; não atribua silenciosamente
seus resultados ao checkout atual ou apenas ao canal móvel `stable`.

Para análises externas, copie apenas a seleção necessária e registre o run e
o contrato. Seu script e os resultados da pesquisa podem ficar em outro
projeto. Experimentos feitos dentro deste repositório devem usar uma campanha
em `temp/<id>/`. Não edite os runs publicados. O WLVPanel seleciona o canal
por `WLV_RELEASE_CHANNEL` e valida manifestos, arquivos e metadados; copiar
somente um FST não produz uma publicação íntegra para o painel.

A publicação já é a exportação consumida pelo painel: não há uma segunda
conversão científica a executar. Para instalar os dados em outro checkout do
WLVPanel, disponibilize em sua pasta `results/` a árvore íntegra de canais,
releases e runs referenciados, preservando nomes e bytes. O preparador
`utils/prepare_data.R` do painel lê essa árvore e produz os objetos usados na
apresentação. A instalação e as dependências do aplicativo estão no
[repositório WLVPanel](https://github.com/rodrigofranklin/wlvpanel).

## Executar o projeto

### Escolher o nível de reprodução

| Nível | Operação | O que permite demonstrar |
| --- | --- | --- |
| Reproduzir uma análise | Ler a mesma publicação imutável e repetir o script de seleção, transformação e análise. | Os mesmos dados sustentam a tabela ou conclusão apresentada. Isso não recalcula o banco. |
| Recalcular indicadores selecionados | Usar `recalc_wlv` com um run pai publicado compatível e fontes normalizadas. | Variáveis selecionadas podem ser reconstruídas com reutilização das matrizes autenticadas. |
| Reproduzir o cálculo completo | Restaurar o ambiente identificado, preparar fontes fixadas e executar `get_wlv` ou a CLI. | O banco pode ser reconstruído a partir das entradas estatísticas e hipóteses declaradas. |
| Verificar o software ou a sensibilidade | Executar testes sintéticos ou uma campanha identificada separadamente que varie uma hipótese. | Testes verificam comportamentos definidos; sensibilidade mede a dependência de uma hipótese. Nenhum deles reproduz sozinho o resultado empírico original. |

Primeiro identifique a publicação desejada e a proveniência de seu código e
ambiente. O branch atual contém a implementação atual; não necessariamente
a versão que produziu um resultado histórico. Confira identidades das fontes,
suplementos, classificação e contratos antes de comparar saídas. Uma nova
execução recebe outro `run_id`; compare os valores numéricos segundo as
tolerâncias declaradas, junto com eixos, unidades, ausências e diagnósticos.
Números arredondados iguais ou um código de saída bem-sucedido não bastam.
Reconstruir o banco também não reproduz automaticamente figuras, restrições
amostrais ou especificações de um artigo publicado: isso exige as etapas
de análise do próprio artigo.

### Instalação e preparação

Use Git para obter o repositório e entre na pasta clonada. Git registra as
revisões do código; `git rev-parse HEAD` mostra o commit exato. Instale R 4.6.1,
a versão fixada no `renv.lock` e na integração contínua. Um terminal executa
os comandos `Rscript`; uma sessão R executa os blocos `r` deste guia.
Não digite o marcador de bloco de código junto com o comando.

Obtenha o instalador pela página oficial do [R para Windows](https://cran.r-project.org/bin/windows/base/)
ou siga o [repositório oficial para Ubuntu](https://cran.r-project.org/bin/linux/ubuntu/).
Confirme R 4.6.1 antes de restaurar os pacotes; o R padrão de uma distribuição
antiga pode ter outra versão. No Windows, o [Rtools oficial](https://cran.r-project.org/bin/windows/Rtools/)
informa a ferramenta compatível para compilar pacotes quando necessário.
Com o R correto já instalado, as dependências para compilação dos pacotes
fixados no Ubuntu 24.04 podem ser instaladas com:

```sh
sudo apt-get update
sudo apt-get install --no-install-recommends git build-essential gfortran pkg-config libcurl4-openssl-dev libssl-dev libxml2-dev libicu-dev zlib1g-dev
Rscript --version
```

Essas bibliotecas atendem a curl, openssl, xml2, stringi e componentes C/C++
do `renv.lock`; os comandos `sudo` são exclusivos do Ubuntu. O cálculo atual
não requer um editor gráfico, LaTeX nem ferramentas de geração de artigos.
Escolha livremente seu IDE ou editor; o repositório não versiona arquivos de
projeto do RStudio nem configurações pessoais de IDE. Todos os comandos
documentados funcionam a partir da raiz do repositório em um terminal.

```sh
git clone https://github.com/rodrigofranklin/wlvdb.git
cd wlvdb
Rscript --vanilla scripts/bootstrap.R
Rscript --vanilla scripts/run_wlv.R --help
Rscript --vanilla scripts/run_wlv.R --list-methods
Rscript --vanilla scripts/run_wlv.R --method wiodr13,wiodr16 --prepare-only --check
Rscript --vanilla scripts/run_wlv.R --method wiodr13,wiodr16 --prepare-only
```

`renv` restaura as versões de pacotes registradas; não restaura dados
econômicos. A restauração precisa de internet. No Windows, use binários dos
pacotes quando disponíveis; compilação exige Rtools correspondente à versão
do R. No Ubuntu, dependências compiladas podem exigir ferramentas de
compilação e bibliotecas de desenvolvimento de curl, SSL e XML. A CI
(integração contínua, testes automáticos a cada alteração) executa Windows
2022 e Ubuntu 24.04. Consulte [o workflow](../.github/workflows/r-ci.yml) para
o ambiente exato.

A preparação baixa as fontes fixadas, verifica tamanho e checksum, extrai os
anos suportados, normaliza unidades e valida eixos e ausências. Os dados ficam
em `source_data/`, incluindo `normalized/` e seu manifesto. Arquivos
complementares versionados ficam em `complementar/`. Fontes já em cache são
verificadas antes do reuso. Não é necessário obter um pacote de dados de links
antigos compartilhados. `--check` apenas verifica argumentos e dependências;
é a preparação efetiva que valida as fontes.

Os caminhos de download e as identidades aceitas das fontes estão descritos
nos contratos [WIOD13](wiodr13.md) e [WIOD16](wiodr16.md). A preparação depende
de os provedores continuarem disponibilizando esses arquivos exatos. Se um
arquivo não puder ser obtido ou não passar na verificação de checksum,
conserve o diagnóstico e procure a fonte autenticada; substituí-lo pelo
arquivo mais recente de nome semelhante muda o experimento. Um suplemento
histórico documentado pode ser reproduzido como entrada sem que sua construção
original seja repetível de forma independente: a correspondência das horas
chinesas é uma dessas limitações pendentes.

### Cálculo, recálculo e publicação

```sh
Rscript --vanilla scripts/run_wlv.R --method wiodr13,wiodr16 --workers 1 --channel stable
```

Esse comando calcula os dois métodos e só publica a release quando ambos
passam. Para preparar e calcular em uma chamada, acrescente `--repeat-pp`.
`workers = 1` executa sequencialmente. Valores maiores criam processos R
auxiliares e podem elevar o consumo de memória; não presuma aceleração linear.
Para uma execução principal em canal separado, use `--channel research/input-v3`.
Uma campanha experimental precisa também de diretórios isolados: mudar apenas
o canal não muda a raiz dos dados e resultados.

Na sessão R inicializada no exemplo de leitura, a API (interface de funções)
oferece:

```r
wlv$prepare_wlv(c("wiodr13", "wiodr16"))
wlv$get_wlv(c("wiodr13", "wiodr16"), workers = 1, channel = "stable")
wlv$recalc_wlv("wiodr13", at_stage = 4, workers = 1, channel = "stable")
wlv$recalc_wlv("wiodr16", at_stage = 5,
  sea_vars = "gross_output.s.du", workers = 1, channel = "stable")
```

Execute somente as operações desejadas: preparação e cálculo acima são
alternativas aos comandos de terminal, não passos adicionais obrigatórios.
As funções públicas retornam invisivelmente os nomes dos métodos processados;
os dados são gravados no run publicado. Leia-os com o leitor de resultados
mostrado acima. A CLI pública e essas funções da API não oferecem filtros
de ano, país ou setor para um cálculo completo: cada método executa sua
cobertura contratada. Selecione uma amostra menor de pesquisa ao ler os
resultados.

Recálculo atualiza variáveis a partir de um run publicado e autenticado,
preservando as matrizes, sem refazer investimento ou a resolução de Leontief.
Ele não é um substituto de cálculo completo após mudar fontes, hipóteses de
matrizes, unidades ou classificação. A fonte normalizada e a proveniência
compatível continuam obrigatórias.

Os estágios aceitos são `1`, `4` e `5`. O estágio 1 refaz variáveis desde o
início e não aceita seleção `sea_vars`. O estágio 4 refaz indicadores que
usam matrizes e os estágios seguintes; o 5 refaz indicadores finais. Seleção
em 4 ou 5 só aceita indicadores existentes e de estágio igual ou posterior.
Somente os indicadores selecionados são substituídos; dependências não
selecionadas usam o pai autenticado. Não há atualização implícita de indicadores
dependentes fora da seleção. Com as mesmas entradas científicas, indicadores
recalculados devem equivaler ao completo dentro das tolerâncias; rótulos,
ausências, zeros estruturais e células não selecionadas são exatos.

A correção de [cálculo/recálculo](validation/issue-28.md) separa no WIOD13 o
índice de preço de origem usado nas cestas do índice publicado rebaseado. O estágio 4
usa `GO_P` da fonte autenticada, com base 1995 = 1 e hipótese USA → ROW,
junto às participações monetárias de consumo de 1995. Substituí-lo pelo índice
setorial em base 2000 alterava os pesos relativos da cesta. A diferença
histórica atingia os dois índices de cesta e as duas remunerações constantes.
Um pai anterior à correção exige novo cálculo completo devido à mudança de
proveniência semântica; não se reatribui a ele a proveniência nova.

Cada publicação escreve em uma área provisória (*staging*), relê os arquivos,
valida ciência e integridade e instala um novo run imutável. O recálculo
registra `parent_run_id`, ligando filho e pai. O marcador do canal é escrito
por último. Se qualquer etapa falhar, a release anterior permanece visível.
Uma falha pode deixar um run sem referência, mas não uma versão parcial
selecionada pelo painel. Um bloqueio global impede publicações concorrentes.

### Recursos

As fontes compactadas WIOD13 somam aproximadamente 300 MB, WIOD16 647 MB, mais
174 MB compartilhados de EU KLEMS. Isso não é o espaço total: há extração,
normalização, matrizes, cópias provisórias e histórico imutável. Uma campanha
anterior conferiu 9,96 GB de arquivos preparados/complementares. Verifique o
espaço livre antes de repetir uma execução; não use outro volume silenciosamente.
MB/GB usam milhões/bilhões de bytes; MiB/GiB usam potências de dois
(1 GiB = 1.073.741.824 bytes). Memória residente é a RAM ocupada pelo processo.

As [medições reais do issue #13](validation/issue-13.md) registram, no candidato
Windows/R 4.6.1, cálculo WIOD16 sequencial em cerca de 1.151 s (19,2 min), com
pico de memória residente de 15,54 GB (14,48 GiB). O recálculo desde estágio 1
usou 736 s e 15,94 GB; estágio 5, 392 s e 2,77 GB. O cálculo WIOD13 com dois
workers usou 427 s e 5,45 GB. São observações daquela máquina e versão,
não mínimos garantidos nem previsões para outros computadores. Reserve memória
para o sistema e cópias transitórias; um computador com 16 GB fica próximo do
pico observado WIOD16. Preparar downloads pela primeira vez pode levar mais
tempo que a preparação com cache medida na campanha.

O [benchmark de Leontief](leontief-benchmark.md) mede apenas um sistema anual:
0,38 s e 121,78 MiB para o bloco produtivo de WIOD16/2013. Não use essa
medição como requisito de memória ou duração do cálculo inteiro.

### Validação e erros frequentes

Os testes sintéticos usam números pequenos para verificar integração; não
substituem a prova científica com as fontes reais. Para reproduzir a suíte,
crie uma campanha e configure `TEMP`, `TMP`, `TMPDIR` antes de iniciar R,
conforme [campanhas locais](local-campaigns.md). Instale
[PowerShell 7.5 ou posterior](https://learn.microsoft.com/powershell/scripting/install/installing-powershell),
abra `pwsh` na raiz do repositório e execute o bloco abaixo. Windows PowerShell
5.1 não atende ao requisito. O mesmo bloco de criação funciona no Ubuntu com
PowerShell instalado; `$campaign` recebe um objeto, não uma linha de texto.
No Linux sem PowerShell, o equivalente em bash devolve linhas `chave=valor`
(use `root=` e `temporary_directory=`) e o bloco fica:

```bash
campaign=$(bash scripts/manage-campaigns.sh -Action New -Id local-check \
  -Purpose 'Local unit and synthetic integration checks')
root=$(printf '%s\n' "$campaign" | sed -n 's/^root=//p')
scratch=$(printf '%s\n' "$campaign" | sed -n 's/^temporary_directory=//p')
export TEMP="$scratch" TMP="$scratch" TMPDIR="$scratch" WLV_CAMPAIGN_ROOT="$root"
R --vanilla
```

```powershell
$campaign = ./scripts/manage-campaigns.ps1 -Action New -Id local-check -Purpose 'Local unit and synthetic integration checks'
$env:TEMP = $campaign.temporary_directory
$env:TMP = $campaign.temporary_directory
$env:TMPDIR = $campaign.temporary_directory
$env:WLV_CAMPAIGN_ROOT = $campaign.root
R --vanilla
```

Se `local-check` já existir, confira `-Action Status -Id local-check` e retome
a campanha existente quando cabível, em vez de criar cópias. Dentro da sessão
R iniciada pelo bloco:

```r
source("renv/activate.R")
testthat::test_dir("tests/testthat", reporter = "summary",
  stop_on_failure = TRUE, stop_on_warning = TRUE)
```

Saia de R sem salvar (`q(save = "no")`), encerre a campanha com `Complete`
ou `Fail` e siga a limpeza documentada. O comando `Clean` inspeciona processos
do Windows e requer Windows; `New`, `Status`, `Complete` e `Fail` funcionam
também em PowerShell no Ubuntu. Na CI hospedada, os runners descartam a
campanha junto com o checkout ao terminar o job. A CI confere PowerShell,
R 4.6.1 e a localização dos temporários antes da suíte; o cache de pacotes
fica em `renv/local/ci-cache/`, separado dos dados de teste.

```sh
Rscript --vanilla scripts/render_method_catalog.R --check
Rscript --vanilla scripts/render_results_dictionary.R --check
```

| Mensagem/situação | Ação |
| --- | --- |
| Pacote ausente | Refaça `scripts/bootstrap.R` com a versão correta do R e conexão à internet. |
| Falha de download/checksum | Preserve a mensagem e o arquivo em questão. Retome pela preparação oficial; não desative hashes nem substitua a fonte por uma versão nova. |
| Não há resultado publicado | Faça cálculo completo no canal desejado antes do recálculo. Diretórios históricos `results/<método>/` não são entradas válidas. |
| Contrato/proveniência incompatível | Faça nova preparação/cálculo completo conforme a mudança. Não altere manifestos para autorizar o arquivo antigo. |
| Estágio/indicador inválido | Use 1, 4 ou 5 e identifique o estágio em `_method_solutions.csv`; seleção é permitida somente em 4 e 5. |
| Erro de ausência, identidade ou Leontief | Leia a coordenada e `results/diagnostics/`. Preserve a prova e corrija a causa; não substitua o valor por zero. |
| Bloqueio ou falta de memória/espaço | Confirme se há execução ativa antes de intervir. Use um worker e limpe somente campanhas encerradas pelo gerenciador. |
| Painel rejeita arquivo | Verifique cadeia completa de canal, release, run, FST e sidecars e o canal configurado. |

## Compreender o código

`scripts/` reúne o código da aplicação e os comandos de manutenção. O
restaurador de pacotes `scripts/bootstrap.R` e o carregador privado
`scripts/runtime_bootstrap.R` têm funções distintas. `tests/` contém código
de verificação e dados de exemplo controlados (*fixtures*) mantidos no Git.
Os resultados gerados pelos testes, logs e dados de campanhas ficam em
`temp/<id>/`, ignorado pelo Git; não devem ser gravados junto ao código de teste.

| Entrada/pasta | Função no percurso |
| --- | --- |
| `scripts/bootstrap.R`, `renv.lock` | Ambiente de pacotes reproduzível. |
| `scripts/run_wlv.R`, `scripts/runtime_bootstrap.R`, `scripts/main.R` | Comandos de terminal, carregamento privado e funções públicas `prepare_wlv`, `get_wlv`, `recalc_wlv`. |
| `catalog/`, `config/`, `parameters/`, `methods/` | Suporte, unidades, seleção de módulos/indicadores, dependências e classificação econômica. Ordem de linhas CSV não define ordem de cálculo. |
| `scripts/preparation/`, `scripts/lib/preparation_*`, `source_normalization.R` | Download verificado, preparação e geração normalizada. |
| `scripts/modules/native/source_modules.R`, `indicator_source_derived_modules.R` | Variáveis observadas e derivadas: emprego, horas, câmbio, capital e preços. |
| `scripts/modules/native/assumption_modules.R`, `capital_matrix_modules.R` | Complementação econômica e alocação de capital. |
| `scripts/modules/native/matrix_modules.R`, `indicator_common_modules.R` | Valores, comércio, cestas e indicadores econômicos. |
| `scripts/lib/native_planner.R`, `native_store.R`, `execution.R` | Ordenação por dependências, gestão dos recursos e cálculo/recálculo. |
| `scripts/lib/scientific_validation.R`, `leontief_diagnostics.R`, `missingness.R` | Identidades, estabilidade numérica e significado das ausências. |
| `scripts/lib/publication*.R`, `contracts/results/` | Proveniência, inventários e publicação transacional para WLVPanel. |
| `tests/testthat/`, `tests/manual/`, `docs/validation/` | Testes automáticos, provas reais reproduzíveis e evidências de versões. |

Comece pelo módulo do indicador de interesse e leia suas entradas, unidades e
hipóteses antes de alterar a fórmula. O grafo de dependências é a lista de
relações “A precisa de B”; ele ordena funções com contexto explícito, sem
executar scripts históricos espalhados pelo repositório. Os
[comentários científicos](code-commenting.md) explicam os pontos de decisão.
Mudar uma regra econômica exige revisar contratos, testes, dicionário e os
dois guias juntos. [Sincronização](documentation-sync.md) define essa revisão.

## Contribuir com uma melhoria

Uma issue registra uma pergunta ou um problema; um pull request (PR) propõe
uma alteração concreta para revisão. As contribuições podem melhorar
explicações, correspondências de fontes, hipóteses econômicas, cálculos
numéricos ou cobertura. Declare qual desses elementos muda para que os
revisores possam avaliar as evidências necessárias.

### Acompanhar um indicador do significado à saída

Considere `surplus_value.empe.r.pc`, a taxa de mais-valia dos empregados.
Sua definição é o trabalho abstrato total dos empregados dividido pelo valor
estimado da força de trabalho dos empregados, menos um. Para investigar ou
melhorar sua implementação:

1. Leia [teoria](theory-pt.md), [metodologia](methodology-pt.md),
   [hipóteses](assumptions-pt.md) e a entrada do dicionário. Especifique a
   população afetada, a unidade e o comportamento esperado antes de mudar
   o código.
2. Localize `wlv_indicator_surplus_value_empe_r_pc_spec()` em
   `scripts/modules/native/indicator_common_modules.R`. A função nomeia os dois
   indicadores de entrada e chama `wlv_native_stage5_ratio_spec()` no mesmo
   arquivo. Essa fábrica compartilhada define o estágio 5, o tratamento do
   denominador zero e o cálculo setorial e nacional. Leia a fábrica além
   da pequena função específica do indicador.
3. Acompanhe o registro em `scripts/modules/native/zz_indicator_registry.R` e a
   seleção em `config/modules/common.csv`. As listas de indicadores publicados
   estão em `config/outputs/sources/wiodr13.csv` e `wiodr16.csv`. Os contratos
   aplicáveis `contracts/units/*_v2-units.csv` e `*_v2-aggregations.csv` definem
   unidades armazenadas, exibição e agregação. `_method_solutions.csv` em um
   run publicado é uma evidência gerada dos estágios selecionados, não um
   arquivo-fonte a editar. Os scripts históricos de nomes semelhantes em
   `scripts/modules/variables/` não substituem a implementação nativa ativa.
4. Use um exemplo calculado de forma independente para definir o comportamento
   esperado. Se dois setores têm 100 e 300 horas de trabalho e valores da
   força de trabalho de 50 e 100 horas, suas taxas são 100% e 200%; a agregada
   é `400 / 150 - 1 = 1.666...`, aproximadamente 166,67%. A média simples
   produz 150% e é incorreta para esse agregado. Inclua também um denominador
   zero e um grupo inteiramente ausente. Esses casos verificam o comportamento
   econômico pretendido, em vez de apenas repetir a implementação no teste.
5. Ajuste as evidências à mudança. Uma correção editorial exige equivalência
   de sentido nos dois idiomas e verificações documentais. Uma correção de
   fórmula exige também testes pertinentes, comparações numéricas e indicação
   dos resultados afetados. Uma hipótese alterada a montante pode exigir
   cálculo completo; o recálculo seletivo não substitui automaticamente
   indicadores dependentes fora da seleção.

Os arquivos pertinentes podem ser localizados na raiz do repositório com:

```sh
rg -n 'surplus_value.empe.r.pc|wlv_native_stage5_ratio_spec' scripts/modules/native config contracts/units docs/indicator-descriptions.csv
```

### Acrescentar um indicador ou ampliar o método

| Alteração proposta | Implementação e documentação a consultar |
| --- | --- |
| Esclarecer um indicador existente | `docs/indicator-descriptions.csv` contém descrições PT/EN; os guias pareados explicam a interpretação. As páginas geradas do dicionário precisam ser regeneradas, não editadas diretamente. |
| Acrescentar um indicador derivado | Especificação de módulo nativo e entrada no registro explícito; módulos selecionados em `config/modules/`; saídas selecionadas em `config/outputs/`; contratos de unidade/agregação aplicáveis; descrições econômicas, tratamento de ausências e testes. |
| Alterar a classificação do trabalho ou uma imputação | `methods/<method>/_sectors.csv`, módulos ativos de hipóteses, dependências matriciais afetadas, contratos científicos e evidências de sensibilidade. Preserve a interpretação dos resultados já publicados. |
| Acrescentar uma fonte estatística ou edição | `catalog/sources.csv`, `catalog/methods.csv`, `scripts/preparation/registry.R`, preparação e normalização da fonte, correspondência de setores/países, políticas de unidades e ausências, módulos nativos e validação independente. Um adaptador de download sozinho não basta. |

Uma fonte adicionada precisa estabelecer quais campos medem produção,
insumos, horas, emprego, remuneração, investimento e capital; suas unidades
e anos; a orientação de cada eixo; e o tratamento dos campos indisponíveis.
Também precisa de identificação e direitos das fontes, classificação
justificada dos setores produtivos, correspondências reproduzíveis e
evidências sobre as estimativas resultantes. EXIOBASE, EORA e métodos
alternativos de redução continuam adiados até que seu percurso público e
sua validação sejam implementados. Mudar um rótulo no catálogo ou usar
`--allow-experimental` não fornece esses componentes pendentes. O
[registro de tarefas pendentes](assumptions-pt.md) distingue essas ampliações
de pesquisa das correções aos métodos atualmente suportados.

Para modificar um indicador, comece pelos testes pertinentes em
`tests/testthat/test-native-indicator-modules.R`,
`test-native-aggregation-registry.R`, `test-unit-dimensions.R`,
`test-missingness-contracts.R` e `test-scientific-validation.R`.
Os testes de integração pública e de recálculo verificam se a mudança funciona
no percurso completo. Execute os testes pelo fluxo de campanhas em
[validação e erros frequentes](#validação-e-erros-frequentes); mantenha
comparações empíricas, logs e worktrees temporárias dentro da campanha.
Nunca use a campanha 054 preservada para uma nova tentativa.

Quando descrições econômicas ou a cobertura dos indicadores mudarem,
regenere e confira os dicionários e então revise as diferenças:

```sh
Rscript --vanilla scripts/render_results_dictionary.R
Rscript --vanilla scripts/render_results_dictionary.R --check
Rscript --vanilla scripts/render_method_catalog.R --check
git diff --check
git status --short
```

Um PR passível de revisão explica o problema econômico, comportamentos anterior
e novo, métodos e períodos afetados, hipóteses e limitações, arquivos alterados
e evidências obtidas. Declare expressamente quais verificações foram executadas
e se houve algum cálculo com fontes reais. Inclua os dois idiomas e atualize
contratos e revisão documental se a semântica científica ou o percurso público
mudar. Mantenha os dados de pesquisa gerados fora do Git. Relate falhas de
download com a identidade da fonte e o diagnóstico; relate discrepâncias
numéricas com método, run, indicador, coordenadas, valor observado e
comportamento esperado.

## Fontes e atribuição

WIOD13 é a edição 2013, DOI [10.34894/XDTAUZ](https://doi.org/10.34894/XDTAUZ);
WIOD16 é a edição 2016, DOI [10.34894/PJ2M1C](https://doi.org/10.34894/PJ2M1C).
Os registros Dataverse consultados em 06/09/2026 eram versão 2.1 e declaravam
Creative Commons Attribution 4.0 International (CC BY 4.0). Essa licença
permite reutilização com atribuição e identificação de alterações. As versões
da edição e do depósito são diferentes; os downloads efetivos são fixados
por IDs de arquivo, tamanho e hash nos contratos [WIOD13](wiodr13.md) e
[WIOD16](wiodr16.md). Um depósito atualizado não altera automaticamente a fonte
que o código aceita.

O [arquivo oficial EU KLEMS 2019](https://euklems.eu/archive-history/) também
declara CC BY 4.0. EU KLEMS designa a análise europeia de capital (K), trabalho
(L), energia (E), materiais (M) e serviços (S). Os dois arquivos estatísticos
compartilhados têm SHA-256 e tamanhos em [WIOD13](wiodr13.md); o ano de
depreciação adicional é necessário. A fonte 2024 que hoje aparece na página
principal não deve substituir silenciosamente a edição histórica.

Complementos em `complementar/` são versionados: emprego do Banco Mundial,
horas da China e tabelas de correspondência/depreciação EU KLEMS. Seu uso é
metodológico e sua identidade é registrada no manifesto do run; eles não são
novas observações WIOD. O arquivo histórico da China e a ausência de script
original de correspondência estão descritos no contrato WIOD16. Os direitos
das fontes continuam aplicáveis aos derivados: não presuma que a licença de
um programa substitui as licenças dos dados. Cite WLVDB com método, período,
commit, contratos e IDs publicados, além das citações oficiais dos provedores.
Não use como referência bibliográfica uma antiga indicação de artigo “no prelo”.

Uma impressão SHA-256 identifica bytes, não a correção de uma hipótese.
`_source_manifest.csv` registra a geração normalizada; o manifesto do run
registra seus hashes, complementos, parâmetros, código, estado de alterações
locais, R, pacotes e hash de `renv.lock`. Preserve esses registros junto com
qualquer seleção usada em análise. As [evidências #13](validation/issue-13.md)
são históricas e a [verificação #28](validation/issue-28.md) registra a correção
do recálculo. A campanha 054 é arquivo preservado, não um comando a repetir.
