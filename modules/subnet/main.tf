resource "aws_subnet" "subnet" {
  vpc_id            = var.vpc_id
  cidr_block        = var.cidr_block
  availability_zone = var.availability_zone
  tags = merge({
    Service   = "network"
    ManagedBy = "Terraform"
    },
    var.tags
  )
  map_public_ip_on_launch = var.is_public
}


resource "aws_route_table" "rt" {
  count  = var.is_public ? 1 : 0
  vpc_id = var.vpc_id

}

resource "aws_route" "route" {
  count          = var.is_public ? 1 : 0
  route_table_id = aws_route_table.rt[0].id
  region         = "us-east-2"
  gateway_id     = var.gateway_id
  destination_cidr_block = "0.0.0.0/0"

}
