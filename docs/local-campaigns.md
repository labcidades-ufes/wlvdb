# Campanhas e limpeza local

Toda campanha ou experimento fica em `temp/<id>/`, dentro do checkout principal.
Isso inclui worktrees Git, fontes copiadas, resultados, logs e arquivos temporários.
O diretório é ignorado pelo Git. O código reutilizável continua em `scripts/` e
`tests/manual/`.

`tests/` é código-fonte versionado: contém verificações automáticas, ferramentas
de prova manual e dados de exemplo controlados (*fixtures*) que permitem
detectar regressões. Saídas dos testes, relatórios gerados e logs pertencem à
campanha, não a `tests/` nem ao código da aplicação.

`run_logs/` deixou de ser uma pasta versionada e é ignorada pelo Git. As
ferramentas históricas autenticadas antes guardadas nela foram preservadas,
sem alteração dos bytes, em
`tests/manual/archive/issue13-evidence-source-v5/` e
`tests/manual/archive/issue13-native-gate-orchestrator-v5/`. O
[arquivo de ferramentas](../tests/manual/archive/README.md) explica seu uso
para derivação ou reconstrução na revisão original. Seus caminhos internos
históricos não são comandos para executar no checkout atual. Novos logs
continuam obrigatoriamente em `temp/<id>/logs/`.

No Windows, os comandos de gerenciamento requerem PowerShell 7.5 ou posterior
(`scripts/*.ps1`). No Linux, use os equivalentes em bash: `scripts/manage-campaigns.sh`,
`scripts/run-experiment.sh` e `scripts/campaign-paths.sh` cobrem todas as
ações, inclusive `Clean`. A verificação de processos em uso usa
`/proc/*/cmdline` no lugar de `Get-CimInstance Win32_Process`. Os manifests
`.campaign.json` e a pasta `temp/` são compartilhados entre os dois ambientes:
o formato escrito por uma ferramenta é lido pela outra. Os runners hospedados
 da CI continuam usando os scripts `.ps1`.

## Criar e executar

Para preparar uma campanha composta de várias etapas, na raiz do projeto:

```powershell
pwsh -File scripts/manage-campaigns.ps1 -Action New -Id teste-055 -Purpose 'Comparação de desempenho'
```

No Linux, o equivalente é:

```bash
bash scripts/manage-campaigns.sh -Action New -Id teste-055 -Purpose 'Comparação de desempenho'
```

O comando cria `worktrees/`, `scratch/`, `logs/` e `results/`, além de
`.campaign.json`, que registra commit, finalidade, estado e preservação.
Use somente esses diretórios para os artefatos da campanha.

Para executar um comando em uma campanha nova, com os temporários dos processos
filhos direcionados para dentro dela:

```powershell
./scripts/run-experiment.ps1 -Id teste-056 -Executable Rscript `
  -ArgumentList @('--vanilla', 'scripts/benchmark_leontief.R') `
  -Purpose 'Benchmark Leontief' -Preserve
```

No Linux, os argumentos do programa vão depois de `--`:

```bash
bash scripts/run-experiment.sh -Id teste-056 -Purpose 'Benchmark Leontief' -Preserve \
  -Executable Rscript -- --vanilla scripts/benchmark_leontief.R
```

O executor configura `TEMP`, `TMP`, `TMPDIR` e `WLV_CAMPAIGN_ROOT`, captura o log
em UTF-8 e registra conclusão ou falha. Os argumentos de saída dos programas
também precisam apontar para a campanha; variáveis de ambiente não redirecionam
arquivos com caminhos explicitamente definidos pelo programa.

Para campanhas de várias etapas, configure essas quatro variáveis no processo
lançador antes de iniciar R/Python/PowerShell. Os escritores JSON da campanha
manual da issue 13 rejeitam destinos externos a `temp/<id>/` e campanhas fechadas.
O provisionador de desempenho aplica a mesma restrição antes de copiar dados.
Scripts históricos arquivados conservam seus bytes e não devem ser executados
diretamente como lançadores de campanhas novas.

## Encerrar e limpar

Depois de encerrar os processos e revisar os resultados:

```powershell
pwsh -File scripts/manage-campaigns.ps1 -Action Complete -Id teste-055
pwsh -File scripts/manage-campaigns.ps1 -Action Clean
pwsh -File scripts/manage-campaigns.ps1 -Action Clean -Apply
```

No Linux:

```bash
bash scripts/manage-campaigns.sh -Action Complete -Id teste-055
bash scripts/manage-campaigns.sh -Action Clean
bash scripts/manage-campaigns.sh -Action Clean -Apply
```

Use `Fail` para uma campanha abandonada ou reprovada. Use `-Preserve` em `New`,
`Complete` ou `Fail` quando a campanha precisar permanecer para consulta.
`Status` lista campanhas e seus estados; `Clean -Id <id>` limita o alvo.

`Clean` faz uma simulação por padrão. `-Apply` exclui somente campanhas encerradas
e não preservadas, depois de verificar os caminhos, manifests, processos, locks,
links e o estado das worktrees. Uma worktree com alterações versionadas ou
arquivos não rastreados bloqueia a limpeza; dados ignorados pelo Git são
descartáveis quando a campanha foi encerrada sem preservação. O comando remove
as worktrees pelo Git antes de remover a pasta da campanha.

A limpeza faz parte do encerramento: não acumule campanhas, tentativas ou caches
sem finalidade. Se for preciso preservar apenas um relatório, guarde-o com sua
proveniência antes de descartar as fontes e resultados intermediários.

## Arquivo 054

`temp/054/` está marcado como `archived` e `preserve=true`; o comando de limpeza
também protege explicitamente esse identificador. A pasta contém `main/`,
`performance/`, pequenas dependências de tooling e os registros da realocação.
Os arquivos autenticados conservam o conteúdo original. `relocation-map.json`
relaciona os caminhos históricos com os atuais. Consulte o `README.md` dentro
desse arquivo para verificar sua integridade e localizar as provas finais.

Essa pasta não é o destino de novos experimentos e não deve ser reexecutada.
Excluir ou modificar a 054 requer nova instrução explícita do usuário.

`source_data/`, `results/`, `renv/` e `.git/` do checkout principal são preservados
pelo gerenciamento de campanhas. A retenção de publicações do banco é uma
operação separada, descrita em `publication-storage.md`.
