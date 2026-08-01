# Root Terraform ativo: `live`

Esta pasta é o root Terraform executado atualmente. Os comandos `terraform init`, `terraform validate`, `terraform plan` e `terraform apply` devem ser executados aqui.

## Configuração atual

- Provider AWS na região `us-east-2`, usando o profile `terraform-local`.
- VPC `10.16.0.0/16` com DNS support e DNS hostnames habilitados.
- Internet Gateway associado à VPC.
- Subnets públicas A/B: `10.16.0.0/20` e `10.16.16.0/20`.
- Subnets privadas A/B: `10.16.32.0/20` e `10.16.48.0/20`.
- Route table própria associada a cada subnet.
- Apenas as subnets públicas recebem `0.0.0.0/0` para o Internet Gateway.
- Interface Endpoints `ecr.dkr` e `ecr.api` nas duas subnets privadas.
- Gateway Endpoint do S3 associado às route tables das subnets privadas.

As subnets privadas não possuem rota para NAT ou Internet Gateway. Interface Endpoints são alcançados pela rota local da VPC; o Gateway Endpoint adiciona a rota da prefix list do S3 às route tables informadas.

As subnets não possuem SG próprio. Os security groups são associados às ENIs dos workloads e dos Interface Endpoints. Dentro do escopo deste projeto, uma carga privada que use o SG cliente restritivo precisa, no mínimo, de autorização HTTPS para o SG dos Interface Endpoints e para a prefix list do Gateway Endpoint do S3.

## Mapa de arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `00_providers.tf` | Provider AWS, versão `~> 6.0`, região e profile. |
| `00_variables.tf` | Variável `environment_tags`. |
| `00_data.tf` | Availability Zones disponíveis e região atual do provider. |
| `00_output.tf` | Output com o ID do Internet Gateway. |
| `01_vpc.tf` | Módulo VPC e Internet Gateway. |
| `01_subnet.tf` | Duas subnets públicas e duas privadas. |
| `02_sg_engress_eks.tf` | SG cliente e regras de egress. |
| `02_sg_ingress_interface_endpoint.tf` | SG das ENIs dos endpoints e regra de ingress. |
| `03_endpoint_interface.tf` | Interface Endpoints do ECR. |
| `03_endpoint_gateway.tf` | Gateway Endpoint do S3. |

## Fluxo de dependências

```text
module.vpc
├── aws_internet_gateway.internet_gateway
├── module.subnet-public-a/b
├── module.subnet-private-a/b
├── module.sg_egress_eks_ecr
└── module.sg_ingress_interface
    ├── module.sg_egress_eks_ecr_rule
    └── module.sg_ingress_interface_rule

subnet-private-a/b ──┬── ENIs dos Interface Endpoints ECR
                     └── Gateway Endpoint S3 via route_table_id

sg_egress_eks_ecr ──TCP/443──> sg_ingress_interface
sg_egress_eks_ecr ──TCP/443──> prefix list do S3
```

As referências a outputs dos módulos criam as dependências implícitas entre VPC, subnets, security groups e endpoints.

## Módulos instanciados

### VPC e subnets

- `module.vpc` cria a VPC.
- `module.subnet-public-a` e `module.subnet-public-b` criam subnets públicas com rota para o IGW.
- `module.subnet-private-a` e `module.subnet-private-b` criam subnets privadas com route tables próprias, sem rota default para a Internet.

Cada módulo de subnet exporta `subnet_id` e `route_table_id`.

### Security groups

`module.sg_egress_eks_ecr` representa o SG dos clientes. Suas regras de egress permitem:

- UDP/53 para o resolver da VPC em `10.16.0.2`;
- TCP/443 para o SG associado às ENIs dos Interface Endpoints;
- TCP/443 para a prefix list exportada pelo Gateway Endpoint do S3.

`module.sg_ingress_interface` representa o SG das ENIs dos endpoints. A regra de ingress permite TCP/443 originado pelo SG dos clientes.

