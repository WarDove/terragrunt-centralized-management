
locals {
  custom_managed_policy_path = fileset(path.root, "custom-managed-policies/*.json")

  custom_managed_policies = {
    for file in local.custom_managed_policy_path :
    replace(basename(file), ".json", "") => file
  }
}

resource "aws_cloudformation_stack_set" "global_custom_policy" {

  for_each = local.custom_managed_policies

  permission_model = "SERVICE_MANAGED"
  name             = "custom-managed-${each.key}"

  auto_deployment {
    enabled = true
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09",
    Description              = "AWS CloudFormation Template to create a custom global IAM policy named '${each.key}'",
    Resources = {
      CustomPolicy = {
        Type = "AWS::IAM::ManagedPolicy",
        Properties = {
          ManagedPolicyName = each.key,
          PolicyDocument    = jsondecode(file(each.value))
        }
      }
    }
  })

  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "global_custom_policy_zennerai" {
  for_each = local.custom_managed_policies

  stack_set_name = aws_cloudformation_stack_set.global_custom_policy[each.key].name
  deployment_targets {
    organizational_unit_ids = [var.org_root_id]
    account_filter_type     = "INTERSECTION"
    accounts                = ["323847718990"] # TODO: remove post migrations
  }
}


resource "aws_cloudformation_stack_set_instance" "global_custom_policy" {
  for_each = local.custom_managed_policies

  stack_set_name = aws_cloudformation_stack_set.global_custom_policy[each.key].name
  deployment_targets {
    organizational_unit_ids = [var.org_ou_ids["sdlc"], var.org_ou_ids["core"], var.org_ou_ids["production"]]
  }
}
