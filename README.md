# Arquitetura do Projeto Terraform

Este projeto esta organizado para separar claramente:

- onde o Terraform e executado;
- onde ficam os modulos reutilizaveis;
- onde ficam as configuracoes de ambiente;
- onde ficam os valores das variaveis.

A ideia principal e: **environments instanciam modulos; modules definem recursos reutilizaveis**.

## Estrutura de Pastas

```text
.
├── environments
│   └── dev
│       ├── backend.tf
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       ├── terraform.tfvars.example
│       ├── variables.tf
│       └── versions.tf
└── modules
    ├── ec2-instance
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    └── network
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

## Visao Geral

O Terraform trabalha melhor quando voce separa o projeto em duas partes:

1. **Ambientes**

   Sao as pastas onde voce roda comandos como:

   ```powershell
   terraform init
   terraform plan
   terraform apply
   ```

   Neste projeto, o ambiente criado foi:

   ```text
   environments/dev
   ```

2. **Modulos**

   Sao blocos reutilizaveis de infraestrutura.

   Neste projeto, os modulos criados foram:

   ```text
   modules/network
   modules/ec2-instance
   ```

O ambiente `dev` pode chamar os modulos. Os modulos nao chamam o ambiente.

## Pasta `environments`

A pasta `environments` representa os ambientes da sua infraestrutura.

Exemplos comuns:

```text
environments/dev
environments/staging
environments/prod
```

Neste momento existe apenas:

```text
environments/dev
```

Sim, a ideia e exatamente simular que futuramente voce poderia ter `dev` e `prod`.

Por exemplo:

- `dev`: ambiente de estudo, teste ou desenvolvimento;
- `prod`: ambiente real, mais controlado e estavel.

Cada ambiente pode ter:

- backend proprio;
- variaveis proprias;
- regiao propria;
- tamanho diferente de instancia;
- quantidade diferente de recursos;
- tags diferentes;
- modulos instanciados com valores diferentes.

## Pasta `environments/dev`

Essa e a pasta principal para executar o Terraform no ambiente de desenvolvimento.

Quando voce estiver trabalhando no ambiente `dev`, normalmente entra nela:

```powershell
cd environments/dev
```

E entao roda:

```powershell
terraform init
terraform plan
terraform apply
```

## Arquivo `versions.tf`

Esse arquivo costuma declarar:

- versao minima do Terraform;
- providers usados no projeto;
- versao dos providers.

Exemplo conceitual:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Esse arquivo nao cria recurso. Ele define requisitos.

## Arquivo `providers.tf`

Esse arquivo configura o provider.

Provider e o plugin que permite o Terraform conversar com uma plataforma.

Exemplos de providers:

- `aws`;
- `azurerm`;
- `google`;
- `kubernetes`;
- `github`.

No caso da AWS, normalmente voce configura a regiao:

```hcl
provider "aws" {
  region = var.aws_region
}
```

O provider depende da versao declarada em `versions.tf`, mas `providers.tf` e onde voce configura como ele sera usado.

## Arquivo `backend.tf`

Esse arquivo configura onde o Terraform vai guardar o state.

O **state** e o arquivo que registra o que o Terraform criou.

Sem backend remoto, o Terraform cria um arquivo local:

```text
terraform.tfstate
```

Em projetos reais, e comum usar backend remoto, por exemplo:

- S3 na AWS;
- Azure Storage;
- Google Cloud Storage;
- Terraform Cloud.

Para AWS, um backend comum seria S3 com DynamoDB para lock.

Importante: o bloco `backend` nao aceita variaveis normais como `var.nome`. Por isso, normalmente ele tem valores escritos diretamente ou e configurado via parametro no `terraform init`.

## Arquivo `variables.tf`

Esse arquivo declara as variaveis que o ambiente aceita.

Ele responde a pergunta:

> Quais valores este ambiente precisa receber?

Exemplo:

```hcl
variable "aws_region" {
  type        = string
  description = "Regiao AWS onde os recursos serao criados."
}
```

Aqui voce esta apenas declarando que existe uma variavel chamada `aws_region`.

Isso nao significa que voce ja deu valor a ela.

## Arquivo `terraform.tfvars`

O arquivo `terraform.tfvars` serve para passar valores para as variaveis declaradas em `variables.tf`.

Se em `variables.tf` voce declara:

```hcl
variable "aws_region" {
  type = string
}
```

Em `terraform.tfvars`, voce pode preencher:

```hcl
aws_region = "us-east-1"
```

Entao a relacao e:

```text
variables.tf      declara a variavel
terraform.tfvars  define o valor da variavel
```

O `tfvars` **nao e baseado na versao do provider**.

Ele e baseado nas variaveis que voce mesmo criou.

Ou seja:

- o provider define quais recursos e argumentos existem;
- o `variables.tf` define quais entradas seu codigo aceita;
- o `terraform.tfvars` passa valores para essas entradas.

## Arquivo `terraform.tfvars.example`

Neste projeto existe um arquivo:

```text
terraform.tfvars.example
```

Ele serve como modelo.

A ideia e voce copiar:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

E preencher o `terraform.tfvars` real.

Normalmente o arquivo `terraform.tfvars` nao vai para o Git, porque pode conter dados sensiveis ou configuracoes locais.

Ja o `terraform.tfvars.example` pode ir para o Git, porque serve apenas como referencia.

## Arquivo `main.tf` no Ambiente

O `main.tf` dentro de `environments/dev` normalmente e onde voce instancia os modulos.

Exemplo conceitual:

```hcl
module "network" {
  source = "../../modules/network"
}
```

Esse bloco significa:

> Ambiente dev, use o modulo network que esta dentro da pasta modules/network.

O ambiente e quem decide quais modulos usar.

## Arquivo `outputs.tf` no Ambiente

Esse arquivo mostra informacoes importantes depois do `terraform apply`.

Exemplos:

- ID da VPC;
- IP publico de uma instancia;
- nome de um bucket;
- endpoint de uma aplicacao.

Outputs ajudam voce a enxergar o resultado da infraestrutura criada.

## Pasta `modules`

A pasta `modules` guarda blocos reutilizaveis.

Um modulo deve ser pensado como uma peca de Lego da infraestrutura.

Exemplos:

- modulo de rede;
- modulo de instancia EC2;
- modulo de banco de dados;
- modulo de bucket S3;
- modulo de IAM;
- modulo de cluster Kubernetes.

Neste projeto existem dois modulos iniciais:

```text
modules/network
modules/ec2-instance
```

## Modulo `modules/network`

Esse modulo deve ser responsavel por recursos de rede.

Exemplos de recursos que poderiam ficar nele:

- VPC;
- subnets;
- route tables;
- internet gateway;
- NAT gateway;
- security groups de rede, se fizer sentido no seu desenho.

Arquivos:

```text
modules/network/main.tf
modules/network/variables.tf
modules/network/outputs.tf
```

### `main.tf` do modulo

Onde voce declara os recursos do modulo.

### `variables.tf` do modulo

Onde voce declara quais valores o modulo precisa receber.

Exemplo:

```hcl
variable "vpc_cidr" {
  type = string
}
```

### `outputs.tf` do modulo

Onde voce exporta valores para quem chamou o modulo.

Exemplo:

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}
```

