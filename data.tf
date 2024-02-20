data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    location = "private"
  }
}

data "aws_iam_policy" "lambda" {
  name = "AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy" "vpc" {
  name = "AWSLambdaVPCAccessExecutionRole"
}

data "aws_cloudwatch_log_group" "main" {
  for_each = var.log_groups
  name     = each.value
}

data "aws_caller_identity" "main" {

}