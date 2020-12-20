terraform {
  required_providers {
	helm = {
      source = "hashicorp/helm"
      version = "1.3.2"
    }
  }
  required_version = ">= 0.13"
}
