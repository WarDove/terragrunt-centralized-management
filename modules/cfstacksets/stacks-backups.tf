# Centralized Backups account stackset
resource "aws_cloudformation_stack_set" "backups_account_stackset" {
  permission_model = "SERVICE_MANAGED"
  name             = "org-backup-stackset"

  auto_deployment {
    enabled = true
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Description              = "Create IAM role for cross-region backup policy, a backup vault, and a KMS key for backup encryption"

    Metadata = {
      "AWS::CloudFormation::Interface" = {
        ParameterGroups = [
          {
            Label = {
              default = "IAM Configuration"
            }
            Parameters = [
              "BackupRole",
              "RoleRegion"
            ]
          }
        ]
        ParameterLabels = {
          BackupRole = {
            default = "Allows AWS Backup to call AWS services on your behalf."
          }
        }
      }
    }

    Parameters = {
      BackupRole = {
        Type    = "String"
        Default = var.centralized_backup_role_name
      }
      BackupVaultName = {
        Type        = "String"
        Description = "Name of the backup vault"
        Default     = "org-vault"
      }
      KmsKeyAliasName = {
        Type        = "String"
        Description = "Alias for the KMS key"
        Default     = "org/backups"
      }
      OrganizationID = {
        Type        = "String"
        Description = "The ID of the AWS organization."
        Default     = var.org_id
      }
      RoleRegion = {
        Type        = "String"
        Description = "The region where the role should be created"
        Default     = var.region
      }
    }

    Conditions = {
      CreateRole = {
        "Fn::Equals" : [
          { "Ref" : "AWS::Region" },
          { "Ref" : "RoleRegion" }
        ]
      }
    }

    Resources = {
      AccountBackupRole = {
        Type      = "AWS::IAM::Role"
        Condition = "CreateRole"
        Properties = {
          Description = "Allows AWS Backup to call AWS services on your behalf."
          AssumeRolePolicyDocument = {
            Version = "2012-10-17"
            Statement = [
              {
                Effect = "Allow"
                Principal = {
                  Service = ["backup.amazonaws.com"]
                }
                Action = ["sts:AssumeRole"]
              }
            ]
          }
          Path = "/"
          ManagedPolicyArns = [
            "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup",
            "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores",
            { "Ref" : "KMSAccessPolicy" }
          ]
          RoleName = { "Ref" : "BackupRole" }
        }
      }

      KMSAccessPolicy = {
        Type      = "AWS::IAM::ManagedPolicy"
        Condition = "CreateRole"
        Properties = {
          Description = "Managed policy for AWSBackupServiceCentralizedRole"
          PolicyDocument = {
            Version = "2012-10-17"
            Statement = [
              {
                Sid    = "AllowUseOfKeyFromBackupAccount"
                Effect = "Allow"
                Action = [
                  "kms:Encrypt",
                  "kms:Decrypt",
                  "kms:ReEncrypt*",
                  "kms:GenerateDataKey*",
                  "kms:DescribeKey"
                ]
                Resource = { "Fn::Sub" : "arn:aws:kms:*:*:alias/$${KmsKeyAliasName}" }
                Condition = {
                  StringEquals = {
                    "aws:PrincipalOrgID" = { "Ref" : "OrganizationID" }
                  }
                }
              }
            ]
          }
        }
      }

      BackupVault = {
        Type = "AWS::Backup::BackupVault"
        Properties = {
          BackupVaultName  = { "Ref" : "BackupVaultName" }
          EncryptionKeyArn = { "Fn::GetAtt" : ["KmsKey", "Arn"] }
          AccessPolicy = {
            Version = "2012-10-17"
            Statement = [
              {
                Sid    = "AllowOrgAccountCopyIntoCentralVault"
                Effect = "Allow"
                Principal = {
                  AWS = "*"
                }
                Action   = "backup:CopyIntoBackupVault"
                Resource = "*"
                Condition = {
                  StringEquals = {
                    "aws:PrincipalOrgID" = { "Ref" : "OrganizationID" }
                  }
                }
              }
            ]
          }
        }
      }

      KmsKey = {
        Type = "AWS::KMS::Key"
        Properties = {
          Description = "KMS key for encrypting backups"
          KeyPolicy = {
            Version = "2012-10-17"
            Id      = "key-default"
            Statement = [
              {
                Sid    = "Set KMS Owners"
                Effect = "Allow"
                Principal = {
                  AWS = [
                    { "Fn::Sub" : "arn:aws:iam::$${AWS::AccountId}:root" },
                    "arn:aws:iam::${var.shared_services_id}:role/${var.tf_role_name}"
                  ]
                }
                Action   = "kms:*"
                Resource = "*"
              },
              {
                Sid    = "Enable Backup Account Permissions"
                Effect = "Allow"
                Principal = {
                  AWS = "*"
                }
                Action = [
                  "kms:Encrypt",
                  "kms:Decrypt",
                  "kms:ReEncrypt*",
                  "kms:GenerateDataKey*",
                  "kms:DescribeKey"
                ]
                Resource = "*"
                Condition = {
                  StringEquals = {
                    "aws:PrincipalOrgID" = { "Ref" : "OrganizationID" }
                  }
                }
              }
            ]
          }
        }
      }

      KmsKeyAlias = {
        Type = "AWS::KMS::Alias"
        Properties = {
          AliasName   = { "Fn::Sub" : "alias/$${KmsKeyAliasName}" }
          TargetKeyId = { "Ref" : "KmsKey" }
        }
      }
    }

    Outputs = {
      BackupRole = {
        Value = { "Ref" : "BackupRole" }
      }
    }
  })

  lifecycle {
    ignore_changes = [parameters, administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "backups_account_stackset" {
  stack_set_name = aws_cloudformation_stack_set.backups_account_stackset.name

  deployment_targets {
    organizational_unit_ids = [var.org_ou_ids["core"]]
    account_filter_type     = "INTERSECTION"
    accounts                = [var.backups_id]
  }
}

# Individual account backups stackset
resource "aws_cloudformation_stack_set" "backups_org_account_stackset" {
  permission_model = "SERVICE_MANAGED"
  name             = "org-account-backup-stackset"

  auto_deployment {
    enabled = true
  }

  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09",
    Description              = "Create IAM role for cross-region backup policy, a backup vault, and a KMS key for backup encryption",
    Metadata = {
      "AWS::CloudFormation::Interface" = {
        ParameterGroups = [
          {
            Label = {
              default = "IAM Configuration"
            },
            Parameters = [
              "BackupRole",
              "BackupAccountID",
              "RoleRegion"
            ]
          }
        ],
        ParameterLabels = {
          BackupRole = {
            default = "Allows AWS Backup to call AWS services on your behalf."
          }
        }
      }
    },
    Parameters = {
      BackupRole = {
        Type    = "String",
        Default = var.centralized_backup_role_name
      },
      BackupVaultName = {
        Type        = "String",
        Description = "Name of the backup vault",
        Default     = "main-vault"
      },
      KmsKeyAliasName = {
        Type        = "String",
        Description = "Alias for the KMS key",
        Default     = "org/backups"
      },
      BackupAccountID = {
        Type        = "String",
        Description = "AWS account ID for the backup role"
        Default     = var.backups_id
      },
      RoleRegion = {
        Type        = "String",
        Description = "The region where the role should be created",
        Default     = var.region
      }
    },
    Conditions = {
      CreateRole = {
        "Fn::Equals" : [
          { "Ref" : "AWS::Region" },
          { "Ref" : "RoleRegion" }
        ]
      }
    },
    Resources = {
      AccountBackupRole = {
        Type      = "AWS::IAM::Role",
        Condition = "CreateRole",
        Properties = {
          Description = "Allows AWS Backup to call AWS services on your behalf.",
          AssumeRolePolicyDocument = {
            Version = "2012-10-17",
            Statement = [
              {
                Effect = "Allow",
                Principal = {
                  Service = ["backup.amazonaws.com"]
                },
                Action = ["sts:AssumeRole"]
              }
            ]
          },
          Path = "/",
          ManagedPolicyArns = [
            "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup",
            "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores",
            { "Ref" : "KMSAccessPolicy" }
          ],
          RoleName = { "Ref" : "BackupRole" }
        }
      },
      KMSAccessPolicy = {
        Type      = "AWS::IAM::ManagedPolicy",
        Condition = "CreateRole",
        Properties = {
          Description = "Managed policy for AWSBackupServiceCentralizedRole",
          PolicyDocument = {
            Version = "2012-10-17",
            Statement = [
              {
                Sid    = "AllowUseOfKeyInBackupAccount",
                Effect = "Allow",
                Action = [
                  "kms:Encrypt",
                  "kms:Decrypt",
                  "kms:ReEncrypt*",
                  "kms:GenerateDataKey*",
                  "kms:DescribeKey"
                ],
                Resource = { "Fn::Sub" : "arn:aws:kms:*:$${BackupAccountID}:alias/$${KmsKeyAliasName}" }
              }
            ]
          }
        }
      },
      BackupVault = {
        Type = "AWS::Backup::BackupVault",
        Properties = {
          BackupVaultName  = { "Ref" : "BackupVaultName" },
          EncryptionKeyArn = { "Fn::GetAtt" : ["KmsKey", "Arn"] },
          AccessPolicy = {
            Version = "2012-10-17",
            Statement = [
              {
                Sid    = "AllowBackupAccountCopyIntoAccountVaults",
                Effect = "Allow",
                Principal = {
                  AWS = { "Fn::Sub" : "arn:aws:iam::$${BackupAccountID}:role/$${BackupRole}" }
                },
                Action   = "backup:CopyIntoBackupVault",
                Resource = "*"
              }
            ]
          }
        }
      },
      KmsKey = {
        Type = "AWS::KMS::Key",
        Properties = {
          Description = "KMS key for encrypting backups",
          KeyPolicy = {
            Version = "2012-10-17",
            Id      = "key-default",
            Statement = [
              {
                Sid    = "Enable IAM User Permissions",
                Effect = "Allow",
                Principal = {
                  AWS = { "Fn::Sub" : "arn:aws:iam::$${AWS::AccountId}:root" }
                },
                Action   = "kms:*",
                Resource = "*"
              },
              {
                Sid    = "Enable IAM User Permissions",
                Effect = "Allow",
                Principal = {
                  AWS = { "Fn::Sub" : "arn:aws:iam::$${BackupAccountID}:role/$${BackupRole}" }
                },
                Action = [
                  "kms:Encrypt",
                  "kms:Decrypt",
                  "kms:ReEncrypt*",
                  "kms:GenerateDataKey*",
                  "kms:DescribeKey"
                ],
                Resource = "*"
              }
            ]
          }
        }
      },
      KmsKeyAlias = {
        Type = "AWS::KMS::Alias",
        Properties = {
          AliasName   = { "Fn::Sub" : "alias/$${KmsKeyAliasName}" },
          TargetKeyId = { "Ref" : "KmsKey" }
        }
      }
    },
    Outputs = {
      BackupRole = {
        Value = { "Ref" : "BackupRole" }
      }
    }
  })

  lifecycle {
    ignore_changes = [parameters, administration_role_arn]
  }
}

resource "aws_cloudformation_stack_set_instance" "backups_org_account_stackset" {
  stack_set_name = aws_cloudformation_stack_set.backups_org_account_stackset.name

  deployment_targets {
    organizational_unit_ids = [var.org_ou_ids["sdlc"], var.org_ou_ids["production"]]
  }
}