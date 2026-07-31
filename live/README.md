# Infraestrutura ativa em `live`

Esta pasta e o root Terraform ativo do projeto. E aqui que os comandos `terraform init`, `terraform plan` e `terraform apply` devem ser executados neste momento.

## O que esta sendo criado

A configuracao atual monta a base de rede AWS:

- VPC `10.16.0.0/16`;
- Internet Gateway conectado na VPC;
- subnet publica A `10.16.0.0/20`;
- subnet publica B `10.16.16.0/20`;
- subnet privada A `10.16.32.0/20`;
- subnet privada B `10.16.48.0/20`.

## Fluxo dos arquivos

| Arquivo | Papel |
| --- | --- |
| `00_providers.tf` | Configura o provider AWS na regiao `us-east-2`. |
| `00_variables.tf` | Declara `environment_tags`. |
| `00_data.tf` | Busca as Availability Zones disponiveis. |
| `00_output.tf` | Mostra o ID do Internet Gateway. |
| `01_vpc.tf` | Cria a VPC via modulo e cria o Internet Gateway. |
| `01_subnet.tf` | Cria as quatro subnets via modulo. |
| `02_sg_engress_eks.tf` | Cria o SG de saida do EKS e suas regras de DNS e HTTPS. |
| `02_sg_ingress_interface_endpoint.tf` | Cria o SG do Interface Endpoint e permite HTTPS vindo do EKS. |
| `03_endpoint_interface.tf` | Cria o VPC Interface Endpoint do ECR nas subnets privadas. |

## Conexao entre recursos

O modulo `vpc` exporta `module.vpc.vpc_id`.

Esse ID e usado por:

- `aws_internet_gateway.internet_gateway`;
- todos os blocos `module "subnet-..."`.

As subnets publicas usam `is_public = true`, o que ativa a criacao de route table, rota publica e associacao da route table dentro do modulo `subnet`. O `gateway_id` do Internet Gateway e passado explicitamente para as subnets publicas.

Os security groups sao criados separadamente dos modulos de regras. Isso permite que as regras de entrada e saida referenciem os dois SGs sem criar dependencia circular entre os modulos.

## Comandos

```powershell
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

## Modulos de rede adicionados

### `modules/security_group_egress`

#### Purpose

Cria o security group usado como origem do trafego dos nodes/pods do EKS.

#### Intended use

Associe-o aos nodes/pods do EKS e use-o como origem para endpoints privados.

#### Resources and behavior

- Cria `aws_security_group.security_group`.
- Nao cria regras internamente.
- O egress padrao permanece aberto porque o SG nao usa `egress = []`.

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

Depende da VPC criada pelo modulo `vpc`.

#### Example

Uso atual: `module "sg_egress_eks_ecr"` neste root.

#### Limitations and follow-ups

Ainda nao esta associado a um EKS real. O caller deve associar o SG aos nodes/pods e criar as regras.

### `modules/security_group_ingress`

#### Purpose

Cria o security group associado as ENIs do Interface Endpoint.

#### Intended use

Associe-o ao endpoint e controle a entrada TCP/443 a partir do SG do EKS.

#### Resources and behavior

- Cria `aws_security_group.security_group`.
- Nao cria regras internamente.
- O egress padrao permanece aberto.

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
| `sg_id` | ID do SG criado. | Endpoint e regra de ingress. |

#### Dependencies and assumptions

Depende da VPC criada pelo modulo `vpc`.

#### Example

Uso atual: `module "sg_ingress_interface"` neste root.

#### Limitations and follow-ups

O modulo nao associa o SG a um endpoint e nao cria regras.

### `modules/security_group_egress_rule.tf`

#### Purpose

Cria as regras de saida do SG do EKS.

#### Intended use

Use-o para liberar DNS da VPC e HTTPS para um Interface Endpoint.

#### Resources and behavior

- UDP/53 para o resolver DNS da VPC `10.16.0.2`;
- TCP/443 para o SG do Interface Endpoint.

#### Inputs

| Nome | Tipo | Obrigatorio | Finalidade |
| --- | --- | --- | --- |
| `security_group_id` | `string` | sim | SG que recebe as regras. |
| `referenced_security_group_id` | `string` | sim | SG de destino do HTTPS. |

#### Outputs

Nao possui outputs.

#### Dependencies and assumptions

Depende dos dois SGs existirem. As referencias aos outputs criam dependencias implicitas sem ciclo.

#### Example

Uso atual: `module "sg_egress_eks_ecr_rule"` neste root.

#### Limitations and follow-ups

TCP/53 nao esta incluido atualmente.

### `modules/security_group_ingress_rule.tf`

#### Purpose

Cria a regra de entrada TCP/443 no SG do endpoint.

#### Intended use

Autoriza o SG do EKS como origem do trafego para o endpoint.

#### Resources and behavior

- `security_group_id` e o SG de destino.
- `referenced_security_group_id` e o SG de origem autorizado.

#### Inputs

| Nome | Tipo | Obrigatorio | Finalidade |
| --- | --- | --- | --- |
| `security_group_id` | `string` | sim | SG do endpoint. |
| `referenced_security_group_id` | `string` | sim | SG do EKS. |

#### Outputs

Nao possui outputs.

#### Dependencies and assumptions

Depende dos dois SGs existirem e da mesma VPC permitir a referencia entre eles.

#### Example

Uso atual: `module "sg_ingress_interface_rule"` neste root.

#### Limitations and follow-ups

A regra cobre somente TCP/443.

### `modules/endpoint_interface`

#### Purpose

Cria um VPC Interface Endpoint para expor um servico AWS por ENIs privadas.

#### Intended use

Use-o com subnets privadas e um SG que permita o acesso dos clientes.

#### Resources and behavior

- Cria `aws_vpc_endpoint.interface` do tipo `Interface`.
- Associa os SGs e subnets informados.
- Habilita `private_dns_enabled = true`.

#### Inputs

| Nome | Tipo | Obrigatorio | Finalidade |
| --- | --- | --- | --- |
| `vpc_id` | `string` | sim | VPC do endpoint. |
| `service_name` | `string` | sim | Nome de um servico AWS. |
| `security_group_ids` | `list(string)` | sim | SGs das ENIs. |
| `subnet_ids` | `list(string)` | sim | Subnets das ENIs. |
| `tags` | `map(string)` | sim | Tags adicionais. |

#### Outputs

Nao possui outputs atualmente.

#### Dependencies and assumptions

Depende da VPC, das subnets privadas e do SG do endpoint.

#### Example

```hcl
module "ecr_interface" {
  source             = "../modules/endpoint_interface"
  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.sg_ingress_interface.sg_id]
  service_name       = "com.amazonaws.us-east-2.ecr.dkr"
  subnet_ids         = [module.subnet-private-b.subnet_id, module.subnet-private-a.subnet_id]
}
```

#### Limitations and follow-ups

Cada instancia representa um servico. Atualmente o root cria somente `ecr.dkr`; endpoints adicionais, como `ecr.api` e S3 Gateway, sao trabalho futuro.
