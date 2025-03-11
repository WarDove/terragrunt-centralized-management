skip = true

terraform {
  source = "${get_repo_root()}/modules/${basename(get_terragrunt_dir())}"
}

locals {
  common_vars   = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  global_prefix = local.common_vars.locals.global_prefix
  env           = "root"
  profile       = get_env("AWS_PROFILE_ROOT", "${local.global_prefix}-root-sso")
  region        = local.common_vars.inputs.region
}

inputs = merge(
  local.common_vars.inputs,
  {
    env        = local.env
    region     = local.region
    account_id = local.common_vars.inputs.org_account_ids[local.env]
  }
)

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket         = "${local.global_prefix}-terraform-state-root"
    key            = "${local.global_prefix}/${get_path_from_repo_root()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "root-tfstate-lock-table"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region = "${local.region}"
      allowed_account_ids =["${local.common_vars.inputs.org_account_ids[local.env]}"]

      default_tags {
        tags = {
          Environment  = "${local.env}"
          ManagedBy    = "terraform"
        }
      }
    }
EOF
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.74"
        }
      }
    }
EOF
}