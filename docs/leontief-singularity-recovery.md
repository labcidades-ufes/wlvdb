# Roadmap: recuperação de sistemas singulares na inversão de Leontief

Branch: `agent/leontief-singularity-recovery` (criado a partir de `master`).

## 1. Contexto e estado atual

- O passo central do cálculo é a solução do sistema de Leontief `t(I - C) lambda = l`
  no bloco produtivo, implementada em `wlv_solve_leontief`
  ([scripts/lib/leontief_diagnostics.R](../scripts/lib/leontief_diagnostics.R)).
  Chamada pelos módulos `matrix.transformation`
  ([scripts/modules/native/matrix_modules.R](../scripts/modules/native/matrix_modules.R))
  e pelo caminho legado `scripts/modules/matrices/transformation.R`.
- O solucionador atual é deliberadamente conservador: qualquer uma das violações
  abaixo interrompe a execução com erro, sem caminho de recuperação:
  - `rcond` (norma do infinito) igual a zero ou indisponível (singular);
  - `rcond < rcond_min`, com `rcond_min` derivado do orçamento de erro direto
    (`forward_error_budget = 1e-8`) e de `n * eps`;
  - erro regressivo/erro direto acima do orçamento após o refinamento iterativo
    (até 2 rodadas, reutilizando a fatoração LU);
  - certificado de produtividade (coeficientes não negativos) ou de convergência
    absoluta (coeficientes com sinais) reprovado, inclusive com a guarda de
    arredondamento.
- Sintoma relatado: as últimas versões baixadas da EXIOBASE não completam a
  inversão. A versão corrente de preparação é a EXIOBASE 3.9.5 (1995-2022, Zenodo
  record 14869924, em `scripts/utils/prepare_exiobase_data.R`), registrada no
  catálogo como experimental com "recovery pending" (`catalog/sources.csv`).
  O arquivo `_leontief_diagnostics.csv` e a mensagem de erro exata do ano que
  falhou devem ser preservados na primeira campanha de diagnóstico.
- Dimensão esperada do sistema: cerca de 9.800 setores (49 regiões x 200 setores
  na variante ixi). Uma matriz densa dessa ordem ocupa ~0,75 GB; SVD e múltiplas
  cópias multiplicam esse custo (ver Fase 3, benchmark).
- Estado dos dados locais: as pastas `source_data/exiobase*` estão vazias neste
  volume; a reprodução exige novo download (conforme o script de preparação).
- Branch `singularity_c`: local e remoto apontam para `724b61a`, commit já contido
  no histórico de `master`. Não há trabalho versionado novo nessa frente.
  Trabalho não commitado pode existir em `borges@38.242.154.34:~/pRojetos/`
  (`worldlabourvalues` ou `wiodvalues`) ou em `/home/wlvdbaj/pRojetos/`;
  verificação pendente (ver Pendências externas).

## 2. Princípios

1. Diagnóstico antes de remédio: nenhum método alternativo de inversão é
   aplicado sem antes classificar a causa e o tamanho do problema.
2. O caminho que não altera os dados fontes (Caminho A) tem precedência
   absoluta sobre o que altera (Caminho B).
3. Toda decisão é auditável: artifacts com fingerprints, contratos e perfis
   explícitos por método/ano, no padrão já usado para `leontief_zero`.
4. Compatibilidade retrógrada: onde o sistema é inversível, o comportamento
   permanece idêntico ao atual; as novas políticas são opt-in.

## 3. Fase 0 - Perfil de singularidade (medir o tamanho do problema)

Objetivo: transformar "a matriz não inverte" em um relatório quantificado por
método e ano, com causa classificada e lista de país/setor responsáveis.

Entregas:

- Função `wlv_leontief_singularity_profile(system_matrix)` em
  `scripts/lib/leontief_diagnostics.R`, reportando:
  - contagens estruturais: número de linhas completamente nulas, número de
    colunas completamente nulas, grupos de colunas duplicadas/colineares
    (QR com pivoteamento, `Matrix::qr`), posto efetivo `k` com tolerância
    ligada a `n * eps` e nulidade `n - k`;
  - medidas numéricas: `rcond` (norma do infinito, já usado), norma do infinito
    e raio espectral aproximado de `C` (iteração de potências sobre `|C|`);
  - medidas econômicas: integração com `wlv_scan_leontief_zero_output_year`
    (produção bruta zero com insumos não nulos), produção bruta mínima
    positiva, trabalho direto nulo em setores produtivos;
  - classificação da causa: (a) linhas/colunas nulas, (b) colinearidade exata
    entre setores, (c) sistema incompatível (resíduo de mínimos quadrados
    diferente de zero), (d) apenas mal-condicionado, (e) inversível.
- Campanha de diagnóstico em `temp/<id>/` criada com
  `scripts/manage-campaigns.ps1 -Action New -Id <id>`: download da EXIOBASE
  3.9.5 pelas URLs do script de preparação e execução apenas do perfil por
  ano (sem rodar o pipeline completo), gravando `_singular_profile.csv`
  em `temp/<id>/results/`.
- Fixtures sintéticas em `tests/fixtures/`: matrizes pequenas construindo cada
  causa (a)-(e) com solução esperada conhecida, para CI independente dos dados.

Aceitação: para cada ano problemático, o perfil reporta `k`, `n - k`, as
coordenadas (país/setor) envolvidas e a causa; a falha deixa de ser uma
mensagem genérica.

## 4. Fase 1 - Caminho A: resolver sem alterar os dados fontes

