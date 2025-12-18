terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "6.20.0"
        }
    }

    backend "s3" {
        bucket = "d78s-remote-state"
        key = "expense-infra-backend"
        region = "us-east-1"
        dynamodb_table = "daws78s-locking"
    }
}

provider "aws" {
    region = "us-east-1"
}