# Projeto Terraform

Este repositorio e um projeto de estudo para organizar infraestrutura AWS com Terraform usando modulos reutilizaveis.

A ideia principal e:

- `modules/` guarda pecas reutilizaveis de infraestrutura;
- `live/` e a configuracao ativa que instancia os modulos;
- `environments/` guarda valores por ambiente, como `dev` e `prod`.

## O que esta sendo criado agora

A configuracao ativa esta em `live/`.

Ela cria uma rede AWS na regiao `us-east-2` usando o profile `terraform-local`:

- uma VPC com CIDR `10.16.0.0/16`;
- um Internet Gateway conectado na VPC;
- quatro subnets usando o modulo `modules/subnet`;
- duas subnets publicas;
- duas subnets privadas;
- output com o ID do Internet Gateway;
- security groups separados para o EKS e para o Interface Endpoint;
- regras de DNS e HTTPS entre o EKS e o endpoint;
- VPC Interface Endpoint do ECR nas subnets privadas.

As subnets usam as duas primeiras Availability Zones retornadas por:

```hcl
data "aws_availability_zones" "available" {
  state = "available"
}
```

## Estrutura atual

```text
.
|-- environments
|   |-- dev
|   |   |-- backend.tf
|   |   `-- terraform.tfvars
|   `-- prod
|       |-- backend.tf
|       `-- terraform.tfvars
|-- live
|   |-- 00_data.tf
|   |-- 00_output.tf
|   |-- 00_providers.tf
|   |-- 00_variables.tf
|   |-- 02_sg_engress_eks.tf
|   |-- 02_sg_ingress_interface_endpoint.tf
|   |-- 03_endpoint_interface.tf
|   |-- 01_subnet.tf
|   `-- 01_vpc.tf
`-- modules
    |-- endpoint_interface
    |-- security_group_egress
    |-- security_group_egress_rule.tf
    |-- security_group_ingress
    |-- security_group_ingress_rule.tf
    |-- subnet
    |   |-- main.tf
    |   `-- variables..tf
    `-- vpc
        |-- main.tf
        |-- output.tf
        `-- variables.tf
```

Observacao: o modulo `subnet` usa o arquivo `variables..tf` com dois pontos antes de `tf`. O Terraform ainda le arquivos `.tf`, mas esse nome pode ser ajustado depois para `variables.tf`.

## Como executar

Entre na pasta ativa:

```powershell
cd live
```

Inicialize o Terraform:

```powershell
terraform init
```

Formate os arquivos:

```powershell
terraform fmt -recursive
```

Valide a configuracao:

```powershell
terraform validate
```

Veja o plano:

```powershell
terraform plan
```

Aplique quando estiver pronto:

```powershell
terraform apply
```

## Modulo `modules/vpc`

### Purpose

O modulo `vpc` cria uma VPC AWS.

### Intended use

Use como base da rede para subnets, gateways, endpoints e outros recursos dentro da mesma VPC.

### Recurso criado

- `aws_vpc.main`

### Entradas

| Variavel | Tipo | Padrao | Descricao |
| --- | --- | --- | --- |
| `cidr_block` | `string` | `"10.16.0.0/16"` | CIDR da VPC. |
| `tags` | `map(string)` | sem padrao | Tags extras para a VPC. |

### Saidas

| Output | Descricao |
| --- | --- |
| `vpc_id` | ID da VPC criada. |

### Dependencias e premissas

- Usa o provider AWS configurado pelo caller.
- A regiao e definida no provider e tambem esta fixada como `us-east-2` no recurso.
- O modulo habilita `enable_dns_support` e `enable_dns_hostnames`.

### Limitacoes e follow-ups

- Nao cria subnets, route tables, Internet Gateway ou NAT Gateway.
- As tags comuns `Service = "network"` e `ManagedBy = "Terraform"` sao aplicadas automaticamente.

### Exemplo de uso

Exemplo usado em `live/01_vpc.tf`:

```hcl
module "vpc" {
  source     = "../modules/vpc"
  cidr_block = "10.16.0.0/16"

  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"
    }
  )
}
```

Depois, outros recursos podem usar:

```hcl
module.vpc.vpc_id
```

## Modulo `modules/subnet`

### Purpose

O modulo `subnet` cria uma subnet AWS. Quando `is_public = true`, ele tambem cria uma route table e uma rota padrao para um Internet Gateway.

### Intended use

Use para criar subnets publicas ou privadas dentro de uma VPC. Para uma subnet publica, informe `is_public = true` e o ID de um Internet Gateway.

### Recursos criados

- `aws_subnet.subnet`
- `aws_route_table.rt`, somente para subnet publica
- `aws_route.route`, somente para subnet publica;
- `aws_route_table_association.association`, somente para subnet publica.

O modulo tambem exporta `subnet_id`, usado pelos VPC Interface Endpoints.

### Entradas

