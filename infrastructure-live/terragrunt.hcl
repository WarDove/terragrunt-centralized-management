// Additional binary dependencies: sops, python3.12, pip, boto3
skip                          = true
terragrunt_version_constraint = ">= 0.66"
terraform_version_constraint  = ">= 1.9.0"
retryable_errors              = ["(?s).*failed calling webhook*"]
retry_max_attempts            = 2
retry_sleep_interval_sec      = 30

dependencies {
  paths = ["${get_repo_root()}/infrastructure-org/root/cfstacksets"]
}

terraform {
  source = "${get_repo_root()}/modules/${basename(get_terragrunt_dir())}"
}

locals {
  common_vars   = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  region        = local.common_vars.inputs.region
  env_regex     = local.common_vars.locals.env_regex
  env           = local.common_vars.locals.env
  global_prefix = local.common_vars.locals.global_prefix
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
    bucket         = "${local.global_prefix}-terraform-state-shared-services"
    key            = "${local.global_prefix}/${get_path_from_repo_root()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "shared-services-tfstate-lock-table"

    assume_role = {
      role_arn = "arn:aws:iam::${local.common_vars.inputs.org_account_ids["shared-services"]}:role/${local.common_vars.inputs.tf_role_name}"
    }
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "aws" {
      region              = "${local.region}"
      allowed_account_ids = ["${local.common_vars.inputs.org_account_ids[local.env]}"]

      assume_role {
        role_arn = "arn:aws:iam::${local.common_vars.inputs.org_account_ids[local.env]}:role/${local.common_vars.inputs.tf_role_name}"
      }

      default_tags {
        tags = {
          Environment   = "${local.env}"
          ManagedBy     = "terraform"
          DeployedBy    = "terragrunt"
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
