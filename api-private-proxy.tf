data "aws_vpc_endpoint_service" "test" {
  service = "execute-api"
}

# resource "aws_vpc_endpoint" "proxy-endpoint" {
#   vpc_id              = var.vpc_id
#   service_name        = data.aws_vpc_endpoint_service.test.service_name
#   vpc_endpoint_type   = "Interface"
#   private_dns_enabled = true

#   subnet_ids = [var.subnet_id_1, var.subnet_id_2]
#   # security_group_ids = []
# }

data "aws_vpc_endpoint" "proxy-endpoint" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.us-east-1.execute-api"
}



data "aws_availability_zones" "available" {}


data "aws_ec2_managed_prefix_list" "epa_vpn" {
  filter {
    name   = "prefix-list-id"
    values = ["pl-06b899e10a0168b2b"]
  }
}

output "data_vpn" {
  value = join(",", data.aws_ec2_managed_prefix_list.epa_vpn.entries[*].cidr)
}

resource "aws_api_gateway_rest_api" "proxy-api-gateway" {
  name = "Unified Search Private Proxy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": "*",
            "Action": "execute-api:Invoke",
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Deny",
            "Principal": "*",
            "Action": "execute-api:Invoke",
            "Resource": [
                "*"
            ],
            "Condition" : {
                "StringNotEquals": {
                    "aws:SourceVpce": "${var.vpc_id}"
                }
            }
        }
    ]
}
EOF

  endpoint_configuration {
    types = ["PRIVATE"]
    vpc_endpoint_ids = [data.aws_vpc_endpoint.proxy-endpoint.id]
  }
}

variable "stage_name" {
  default = "api"
}


output "api-url" {
  value = "https://${aws_api_gateway_rest_api.proxy-api-gateway.id}-${data.aws_vpc_endpoint.proxy-endpoint.id}.execute-api.us-east-1.amazonaws.com/${var.stage_name}"
}



##EDG

resource "aws_api_gateway_resource" "proxy-resource-edg" {
  rest_api_id = aws_api_gateway_rest_api.proxy-api-gateway.id
  parent_id   = aws_api_gateway_rest_api.proxy-api-gateway.root_resource_id
  path_part   = "EDG"
}

resource "aws_api_gateway_integration" "edg-integration" {
  rest_api_id             = aws_api_gateway_rest_api.proxy-api-gateway.id
  resource_id             = aws_api_gateway_resource.proxy-resource-edg.id
  http_method             = aws_api_gateway_method.proxy-method-edg.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "https://edg.epa.gov/metadata/rest/find/document{proxy+}"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

resource "aws_api_gateway_method" "proxy-method-edg" {
  rest_api_id        = aws_api_gateway_rest_api.proxy-api-gateway.id
  resource_id        = aws_api_gateway_resource.proxy-resource-edg.id
  http_method        = "ANY"
  authorization      = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
  api_key_required   = true
}


###USGS
resource "aws_api_gateway_resource" "proxy-resource-usgs" {
  rest_api_id = aws_api_gateway_rest_api.proxy-api-gateway.id
  parent_id   = aws_api_gateway_rest_api.proxy-api-gateway.root_resource_id
  path_part   = "USGS"
}

resource "aws_api_gateway_integration" "usgs-ingestion" {
  rest_api_id             = aws_api_gateway_rest_api.proxy-api-gateway.id
  resource_id             = aws_api_gateway_resource.proxy-resource-usgs.id
  http_method             = aws_api_gateway_method.proxy-method-usgs.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  uri                     = "https://pubs.er.usgs.gov/{proxy+}"
  passthrough_behavior    = "WHEN_NO_MATCH"
}



resource "aws_api_gateway_method" "proxy-method-usgs" {
  rest_api_id        = aws_api_gateway_rest_api.proxy-api-gateway.id
  resource_id        = aws_api_gateway_resource.proxy-resource-usgs.id
  http_method        = "ANY"
  authorization      = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}



resource "aws_api_gateway_deployment" "proxy-api-deployment" {
  depends_on = [
    aws_api_gateway_method.proxy-method-usgs,
    aws_api_gateway_method.proxy-method-edg
  ]
  rest_api_id = aws_api_gateway_rest_api.proxy-api-gateway.id
}

# output "api-url" {
#   value = "https://${aws_api_gateway_rest_api.proxy-api-gateway.id}-${aws_vpc_endpoint.proxy-api.id}.execute-api.us-east-1.amazonaws.com/Stage"
# }



resource "aws_api_gateway_stage" "staged_api" {
  stage_name    = var.stage_name
  rest_api_id   = aws_api_gateway_rest_api.proxy-api-gateway.id
  deployment_id = aws_api_gateway_deployment.proxy-api-deployment.id
}

# resource "aws_api_gateway_usage_plan" "apigw_usage_plan" {
#   name = "apigw_usage_plan"

#   api_stages {
#     api_id = aws_api_gateway_rest_api.proxy-api-gateway.id
#     stage  = aws_api_gateway_stage.staged_api.stage_name
#   }
# }

# resource "aws_api_gateway_usage_plan_key" "apigw_usage_plan_key" {
#   key_id        = aws_api_gateway_api_key.apigw_stage_key.id
#   key_type      = "API_KEY"
#   usage_plan_id = aws_api_gateway_usage_plan.apigw_usage_plan.id
# }

# resource "aws_api_gateway_api_key" "apigw_stage_key" {
#   name = "stage_key"
# }