| Variavel | Tipo | Padrao | Descricao |
| --- | --- | --- | --- |
| `vpc_id` | `string` | sem padrao | ID da VPC onde a subnet sera criada. |
| `cidr_block` | `string` | sem padrao | CIDR da subnet. |
| `tags` | `map(string)` | sem padrao | Tags extras para a subnet. |
| `availability_zone` | `string` | sem padrao | Availability Zone da subnet. |
| `is_public` | `bool` | `false` | Define se a subnet e publica. |
| `gateway_id` | `string` | `""` | ID do Internet Gateway usado na rota publica. |

### Exemplo de subnet publica

```hcl
module "subnet-public-a" {
  source            = "../modules/subnet"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.16.0.0/20"
  is_public         = true
  gateway_id        = aws_internet_gateway.internet_gateway.id

  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"
      Name  = "public-a"
    }
  )
}
```

### Exemplo de subnet privada

```hcl
module "subnet-private-a" {
  source            = "../modules/subnet"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.16.32.0/20"

  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"
      Name  = "private-a"
    }
  )
}
```

### Dependencias e premissas

- Recebe o ID da VPC e da Availability Zone do caller.
- Quando publico, depende de um Internet Gateway existente e associa uma route table dedicada a subnet.
- Quando privado, cria somente a subnet; nao cria NAT Gateway nem rota de saida para a internet.

### Limitacoes e follow-ups

- O nome do arquivo de variaveis ainda e `variables..tf` e pode ser renomeado para `variables.tf`.
- O output atual expoe somente `subnet_id`; o ID da route table nao e exportado.

## Configuracao `live`

Arquivos principais:

| Arquivo | Funcao |
| --- | --- |
| `00_providers.tf` | Declara o provider AWS `~> 6.0`, regiao `us-east-2` e profile `terraform-local`. |
| `00_variables.tf` | Declara `environment_tags`, usado para tags por ambiente. |
| `00_data.tf` | Busca Availability Zones disponiveis. |
| `00_output.tf` | Exporta o ID do Internet Gateway. |
| `01_vpc.tf` | Instancia o modulo VPC e cria o Internet Gateway. |
| `01_subnet.tf` | Instancia quatro subnets: duas publicas e duas privadas, passando o Internet Gateway para as publicas. |
| `02_sg_engress_eks.tf` | Instancia o SG de egress do EKS e as regras de DNS/HTTPS. |
| `02_sg_ingress_interface_endpoint.tf` | Instancia o SG de ingress do Interface Endpoint e sua regra HTTPS. |
| `03_endpoint_interface.tf` | Instancia o Interface Endpoint do ECR nas subnets privadas. |

## Ambientes

A pasta `environments/` tem valores separados para `dev` e `prod`:

```text
environments/dev/terraform.tfvars
environments/prod/terraform.tfvars
```

Hoje esses arquivos definem apenas a tag `Environment`.

Exemplo:

```hcl
environment_tags = {
  Environment = "dev"
}
```

Eles ainda nao estao conectados diretamente a uma configuracao raiz propria. A execucao ativa do projeto acontece em `live/`.

## Modulos de security group e endpoint

### `modules/security_group_egress`

#### Purpose

Cria um security group independente para o trafego dos nodes/pods do EKS.

#### Intended use

Associe-o aos nodes/pods do EKS e use-o como origem do trafego para endpoints privados.

#### Resources and behavior

- Cria `aws_security_group.security_group`.
- Nao cria regras internamente.
- O egress padrao da AWS permanece aberto porque o recurso nao usa `egress = []`.

#### Inputs

| Nome | Tipo | Obrigatorio | Finalidade |
| --- | --- | --- | --- |
| `name` | `string` | sim | Nome do SG. |
| `description` | `string` | sim | Descricao do SG. |
| `vpc_id` | `string` | sim | VPC do SG. |
| `tags` | `map(string)` | sim | Tags adicionais. |

#### Outputs

| Nome | Descricao | Consumidores |
| --- | --- | --- |
| `sg_id` | ID do SG criado. | Modulos de regras e EKS futuro. |

#### Dependencies and assumptions

Depende de uma VPC existente. O caller deve associar o SG aos nodes/pods e criar as regras.

#### Example

O uso atual e `module "sg_egress_eks_ecr"` em `live/02_sg_engress_eks.tf`.

#### Limitations and follow-ups

O modulo nao associa o SG a nodes/pods e nao cria regras.

### `modules/security_group_ingress`

#### Purpose

Cria o SG associado as ENIs de um VPC Interface Endpoint.

#### Intended use

Associe-o ao Interface Endpoint e use-o para controlar o acesso de entrada dos clientes.

#### Resources and behavior

- Cria `aws_security_group.security_group`.
- Nao cria regras internamente.
- O egress padrao permanece aberto, embora o uso principal seja controlar o ingress TCP/443.

#### Inputs

