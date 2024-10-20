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

locals {
  diagnostics_map           = data.terraform_remote_state.shared.outputs.diagnostics_map
  diagnostics_keyvault_name = data.terraform_remote_state.shared.outputs.diagnostics_keyvault_name

  resource_prefix = "${var.company_prefix}-${terraform.workspace}"

  ## front door admin rules
  backendpools_admin = {
    bp1 = {
      name = "aue${var.zone}-adminportalweb"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-adm-aue${var.zone}-adminportalweb.azurewebsites.net"
          host_header = "${local.resource_prefix}-adm-aue${var.zone}-adminportalweb.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-default"
    },
    bp2 = {
      name = "aue${var.zone}-adminportalxl"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-adm-aue${var.zone}-adminportalxl.azurewebsites.net"
          host_header = "${local.resource_prefix}-adm-aue${var.zone}-adminportalxl.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-healthcheck"
    }
  }

  routingrules_admin = {
    rr1 = {
      name               = "aue${var.zone}-adminportalweb"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "aue${var.zone}-adminportalweb"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr2 = {
      name               = "aue${var.zone}-adminportalxl"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/api/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "aue${var.zone}-adminportalxl"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    }
  }

  ## front door api rules
  backendpools_api = {
    bp1 = {
      name = "publicapi"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-aue${var.zone}-publicapi.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-aue${var.zone}-publicapi.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        },
        be2 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-eu2${var.zone}-publicapi.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-eu2${var.zone}-publicapi.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        },
        be3 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-weu${var.zone}-publicapi.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-weu${var.zone}-publicapi.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-healthcheck"
    }
  }

  routingrules_api = {
    rr1 = {
      name               = "publicapi"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/v1/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "publicapi"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    }
  }

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
    bp2 = {
      name = "eu2${var.zone}-portalxl"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-eu2${var.zone}-portalxl.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-eu2${var.zone}-portalxl.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-healthcheck"
    },
    bp3 = {
      name = "weu${var.zone}-portalxl"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-weu${var.zone}-portalxl.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-weu${var.zone}-portalxl.azurewebsites.net"
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
    bp5 = {
      name = "eu2${var.zone}-imagehub"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-eu2${var.zone}-imagehub.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-eu2${var.zone}-imagehub.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-healthcheck"
    },
    bp6 = {
      name = "weu${var.zone}-imagehub"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-weu${var.zone}-imagehub.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-weu${var.zone}-imagehub.azurewebsites.net"
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
          address     = "${local.resource_prefix}-plt-aue${var.zone}-portalweb.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-aue${var.zone}-portalweb.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        },
        be2 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-eu2${var.zone}-portalweb.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-eu2${var.zone}-portalweb.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        },
        be3 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-weu${var.zone}-portalweb.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-weu${var.zone}-portalweb.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-default"
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
    rr2 = {
      name               = "eu2${var.zone}-portalxl"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/us/api/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "eu2${var.zone}-portalxl"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr3 = {
      name               = "weu${var.zone}-portalxl"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/eu/api/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "weu${var.zone}-portalxl"
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
    rr5 = {
      name               = "eu2${var.zone}-imagehub"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/us/api/images/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "eu2${var.zone}-imagehub"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr6 = {
      name               = "weu${var.zone}-imagehub"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/eu/api/images/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "weu${var.zone}-imagehub"
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
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    }
  }

  ## front door mobile rules
  backendpools_mobile = {
    bp1 = {
      name = "aue${var.zone}-mobilexl"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-aue${var.zone}-mobilexl.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-aue${var.zone}-mobilexl.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-default"
    },
    bp2 = {
      name = "eu2${var.zone}-mobilexl"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-eu2${var.zone}-mobilexl.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-eu2${var.zone}-mobilexl.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-default"
    },
    bp3 = {
      name = "weu${var.zone}-mobilexl"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-weu${var.zone}-mobilexl.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-weu${var.zone}-mobilexl.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-default"
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
    bp5 = {
      name = "eu2${var.zone}-imagehub"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-eu2${var.zone}-imagehub.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-eu2${var.zone}-imagehub.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 100
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-healthcheck"
    },
    bp6 = {
      name = "weu${var.zone}-imagehub"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-weu${var.zone}-imagehub.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-weu${var.zone}-imagehub.azurewebsites.net"
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
      name = "mobileweb"
      backend = {
        be1 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-aue${var.zone}-mobileweb.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-aue${var.zone}-mobileweb.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        },
        be2 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-eu2${var.zone}-mobileweb.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-eu2${var.zone}-mobileweb.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        },
        be3 = {
          enabled     = true
          address     = "${local.resource_prefix}-plt-weu${var.zone}-mobileweb.azurewebsites.net"
          host_header = "${local.resource_prefix}-plt-weu${var.zone}-mobileweb.azurewebsites.net"
          http_port   = 80
          https_port  = 443
          priority    = 1
          weight      = 50
        }
      }
      load_balancing_name = "loadbalancing-default"
      health_probe_name   = "healthprobe-default"
    }
  }

  routingrules_mobile = {
    rr1 = {
      name               = "aue${var.zone}-mobilexl"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/au/api/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "aue${var.zone}-mobilexl"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr2 = {
      name               = "eu2${var.zone}-mobilexl"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/us/api/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "eu2${var.zone}-mobilexl"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr3 = {
      name               = "weu${var.zone}-mobilexl"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/eu/api/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "weu${var.zone}-mobilexl"
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
    rr5 = {
      name               = "eu2${var.zone}-imagehub"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/us/api/images/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "eu2${var.zone}-imagehub"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr6 = {
      name               = "weu${var.zone}-imagehub"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/eu/api/images/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "weu${var.zone}-imagehub"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    },
    rr7 = {
      name               = "mobileweb"
      accepted_protocols = ["Https"]
      patterns_to_match  = ["/*"]
      configuration      = "Forwarding"
      forwarding_configuration = {
        backend_pool_name                     = "mobileweb"
        cache_enabled                         = false
        cache_use_dynamic_compression         = false
        cache_query_parameter_strip_directive = "StripNone"
        custom_forwarding_path                = "/"
        forwarding_protocol                   = "MatchRequest"
      }
    }
  }
}
