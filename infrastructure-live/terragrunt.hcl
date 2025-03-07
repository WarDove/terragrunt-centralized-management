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
  common_vars     = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  secret_vars_ecs = yamldecode(sops_decrypt_file(find_in_parent_folders("secrets-ecs.yaml")))
  company_prefix  = local.common_vars.inputs.company_prefix
  region          = local.common_vars.inputs.region
  env_regex       = "infrastructure-live/([a-zA-Z0-9-]+)/"
  env             = try(regex(local.env_regex, get_original_terragrunt_dir())[0], "shared-services")
  tg_repo         = "repo:${replace(replace(trimspace(run_cmd("git", "config", "--get", "remote.origin.url")), "git@github.com:", ""), ".git", "")}"
  profile         = get_env("AWS_PROFILE", "${local.company_prefix}-shared-services-tf")
  ci_env          = get_env("CI", "false")
  creator_email   = tobool(local.ci_env) ? get_env("GITHUB_ACTOR", "NOT_SET") : run_cmd("git", "config", "--get", "user.email")
  creator         = get_env("USER", "NOT_SET")
}

inputs = merge(
  local.common_vars.inputs,
  local.secret_vars_ecs,
  {
    tg_repo    = local.tg_repo
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
    bucket         = "${local.company_prefix}-terraform-state-shared-services"
    key            = "${local.company_prefix}/${get_path_from_repo_root()}/terraform.tfstate"
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
          Company       = "${local.company_prefix}"
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
