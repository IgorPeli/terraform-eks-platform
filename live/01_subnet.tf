module "subnet-public-a" {
  source            = "../modules/subnet"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.16.0.0/20"
  depends_on        = [module.vpc]
  is_public         = true
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d",
      Name  = "public-a"
    }

  )
  gateway_id = aws_internet_gateway.internet_gateway.id

}

module "subnet-public-b" {
  source            = "../modules/subnet"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[1]
  depends_on        = [module.vpc]
  cidr_block        = "10.16.16.0/20"
  is_public         = true
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d",
      Name  = "public-b"
    }
  )
  gateway_id = aws_internet_gateway.internet_gateway.id

}

module "subnet-private-a" {
  source            = "../modules/subnet"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block        = "10.16.32.0/20"
  depends_on        = [module.vpc]
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d",
      Name  = "private-a"
    }

  )

}

module "subnet-private-b" {
  source            = "../modules/subnet"
  vpc_id            = module.vpc.vpc_id
  availability_zone = data.aws_availability_zones.available.names[1]
  cidr_block        = "10.16.48.0/20"
  depends_on        = [module.vpc]
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d",
      Name  = "private-b"
    }

  )

}