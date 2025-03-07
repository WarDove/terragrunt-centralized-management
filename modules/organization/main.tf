resource "aws_organizations_organization" "main" {
  aws_service_access_principals = [
    "controltower.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com",
    "account.amazonaws.com",
    "backup.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com"
  ]

  feature_set = "ALL"

  enabled_policy_types = [
    "AISERVICES_OPT_OUT_POLICY",
    "BACKUP_POLICY",
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]
}

resource "aws_organizations_organizational_unit" "main" {
  for_each  = var.org_units
  name      = each.value
  parent_id = aws_organizations_organization.main.roots[0].id
}

# Activate trusted access with AWS Organizations to use service-managed permissions.
# You must enable organizations access to operate a service managed stack set.