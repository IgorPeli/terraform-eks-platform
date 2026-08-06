# Root Terraform ativo: `live`

Esta pasta é o root Terraform executado atualmente. Os comandos `terraform init`, `terraform validate`, `terraform plan` e `terraform apply` devem ser executados aqui.

## Configuração atual

- Provider AWS na região `us-east-2`, usando o profile `terraform-local`.
- VPC `10.16.0.0/16` com DNS support e DNS hostnames habilitados.
- Internet Gateway associado à VPC.
- Subnets públicas A/B: `10.16.0.0/20` e `10.16.16.0/20`.
- Subnets privadas A/B: `10.16.32.0/20` e `10.16.48.0/20`.
- Route table própria associada a cada subnet.
- Rota `0.0.0.0/0` das subnets públicas para o Internet Gateway.
- Rota `0.0.0.0/0` das subnets privadas para um NAT Gateway regional público.
- Um único ID de NAT Gateway regional consumido pelas duas subnets privadas.
- Gateway Endpoint do S3 associado às duas route tables privadas.
- Nenhum Interface Endpoint instanciado no root ativo.
- Um SG do EKS com regras de ingress e egress explícitas.
- Um SG do ALB com ingress HTTPS público e egress HTTPS para o SG do EKS.
- Um caller de ALB internet-facing posicionado nas duas subnets públicas.

As subnets privadas não apontam diretamente para o Internet Gateway. Elas encaminham tráfego externo para o NAT Gateway, que permite conexões iniciadas pelos workloads privados sem aceitar conexões de entrada não solicitadas. Esse caminho atende, entre outros casos, ao polling do Argo CD sobre repositórios no GitHub.

## Decisão de arquitetura

O desenho anterior usava Interface Endpoints para `ecr.api` e `ecr.dkr`. A arquitetura foi alterada para combinar NAT Gateway regional e Gateway Endpoint do S3 com os seguintes objetivos:

- oferecer saída genérica para o GitHub e outros endpoints públicos consumidos por workloads e add-ons;
- evitar criar e manter um Interface Endpoint diferente para cada serviço AWS necessário;
- simplificar rotas, security groups e dependências entre módulos;
- reduzir as cobranças fixas dos Interface Endpoints por endpoint e por Availability Zone.

O NAT Gateway também é cobrado por hora em cada AZ atendida pelo modo regional e por volume processado. A mudança não elimina custos de rede; ela troca uma arquitetura de acesso privado específico por serviço por uma saída compartilhada e mais flexível. O custo deve ser acompanhado conforme o volume real.

> [!decision]
> O Gateway Endpoint do S3 foi mantido porque não possui cobrança adicional. Sua rota específica evita que tráfego S3 passe pelo NAT e incorra na cobrança de processamento do NAT, enquanto os demais destinos continuam usando o egress regional.

Referências: [Interface VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html), [Gateway Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html) e [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/).

## Roteamento

Cada subnet possui uma route table própria. A mesma rede de destino pode aparecer em route tables diferentes com alvos distintos:

| Route table | Rota default | Finalidade |
| --- | --- | --- |
| Pública A | `0.0.0.0/0 → Internet Gateway` | Saída direta dos recursos públicos. |
| Pública B | `0.0.0.0/0 → Internet Gateway` | Saída direta dos recursos públicos. |
| Privada A | `0.0.0.0/0 → NAT regional` e prefix list S3 → Gateway Endpoint | NAT para egress geral; endpoint para S3. |
| Privada B | `0.0.0.0/0 → NAT regional` e prefix list S3 → Gateway Endpoint | NAT para egress geral; endpoint para S3. |

O NAT regional é associado diretamente à VPC e não recebe `subnet_id`. A AWS gerencia sua expansão entre Availability Zones e a route table própria com o caminho até o Internet Gateway.

