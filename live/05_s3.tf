module "s3_alb" {
  source = "../modules/s3"
  region = data.aws_region.current.region
  bucket = "loglume-${var.environment}-alb-access-logs-${data.aws_region.current.region}-${data.aws_caller_identity.current.account_id}"
  status = "Enabled"
}

data "aws_iam_policy_document" "alb_access_logs" {
  statement {
    sid    = "AllowALBLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    resources = [
      "${module.s3_alb.bucket_arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs" {
  bucket = module.s3_alb.bucket_id
  policy = data.aws_iam_policy_document.alb_access_logs.json
}
