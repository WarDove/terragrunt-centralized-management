locals {
  env_regex = "infrastructure-live/([a-zA-Z0-9-]+)/"
  env       = try(regex(local.env_regex, get_original_terragrunt_dir())[0], "shared-services")

  sdlc_account_ids = {
    development = "XXXXXXXXXXXXX"
    staging     = "XXXXXXXXXXXXX"
    production  = "XXXXXXXXXXXXX"
  }

  core_account_ids = {
    shared-services = "XXXXXXXXXXXXX"
    backups         = "XXXXXXXXXXXXX"
  }

  management_accoount_id = {
    root = "XXXXXXXXXXXXX"
  }

  sandbox_accoount_id = {
    sandbox = "XXXXXXXXXXXXX"
  }

  global_prefix = "XXXXXXXXXXXXX"
}

inputs = {
  global_prefix      = local.global_prefix
  sdlc_account_ids   = local.sdlc_account_ids
  core_account_ids   = local.core_account_ids
  org_account_ids    = merge(local.sdlc_account_ids, local.core_account_ids, local.management_accoount_id, local.sandbox_accoount_id)
  shared_services_id = local.core_account_ids["shared-services"]
  backups_id         = local.core_account_ids["backups"]
  root_account_id    = local.management_accoount_id["root"]
  org_units          = ["SDLC", "Production", "Core", "Sandbox"]
  tf_repo            = "XXXXXXXXXXXXX/terragrunt-infrastructure"
  tf_role_name       = "terraform-execution-role"
  gha_role_name      = "gha-role"
  gha_oidc_enabled   = true
  repo_root_path     = get_repo_root()
}