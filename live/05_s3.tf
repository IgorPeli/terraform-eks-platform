module "s3_alb" {
  source = "../modules/s3"
  region = data.aws_availability_zones.available
  bucket = "loglume-${var.environment}-alb-access-logs-${data.aws_region.current.name}-${data.aws_caller_identity.current.account_id}"
  status = "Enabled"
}