Ao criar esses SGs, o provider Terraform AWS remove a regra AWS padrão de egress irrestrito. Portanto, o SG cliente inicia somente o tráfego permitido pelas regras explícitas acima. O SG dos endpoints não possui egress explícito para iniciar novas conexões; respostas ao ingress HTTPS permitido continuam autorizadas porque security groups são stateful.

Essas regras não pertencem às subnets. Para terem efeito, `sg_egress_eks_ecr` deve ser associado às ENIs dos nodes ou pods clientes, enquanto `sg_ingress_interface` já é informado aos Interface Endpoints e fica associado às ENIs criadas para eles.

### Interface Endpoints

`module.ecr_interface` cria:

```text
com.amazonaws.us-east-2.ecr.dkr
```

`module.api_interface` cria:

```text
com.amazonaws.us-east-2.ecr.api
```

Ambos usam as duas subnets privadas, o SG `sg_ingress_interface` e DNS privado habilitado.

Cada endpoint cria ENIs nas subnets selecionadas. O tráfego utiliza a rota local da VPC, e o SG dessas ENIs aceita TCP/443 somente quando a origem possui o SG cliente referenciado.

### Gateway Endpoint

`module.s3_gateway` cria um Gateway Endpoint para:

```text
com.amazonaws.us-east-2.s3
```

Ele recebe os `route_table_id` das subnets privadas. A AWS/Terraform gerencia a rota baseada na prefix list do S3; não são usadas rotas manuais por DNS ou IP.

O módulo exporta `prefix_list_id`, que é consumido pela regra TCP/443 do SG cliente. Essa referência cria a dependência implícita entre a criação do endpoint e a regra de SG. O Gateway Endpoint não possui ENIs nem SG próprio: a route table fornece o caminho, e a regra do SG cliente autoriza a saída para a prefix list.

## Requisitos mínimos de acesso privado no escopo atual

Para os clientes privados alcançarem ECR e S3 sem NAT Gateway, o projeto combina:

1. DNS UDP/53 para o resolver da VPC.
2. Egress TCP/443 do SG cliente para `sg_ingress_interface`.
3. Ingress TCP/443 em `sg_ingress_interface`, tendo o SG cliente como origem.
4. Interface Endpoints `ecr.api` e `ecr.dkr` nas subnets privadas.
5. Egress TCP/443 do SG cliente para a prefix list do S3.
6. Gateway Endpoint do S3 associado às duas route tables privadas.

As etapas 2 e 3 protegem o caminho até as ENIs dos Interface Endpoints. As etapas 5 e 6 protegem e roteiam o caminho até o Gateway Endpoint. Uma regra de SG não cria uma rota, e uma rota não libera tráfego bloqueado pelo SG.

## Comandos

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

## Limitações atuais

- O cluster EKS ainda não está definido neste root.
- O SG de egress ainda não está associado a nodes ou pods reais.
- O acesso privado implementado cobre apenas ECR API, ECR DKR e S3. Um cluster EKS sem NAT pode precisar de endpoints adicionais conforme os workloads e add-ons usados, por exemplo STS, CloudWatch Logs, EC2, Elastic Load Balancing, Auto Scaling, SSM e KMS.
- O módulo de regras de egress exige simultaneamente um SG de Interface Endpoint e uma prefix list de Gateway Endpoint; ele não oferece flags para tornar esses destinos opcionais.
- A regra de DNS configurada pelo módulo é UDP/53; TCP/53 não está incluído.
- Não há policies customizadas nos VPC Endpoints. A policy padrão permite acesso amplo ao serviço, ainda sujeito às permissões IAM e às políticas do próprio serviço.
- O primeiro download de uma imagem por uma regra de pull-through cache do ECR pode exigir NAT para buscar a imagem original. Os downloads seguintes usam a imagem armazenada no cache.
- Imagens Windows que mantêm camadas externas no provedor original podem exigir acesso externo ou a publicação dessas camadas no ECR, respeitando as respectivas licenças.
- Não existem network ACLs customizadas no projeto.
- A região está declarada no provider, mas alguns módulos ainda possuem valores regionais fixos.
- `data.aws_region.current` está declarado, mas ainda não é consumido por recursos ou outputs.
- Os arquivos de `environments/dev` e `environments/prod` ainda não são roots Terraform independentes.