Isso permite que o ambiente use:

```hcl
module.network.vpc_id
```

## Modulo `modules/ec2-instance`

Esse modulo deve ser responsavel por criar uma instancia EC2.

Exemplos de coisas que poderiam ficar nele:

- instancia EC2;
- security group da instancia;
- user data;
- volume EBS;
- elastic IP, se necessario.

Arquivos:

```text
modules/ec2-instance/main.tf
modules/ec2-instance/variables.tf
modules/ec2-instance/outputs.tf
```

Esse modulo provavelmente receberia valores como:

- AMI;
- tipo da instancia;
- subnet;
- security groups;
- nome da instancia;
- tags.

## Fluxo Mental do Projeto

Pense assim:

```text
environments/dev
    chama
        modules/network
        modules/ec2-instance
```

O ambiente `dev` e o "orquestrador".

Os modulos sao as "pecas".

O ambiente passa valores para os modulos.

Os modulos criam recursos.

Os modulos devolvem outputs.

O ambiente pode usar esses outputs para conectar uma coisa na outra.

## Exemplo de Conexao Entre Modulos

Imagine que o modulo `network` cria uma subnet e exporta:

```hcl
output "public_subnet_id" {
  value = aws_subnet.public.id
}
```

Depois o ambiente `dev` pode passar essa subnet para o modulo de EC2:

```hcl
module "ec2" {
  source    = "../../modules/ec2-instance"
  subnet_id = module.network.public_subnet_id
}
```

Isso e uma das partes mais importantes do Terraform modular:

```text
um modulo cria algo
outro modulo usa esse resultado
o ambiente conecta os dois
```

## Por que Esse Jeito e Bom?

Essa organizacao e boa porque:

- evita deixar todos os recursos em um unico arquivo gigante;
- facilita reaproveitar codigo;
- deixa claro onde executar o Terraform;
- separa configuracao de ambiente da definicao dos recursos;
- facilita criar `dev`, `staging` e `prod` depois;
- ajuda voce a entender a dependencia entre recursos;
- aproxima seu projeto de uma estrutura usada em projetos reais.

## O que Evitar

Evite colocar tudo em uma unica pasta quando o projeto comecar a crescer.

Por exemplo:

```text
main.tf
variables.tf
outputs.tf
vpc.tf
ec2.tf
rds.tf
iam.tf
bucket.tf
```

Isso ate funciona no inicio, mas com o tempo fica mais dificil entender:

- o que pertence a rede;
- o que pertence a compute;
- o que muda por ambiente;
- o que pode ser reutilizado;
- o que e configuracao;
- o que e modulo.

## Ordem Recomendada Para Estudar

Uma boa ordem para preencher manualmente os arquivos seria:

1. `environments/dev/versions.tf`
2. `environments/dev/providers.tf`
3. `environments/dev/variables.tf`
4. `environments/dev/main.tf`
5. `modules/network/variables.tf`
6. `modules/network/main.tf`
7. `modules/network/outputs.tf`
8. `modules/ec2-instance/variables.tf`
9. `modules/ec2-instance/main.tf`
10. `modules/ec2-instance/outputs.tf`
11. `environments/dev/outputs.tf`
12. `environments/dev/backend.tf`

Eu deixaria o `backend.tf` por ultimo, porque primeiro e melhor entender provider, recurso, variavel, modulo e output. Depois voce coloca backend remoto.

## Resumo Curto

```text
versions.tf             versoes do Terraform e providers
providers.tf            configuracao do provider
backend.tf              onde o state sera salvo
variables.tf            declara variaveis
terraform.tfvars        passa valores para variaveis
main.tf                 cria recursos ou instancia modulos
outputs.tf              mostra ou exporta resultados
modules/                pecas reutilizaveis
environments/           ambientes que usam os modulos
```
