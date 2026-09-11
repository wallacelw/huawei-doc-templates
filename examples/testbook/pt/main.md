> **Informação:** Este documento demonstra o template `testbook`
> (`testbook.cls`) para documentos de casos de teste POC/aceitação do
> Huawei Cloud. Ele exercita todos os comandos e ambientes disponíveis:
> capa, sumário, ambiente de caso de teste com todos os comandos de
> campo, bloco de objetivos, blocos de código, imagens, caixas de
> destaque, tabelas, badge e histórico de versões.

# Descrição dos Casos de Teste

> **Objetivo Geral:** Validar a implantação da Plataforma de Dados do
> Huawei Cloud para o ambiente de POC, garantindo que todos os serviços
> principais (DataArts Studio, MRS, OBS, VPC) estejam provisionados
> corretamente, acessíveis e funcionando conforme especificado na
> arquitetura da solução.
>
> **Pré-requisitos:**
>
> -   Conta Huawei Cloud com privilégios de administrador IAM na região
>     `sa-brazil-1`.
>
> -   VPC, sub-rede e grupos de segurança já criados pela equipe de
>     infraestrutura.
>
> -   Instância do DataArts Studio (Dayu) provisionada e licenciada.
>
> -   Cluster MRS implantado com a pilha de componentes necessária
>     (HDFS, YARN, Spark, Hive).
>
> -   Bucket OBS criado e acessível com a política IAM designada.
>
> -   Ambiente de execução de testes com conectividade de rede ao
>     Console do Huawei Cloud.

## Escopo dos Testes

| Domínio | O Que Deve Ser Observado |
| --- | --- |
| Arquitetura da Plataforma | Os serviços principais estão implantados, saudáveis e acessíveis via API do Console. |
| Engenharia de Dados | Os pipelines do DataArts Studio conseguem ingerir, transformar e carregar dados no armazenamento de destino. |
| Armazenamento de Dados | Os buckets OBS e o HDFS do MRS aceitam escritas/leituras com as permissões corretas. |
| Segurança | As políticas IAM, o isolamento VPC e as regras dos grupos de segurança impõem o controle de acesso pretendido. |

## Pré-condições e Preparações

-   Todos os recursos de infraestrutura devem ser provisionados via
    Terraform e a saída de `terraform apply` deve apresentar zero erros.

-   O cluster MRS deve estar no estado **Executando** antes da execução
    de qualquer caso de teste de engenharia de dados.

-   Os arquivos de dados de teste (CSV/JSON) devem ser carregados no
    bucket OBS designado antes da execução dos pipelines.

-   Cada testador deve ter uma conta IAM pessoal com a função
    **Dayu_User** atribuída no DataArts Studio.

-   As regras de firewall de rede devem permitir TCP 22 (SSH) e TCP 443
    (HTTPS) de entrada a partir da sub-rede de execução de testes.

## Método de Aceitação

| Resultado | Explicação |
| --- | --- |
| Satisfeito | O caso de teste passa completamente --- o comportamento observado corresponde ao resultado esperado sem desvios. |
| Satisfeito com ressalvas | O caso de teste passa, mas desvios menores foram observados que não impactam os objetivos da POC (documentados em Observações). |
| Não satisfeito | O caso de teste falha --- o comportamento observado não corresponde ao resultado esperado. Um relatório de defeito deve ser registrado. |
| Não testado | O caso de teste não pôde ser executado devido a dependências bloqueantes ou problemas de ambiente. |

# Arquitetura da Plataforma

## TC-001: Verificar implantação e saúde do cluster MRS

  Field      Description
  ---------- -----------------------------------------------------------------
  Objetivo   Confirmar que o cluster MapReduce Service (MRS) está implantado

    com os componentes necessários (HDFS, YARN, Spark, Hive) e que todos os nós
    apresentam status saudável. |

| Pré-requisitos \| 1. Aplicação da infraestrutura Terraform concluída
  com sucesso. 2. ID do cluster MRS disponível na saída do Terraform. 3.
  Usuário IAM possui função MRS_Viewer ou superior. \|
| Procedimento \| 1. Acessar o Console do Huawei Cloud. 2. Navegar em
  Console, MapReduce Service, Clusters. 3. Localizar o cluster pelo nome
  (ex.: mrs-poc-cluster). 4. Verificar se o status do cluster é
  Executando. 5. Clicar no nome do cluster e revisar a aba Componente
  --- confirmar que HDFS, YARN, Spark e Hive estão listados com status
  Normal. 6. Revisar a aba Nó --- confirmar que todos os nós master e
  core apresentam status Executando. \|
