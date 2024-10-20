## front door
variable frontdoor_dns_name {
  description = "FrontDoor dns name e.g., willowinc.com or willowrail.com etc"
  type        = string
  default     = "willowinc.com"
}

variable frontdoor_keyvault_certificate_secret_name {
  description = "Keyvault certificate secret name"
  type        = string
  default     = "willowinc-com"
}

variable frontdoor_probe_interval_in_seconds {
  type        = number
  description = "The number of seconds between each Health Probe. The value must be between 5 and 255"
  default     = 120
}

variable frontdoor_dns_product_name {
  description = "Prefix of subdomain front door being used e.g. mining for mining-dev.willowinc.com"
  type        = string
  default     = "mining"
}

variable aks_public_ip {
  description = "IP Address of AKS cluster"
  type        = string
}

variable aks_backend_host_name {
  description = "Host name of the AKS backend"
  type        = string
}

variable aks_backend_host_header {
  description = "Host header of gloo virtual service on AKS cluster"
  type        = string
}

variable aks_namespace_path {
  description = "Namespace path of AKS cluster ingress"
  type        = string
}

variable enable_custom_domain_for_nonProd {
  type        = bool
  description = "Overrides existing behaviour that ignores custom domain for non prod environments"
  default     = false
}

variable enable_custom_domain {
  type        = bool
  description = "Whether to enable custom domain or use default front door domain"
  default     = false
}

variable use_keyvault_cert_for_custom_domain {
  type        = bool
  description = "Whether to use certificate from the shared keyvault for custom domain"
  default     = false
}

locals {
  diagnostics_map           = data.terraform_remote_state.shared.outputs.diagnostics_map
  shared_diagnostics_keyvault_name = data.terraform_remote_state.shared.outputs.shared_diagnostics_keyvault_name

  resource_prefix = "${var.company_prefix}-${terraform.workspace}-min"

 ## front door command rules
  backendpools_command = {
    bp1 = {
      name = "aue${var.zone}-portalxl"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-aue${var.zone}-portalxl.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-aue${var.zone}-portalxl.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-healthcheck"
    },
    bp4 = {
      name = "aue${var.zone}-imagehub"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-aue${var.zone}-imagehub.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-aue${var.zone}-imagehub.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-healthcheck"
    },
    bp7 = {
      name = "aue${var.zone}-mkp-imagehub"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-mkp-aue${var.zone}-imagehub.azurewebsites.net"
          host_header = "${local.resource_prefix}-mkp-aue${var.zone}-imagehub.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-healthcheck"
    },
    bp8 = {
      name = "web"
      backend = {
        be1 = {
          enabled     = true
          address     = "${var.aks_backend_host_name}"
          host_header = "${var.aks_backend_host_header}"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-default"
    },
    bp9 = {
      name = "mining-api-bp"
      backend = {
        be1 = {
          enabled     = true
          address     = "${var.aks_backend_host_name}"
          #This will need to change in future for different envs?
          host_header = "${var.aks_backend_host_header}"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-health-http"
    }
  }

  routingrules_command = {
    rr1 = {
      name               = "aue${var.zone}-portalxl"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/au/api/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "aue${var.zone}-portalxl"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr4 = {
      name               = "aue${var.zone}-imagehub"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/au/api/images/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "aue${var.zone}-imagehub"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr7 = {
      name               = "aue${var.zone}-mkp-imagehub"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/api/marketplace/images/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "aue${var.zone}-mkp-imagehub"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr8 = {
      name               = "web"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "web"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/${var.aks_namespace_path}/mining-web/"
        forwarding_protocol                   = "HttpOnly"
      }
    },
    rr9 = {
      name               = "mining-api"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/au/api/mining/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "mining-api-bp"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/${var.aks_namespace_path}/mining/"
        forwarding_protocol                   = "HttpOnly"
      }
    }
  }
}