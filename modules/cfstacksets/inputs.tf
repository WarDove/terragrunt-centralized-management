variable "shared_services_id" {
  type        = string
  description = "The Shared-services AWS account ID"
}

variable "backups_id" {
  type        = string
  description = "The Backups AWS account ID"
}

variable "root_account_id" {
  type        = string
  description = "The Root AWS account ID"
}

variable "tf_role_name" {
  type        = string
  description = "Standard role name for Terraform execution"
}

variable "gha_role_name" {
  type        = string
  description = "Standard role name for GitHub Actions execution"
}

variable "org_ou_ids" {
  type = map(string)
}

variable "repo_root_path" {
  type = string
}

variable "region" {
  type = string
}

variable "org_root_id" {
  type = string
}

variable "org_id" {
  type = string
}

variable "centralized_backup_role_name" {
  type    = string
  default = "AWSBackupServiceCentralizedRole"
}
