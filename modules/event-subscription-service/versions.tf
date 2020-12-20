terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    external = {
      source = "hashicorp/external"
    }
    null = {
      source = "hashicorp/null"
    }
	helm = {
      source = "hashicorp/helm"
      version = "1.3.2"
    }	
  }
  required_version = ">= 0.13"
}
