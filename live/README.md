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

## Conexao entre recursos

O modulo `vpc` exporta `module.vpc.vpc_id`.

Esse ID e usado por:

- `aws_internet_gateway.internet_gateway`;
- todos os blocos `module "subnet-..."`.

As subnets publicas usam `is_public = true`, o que ativa a criacao de route table e rota publica dentro do modulo `subnet`.

## Comandos

```powershell
terraform fmt -recursive
terraform init
terraform validate
terraform plan
```

## Pendencias atuais

- Informar `gateway_id = aws_internet_gateway.internet_gateway.id` nas subnets publicas.
- Associar as route tables publicas as subnets publicas.
- Criar outputs no modulo `subnet`.
