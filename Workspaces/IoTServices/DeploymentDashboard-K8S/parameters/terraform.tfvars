# This is where the terraform variables are set from the
# variables defined in the release pipeline.

location                                 = "${location}$"
project                                  = "${project}$"
project_prefix                           = "${project_prefix}$"
release_id                               = "${release_id}$"
release_url                              = "${release_url}$"
tier                                     = "${tier}$"
zone                                     = "${zone}$"
forwarding_function_system_identity_list = "${forwarding_function_system_identity_list}$"
sql_db_sku_dev                           = "${sql_db_sku_dev}$"
sql_db_min_capacity_dev                  = "${sql_db_min_capacity_dev}$"
sql_db_max_size_gb_dev                   = "${sql_db_max_size_gb_dev}$"
sql_db_pause_delay_minutes_dev           = "${sql_db_pause_delay_minutes_dev}$"
sql_db_sku_prd                           = "${sql_db_sku_prd}$"
sql_db_min_capacity_prd                  = "${sql_db_min_capacity_prd}$"
sql_db_max_size_gb_prd                   = "${sql_db_max_size_gb_prd}$"
sql_db_pause_delay_minutes_prd           = "${sql_db_pause_delay_minutes_prd}$"