| Resultado Esperado \| 1. Status do cluster é Executando. 2. Todos os
  quatro componentes (HDFS, YARN, Spark, Hive) estão listados com status
  Normal. 3. Todos os nós apresentam status Executando sem alarmes. \|
| Observações \| Se algum componente apresentar status Anormal,
  verificar a página de alarmes do MRS antes de registrar o resultado.
  \|
| Resultado do Teste \| Aprovado \|

## TC-002: Verificar criação e acessibilidade do bucket OBS

  Field      Description
  ---------- ------------------------------------------------------------------
  Objetivo   Confirmar que o bucket do Object Storage Service (OBS) utilizado

    para o data lake da POC está criado, possui a classe de armazenamento correta
    e é acessível com a política IAM designada. |

| Pré-requisitos \| 1. Nome do bucket OBS definido na configuração
  Terraform. 2. Política IAM concedendo acesso de leitura/escrita ao
  bucket está anexada ao usuário de teste. \|
| Procedimento \| 1. Acessar o Console. 2. Navegar em Console, Object
  Storage Service. 3. Localizar o bucket (ex.: poc-datalake-raw). 4.
  Verificar se a classe de armazenamento é Standard. 5. Carregar um
  arquivo de teste (test-upload.txt) no bucket. 6. Baixar o arquivo e
  comparar seu conteúdo com o original. 7. Excluir o arquivo de teste.
  \|
| Resultado Esperado \| 1. O bucket existe com classe de armazenamento
  Standard. 2. O carregamento do arquivo conclui sem erro. 3. O conteúdo
  do arquivo baixado corresponde ao original. 4. A exclusão do arquivo é
  realizada com sucesso. \|
| Observações \| A consistência eventual do OBS pode causar um breve
  atraso antes que um objeto recém-carregado apareça nas listagens. \|
| Resultado do Teste \| Aprovado \|

## TC-003: Verificar configuração de VPC e grupo de segurança

  Field      Description
  ---------- ----------------------------------------------------------------
  Objetivo   Confirmar que a VPC, a sub-rede e os grupos de segurança estão

    configurados conforme o diagrama de arquitetura de rede, com os blocos CIDR
    e regras de entrada/saída corretos. |

| Pré-requisitos \| 1. IDs da VPC e da sub-rede disponíveis na saída do
  Terraform. 2. Nomes dos grupos de segurança documentados na
  arquitetura da solução. \|
| Procedimento \| 1. Acessar o Console. 2. Navegar em Console, Virtual
  Private Cloud, VPCs. 3. Localizar a VPC (ex.: vpc-poc) e verificar se
  o bloco CIDR corresponde à arquitetura (ex.: 10.0.0.0/16). 4. Clicar
  na sub-rede e verificar seu CIDR (ex.: 10.0.1.0/24). 5. Navegar até
  Security Groups e verificar regras de entrada: TCP 22 da sub-rede
  bastion, TCP 443 do proxy corporativo. 6. Verificar se as regras de
  saída permitem todo o tráfego (padrão). \|
| Resultado Esperado \| 1. CIDR da VPC é 10.0.0.0/16. 2. CIDR da
  sub-rede é 10.0.1.0/24. 3. Regras de entrada correspondem à
  arquitetura: TCP 22 e TCP 443 das origens especificadas. 4. Saída
  permite todo o tráfego. \|
| Observações \| Se o grupo de segurança possuir regras adicionais além
  da especificação da arquitetura, documentá-las no campo de
  Observações. \|
| Resultado do Teste \| Aprovado \|

# Engenharia de Dados

## TC-004: Verificar criação do workspace do DataArts Studio

  Field      Description
  ---------- ----------------------------------------------------------
  Objetivo   Confirmar que a instância do DataArts Studio (Dayu) está

    provisionada, o workspace está acessível e os usuários IAM designados
    conseguem acessar com a função Dayu\_User. |

| Pré-requisitos \| 1. Instância do DataArts Studio provisionada e com
  status Executando. 2. Usuário IAM de teste possui a função Dayu_User
  atribuída. \|
