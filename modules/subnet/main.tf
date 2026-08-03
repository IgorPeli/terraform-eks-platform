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
  vpc_id = var.vpc_id

}

resource "aws_route" "public_route" {
  count                  = var.is_public ? 1 : 0
  route_table_id         = aws_route_table.rt.id
  region                 = "us-east-2"
  gateway_id             = var.gateway_id
  destination_cidr_block = "0.0.0.0/0"

}

resource "aws_route_table_association" "association" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route" "private_route" {
  count                  = var.is_public ? 0 : 1
  route_table_id         = aws_route_table.rt.id
  region                 = "us-east-2"
  nat_gateway_id         = var.nat_gateway
  destination_cidr_block = "0.0.0.0/0"

}