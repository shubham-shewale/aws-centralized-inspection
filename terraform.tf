terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.11"
    }
    panos = {
      source  = "paloaltonetworks/panos"
      version = "~> 1.11"
    }
    cloudngfwaws = {
      source  = "paloaltonetworks/cloudngfwaws"
      version = "~> 1.0"
    }
  }
}