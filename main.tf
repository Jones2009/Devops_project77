resource "aws_security_group" "main" {
  name        = local.security_group_name
  description = local.security_group_description
  vpc_id      = var.vpc_id
  tags        = merge(tomap({ "name" = local.security_group_name }), local.tags)
}

resource "aws_security_group_rule" "cidr_block_egress" {
  for_each          = var.security_group_cidr_block_egress
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  description       = each.key
  security_group_id = aws_security_group.main.id
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  type              = "egress"
}

resource "aws_iam_role" "main" {
  name = local.role_name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
  tags               = merge(tomap({ "Name" = local.role_name }), local.tags)
}

resource "aws_iam_policy" "main" {
  name = local.policy_name

  policy = templatefile("${path.module}/templates/default_lambda_policy.tfpl", {
    deployment_s3_bucket = var.deployment_s3_bucket,
    kms_key_arn          = var.deployment_bucket_kms_key_arn
  })
}

resource "aws_iam_role_policy_attachment" "main" {
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.main.arn
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.lambda.arn
}

resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.vpc.arn
}

resource "aws_lambda_function" "main" {
  s3_key        = var.function_s3_key
  s3_bucket     = var.deployment_s3_bucket
  function_name = local.function_name
  role          = aws_iam_role.main.arn
  handler       = "handler.lambda_handler"
  runtime       = var.runtime
  timeout       = 180
  tags          = merge(tomap({ "name" = local.function_name }), local.tags)
  vpc_config {
    security_group_ids = [aws_security_group.main.id]
    subnet_ids         = data.aws_subnets.private.ids
  }
  depends_on = [
    aws_security_group.main,
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda
  ]
  dynamic "environment" {
    for_each = local.environment_map
    content {
      variables = environment.value
    }
  }
}

resource "aws_lambda_permission" "cloudwatch" {
  for_each      = var.log_groups
  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = format("logs.%s.amazonaws.com", var.region)
  source_arn    = format("%s:*", data.aws_cloudwatch_log_group.main[each.key].arn)
}

resource "aws_cloudwatch_log_subscription_filter" "main" {
  for_each        = var.log_groups
  name            = format("%s-log_group_filter", var.name)
  destination_arn = aws_lambda_function.main.arn
  log_group_name  = each.value
  filter_pattern  = ""
}

resource "aws_sns_topic_subscription" "main" {
  for_each  = var.topic_arns
  protocol  = "lambda"
  endpoint  = aws_lambda_function.main.arn
  topic_arn = each.value
}

resource "aws_lambda_permission" "sns" {
  for_each      = var.topic_arns
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = each.value

}

# This is required due to Lambda ENIs https://github.com/hashicorp/terraform-provider-aws/issues/10329

resource "null_resource" "assign_default_sg" {
  triggers = {
    sg     = aws_security_group.main.id
    func   = aws_lambda_function.main.id
    vpc_id = var.vpc_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = "/bin/bash ${path.module}/scripts/lambda_cleanup.sh ${self.triggers.vpc_id} ${self.triggers.sg}"
  }
}
# Creates the KMS Key used to encrypt SNS, SQS and S3

resource "aws_kms_key" "lambda" {
  description              = "KMS Key to encrypt CloudWatch Logs for ${local.cloudwatch_logs_group_name}"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  policy = templatefile("${path.module}/templates/kms_policy.tftpl", {
    log_service   = jsonencode(format("logs.%s.amazonaws.com", var.region)),
    log_group_arn = jsonencode(format("arn:aws:logs:%s:%s:log-group:%s", var.region, data.aws_caller_identity.main.account_id, local.cloudwatch_logs_group_name)),
    admin_ids     = jsonencode(format("arn:aws:iam::%s:role/slc-%s-cross_account_codebuild-role", data.aws_caller_identity.main.account_id, var.account_name)),
    account_ids   = jsonencode(formatlist("arn:aws:iam::%s:root", data.aws_caller_identity.main.account_id))

  })
  enable_key_rotation = true

  tags = {
    Name      = local.cloudwatch_logs_kms_key_alias
    tfmanaged = "true"
  }
}

resource "aws_kms_alias" "lambda" {
  name          = local.cloudwatch_logs_kms_key_alias
  target_key_id = aws_kms_key.lambda.arn
}

resource "aws_cloudwatch_log_group" "lambda" {
  name       = local.cloudwatch_logs_group_name
  kms_key_id = aws_kms_key.lambda.arn
}
