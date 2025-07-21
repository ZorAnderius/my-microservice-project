terraform {
  backend "s3" {
    bucket         = "tf-lesson5-bucket"
    key            = "lesson-8-9/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "tf-locks"
    encrypt        = true
  }
}