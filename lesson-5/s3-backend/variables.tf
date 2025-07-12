variable "bucket_name" {
  type        = string
  description = "S3 bucket name"
  default     = "tf-lesson5-bucket"
}

variable "table_name" {
  type        = string
  description = "DynamoDB table name"
  default     = "tf-locks"
}