- A0. Equilíbrio numérico (scaling): reescalar linhas/colunas da matriz do
  sistema antes de fatorar. Não altera a solução em aritmética exata e pode
  recuperar `rcond` sem qualquer mudança de dados. Barato; testar primeiro
  para os casos classificados como (d) mal-condicionado.
- A1. Resolução pelo sub-bloco de posto completo (preferencial): usar a
  permutação do QR pivoteado para separar `k` colunas/linhas independentes,
  resolver o sistema reduzido `k x k` e reconstruir `lambda` completo a partir
  das relações lineares exatas identificadas. Hipóteses típicas a confirmar na
  Fase 0: setores com produção zero (coluna de coeficientes zerada pelo módulo)
  e setores com colunas exatamente proporcionais. A solução estendida deve
  ter resíduo zero e coincidir com a solução de mínima norma.
- A2. Pseudo-inversa de Moore-Penrose (fallback numérico): `pinv` via SVD com
  truncamento na tolerância definida no perfil; devolve a solução de mínimos
  resíduos e mínima norma. Custo alto na ordem de 9.800 (ver Fase 3); avaliar
  decomposições parciais/esparsas no benchmark antes de adotar.
- A3. Política `singular_policy` em `wlv_solve_leontief`, com valores:
  - `fail` (padrão, comportamento atual);
  - `structural` (A1);
  - `minimum_norm` (A2).
  Novo artifact `_singular_resolution_diagnostics.csv` (posto, nulidade,
  tolerâncias, resíduo, norma da solução, colunas dependentes, fingerprint de
  lambda) e colunas novas em `_leontief_diagnostics.csv`, com atualização dos
  contratos em `result_contracts.R` e `scientific_validation.R`.
- A4. Critérios de aceite das políticas A:
  - resíduo dentro do orçamento de erro vigente;
  - `lambda >= 0` quando `C >= 0` (a não-negatividade deve valer no bloco de
    posto completo);
  - certificado de produtividade/convergência avaliado no bloco reduzido.

## 5. Fase 2 - Caminho B: ajustes mínimos e auditados nos dados (último recurso)

Só entra em cena se a Fase 0 detectar sistema incompatível (informação
conflitante na fonte), caso em que nenhum método sem alteração produz resíduo
zero.

- B1. Regularização de Tikhonov: menor `epsilon` que restabelece
  `rcond >= rcond_min`, escolhido por busca binária; reportar a curva
  `epsilon` x distorção de `lambda`.
- B2. Correção de balanço mínima: ajuste biproporcional (RAS) restrito às
  células culpadas identificadas na Fase 0 (priorizar células quase nulas ou
  do agregado RoW); artifact listando célula, valor original, valor novo e
  motivo, com `policy_id` e md5 das coordenadas, no padrão do allowlist
  `leontief_zero`.
- B3. Fronteira A/B: fusão de setores exatamente colineares feita apenas na
  etapa de resolução pertence ao Caminho A (A1); o Caminho B se restringe a
  alterações de células publicadas, sempre atrás de perfil versionado por
  método/ano. Nada entra no fluxo padrão.

## 6. Fase 3 - Validação, contratos e documentação

- Testes: ampliar `tests/testthat/test-leontief-diagnostics.R` com as fixtures
  sintéticas da Fase 0; oráculo por causa x política; paridade A1 vs. A2 em
  sistemas compatíveis.
- Benchmark: estender `scripts/benchmark_leontief.R` com as estratégias novas
  (tempo e RSS por ano na ordem de 9.800), comparando com a LU densa atual.
- Documentação: atualizar `methodology-pt.md`/`methodology-en.md`,
  `scientific-validation.md` e `assumptions-pt.md`/`assumptions-en.md`
  (substituir "sistemas quase singulares exigem diagnóstico" pela política
  definida e seus limites).

## 7. Marcos e ordem de execução

| Marco | Conteúdo | Gatilho |
|-------|----------|---------|
| M0 | Fase 0 completa: ferramenta de perfil + campanha de diagnóstico + fixtures | sempre |
| M1 | A0 + A1 + A3 (`structural`) + testes | sempre |
| M2 | A2 (`minimum_norm`) + benchmark de custo | se M0 mostrar colinearidades que A1 não cobrir ou custo aceitável |
| M3 | B1/B2 com perfis auditados | somente se M0 detectar incompatibilidade real |
| M4 | Contratos, publicação e documentação | após M1 (e M2/M3 se atingidos) |

Árvore de decisão no tempo de execução:

1. `rcond > 0` e `>= rcond_min`: fluxo atual, sem mudanças.
2. posto completo, mas mal-condicionado: A0 (equilíbrio) e, se persistir,
   revisão da política numérica com o perfil em mãos.
3. posto `k < n` e sistema compatível: A1 (estrutural), fallback A2.
4. sistema incompatível: Caminho B com distorção mínima auditada.

## 8. Pendências externas

- Verificar trabalho não commitado nos hosts remotos antes de implementar
  (evita retrabalho): em `borges@38.242.154.34` e, se aplicável, no usuário
  `wlvdbaj`, inspecionar `~/pRojetos/worldlabourvalues` e `~/pRojetos/wiodvalues`
  com `git status`/`git stash list`; se houver trabalho útil, trazer como patch
  para este branch. O acesso direto por SSH não está disponível neste ambiente.
- Repor os downloads da EXIOBASE 3.9.5 (pastas `source_data/exiobase*` vazias)
  dentro da campanha da Fase 0, respeitando a política de campanhas
  (`docs/local-campaigns.md`).
