terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    external = {
      source = "hashicorp/external"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    template = {
      source = "hashicorp/template"
    }
	helm = {
      source = "hashicorp/helm"
      version = "1.3.2"
    }	
  }
  required_version = ">= 0.13"
}