| Procedimento \| 1. Acessar o Console com o usuário IAM de teste. 2.
  Navegar em Console, DataArts Studio, Workspaces. 3. Localizar o
  workspace (ex.: poc-workspace). 4. Clicar em Acessar Workspace para
  abrir o console do DataArts Studio. 5. Verificar se o painel de
  navegação à esquerda carrega com os módulos esperados: Integração de
  Dados, Desenvolvimento de Dados, Arquitetura de Dados. \|
| Resultado Esperado \| 1. O workspace está listado e acessível. 2. O
  console do DataArts Studio abre sem erros. 3. Todos os três módulos
  (Integração de Dados, Desenvolvimento de Dados, Arquitetura de Dados)
  estão visíveis na navegação. \|
| Observações \| Se o workspace falhar ao carregar, verificar o status
  da instância Dayu e a atribuição da função IAM. \|
| Resultado do Teste \| Aprovado \|

## TC-005: Verificar execução do pipeline de ingestão de dados

  Field      Description
  ---------- ---------------------------------------------------------------
  Objetivo   Confirmar que um pipeline em lote do DataArts Studio consegue

    ingerir dados CSV do OBS, aplicar uma transformação básica
    e gravar o resultado no caminho OBS de destino. |

| Pré-requisitos \| 1. TC-004 concluído (workspace do DataArts Studio
  acessível). 2. Arquivo CSV de origem (customers.csv) existe no bucket
  OBS raw. 3. Caminho OBS de destino (poc-datalake-curated/customers/)
  está configurado. 4. Pipeline pl-ingest-customers está publicado no
  DataArts Studio. \|
| Procedimento \| 1. No console do DataArts Studio, navegar até
  Desenvolvimento de Dados. 2. Localizar o pipeline pl-ingest-customers
  na lista de jobs. 3. Clicar em Executar para iniciar o pipeline. 4.
  Aguardar o status do pipeline mudar para Sucesso (timeout: 10
  minutos). 5. Navegar até o OBS e verificar se o arquivo de saída
  existe em poc-datalake-curated/customers/. 6. Baixar o arquivo de
  saída e verificar se a contagem de linhas corresponde à origem (sem
  perda de dados). \|
| Resultado Esperado \| 1. A execução do pipeline conclui com status
  Sucesso. 2. O arquivo de saída é criado no caminho OBS de destino. 3.
  A contagem de linhas do arquivo de saída corresponde ao arquivo de
  origem. \|
| Observações \| O tempo de execução do pipeline varia conforme o volume
  de dados. Para a POC, o arquivo de origem contém aproximadamente
  10.000 linhas. \|
| Resultado do Teste \| Aprovado \|

## TC-006: Verificar consulta Spark SQL no cluster MRS

  Field      Description
  ---------- ------------------------------------------------------------
  Objetivo   Confirmar que uma consulta Spark SQL pode ser executada no

    cluster MRS para ler dados de uma tabela Hive e retornar resultados
    corretos, validando a integração entre o MRS e o data lake. |

| Pré-requisitos \| 1. TC-001 concluído (cluster MRS saudável). 2.
  Tabela Hive poc_db.customers existe e contém dados carregados pelo
  pipeline de ingestão. 3. Acesso SSH ao nó master do MRS configurado.
  \|
| Procedimento \| 1. Acessar o nó master do MRS via SSH. 2. Executar a
  CLI do Spark SQL: spark-sql --master yarn -{}-conf
  spark.sql.hive.convertMetastoreOrc=true -e "SELECT COUNT(\*) FROM
  poc_db.customers;" 3. Verificar se a contagem retornada corresponde ao
  esperado (10.000). 4. Executar uma consulta de amostra para verificar
  a integridade dos dados: spark-sql --master yarn -e "SELECT
  customer_id, name FROM poc_db.customers LIMIT 5;" 5. Confirmar que a
  consulta retorna 5 linhas com valores não nulos. \|
| Resultado Esperado \| 1. COUNT(\*) retorna 10.000. 2. A consulta de
  amostra retorna 5 linhas com valores válidos de customer_id e name. \|
| Observações \| Se a CLI do Spark SQL não estiver disponível, utilizar
  a interface web do componente Spark2x do MRS para submeter a consulta.
  \|
| Resultado do Teste \| Aprovado \|

# Histórico de versões

**1.0.0**  *2026-09-12*

Versão inicial.

Adicionados casos de teste de Arquitetura da Plataforma (TC-001 a
TC-003).

Adicionados casos de teste de Engenharia de Dados (TC-004 a TC-006).
