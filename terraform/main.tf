provider "aws" {
  region = var.region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

locals {
  name = "devops-task-${var.environment}"
  ami  = data.aws_ami.al2023.id
}

# Only the app port is open. No SSH: we use SSM instead.
resource "aws_security_group" "app" {
  name_prefix = "${local.name}-"
  description = "Allow app traffic on 8080"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "App"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${local.name}/app"
  retention_in_days = var.log_retention_days
}

# EC2 IAM role: SSM access and least-privilege log writing, no instance access keys.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${local.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# lets GitHub Actions run the deploy script through SSM (no SSH)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# write logs to ONE log group only
resource "aws_iam_role_policy" "logs" {
  name = "write-app-logs"
  role = aws_iam_role.ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.app.arn}:*"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name}-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "app" {
  ami                    = local.ami
  instance_type          = var.instance_type
  iam_instance_profile   = aws_iam_instance_profile.ec2.name
  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    image         = var.app_image
    log_group     = aws_cloudwatch_log_group.app.name
    region        = var.region
    deploy_script = file("${path.module}/../scripts/deploy.sh")
  })

  tags = {
    Name        = local.name
    Environment = var.environment
  }
}
