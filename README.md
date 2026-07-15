# TECH CHALLENGE | TOOGLEMASTER - FASE 2
Tech Challenge é o projeto que engloba os conhecimentos obtidos em todas as disciplinas da fase. Esta é uma atividade que, em princípio, deve ser desenvolvida em grupo. Importante atentar-se ao prazo de entrega, pois trata-se de uma atividade obrigatória, uma vez que vale 90% da nota de todas as disciplinas da fase.

### Nota Importante sobre o Ambiente de Nuvem
Desenvolvimento em ambiente com limitações: **AWS Academy**.
1. Se você está usando sua conta do AWS Academy, você **não pode criar novas roles de IAM**.
2. Você **deve** usar a role existente chamada **LabRole** para todas as operações que exigem permissão (criação do cluster, node groups, etc.).
3. Ferramentas modernas como KEDA e Karpenter **não funcionarão**, pois dependem da criação de novas roles (IRSA).
4. **Este documento fornecerá o caminho e os workarounds necessários para ser bem-sucedido neste ambiente.**

## Desafio
Parabéns! O MVP monolítico do ToggleMaster implantado na Fase 1 foi um sucesso. A plataforma validou sua utilidade e agora a demanda explodiu. A arquitetura monolítica começou a apresentar gargalos, e a diretoria da DevOps Solutions Inc. decidiu que é hora de evoluir: o ToggleMaster será reescrito como um ecossistema de microsserviços distribuídos.

O seu desafio nesta fase é pegar o código-fonte dos 5 novos microsserviços, conteinerizá-los, provisionar a infraestrutura de nuvem necessária e implantá-los em um ambiente de orquestração robusto, escalável e resiliente: o Kubernetes na AWS (EKS).

A arquitetura foi quebrada nos seguintes 5 microsserviços (você receberá o código-fonte de todos eles):
- **auth-service (Go)**: Gerencia chaves de API e autenticação. (Banco de Dados: PostgreSQL)
- **flag-service (Python)**: CRUD das definições das feature flags. (Banco de Dados: PostgreSQL)
- **targeting-service (Python)**: Gerencia regras complexas de segmentação. (Banco de Dados: PostgreSQL)
- **evaluation-service (Go)**: O "caminho quente" (hot path) de alta performance que retorna a decisão final (true/false). (Cache: Redis)
- **analytics-service (Python)**: Consome eventos de uma fila e salva dados de análise. (Fila: AWS SQS, Banco de Dados: AWS DynamoDB)

Sua missão é projetar e implementar a infraestrutura de contêineres e orquestração para colocar esse novo ecossistema em produção.

### Código usado durante o Tech Challenge
Segue o código para utilizar no desafio:
- **auth-service (Go)**: https://github.com/FIAP-TCs/auth-service
- **flag-service (Python)**: https://github.com/FIAP-TCs/flag-service
- **targeting-service (Python)**: https://github.com/FIAP-TCs/targeting-service
- **evaluation-service (Go)**: https://github.com/FIAP-TCs/evaluation-service
- **analytics-service (Python)**: https://github.com/FIAP-TCs/analytics-service

## Requisitos técnicos

### 1. Análise e Conteinerização (Docker)

O primeiro passo é garantir que você consiga executar e entender todo o ecossistema localmente.
- [x] **Dockerfile**: Você deve criar um Dockerfile otimizado (multi-stage builds são altamente recomendados) para cada um dos 5 microsserviços.
- [x] **Docker Compose**: Crie um único arquivo docker-compose.yml na raiz do projeto que suba todos os 5 microsserviços e seus 4 bancos de dados locais (2 instâncias PostgreSQL, 1 Redis, 1 DynamoDB Local). Isso é essencial para provar que o ambiente local funciona

### 2. Provisionando a Infraestrutura na Nuvem (Console AWS e eksctl)

Antes de implantar, você deve provisionar manualmente (via Console da AWS ou eksctl) todos os recursos de nuvem que seus microsserviços precisarão. Este é o seu **checklist de infraestrutura**:

