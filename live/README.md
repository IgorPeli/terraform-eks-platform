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

Cria o security group usado como origem do trafego dos nodes/pods do EKS. O modulo cria somente o SG; suas regras ficam no modulo `security_group_egress_rule.tf`.

### `modules/security_group_ingress`

Cria o security group associado as ENIs do Interface Endpoint. O modulo cria somente o SG; sua regra de entrada fica no modulo `security_group_ingress_rule.tf`.

### `modules/security_group_egress_rule.tf`

Cria as regras de saida do SG do EKS:

- UDP/53 para o resolver DNS da VPC `10.16.0.2`;
- TCP/443 para o SG do Interface Endpoint.

### `modules/security_group_ingress_rule.tf`

Cria a regra de entrada TCP/443 no SG do endpoint, permitindo origem no SG do EKS.

### `modules/endpoint_interface`

Cria um VPC Interface Endpoint em subnets especificas, associa os security groups informados e habilita `private_dns_enabled`.

Exemplo atual:

```hcl
module "ecr_interface" {
  source             = "../modules/endpoint_interface"
  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.sg_ingress_interface.sg_id]
  service_name       = "com.amazonaws.us-east-2.ecr.dkr"
  subnet_ids         = [module.subnet-private-b.subnet_id, module.subnet-private-a.subnet_id]
}
```
