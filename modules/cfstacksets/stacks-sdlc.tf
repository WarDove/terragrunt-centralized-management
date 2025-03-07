resource "aws_cloudformation_stack_set" "terraform_role_sdlc" {
  permission_model = "SERVICE_MANAGED"
  name             = "${var.tf_role_name}-sdlc"

  auto_deployment {
    enabled = true
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09",
    Description              = "AWS CloudFormation Template to create an IAM Role named '${var.tf_role_name}' and attach the 'AdministratorAccess' AWS managed policy. The role can be assumed by an external account with a matching condition.",
    Resources = {
      OrgRole = {
        Type = "AWS::IAM::Role",
        Properties = {
          RoleName = "${var.tf_role_name}",
          AssumeRolePolicyDocument = {
            Version = "2012-10-17",
            Statement = [
              {
                Effect = "Allow",
                Principal = {
                  AWS = ["arn:aws:iam::${var.shared_services_id}:root"]
                },
                Action = [
                  "sts:AssumeRole",
                  "sts:TagSession"
                ],
                Condition = {
                  StringLike = {
                    "aws:PrincipalArn" = [
                      "arn:aws:iam::${var.shared_services_id}:role/${var.tf_role_name}",
                      "arn:aws:iam::${var.shared_services_id}:role/${var.gha_role_name}"
                    ]
                  }
                }
              },
              {
                Effect = "Allow",
                Principal = {
                  AWS = ["arn:aws:iam::${var.root_account_id}:root"]
                },
                Action = ["sts:AssumeRole"],
              }
            ]
          },
          ManagedPolicyArns = [
            "arn:aws:iam::aws:policy/AdministratorAccess"
          ]
        }
      }
    }
  })

  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "terraform_role_sdlc" {
  stack_set_name = aws_cloudformation_stack_set.terraform_role_sdlc.name
  deployment_targets {
    organizational_unit_ids = [var.org_ou_ids["sdlc"], var.org_ou_ids["production"], var.org_ou_ids["sandbox"]]
  }
}