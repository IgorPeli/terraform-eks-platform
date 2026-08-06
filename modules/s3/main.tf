resource "aws_s3_bucket" "s3" {
  bucket = var.bucket
  region = var.region
}

resource "aws_s3_bucket_versioning" "s3_version" {
  bucket = aws_s3_bucket.s3.id

  versioning_configuration {
    status = var.status
  }
}