| Nome | Tipo | Obrigatorio | Finalidade |
| --- | --- | --- | --- |
| `name` | `string` | sim | Nome do SG. |
| `description` | `string` | sim | Descricao do SG. |
| `vpc_id` | `string` | sim | VPC do SG. |
| `tags` | `map(string)` | sim | Tags adicionais. |

#### Outputs

| Nome | Descricao | Consumidores |
| --- | --- | --- |
| `sg_id` | ID do SG criado. | Endpoint e modulo de regra de ingress. |

#### Dependencies and assumptions

Depende de uma VPC existente. O caller deve associar o SG ao endpoint e criar as regras.

#### Example

O uso atual e `module "sg_ingress_interface"` em `live/02_sg_ingress_interface_endpoint.tf`.

#### Limitations and follow-ups

O modulo nao associa o SG ao endpoint e nao cria regras.

### `modules/security_group_egress_rule.tf`

#### Purpose

Cria regras de saida do SG do EKS.

#### Intended use

Use-o para liberar DNS da VPC e HTTPS para um Interface Endpoint.

#### Resources and behavior

- UDP/53 para o resolver da VPC `10.16.0.2` usando CIDR.
- TCP/443 para o SG do endpoint usando `referenced_security_group_id`.

#### Inputs

| Nome | Tipo | Obrigatorio | Finalidade |
| --- | --- | --- | --- |
| `security_group_id` | `string` | sim | SG que recebe as regras de saida. |
| `referenced_security_group_id` | `string` | sim | SG de destino do HTTPS. |

#### Outputs

Nao possui outputs.

#### Dependencies and assumptions

Depende dos dois SGs existirem; as referencias aos outputs criam dependencias implicitas sem ciclo.

#### Example

O uso atual e `module "sg_egress_eks_ecr_rule"` em `live/02_sg_engress_eks.tf`.

#### Limitations and follow-ups

TCP/53 nao esta incluido atualmente.

### `modules/security_group_ingress_rule.tf`

#### Purpose

Cria uma regra de entrada TCP/443 no SG do endpoint.

#### Intended use

Use-o para autorizar o SG do EKS como origem do trafego para o endpoint.

#### Resources and behavior

- `security_group_id` e o SG de destino da regra.
- `referenced_security_group_id` e o SG de origem autorizado.

#### Inputs

| Nome | Tipo | Obrigatorio | Finalidade |
| --- | --- | --- | --- |
| `security_group_id` | `string` | sim | SG do endpoint. |
| `referenced_security_group_id` | `string` | sim | SG do EKS autorizado. |

#### Outputs

Nao possui outputs.

#### Dependencies and assumptions

Depende dos dois SGs existirem. A regra cobre somente TCP/443.

#### Example

O uso atual e `module "sg_ingress_interface_rule"` em `live/02_sg_ingress_interface_endpoint.tf`.

#### Limitations and follow-ups

Nao ha portas adicionais configuradas.

### `modules/endpoint_interface`

#### Purpose

Cria um VPC Interface Endpoint para expor um servico AWS por ENIs privadas.

#### Intended use

Use-o com uma subnet por Availability Zone desejada e um SG que permita o acesso dos clientes.

#### Resources and behavior

- Cria `aws_vpc_endpoint.interface` do tipo `Interface`.
- Associa `security_group_ids` e `subnet_ids`.
- Mantem `private_dns_enabled = true`.
- Aplica tags de rede e Terraform.

#### Inputs

| Nome | Tipo | Obrigatorio | Finalidade |
| --- | --- | --- | --- |
| `vpc_id` | `string` | sim | VPC do endpoint. |
| `service_name` | `string` | sim | Nome de um servico AWS. Um endpoint por servico. |
| `security_group_ids` | `list(string)` | sim | SGs associados as ENIs. |
| `subnet_ids` | `list(string)` | sim | Subnets que receberao as ENIs. |
| `tags` | `map(string)` | sim | Tags adicionais. |

#### Outputs

Nao possui outputs atualmente.

#### Dependencies and assumptions

Depende de VPC, subnets e SGs existentes. O endpoint usa DNS privado e as ENIs sao criadas nas subnets informadas.

#### Example

O uso atual e `module "ecr_interface"` em `live/03_endpoint_interface.tf`.

#### Limitations and follow-ups

O caller deve criar os endpoints complementares necessarios; atualmente apenas `ecr.dkr` esta instanciado em `live/03_endpoint_interface.tf`.

## Proximos passos naturais

- Renomear `modules/subnet/variables..tf` para `variables.tf`.
- Decidir se `environments/dev` e `environments/prod` vao virar roots Terraform completos ou apenas arquivos de valores.
- Criar os endpoints adicionais necessarios para o EKS/ECR, como `ecr.api` e S3 Gateway Endpoint.
- Associar o security group de egress aos nodes ou pods do EKS quando o cluster for criado.
