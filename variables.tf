variable "subnet_id_1" {
  type    = string
  default = "subnet-0b5955cdc2339b4dc"
}

variable "subnet_id_2" {
  type    = string
  default = "subnet-0d5828db1f3de5653"
}

variable "vpc_id" {
  default = "vpc-03f9ce67c8659a467"
  type    = string
}

resource "vpc" "bens-vpc" {
  /// details
  
}

resource "aws_lambda_function" "name" {
  vpc_config {
    id = vpc.bens-vpc.id
  }
}

output "API URL" {
  value = aws_lambda_function.name.arn

}