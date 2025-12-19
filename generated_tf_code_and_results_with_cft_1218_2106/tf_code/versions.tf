# <!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
terraform {
  # Specifies the required Terraform version.
  required_version = ">= 1.3.0"

  # Specifies the required provider versions.
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.14"
    }
  }
}
