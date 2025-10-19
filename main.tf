terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Use local state for initial creation, then migrate to S3
  backend "s3" {
    bucket = "dynamic-website-tf-state-2024"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}


provider "aws" {
  region = var.aws_region
}

# S3 Bucket for website hosting
resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
}

# DynamoDB table for storing the dynamic string - FIXED
resource "aws_dynamodb_table" "string_table" {
  name           = "DynamicStringTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Removed the non-key attribute definition that was causing the error
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "lambda_dynamic_string_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "dynamodb_policy" {
  name        = "lambda_dynamodb_policy"
  description = "Policy for Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.string_table.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

# Lambda function to get the current string
resource "aws_lambda_function" "get_string" {
  filename         = "lambda/get_string.zip"
  function_name    = "get_dynamic_string"
  role            = aws_iam_role.lambda_role.arn
  handler         = "get_string.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.string_table.name
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_dynamodb
  ]
}

# Lambda function to update the string
resource "aws_lambda_function" "update_string" {
  filename         = "lambda/update_string.zip"
  function_name    = "update_dynamic_string"
  role            = aws_iam_role.lambda_role.arn
  handler         = "update_string.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.string_table.name
    }
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "main" {
  name          = "dynamic-string-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "get_integration" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.get_string.invoke_arn
}

resource "aws_apigatewayv2_integration" "update_integration" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.update_string.invoke_arn
}

resource "aws_apigatewayv2_route" "get_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.get_integration.id}"
}

resource "aws_apigatewayv2_route" "update_route" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /update"
  target    = "integrations/${aws_apigatewayv2_integration.update_integration.id}"
}

resource "aws_lambda_permission" "api_gw_get" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_string.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_update" {
  statement_id  = "AllowExecutionFromAPIGatewayUpdate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_string.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Initial data in DynamoDB - FIXED
resource "aws_dynamodb_table_item" "initial_string" {
  table_name = aws_dynamodb_table.string_table.name
  hash_key   = aws_dynamodb_table.string_table.hash_key

  item = jsonencode({
    id = { "S" = "current" }
    current_string = { "S" = "dynamic string" }
  })
}
