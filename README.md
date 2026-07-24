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
- output com o ID do Internet Gateway.

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
|   |-- 01_subnet.tf
|   `-- 01_vpc.tf
`-- modules
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

O modulo `vpc` cria uma VPC AWS.

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

O modulo `subnet` cria uma subnet AWS. Quando `is_public = true`, ele tambem cria uma route table e uma rota padrao para um Internet Gateway.

### Recursos criados

- `aws_subnet.subnet`
- `aws_route_table.rt`, somente para subnet publica
- `aws_route.route`, somente para subnet publica

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

## Configuracao `live`

Arquivos principais:

| Arquivo | Funcao |
| --- | --- |
| `00_providers.tf` | Declara o provider AWS `~> 6.0`, regiao `us-east-2` e profile `terraform-local`. |
| `00_variables.tf` | Declara `environment_tags`, usado para tags por ambiente. |
| `00_data.tf` | Busca Availability Zones disponiveis. |
| `00_output.tf` | Exporta o ID do Internet Gateway. |
| `01_vpc.tf` | Instancia o modulo VPC e cria o Internet Gateway. |
| `01_subnet.tf` | Instancia quatro subnets: duas publicas e duas privadas. |

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

## Proximos passos naturais

- Passar `gateway_id` para os modulos de subnet publica em `live/01_subnet.tf`.
- Criar associacao explicita entre route table publica e subnet publica.
- Adicionar outputs no modulo `subnet`, como subnet ID e route table ID.
- Renomear `modules/subnet/variables..tf` para `variables.tf`.
- Decidir se `environments/dev` e `environments/prod` vao virar roots Terraform completos ou apenas arquivos de valores.
