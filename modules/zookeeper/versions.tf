terraform {
  required_providers {
    null = {
      source = "hashicorp/null"
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
