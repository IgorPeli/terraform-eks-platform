module "vpc" {
  source     = "../modules/vpc"
  cidr_block = "10.16.0.0/16"
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"

  })

}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = module.vpc.vpc_id

}