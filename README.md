# Projeto Terraform

Projeto de estudo para organizar infraestrutura AWS com módulos Terraform reutilizáveis. O root ativo está em [`live/`](live/README.md); os módulos ficam em [`modules/`](modules).

## Arquitetura atual

O root `live` usa a região `us-east-2` e o profile `terraform-local`. Ele cria:

- uma VPC `10.16.0.0/16` com DNS da VPC habilitado;
- duas subnets públicas e duas privadas, distribuídas nas duas primeiras Availability Zones disponíveis;
- route table própria para cada subnet; apenas as públicas recebem rota `0.0.0.0/0` para o Internet Gateway;
- security groups separados para clientes EKS e ENIs dos endpoints;
- Interface Endpoints para `ecr.dkr` e `ecr.api` nas subnets privadas;
- Gateway Endpoint para S3 associado às route tables privadas.

As subnets privadas não recebem rota para NAT ou Internet Gateway. O acesso aos serviços AWS depende dos endpoints configurados e das regras de security group.

## Estrutura

```text
.
├── environments/
│   ├── dev/
│   └── prod/
├── live/
└── modules/
    ├── endpoint_gateway/
    ├── endpoint_interface/
    ├── security_group_egress/
    ├── security_group_egress_rule.tf/
    ├── security_group_ingress/
    ├── security_group_ingress_rule.tf/
    ├── subnet/
    └── vpc/
```

## Execução

