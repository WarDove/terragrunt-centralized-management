resource "aws_cloudformation_stack_set" "terraform_role_shared" {
  permission_model = "SERVICE_MANAGED"
  name             = "${var.tf_role_name}-shared"

  auto_deployment {
    enabled = true
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09",
    Description              = <<EOT
AWS CloudFormation StackSet template to create an IAM Role named '${var.tf_role_name}' on Shared-Services
account and attach the 'AdministratorAccess' AWS managed policy. The role can be assumed by an external account with
a matching condition. Exclusively this role itself is able to assume '${var.tf_role_name}'s across the SDLC and
Production OUs. Note: Root Administrators are also able to assume target '${var.tf_role_name}'s across the SDLC
and Production OUs.
EOT
    Resources = {
      OrgRole = {
        Type = "AWS::IAM::Role",
        Properties = {
          RoleName = var.tf_role_name,
          AssumeRolePolicyDocument = {
            Version = "2012-10-17",
            Statement = [
              {
                Effect = "Allow",
                Principal = {
                  AWS = [
                    "arn:aws:iam::${var.shared_services_id}:root",
                    "arn:aws:iam::${var.root_account_id}:root"
                  ]
                },
                Action = ["sts:AssumeRole"]
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

resource "aws_cloudformation_stack_set_instance" "terraform_role_shared" {
  stack_set_name = aws_cloudformation_stack_set.terraform_role_shared.name
  deployment_targets {
    organizational_unit_ids = [var.org_ou_ids["core"]]
    account_filter_type     = "INTERSECTION"
    accounts                = [var.shared_services_id]
  }
}

# SOPS encryption/decryption key
resource "aws_cloudformation_stack_set" "kms_sops_key" {
  name             = "kms-sops-key"
  permission_model = "SERVICE_MANAGED"

  auto_deployment {
    enabled = true
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09",
    Description              = <<EOT
AWS CloudFormation StackSet template to create a multi-region KMS key with alias 'sops'.
Key administrators are OrganizationAccountAccessRole and ${var.tf_role_name}.
EOT
    Resources = {
      KMSKey = {
        Type = "AWS::KMS::Key",
        Properties = {
          Description       = "Multi-region KMS key for sops",
          Enabled           = true,
          EnableKeyRotation = true,
          MultiRegion       = true,
          KeyPolicy = {
            Version = "2012-10-17",
            Id      = "key-consolepolicy",
            Statement = [
              {
                Sid    = "Enable IAM User Permissions",
                Effect = "Allow",
                Principal = {
                  AWS = [
                    "arn:aws:iam::${var.shared_services_id}:root",
                    "arn:aws:iam::${var.root_account_id}:root"
                  ]
                },
                Action   = "kms:*",
                Resource = "*"
              },
              {
                Sid    = "Allow access for Key Administrators",
                Effect = "Allow",
                Principal = {
                  AWS = [
                    "arn:aws:iam::${var.shared_services_id}:role/OrganizationAccountAccessRole",
                    "arn:aws:iam::${var.shared_services_id}:role/${var.tf_role_name}"
                  ]
                },
                Action = [
                  "kms:Create*",
                  "kms:Describe*",
                  "kms:Enable*",
                  "kms:List*",
                  "kms:Put*",
                  "kms:Update*",
                  "kms:Revoke*",
                  "kms:Disable*",
                  "kms:Get*",
                  "kms:Delete*",
                  "kms:TagResource",
                  "kms:UntagResource",
                  "kms:ScheduleKeyDeletion",
                  "kms:CancelKeyDeletion",
                  "kms:ReplicateKey",
                  "kms:UpdatePrimaryRegion",
                  "kms:RotateKeyOnDemand"
                ],
                Resource = "*"
              }
            ]
          }
        }
      },
      KMSAlias = {
        Type = "AWS::KMS::Alias",
        Properties = {
          AliasName   = "alias/sops",
          TargetKeyId = { Ref = "KMSKey" }
        }
      }
    }
  })

  lifecycle {
    ignore_changes = [administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "kms_sops_key_instance" {
  depends_on     = [aws_cloudformation_stack_set.terraform_role_shared]
  stack_set_name = aws_cloudformation_stack_set.kms_sops_key.name

  deployment_targets {
    organizational_unit_ids = [var.org_ou_ids["core"]]
    account_filter_type     = "INTERSECTION"
    accounts                = [var.shared_services_id]
  }
}

resource "local_file" "sops_config_file" {
  depends_on = [aws_cloudformation_stack_set_instance.kms_sops_key_instance]
  filename   = "${var.repo_root_path}/.sops.yaml"

  content = yamlencode({
    creation_rules = [
      {
        path_regex = "secrets.*"
        kms        = "arn:aws:kms:${var.region}:${var.shared_services_id}:alias/sops"
      }
    ]
  })
}