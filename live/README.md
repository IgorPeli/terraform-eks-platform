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

## Mapa de arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `00_providers.tf` | Provider AWS, versão `~> 6.0`, região e profile. |
| `00_variables.tf` | Variável `environment_tags`. |
| `00_data.tf` | Availability Zones disponíveis e região atual do provider. |
| `00_output.tf` | IDs do Internet Gateway e da região do provider. |
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

subnet-private-a/b ──┬── Interface Endpoints ECR
                     └── Gateway Endpoint S3 via route_table_id
```

As referências a outputs dos módulos criam as dependências implícitas entre VPC, subnets, security groups e endpoints.

## Módulos instanciados

### VPC e subnets

- `module.vpc` cria a VPC.
- `module.subnet-public-a` e `module.subnet-public-b` criam subnets públicas com rota para o IGW.
- `module.subnet-private-a` e `module.subnet-private-b` criam subnets privadas com route tables próprias, sem rota default para a Internet.

Cada módulo de subnet exporta `subnet_id` e `route_table_id`.

### Security groups

`module.sg_egress_eks_ecr` representa o SG dos clientes. A regra de egress permite UDP/53 para `10.16.0.2` e TCP/443 para o SG dos endpoints.

`module.sg_ingress_interface` representa o SG das ENIs dos endpoints. A regra de ingress permite TCP/443 originado pelo SG dos clientes.

O egress padrão dos security groups permanece aberto porque os módulos não removem a regra padrão da AWS.

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

### Gateway Endpoint

`module.s3_gateway` cria um Gateway Endpoint para:

```text
com.amazonaws.us-east-2.s3
```

Ele recebe os `route_table_id` das subnets privadas. A AWS/Terraform gerencia a rota baseada na prefix list do S3; não são usadas rotas manuais por DNS ou IP.

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
- O egress padrão dos SGs permanece aberto.
- A regra de DNS configurada pelo módulo é UDP/53; TCP/53 não está incluído.
- A região está declarada no provider, mas alguns módulos ainda possuem valores regionais fixos.
- Os arquivos de `environments/dev` e `environments/prod` ainda não são roots Terraform independentes.
