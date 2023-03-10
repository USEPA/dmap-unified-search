data "aws_vpc" "main" {
  id = var.vpc_id
}

resource "aws_ecs_cluster" "unified-search" {
  name = "unified-search" # Naming the cluster
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}


# SANDBOX - , github actions runs against DEV, Stage and Prod


resource "aws_ecs_task_definition" "task" {
  family                   = "service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE", "EC2"]
  cpu                      = 512
  memory                   = 2048
  container_definitions    = <<DEFINITION
  [
    {
      "name"      : "nginx",
      "image"     : "773788440401.dkr.ecr.us-east-1.amazonaws.com/unified-search:latest",
      "cpu"       : 512,
      "memory"    : 2048,
      "essential" : true,
      "portMappings" : [
        {
          "containerPort" : 80,
          "hostPort"      : 80
        }
      ]
    }
  ]
  DEFINITION
}


# resource "aws_ecs_task_definition" "my_first_task" {
#   family                   = "my-first-task" # Naming our first task
#   container_definitions    = <<DEFINITION
#   [
#     {
#       "name": "my-first-task",
#       "image": "773788440401.dkr.ecr.us-east-1.amazonaws.com/unified-search:latest",
#       "essential": true,
#       "portMappings": [
#         {
#           "containerPort": 80,
#           "hostPort": 80
#         }
#       ],
#       "memory": 4096,
#       "cpu": 2048,
#        "logConfiguration": {
#           "logDriver": "awslogs",
#           "options": {
#             "awslogs-group": "cloud-watch-group",
#             "awslogs-region": "us-east-1",
#             "awslogs-stream-prefix": "ecs"
#           }
#         }
#     }
#   ]
#   DEFINITION
#   requires_compatibilities = ["FARGATE", "EC2"] # Stating that we are using ECS Fargate
#   network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
#   memory                   = 4096        # Specifying the memory our container requires
#   cpu                      = 2048        # Specifying the CPU our container requires
#   execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
# }

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# resource "aws_ecs_service" "my_first_service" {
#   name            = "my-first-service"                        # Naming our first service
#   cluster         = aws_ecs_cluster.unified-search.id         # Referencing our created Cluster
#   task_definition = aws_ecs_task_definition.my_first_task.arn # Referencing the task our service will spin up
#   launch_type     = "FARGATE"
#   desired_count   = 2 # Setting the number of containers we want deployed to 2
#   network_configuration {
#     subnets          = ["${var.subnet_id_1}", "${var.subnet_id_2}"]
#     assign_public_ip = true # Providing our containers with public IPs
#   }
# }


resource "aws_ecs_service" "service" {
  name             = "service"
  cluster          = aws_ecs_cluster.unified-search.id
  task_definition  = aws_ecs_task_definition.task.id
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  network_configuration {
    assign_public_ip = true
    subnets = ["${var.subnet_id_1}", "${var.subnet_id_2}"]
  }
  lifecycle {
    ignore_changes = [task_definition]
  }
}