```text
subnet-public-a/b  ──0.0.0.0/0──> Internet Gateway

subnet-private-a/b ──0.0.0.0/0──> NAT Gateway regional
                                          │
                                          └──> Internet Gateway ──> Internet

subnet-private-a/b ──prefix list S3──> Gateway Endpoint S3
```

A rota da prefix list do S3 é mais específica que `0.0.0.0/0` e, por longest prefix match, tem precedência sobre o NAT para destinos do S3. Rotas e security groups cumprem funções diferentes: a route table define o caminho; regras de egress, network ACLs e políticas aplicáveis autorizam o tráfego.

## Mapa de arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `00_providers.tf` | Provider AWS, versão `~> 6.0`, região e profile. |
| `00_variables.tf` | Variável `environment_tags`. |
| `00_data.tf` | Availability Zones disponíveis e região atual do provider. |
| `00_output.tf` | Output com o ID do Internet Gateway. |
| `01_vpc.tf` | Módulo VPC e Internet Gateway. |
| `01_nat.tf` | Instância do NAT Gateway regional. |
| `01_subnet.tf` | Duas subnets públicas, duas privadas e seus destinos de rota. |
| `02_sg_engress_eks.tf` | SG do EKS e regras de egress para DNS, HTTPS público e S3. |
| `02_sg_ingress_eks.tf` | Regra de ingress do EKS proveniente do SG do ALB. |
| `03_endpoint_gateway.tf` | Gateway Endpoint do S3 nas route tables privadas. |
| `04_alb.tf` | ALB internet-facing, SG do ALB e regras de ingress/egress. |

O arquivo `03_endpoint_interface.tf` foi retirado do root ativo. O módulo reutilizável continua disponível em `../modules/endpoint_interface`.

## Fluxo de dependências

```text
module.vpc
├── aws_internet_gateway.internet_gateway
├── module.nat_gateway
├── module.subnet-public-a/b
├── module.subnet-private-a/b
│       ├── module.nat_gateway.nat_id
│       └── module.s3_gateway via route_table_id
├── module.sg_eks
│       ├── ingress HTTPS a partir de module.sg_alb
│       ├── egress DNS UDP/TCP e HTTPS público
│       └── module.egress_s3_gateway via prefix_list_id
├── module.sg_alb
│       ├── ingress HTTPS de 0.0.0.0/0
│       └── egress HTTPS para module.sg_eks
└── module.alb_internet_facing
        ├── module.subnet-public-a/b
        └── module.sg_alb
```

- `module.nat_gateway` recebe `module.vpc.vpc_id` e declara dependência do Internet Gateway.
- As subnets públicas recebem `aws_internet_gateway.internet_gateway.id`.
- As subnets privadas recebem `module.nat_gateway.nat_id`.
- `module.s3_gateway` recebe os `route_table_id` das duas subnets privadas.
- `module.egress_s3_gateway` recebe `module.s3_gateway.prefix_list_id`.
- As referências a outputs criam dependências implícitas entre VPC, NAT, subnets, endpoint e regra de egress.

## Módulos instanciados

### VPC e Internet Gateway

`module.vpc` cria a VPC. O recurso `aws_internet_gateway.internet_gateway` é associado a essa VPC e serve como destino das rotas públicas e como caminho externo do NAT regional.

### NAT Gateway regional

`module.nat_gateway` cria um NAT Gateway com:

```hcl
availability_mode = "regional"
connectivity_type = "public"
```

O módulo recebe `vpc_id` e `tags`, e exporta `nat_id`. No modo regional automático atual, o caller não informa subnet nem Elastic IP.

### Subnets

- `module.subnet-public-a` e `module.subnet-public-b` criam subnets públicas e direcionam `0.0.0.0/0` ao Internet Gateway.
- `module.subnet-private-a` e `module.subnet-private-b` criam subnets privadas e direcionam `0.0.0.0/0` ao NAT Gateway regional.

Cada módulo de subnet exporta `subnet_id` e `route_table_id`.

