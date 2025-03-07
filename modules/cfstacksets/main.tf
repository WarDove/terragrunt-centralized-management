data "aws_iam_policy_document" "cfstackset_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["cloudformation.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "cfstackset_role" {
  assume_role_policy = data.aws_iam_policy_document.cfstackset_assume_policy.json
  name               = "AWSCloudFormationStackSetAdministrationRole"
}