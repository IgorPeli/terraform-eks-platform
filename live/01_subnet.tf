module "subnet" {
    source = "../modules/subnet"
    vpc_id = module.vpc.vpc_id
    availability_zone = [ data.aws_availability_zones.available[0]]
    cidr_block = "10.16.0.0/20"
    tags = merge(
        var.environment_tags,
        {
            Owner = "Ig0d",
            Description = "public-a"
        }
        
    )
   
}