### Gateway Endpoint do S3

`module.s3_gateway` instancia `endpoint_gateway` para `com.amazonaws.us-east-2.s3` e associa o endpoint às duas route tables privadas. O output `prefix_list_id` é consumido pela regra de egress HTTPS específica para S3.

O Gateway Endpoint não cria ENIs nem possui SG próprio. A route table direciona o tráfego pela prefix list, enquanto o SG cliente permite TCP/443 para essa mesma prefix list.

### Interface Endpoints preservados

O módulo `endpoint_interface` não é instanciado neste root, mas permanece no repositório. Ele pode ser reutilizado se surgir requisito de tráfego privado, restrição de egress ou compliance. A reativação exige restaurar callers, SG das ENIs e regras de entrada e saída compatíveis.

### Security groups

`module.sg_eks` e `module.sg_alb` usam o mesmo módulo genérico `security_group`. A separação ocorre por recurso protegido, não por direção de tráfego: cada SG pode receber regras de ingress e egress.

O módulo `security_group_egress_rule` é instanciado quatro vezes para o SG do EKS:

- UDP/53 para o resolver da VPC em `10.16.0.2/32`;
- TCP/53 para o resolver da VPC em `10.16.0.2/32`;
- TCP/443 para `0.0.0.0/0`, usando o NAT como caminho de rede;
- TCP/443 para a prefix list do Gateway Endpoint do S3.

Cada regra seleciona seu destino por `destination_type`: `cidr_ipv4`, `prefix_list` ou `security_group`. O NAT Gateway não é destino do SG; a regra HTTPS autoriza os endereços externos e a route table encaminha esse tráfego ao NAT.

O SG do ALB permite ingress TCP/443 de `0.0.0.0/0` e egress TCP/443 para o SG do EKS. O SG do EKS aceita TCP/443 cuja origem seja o SG do ALB. As respostas são tratadas de forma stateful pelos security groups.

### Application Load Balancer

`module.alb_internet_facing` configura o ALB com `internal = false`, associa as duas subnets públicas e usa apenas `module.sg_alb`. Os nodes e pods do EKS permanecem destinados às subnets privadas; o encaminhamento futuro ocorrerá por target group usando endereços privados.

## Estado da configuração

> [!note]
> O módulo `load_balancer` cria o ALB e associa subnets e SGs, mas ainda não cria listener, target group nem associação de targets. Esses componentes são necessários para o ALB encaminhar tráfego aos workloads.

## Comandos

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Revise o `terraform plan` antes do apply para confirmar:

- destruição somente dos Interface Endpoints anteriores;
- criação do NAT Gateway regional;
- rotas públicas apontando para o Internet Gateway;
- rotas privadas apontando para o NAT Gateway;
- preservação do Gateway Endpoint do S3 nas duas route tables privadas;
- egress DNS UDP/TCP, HTTPS público e HTTPS para a prefix list do S3.
- ALB associado somente às duas subnets públicas e ao SG do ALB.
- ingress do EKS limitado à origem `module.sg_alb` na porta 443.

## Limitações atuais

- O cluster EKS ainda não está definido neste root.
- O SG do EKS ainda não está associado a nodes ou pods reais.
- O módulo de ALB ainda não possui listener, target group, targets ou access logs.
- O NAT regional simplifica HA, mas possui cobrança horária por AZ atendida e por volume processado.
- O Gateway Endpoint reduz processamento do NAT para S3, mas ainda não possui policy customizada.
- A tag interna `Purpose = "eks-interface-endpoints"` do NAT não representa sua finalidade atual.
- Não existem network ACLs customizadas no projeto.
- A região está declarada no provider, mas alguns módulos ainda possuem valores regionais fixos.
- `data.aws_region.current` está declarado, mas ainda não é consumido por recursos ou outputs.
- Os arquivos de `environments/dev` e `environments/prod` ainda não são roots Terraform independentes.
