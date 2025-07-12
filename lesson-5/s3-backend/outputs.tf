#show bucket name after creation
output "s3_bucket" {
  value = aws_s3_bucket.tf_state.bucket
}

#show dynamoDB name after creation
output "dynamoDB_table" {
  value = aws_dynamodb_table.tf_locks.name
}