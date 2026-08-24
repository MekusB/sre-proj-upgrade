terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.11"
    }
  }

  # Remote state backend — placeholder, not active yet. State is still local
  # (terraform.tfstate in this directory), which means no locking and no
  # shared state across machines/CI. To activate:
  #   1. Provision a storage account + container to hold state, e.g.:
  #        az group create -n sre-tfstate-rg -l westus2
  #        az storage account create -n sretfstate -g sre-tfstate-rg -l westus2 --sku Standard_LRS --allow-blob-public-access false
  #        az storage container create -n tfstate --account-name sretfstate
  #   2. Uncomment the block below and fill in the real storage account name.
  #   3. Run `terraform init -migrate-state` to move local state into the backend.
  #
  # backend "azurerm" {
  #   resource_group_name  = "sre-tfstate-rg"
  #   storage_account_name = "sretfstate"
  #   container_name       = "tfstate"
  #   key                  = "dev.terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}

  # Skips the "list all resource providers" call the provider otherwise makes
  # on every run to auto-register missing ones. That call is what's returning
  # a truncated/empty response here ("unexpected end of JSON input") — a
  # transient network issue, not an auth problem (CLI token is valid). All
  # providers this config needs are already registered from prior successful
  # applies, so skip the call entirely instead of hoping it succeeds.
  resource_provider_registrations = "none"
}
