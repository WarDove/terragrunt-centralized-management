skip = true

terraform {
  source = "${get_repo_root()}/modules/${basename(get_terragrunt_dir())}"
}

locals {
  common_vars   = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  env           = "root"
  profile       = get_env("AWS_PROFILE_ROOT", "${local.common_vars.inputs.company_prefix}-root-sso")
  region        = local.common_vars.inputs.region
  ci_env        = get_env("CI", "false")
  creator_email = tobool(local.ci_env) ? get_env("GITHUB_ACTOR", "NOT_SET") : run_cmd("git", "config", "--get", "user.email")
  creator       = get_env("USER", "NOT_SET")
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
    bucket         = "${local.common_vars.inputs.company_prefix}-terraform-state-root"
    key            = "${local.common_vars.inputs.company_prefix}/${get_path_from_repo_root()}/terraform.tfstate"
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

# Assumed terraform-execution-role in root account have to be created manually, alternatively we could use sso
# role / iam user directly by commenting out lines below
# assume_role {
# role_arn = "arn:aws:iam::${local.common_vars.inputs.org_account_ids[local.env]}:role/${local.common_vars.inputs.tf_role_name}"
# }

      default_tags {
        tags = {
          Environment  = "${local.env}"
          ManagedBy    = "terraform"
          DeployedBy   = "terragrunt"
          Company      = "${local.common_vars.inputs.company_prefix}"
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