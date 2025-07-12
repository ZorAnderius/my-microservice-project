#create dynamoDB table 
resource "aws_dynamodb_table" "tf_locks" {
  name = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform  Locks Table"
  }
}