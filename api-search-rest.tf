resource "aws_api_gateway_rest_api" "unified_search_api" {
  name        = "unified_search_api"
  description = "Lambda-powered Unified Search API"
  depends_on = [
    aws_lambda_function.search_requests
  ]
}

resource "aws_api_gateway_stage" "unified-search-rest-api" {
  stage_name    = "stage"
  rest_api_id   = aws_api_gateway_rest_api.unified_search_api.id
  deployment_id = aws_api_gateway_deployment.api_gateway_deployment_get.id
}

resource "aws_api_gateway_usage_plan" "apigw_usage_plan" {
  name = "apigw_usage_plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.unified_search_api.id
    stage  = aws_api_gateway_stage.unified-search-rest-api.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "apigw_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.apigw_stage_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.apigw_usage_plan.id
}

resource "aws_api_gateway_api_key" "apigw_stage_key" {
  name = "stage_key"
}

#SEARCH
resource "aws_api_gateway_resource" "search_api" {
  path_part   = "search"
  parent_id   = aws_api_gateway_rest_api.unified_search_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.unified_search_api.id
}

# POST/GET Needs to run to lambda connecting to Opensearch
resource "aws_api_gateway_method" "search_get" {
  rest_api_id      = aws_api_gateway_rest_api.unified_search_api.id
  resource_id      = aws_api_gateway_resource.search_api.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "search_post" {
  rest_api_id      = aws_api_gateway_rest_api.unified_search_api.id
  resource_id      = aws_api_gateway_resource.search_api.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "search_options" {
  rest_api_id      = aws_api_gateway_rest_api.unified_search_api.id
  resource_id      = aws_api_gateway_resource.search_api.id
  http_method      = "OPTIONS"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_lambda_permission" "lambda_permission_search" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_requests.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.unified_search_api.execution_arn}/*/*/*"
}

# # See also the following AWS managed policy: AWSLambdaBasicExecutionRole
# resource "aws_iam_policy" "lambda_logging" {
#   name        = "lambda_logging"
#   path        = "/"
#   description = "IAM policy for logging from a lambda"

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": [
#         "logs:CreateLogGroup",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents"
#       ],
#       "Resource": "arn:aws:logs:*:*:*",
#       "Effect": "Allow"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_role_policy_attachment" "lambda_logs" {
#   role       = aws_iam_role.iam_for_lambda.name
#   policy_arn = aws_iam_policy.lambda_logging.arn
# }

resource "aws_api_gateway_integration" "lambda_integration_get" {
  depends_on = [
    aws_lambda_permission.lambda_permission_search
  ]
  rest_api_id = aws_api_gateway_rest_api.unified_search_api.id
  resource_id = aws_api_gateway_method.search_get.resource_id
  http_method = aws_api_gateway_method.search_get.http_method

  integration_http_method = "GET" # https://github.com/hashicorp/terraform/issues/9271 Lambda requires POST as the integration type
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.search_requests.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_integration_post" {
  depends_on = [
    aws_lambda_permission.lambda_permission_search
  ]
  rest_api_id = aws_api_gateway_rest_api.unified_search_api.id
  resource_id = aws_api_gateway_method.search_post.resource_id
  http_method = aws_api_gateway_method.search_post.http_method

  integration_http_method = "POST" # https://github.com/hashicorp/terraform/issues/9271 Lambda requires POST as the integration type
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.search_requests.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_integration_options" {
  depends_on = [
    aws_lambda_permission.lambda_permission_search
  ]
  rest_api_id = aws_api_gateway_rest_api.unified_search_api.id
  resource_id = aws_api_gateway_method.search_options.resource_id
  http_method = aws_api_gateway_method.search_options.http_method

  integration_http_method = "OPTIONS" # https://github.com/hashicorp/terraform/issues/9271 Lambda requires POST as the integration type
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.search_requests.invoke_arn
}


#INGEST
resource "aws_api_gateway_resource" "data_ingestion_api" {
  path_part   = "ingest"
  parent_id   = aws_api_gateway_rest_api.unified_search_api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.unified_search_api.id
}

resource "aws_api_gateway_method" "ingest_any" {
  rest_api_id      = aws_api_gateway_rest_api.unified_search_api.id
  resource_id      = aws_api_gateway_resource.data_ingestion_api.id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.unified_search_api.id
  resource_id = aws_api_gateway_resource.data_ingestion_api.id
  http_method = aws_api_gateway_method.ingest_any.http_method
  status_code = "200"
}

resource "aws_lambda_permission" "lambda_permission_ingest" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest_to_opensearch.arn
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.unified_search_api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_integration" "lambda_integration_ingest_any" {
  depends_on = [
    aws_lambda_permission.lambda_permission_ingest
  ]
  rest_api_id = aws_api_gateway_rest_api.unified_search_api.id
  resource_id = aws_api_gateway_method.ingest_any.resource_id
  http_method = aws_api_gateway_method.ingest_any.http_method

  integration_http_method = "ANY" # https://github.com/hashicorp/terraform/issues/9271 Lambda requires POST as the integration type
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ingest_to_opensearch.invoke_arn
}


resource "aws_api_gateway_integration_response" "lambda_integration_ingest_any_response" {
  rest_api_id = aws_api_gateway_rest_api.unified_search_api.id
  resource_id = aws_api_gateway_method.ingest_any.resource_id
  http_method = aws_api_gateway_method.ingest_any.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  depends_on = [
    aws_api_gateway_method_response.response_200,
    aws_api_gateway_method.ingest_any
  ]
}


resource "aws_api_gateway_deployment" "api_gateway_deployment_get" {
  variables = {
    // For new changes to the API to be correctly deployed, they need to
    // be detected by terraform as a trigger to recreate the aws_api_gateway_deployment.
    // This is because AWS keeps a "working copy" of the API resources which does not
    // go live until a new aws_api_gateway_deployment is created.
    // Here we use a dummy stage variable to force a new aws_api_gateway_deployment.
    // We want it to detect if any of the API-defining resources have changed so we
    // hash all of their configurations.
    // IMPORTANT: This list must include all API resources that define the "content" of
    // the rest API. That means anything except for aws_api_gateway_rest_api,
    // aws_api_gateway_stage, aws_api_gateway_base_path_mapping, that are higher-level
    // resources. Any change to a part of the API not included in this list might not
    // trigger creation of a new aws_api_gateway_deployment and thus not fully deployed.
    trigger_hash = sha1(join(",", [
      jsonencode(aws_api_gateway_integration.lambda_integration_get),
      jsonencode(aws_api_gateway_integration.lambda_integration_post),
      jsonencode(aws_api_gateway_integration.lambda_integration_options),
      jsonencode(aws_api_gateway_integration.lambda_integration_ingest_any),
      jsonencode(aws_api_gateway_method.search_get),
      jsonencode(aws_api_gateway_method.search_options),
      jsonencode(aws_api_gateway_method.search_post),
      jsonencode(aws_api_gateway_method.ingest_any),
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  rest_api_id = aws_api_gateway_rest_api.unified_search_api.id
}



resource "aws_api_gateway_model" "filter-requests-model" {
  rest_api_id  = aws_api_gateway_rest_api.unified_search_api.id
  name         = "FilterRequest"
  description  = "a JSON schema"
  content_type = "application/json"

  schema = <<EOF
{ 
  "$schema": "http://json-schema.org/draft-04/schema#",
  "title": "FilterRequest",
  "type": "object",
  "properties": {
    "filters": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "filterName": { "type": "string" },
          "filterValue": { "type": "string" }
        }
      }
    }
  }
}
EOF
}



resource "aws_api_gateway_model" "title-and-id" {
  rest_api_id  = aws_api_gateway_rest_api.unified_search_api.id
  name         = "TitleAndID"
  description  = "a JSON schema"
  content_type = "application/json"

  schema = <<EOF
{
    "$schema": "http://json-schema.org/draft-04/schema#",
     "title": "TitleandID",
     "description":"A Partial of SH data for testing",
     "type":"object",
          "properties": {
              "tracking_number":{"type":"string"},
              "title": {"type":"string" },
              "doi": {"type":"string" },
              "pmc_id":{"type":"string" },
              "type":{"type":"string" },
              "organization":{"type":"string" },
              "datasets": {
                  "type":"array",
                  "items":{
                      "type":"string",
                         "items":{
                             "type":"number"
                         }
                  }
                },
              "data_completed_review": {"type":"boolean"},
              "data_published":{"type":"boolean"}
              
            }
}
EOF
}