#### **Cluster Kubernetes**
- [x] Crie 1 (um) cluster **AWS EKS** usando o Console da AWS. **Não** use o eksctl create cluster.
- [x] Cluster Role: Quando solicitado, selecione a role existente LabRole.
- [x] Crie um **Managed Node Group** (pelo console).
- [x] Node IAM Role: Quando solicitado, selecione a **LabRole** existente. (Isso é crucial! Os nós herdarão as permissões desta role).
- [x] Configuração de Auto Scaling: Defina a configuração de escalabilidade do grupo de nós (ex: Mínimo=1, Desejado=2, Máximo=4 instâncias).

#### **Registro de Contêineres (ECR)**
- [x] Crie 5 (cinco) repositórios no **AWS ECR**, um para cada microsserviço (ex: auth-service, flag-service, etc.).
- [x] Publique as imagens Docker que você criou na etapa 1 para seus respectivos repositórios no ECR.

#### **Bancos de Dados Relacionais (AWS RDS for PostgreSQL) independentes**
- [x] Recurso 1 (RDS): Para o auth-service.
- [x] Recurso 2 (RDS): Para o flag-service.
- [x] Recurso 3 (RDS): Para o targeting-service.

#### **Cache In-Memory (ElastiCache)**
- [x] Crie 1 (um) cluster **AWS ElastiCache for Redis**.
- [x] Recurso 4 (ElastiCache): Para o evaluation-service.

#### **Banco de Dados NoSQL (DynamoDB)**
- [x] Crie 1 (uma) tabela no **AWS DynamoDB**.
- [x] Recurso 5 (DynamoDB): Para o analytics-service. (O código-fonte indicará o nome da tabela e a chave primária esperada).

#### **Fila de Mensagens (SQS)**
- [x] Crie 1 (uma) fila **AWS SQS** (do tipo Standard).
- [x] Recurso 6 (SQS): Para ser usada pelo evaluation-service (que produz mensagens) e pelo analytics-service (que consome as mensagens).

####
> Ao final desta etapa, você deve ter anotado todas as "strings de conexão" (endpoints do RDS, endpoint do ElastiCache, nome da tabela DynamoDB, ARN da fila SQS, etc.), pois você as usará na próxima etapa.

### 3. Configurando o Cluster (Kubernetes)
- [x] Instale o Metrics Server no seu cluster. Ele é necessário para o HPA funcionar. (Você pode usar kubectl apply -f https://github.com/kubernetes-sigs/metricsserver/releases/latest/download/components.yaml)
- [x] Instale o Nginx Ingress Controller (via Helm ou kubectl apply). Como seus nós têm a LabRole, o Nginx Controller terá permissão para criar um Application Load Balancer (ALB) ou Network Load Balancer (NLB) na AWS.

### 4. Orquestração e Implantação (Manifestos)
Agora, escreva os manifestos do Kubernetes para implantar suas aplicações.

Manifestos Básicos: Crie os arquivos YAML para cada um dos 5 microsserviços:
- [x] Namespaces (separadores lógicos para aplicações).
- [x] Deployment (para gerenciar os Pods, garantindo que eles usem as imagens do ECR).
- [x] Service (do tipo ClusterIP).
- [x] Secrets (para injetar com segurança todas as senhas, endpoints e chaves de acesso dos recursos que você criou na Etapa 2).
- [x] ConfigMap (para injetar URLs de serviços internos e outros dados).

#### **Acesso Externo (Ingress)**
- [x] Crie um manifesto Ingress que defina as regras de roteamento (ex: /auth vai para o auth-service, /flags para o flag-service, etc.).

#### **Boas práticas de orquestração**
- [x] Use sempre Requests e Limits nos Deployments para evitar problemas com o Node.
- [x] Garanta que as secrets sempre estarão em base64.
- [x] Use sempre Readiness e/ou LivenessProbe sempre que possível.
- [x] Crie sempre suas aplicações separando por Namespaces. 

### 5. Configurando a Escalabilidade
#### **Horizontal Pod Autoscaler (HPA)**
- [x] Crie um manifesto HorizontalPodAutoscaler para o evaluationservice baseado na utilização média de CPU (ex: targetCPUUtilizationPercentage: 70).
- [x] Crie um manifesto HorizontalPodAutoscaler para o analytics-service também baseado na utilização média de CPU.
Explicação (Workaround): Quando a fila SQS encher, este serviço processará mais mensagens, sua CPU aumentará, e o HPA adicionará mais pods.