location                                   = "australiaeast"
project                                    = "mining"
project_prefix                             = "min"
company_prefix                             = "wil"
state-resource-group-name                  = "deployment-data"
state-storage-account-name                 = "k8sintenvdeploydata"
state-storage-account-sas-token            = ""
tier                                       = 2
zone                                       = 1
frontdoor_dns_name                         = "willowinc.com"
frontdoor_probe_interval_in_seconds        = 300
frontdoor_keyvault_certificate_secret_name = "willowinc-com"
notification_emails                        = "service@contoso.com,support@contoso.com"
frontdoor_dns_product_name                 = "mining"
enable_custom_domain_for_nonProd           = false
enable_custom_domain                       = false
use_keyvault_cert_for_custom_domain        = false