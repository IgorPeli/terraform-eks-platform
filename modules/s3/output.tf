output "bucket_id" {
  value       = aws_s3_bucket.s3.id
  description = "ID of the Bucket"

}

output "bucket_arn" {
  value       = aws_s3_bucket.s3.arn
  description = "ARN of the bucket."
}
