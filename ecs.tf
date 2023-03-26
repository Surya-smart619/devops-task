# Configure the AWS provider
provider "aws" {
  region = "us-west-2"
}

# Create an ECS task definition
resource "aws_ecs_task_definition" "myapp" {
  family = "myapp"
  container_definitions = jsonencode([
    {
      name  = "myapp",
      image = "suryasmart619/express",
      portMappings = [
        {
          containerPort = 3000,
          hostPort      = 3000
        }
      ],
      essential = true
    }
  ])

  # Configure the task to run in Fargate
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
}

# Create an ECS cluster
resource "aws_ecs_cluster" "mycluster" {
  name = "mycluster"
}

# Create an ECS service to run the task
resource "aws_ecs_service" "myapp" {
  name            = "myapp"
  cluster         = aws_ecs_cluster.mycluster.id
  task_definition = aws_ecs_task_definition.myapp.arn
  desired_count   = 1

  # Configure a load balancer to route traffic to the service
  load_balancer {
    target_group_arn = aws_lb_target_group.myapp.arn
    container_name   = "myapp"
    container_port   = 3000
  }

  # Configure autoscaling for the service
  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    ignore_changes = [
      platform_version,
      desired_count,
      deployment_maximum_percent,
      deployment_minimum_healthy_percent,
    ]
  }

  # Configure the service to run in Fargate
  platform_version = "LATEST"
  launch_type      = "FARGATE"
  network_configuration {
    security_groups = [aws_security_group.myapp.id]
    subnets         = aws_subnet.private.*.id
  }
}

# Create a load balancer target group to route traffic to the service
resource "aws_lb_target_group" "myapp" {
  name     = "myapp"
  port     = 3000
  protocol = "HTTP"

  health_check {
    path = "/"
  }
}

# Create a load balancer listener to route traffic to the target group
resource "aws_lb_listener" "myapp" {
  load_balancer_arn = aws_lb.myapp.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.myapp.arn
    type             = "forward"
  }
}

# Create a load balancer to route traffic to the target group
resource "aws_lb" "myapp" {
  name               = "myapp"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.myapp_lb.id]
  # Note below
  subnets            = aws_subnet.private.*.id

  tags = {
    Name = "myapp"
  }
}

# Create a security group for the load balancer
resource "aws_security_group" "myapp_lb" {
  name_prefix = "myapp_lb"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create private subnets for Fargate
resource "aws_subnet" "private" {
  count             = 2
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = "us-west-2a"
  vpc_id            = aws_vpc.myapp.id
}

# Create a security group for the ECS task
resource "aws_security_group" "myapp" {
  name_prefix = "myapp"
  vpc_id      = aws_vpc.myapp.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a VPC for the ECS service
resource "aws_vpc" "myapp" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "myapp"
  }
}

# Output the URL of the load balancer
output "url" {
  value = aws_lb.myapp.dns_name
}
