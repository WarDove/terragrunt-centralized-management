module "iam_github_oidc_provider" {
  count   = var.gha_oidc_enabled ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.47.0"
  create  = true
}

data "aws_iam_policy_document" "gha_oidc_assume_role_policy" {
  count = var.gha_oidc_enabled ? 1 : 0
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringLike"
      variable = "${replace(module.iam_github_oidc_provider[0].url, "https://", "")}:sub"
      values = concat([
        "repo:${var.tf_repo}:*"], [for repo in var.app_repos : "repo:${repo}:*"]
      )
    }

    condition {
      test     = "StringLike"
      variable = "${replace(module.iam_github_oidc_provider[0].url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      identifiers = [module.iam_github_oidc_provider[0].arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "gha_role" {
  count              = var.gha_oidc_enabled ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.gha_oidc_assume_role_policy[0].json
  name               = var.gha_role_name
}

resource "aws_iam_role_policy_attachment" "gha_policy_attachment" {
  count      = var.gha_oidc_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  role       = aws_iam_role.gha_role[0].name
}