```bash
cd live
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Os arquivos em `environments/dev` e `environments/prod` fornecem valores de ambiente, mas a configuração raiz executada atualmente é `live`.

## Contratos dos módulos

### `vpc`

Path: [`modules/vpc`](modules/vpc)

#### Purpose

Cria uma VPC com DNS support e DNS hostnames habilitados.

#### Intended use

Usar como base para subnets, gateways, endpoints e security groups.

#### Resources and behavior

- Cria `aws_vpc.main`.
- Aplica as tags comuns `Service = "network"` e `ManagedBy = "Terraform"`.

#### Inputs

| Nome | Tipo | Obrigatório | Finalidade |
| --- | --- | --- | --- |
| `cidr_block` | `string` | não | CIDR da VPC; padrão `10.16.0.0/16`. |
| `tags` | `map(string)` | sim | Tags adicionais. |

#### Outputs

| Nome | Descrição | Consumidores |
| --- | --- | --- |
| `vpc_id` | ID da VPC. | Root `live`. |

#### Dependencies and assumptions

- Usa o provider AWS do caller.
- O código atual fixa `us-east-2` no recurso.

#### Example

```hcl
module "vpc" {
  source     = "../modules/vpc"
  cidr_block = "10.16.0.0/16"
  tags       = var.environment_tags
}
```

#### Limitations and follow-ups

Não cria subnets, route tables, Internet Gateway ou NAT Gateway.

### `subnet`

Path: [`modules/subnet`](modules/subnet)

#### Purpose

Cria uma subnet, uma route table dedicada e sua associação.

#### Intended use

Usar para subnets públicas ou privadas. A diferença é que somente subnets públicas recebem rota para o Internet Gateway.

#### Resources and behavior

- Cria `aws_subnet.subnet`.
- Cria `aws_route_table.rt` e `aws_route_table_association.association` para toda subnet.
- Cria `aws_route.route` somente quando `is_public = true`.
- Subnets privadas ficam sem rota default para Internet/NAT, mantendo a rota local da VPC.

#### Inputs

| Nome | Tipo | Obrigatório | Finalidade |
| --- | --- | --- | --- |
| `vpc_id` | `string` | sim | VPC da subnet. |
| `cidr_block` | `string` | sim | CIDR da subnet. |
| `tags` | `map(string)` | sim | Tags adicionais. |
| `availability_zone` | `string` | sim | Availability Zone. |
| `is_public` | `bool` | não | Cria rota para o IGW quando `true`; padrão `false`. |
| `gateway_id` | `string` | não | ID do IGW para subnets públicas; padrão vazio. |

#### Outputs

| Nome | Descrição | Consumidores |
| --- | --- | --- |
| `subnet_id` | ID da subnet. | Interface Endpoints. |
| `route_table_id` | ID da route table associada. | Gateway Endpoint. |

#### Dependencies and assumptions

- A VPC deve existir no caller.
- Para uma subnet pública, o IGW deve existir e seu ID deve ser informado.

#### Example

```hcl
module "subnet-private-a" {
  source            = "../modules/subnet"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.16.32.0/20"
  is_public         = false
  tags              = var.environment_tags
}
```

#### Limitations and follow-ups

Não cria NAT Gateway nem rotas de saída para a Internet.

### `endpoint_interface`

Path: [`modules/endpoint_interface`](modules/endpoint_interface)

#### Purpose

Cria um VPC Interface Endpoint com ENIs privadas.

#### Intended use

Usar para serviços como ECR API e ECR DKR, informando subnets privadas e security groups.

#### Resources and behavior

- Cria `aws_vpc_endpoint.interface` do tipo `Interface`.
- Habilita `private_dns_enabled = true`.
- Não exige rotas manuais por endpoint; as ENIs são alcançadas pela rota local da VPC.

#### Inputs

| Nome | Tipo | Obrigatório | Finalidade |
| --- | --- | --- | --- |
| `vpc_id` | `string` | sim | VPC do endpoint. |
| `service_name` | `string` | sim | Nome regional do serviço. |
| `security_group_ids` | `list(string)` | sim | SGs das ENIs. |
| `tags` | `map(string)` | sim | Tags adicionais. |
| `subnet_ids` | `list(string)` | sim | Subnets que receberão as ENIs. |

#### Outputs

Não possui outputs.

#### Dependencies and assumptions

- As subnets e os SGs devem pertencer à VPC informada.
- O DNS da VPC deve estar habilitado para o DNS privado do endpoint.

#### Example

```hcl
module "ecr_interface" {
  source             = "../modules/endpoint_interface"
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.us-east-2.ecr.dkr"
  security_group_ids = [module.sg_ingress_interface.sg_id]
  subnet_ids         = [module.subnet-private-a.subnet_id]
  tags               = var.environment_tags
}
```

#### Limitations and follow-ups

Cada instância representa um serviço. O caller precisa criar os endpoints adicionais necessários.

### `endpoint_gateway`

Path: [`modules/endpoint_gateway`](modules/endpoint_gateway)

#### Purpose

Cria um VPC Gateway Endpoint e associa-o a route tables.

#### Intended use

Usar principalmente para S3 ou DynamoDB. O endpoint adiciona a rota da prefix list do serviço às route tables informadas.

#### Resources and behavior

- Cria `aws_vpc_endpoint.s3` do tipo `Gateway`.
- Usa `route_table_ids`, não `subnet_ids`.
- Não cria rotas `aws_route` manualmente.

#### Inputs

| Nome | Tipo | Obrigatório | Finalidade |
| --- | --- | --- | --- |
| `vpc_id` | `string` | sim | VPC do endpoint. |
| `service_name` | `string` | sim | Serviço, como `com.amazonaws.us-east-2.s3`. |
| `region` | `string` | não | Região do serviço; padrão `us-east-2`. |
| `route_tables_ids` | `list(string)` | sim | Route tables associadas ao endpoint. |
| `tags` | `map(string)` | sim | Tags adicionais. |

#### Outputs

Não possui outputs.

#### Dependencies and assumptions

- As route tables devem pertencer à VPC informada.
- O serviço deve ser compatível com Gateway Endpoint.
- A configuração atual utiliza a variável `route_tables_ids` conforme o caller.

#### Example

```hcl
module "s3_gateway" {
  source           = "../modules/endpoint_gateway"
  vpc_id           = module.vpc.vpc_id
  service_name     = "com.amazonaws.us-east-2.s3"
  route_tables_ids = [
    module.subnet-private-a.route_table_id,
    module.subnet-private-b.route_table_id
  ]
  tags = var.environment_tags
}
```

#### Limitations and follow-ups

Não cria subnets nem route tables. O caller deve fornecê-las.

### `security_group_egress`

Path: [`modules/security_group_egress`](modules/security_group_egress)

#### Purpose

Cria um security group destinado aos clientes, como nodes ou pods do EKS.

#### Intended use

Associar aos workloads e referenciá-lo como origem das regras para endpoints privados.

#### Resources and behavior

- Cria `aws_security_group.security_group`.
- Não cria regras próprias.
- O egress padrão da AWS permanece aberto.

#### Inputs

| Nome | Tipo | Obrigatório | Finalidade |
| --- | --- | --- | --- |
| `name` | `string` | sim | Nome do SG. |
| `description` | `string` | sim | Descrição. |
| `vpc_id` | `string` | sim | VPC do SG. |
| `tags` | `map(string)` | sim | Tags adicionais. |

#### Outputs

| Nome | Descrição | Consumidores |
| --- | --- | --- |
| `sg_id` | ID do SG. | Regras e workloads. |

#### Dependencies and assumptions

Depende de uma VPC existente no caller.

#### Example

Uso atual: `module.sg_egress_eks_ecr` em `live/02_sg_engress_eks.tf`.

#### Limitations and follow-ups

O SG ainda não é associado a um cluster EKS neste projeto.

### `security_group_ingress`

Path: [`modules/security_group_ingress`](modules/security_group_ingress)

#### Purpose

Cria o security group das ENIs dos Interface Endpoints.

#### Intended use

Associar aos endpoints e permitir entrada a partir do SG dos clientes.

#### Resources and behavior

- Cria `aws_security_group.security_group`.
- Não cria regras próprias.
- O egress padrão permanece aberto.

#### Inputs

| Nome | Tipo | Obrigatório | Finalidade |
| --- | --- | --- | --- |
| `name` | `string` | sim | Nome do SG. |
| `description` | `string` | sim | Descrição. |
| `vpc_id` | `string` | sim | VPC do SG. |
| `tags` | `map(string)` | sim | Tags adicionais. |

#### Outputs

| Nome | Descrição | Consumidores |
| --- | --- | --- |
| `sg_id` | ID do SG. | Interface Endpoints e regra de ingress. |

#### Dependencies and assumptions

Depende de uma VPC existente e de regras criadas pelo caller.

#### Example

Uso atual: `module.sg_ingress_interface` em `live/02_sg_ingress_interface_endpoint.tf`.

#### Limitations and follow-ups

Não associa o SG aos endpoints automaticamente.

### `security_group_egress_rule.tf`

Path: [`modules/security_group_egress_rule.tf`](modules/security_group_egress_rule.tf)

#### Purpose

Cria regras de saída para um security group cliente.

#### Intended use

Liberar DNS para o resolver da VPC e HTTPS para o SG do endpoint.

#### Resources and behavior

- UDP/53 para `10.16.0.2`.
- TCP/443 para o security group referenciado.

#### Inputs

| Nome | Tipo | Obrigatório | Finalidade |
| --- | --- | --- | --- |
| `security_group_id` | `string` | sim | SG que recebe as regras. |
| `referenced_security_group_id` | `string` | sim | SG de destino do HTTPS. |

#### Outputs

Não possui outputs.

#### Dependencies and assumptions

Os SGs devem estar na mesma VPC ou em contexto que permita a referência entre grupos.

#### Example

Uso atual: `module.sg_egress_eks_ecr_rule` em `live/02_sg_engress_eks.tf`.

#### Limitations and follow-ups

Não cria TCP/53 e não remove o egress padrão aberto do SG.

### `security_group_ingress_rule.tf`

Path: [`modules/security_group_ingress_rule.tf`](modules/security_group_ingress_rule.tf)

#### Purpose

Cria a regra de entrada HTTPS nos SGs dos Interface Endpoints.

#### Intended use

Permitir que clientes identificados por outro SG acessem o endpoint.

#### Resources and behavior

- Cria `aws_vpc_security_group_ingress_rule.allow_tpc`.
- Permite TCP/443 do SG referenciado para o SG de destino.

#### Inputs

| Nome | Tipo | Obrigatório | Finalidade |
| --- | --- | --- | --- |
| `security_group_id` | `string` | sim | SG de destino. |
| `referenced_security_group_id` | `string` | sim | SG de origem. |

#### Outputs

Não possui outputs.

#### Dependencies and assumptions

Os dois SGs devem ser compatíveis para referência entre grupos.

#### Example

Uso atual: `module.sg_ingress_interface_rule` em `live/02_sg_ingress_interface_endpoint.tf`.

#### Limitations and follow-ups

Permite somente TCP/443.

## Root ativo

Consulte [`live/README.md`](live/README.md) para o mapa dos arquivos, fluxo de dependências, recursos instanciados e limitações do ambiente atual.
