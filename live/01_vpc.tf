module "vpc" {
  source     = "../modules/vpc"
  cidr_block = "10.16.0.0/16"
  tags = merge(
    var.environment_tags,
    {
      Owner = "Ig0d"

  })

}

