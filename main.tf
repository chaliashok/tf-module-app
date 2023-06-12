#iam policy
resource "aws_iam_policy" "policy" {
  name        = "${var.component}-${var.env}-ssm-pm-policy"
  path        = "/"
  description = "${var.component}-${var.env}-ssm-pm-policy"

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
        "Resource": "arn:aws:ssm:us-east-1:355820959649:document/roboshop.${var.env}.${var.component}*"
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