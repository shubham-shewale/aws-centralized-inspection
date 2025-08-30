terraform {
  backend "s3" {
    bucket         = "aws-centralized-inspection-state"
    key            = "live/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-centralized-inspection-lock"
    encrypt        = true
  }
}