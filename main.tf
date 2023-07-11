resource "aws_security_group" "main" {
  name        = "${var.component}-${var.env}-sg"
  description = "${var.component}-${var.env}-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = var.sg_subnets_cidr
  }

  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = var.allow_prometheus_cidr
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allow_ssh_cidr
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.component}-${var.env}-sg"
  }
}

resource "aws_lb_target_group" "main" {
  name                 = "${var.component}-${var.env}-tg"
  port                 = var.app_port
  protocol             = "HTTP"
  deregistration_delay = 30
  vpc_id               = var.vpc_id

  health_check {
    enabled             = true
    interval            = 5
    path                = "/health"
    port                = var.app_port
    protocol            = "HTTP"
    timeout             = 4
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "static" {
  listener_arn = var.listener_arn
  priority     = var.lb_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    host_header {
      values = ["${var.component}-${var.env}.devopsawschinni.online"]
    }
  }
}


resource "aws_launch_template" "main" {
  name = "${var.component}-${var.env}"

  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }
  image_id               = data.aws_ami.ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.main.id]

  tag_specifications {
    resource_type = "instance"
    tags          = merge({ Name = "${var.component}-${var.env}", Monitor = "true" }, var.tags)
  }

  user_data = base64encode(templatefile("${path.module}/userdata.sh", {
    env       = var.env
    component = var.component
  }))

  //  block_device_mappings {
  //    device_name = "/dev/sda1"
  //
  //    ebs {
  //      volume_size = 10
  //      encrypted   = "true"
  //      kms_key_id  = var.kms_key_id
  //    }
  //  }
}

resource "aws_autoscaling_group" "main" {
  desired_capacity    = var.desired_capacity
  max_size            = var.max_size
  min_size            = var.min_size
  vpc_zone_identifier = var.subnets
  target_group_arns   = [aws_lb_target_group.main.arn]


  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }
}



resource "aws_route53_record" "dns" {
  zone_id = "Z0783442RLRP3KGA9XLU"
  name    = "${var.component}-${var.env}"
  type    = "CNAME"
  ttl     = 30
  records = [var.lb_dns_name]
}

/*
#iam policy
resource "aws_iam_policy" "policy" {
  name        = "${var.component}-${var.env}-ssm-pm-policy-latest"
  path        = "/"
  description = "${var.component}-${var.env}-ssm-pm-policy-latest"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "VisualEditor0",
        "Effect": "Allow",
        "Action": [
          "ssm:GetParameterHistory",
          "ssm:DescribeDocumentParameters",
          "ssm:GetParametersByPath",
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        "Resource": "arn:aws:ssm:us-east-1:355820959649:parameter/roboshop.${var.env}.${var.component}*"
      }
    ]
  })
}


#role

resource "aws_iam_role" "role" {
  name = "${var.component}-${var.env}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_instance_profile" "instance-profile" {
  name = "${var.component}-${var.env}"
  role = aws_iam_role.role.name
}

resource "aws_iam_role_policy_attachment" "policy-attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}
#security group

resource "aws_security_group" "sg" {
  name        = "${var.component}-${var.env}-sg"
  description = "Example security group created with Terraform"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.component}-${var.env}-sg"
  }
}
#ec2

resource "aws_instance" "instance" {
  ami                    = data.aws_ami.ami.id
  instance_type          = "t3.small"
  vpc_security_group_ids = [aws_security_group.sg.id]
  iam_instance_profile = aws_iam_instance_profile.instance-profile.name

  tags = {
    Name = "${var.component}-${var.env}"
  }
}
#dns name

resource "aws_route53_record" "dns" {
  zone_id = "Z0783442RLRP3KGA9XLU"
  name    = "${var.component}-dev"  # Replace with your desired subdomain
  type    = "A"
  ttl     = 30
  records = [aws_instance.instance.private_ip]  # Replace with the IP address or target value
  allow_overwrite = true
}
#data
#null resource
resource "null_resource" "ansible" {
  depends_on = [aws_instance.instance,aws_route53_record.dns]
provisioner "remote-exec" {

  connection {
    type     = "ssh"
    user     = "centos"
    password = "DevOps321"
    host     = aws_instance.instance.public_ip
  }
  inline = [
    "sudo labauto ansible",
    "ansible-pull -i localhost, -U https://github.com/chaliashok/roboshop-ansible main.yml  -e role_name=${var.component}"
  ]
}
}
*/