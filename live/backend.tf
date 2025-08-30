terraform {
  backend "s3" {
    bucket         = "aws-centralized-inspection-state"
    key            = "live/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "aws-centralized-inspection-lock"
    encrypt        = true
    # KMS key ID will be dynamically set during init
    # kms_key_id     = "alias/terraform-state-encryption"
  }
}