# Introduction

# Getting Started

This repository is using Git submodules to manage the terraform modules hence this repository should be cloned using the following command

```
git clone --recurse-submodules
```

In order to update the already cloned repository:

```
git submodule update --init --recursive
```

To update the submodule to the lastest master branch after initializing the repository, navigate to the terraform-modules subdirectory then run the following commands:

```
git checkout master
git pull
```

# Repository Structure

The repository has 10 Terraform workspaces where each workspace is a resource group in Azure subscription:

- admin
- alarm
- analytics
- applications (marketplace applications)
- customers (platform customers)
- global
- livedata
- marketplace
- platform
- shared

# Build and Test

In order to test Terraform workspace changes locally:

1- Update the `provider.tf` by uncommenting `backend "local" {}` and commenting `backend "azurerm"` block

2- Run the following command to create a workspace that can be used for testing:

```
terraform workspace new sbx
```

3- Update the `locals` inside `variables.tf` to be like the following:

```
locals {
  diagnostics_map = {}
  app_settings    = {}
}
```
