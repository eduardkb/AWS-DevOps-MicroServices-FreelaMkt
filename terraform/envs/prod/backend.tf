terraform {
  backend "s3" {
    bucket         = "freelamkp-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "FreelaMkp-terraform-locks"
    encrypt        = true
  }
}