variable "domain" {
  default = "unified-search-stage"
}

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

data "aws_caller_identity" "current" {}


resource "aws_security_group" "opensearch-sg" {
  name        = "${var.vpc_id}-opensearch-${var.domain}"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    cidr_blocks = [
      data.aws_vpc.vpc.cidr_block,
    ]
  }
}


resource "aws_opensearch_domain" "opensearch" {
  domain_name    = var.domain
  engine_version = "OpenSearch_2.3"
  cluster_config {
    instance_type = "t3.medium.search"
  }

  vpc_options {
    subnet_ids = [
      var.subnet_id_1
    ]

    security_group_ids = [aws_security_group.opensearch-sg.id]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  access_policies = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "es.amazonaws.com"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:us-east-1:${data.aws_caller_identity.current.account_id}:domain/${var.domain}/*"
    }
  ]
}
EOF
}

resource "aws_lambda_function" "delete_and_rebuild_index" {
  filename      = "lambdaZips/DeleteAndRebuildIndex_2.zip"
  function_name = "DeleteAndRebuildIndex"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  vpc_config {
    security_group_ids = [
      "sg-0901b498ba1d22bc1",
      "sg-090d2d1301b2f86ef",
    ]
    subnet_ids = [
      "subnet-0b5955cdc2339b4dc",
      "subnet-0d5828db1f3de5653",
    ]
  }
  environment {
    variables = {
      API_ENDPOINT = aws_opensearch_domain.opensearch.endpoint
    }
  }

}

resource "aws_lambda_function" "ingest_to_opensearch" {
  filename      = "lambdaZips/IngestToOpensearchLambda.zip"
  function_name = "IngestToOpensearch"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  vpc_config {
    security_group_ids = [
      "sg-0901b498ba1d22bc1",
      "sg-090d2d1301b2f86ef",
    ]
    subnet_ids = [
      "subnet-0b5955cdc2339b4dc",
      "subnet-0d5828db1f3de5653",
    ]
  }

  environment {
    variables = {
      API_ENDPOINT = aws_opensearch_domain.opensearch.endpoint
    }
  }
}



resource "aws_lambda_function" "edg_ingestion" {
  filename      = "lambdaZips/EDGIngestion.zip"
  function_name = "EDGIngestion"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  environment {
    variables = {
      API_ENDPOINT = "https://5s58sutvmf.execute-api.us-east-1.amazonaws.com/stage"
      X_API_KEY    = "Vxhms5nAoe8EdKyxSRZkO4j3LxUiCmxq63JkSh9W"
    }
  }
  timeout = 60 * 15

}

resource "aws_lambda_function" "usgs_ingestion" {
  filename      = "lambdaZips/USGSDataIngestion.zip"
  function_name = "USGSIngestion"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      API_ENDPOINT = "https://5s58sutvmf.execute-api.us-east-1.amazonaws.com/stage"
      X_API_KEY    = "Vxhms5nAoe8EdKyxSRZkO4j3LxUiCmxq63JkSh9W"
    }
  }

  timeout = 60 * 15
}

resource "aws_lambda_function" "rapid_ingestion" {
  filename      = "lambdaZips/RAPIDDataIngestion.zip"
  function_name = "RAPIDIngestion"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  environment {
    variables = {
      API_ENDPOINT = "https://5s58sutvmf.execute-api.us-east-1.amazonaws.com/stage"
      X_API_KEY    = "Vxhms5nAoe8EdKyxSRZkO4j3LxUiCmxq63JkSh9W"
    }
  }
  timeout = 15 * 60
}

resource "aws_lambda_function" "search_requests" {
  filename      = "lambdaZips/SearchRequestsLambda.zip"
  function_name = "SearchRequests"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  vpc_config {
    security_group_ids = [
      "sg-0901b498ba1d22bc1",
      "sg-090d2d1301b2f86ef",
    ]
    subnet_ids = [
      "subnet-0b5955cdc2339b4dc",
      "subnet-0d5828db1f3de5653",
    ]
  }
  timeout = 60 * 1

  environment {
    variables = {
      API_ENDPOINT = aws_opensearch_domain.opensearch.endpoint
    }
  }
}


resource "aws_lambda_function" "pmc_ingestion" {
  filename      = "lambdaZips/PMCIngestion.zip"
  function_name = "SearchRequests"
  role          = aws_iam_role.lambda.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  timeout       = 60 * 15

  environment {
    variables = {
      API_ENDPOINT = "https://5s58sutvmf.execute-api.us-east-1.amazonaws.com/stage"
      X_API_KEY = "Vxhms5nAoe8EdKyxSRZkO4j3LxUiCmxq63JkSh9W"
    }
  }

}

resource "aws_iam_role" "lambda" {
  name = "example-lambda-role"
  inline_policy {
    name = "CreateNetworkInterfaceEc2"
    policy = jsonencode(
      {
        Statement = [
          {
            Action = [
              "ec2:CreateNetworkInterface",
              "ec2:DescribeNetworkInterfaces",
              "ec2:DeleteNetworkInterface",
            ]
            Effect   = "Allow"
            Resource = "*"
            Sid      = "VisualEditor0"
          },
        ]
        Version = "2012-10-17"
      }
    )

  }
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]

    }
  )
  inline_policy {
    name = "example-opensearch-query-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "es:ESHttpGet",
            "es:ESHttpPost",
            "es:ESHttpPut",
            "es:ESHttpDelete"
          ],
          Resource = "${aws_opensearch_domain.opensearch.arn}/*"
        }
      ]
    })
  }
}
