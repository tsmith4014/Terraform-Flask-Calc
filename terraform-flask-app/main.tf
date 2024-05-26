provider "aws" {
  region  = "us-east-1"
  profile = "devopsbravo"
}

resource "aws_security_group" "flask_sg" {
  name        = "flask_sg"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_instance" "flask_instance" {
  count         = 2
  ami           = "ami-0d94353f7bad10668"  # Amazon Linux 2 AMI for us-east-1
  instance_type = "t2.micro"
  key_name      = "cpclass-devopsew-bravo"  # Use the name of your existing key pair
  vpc_security_group_ids = [aws_security_group.flask_sg.id]
  subnet_id     = element(["subnet-0a8e1a148918059f0", "subnet-09afa4f34c839bc67"], count.index)

  tags = {
    Name = "FlaskAppInstance-Chad"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install git -y",
      "sudo yum install python3 -y",
      "sudo pip3 install flask",
      "git clone https://github.com/codeplatoon-devops/calculator-webapp.git",
      "cd calculator-webapp",
      "echo '[Unit]' | sudo tee /etc/systemd/system/flaskapp.service",
      "echo 'Description=Flask App' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "echo 'After=network.target' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "echo '[Service]' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "echo 'User=root' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "echo 'WorkingDirectory=/home/ec2-user/calculator-webapp' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "echo 'ExecStart=/usr/bin/python3 /home/ec2-user/calculator-webapp/calc.py' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "echo 'Restart=always' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "echo 'Environment=\"PATH=/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\"' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "echo '[Install]' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "echo 'WantedBy=multi-user.target' | sudo tee -a /etc/systemd/system/flaskapp.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl start flaskapp",
      "sudo systemctl enable flaskapp"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("/Users/chadthompsonsmith/DevOpsBravo/week-1/keys/cpclass-devopsew-bravo.pem")
      host        = self.public_ip
    }
  }
}

resource "aws_lb" "flask_lb" {
  name               = "flask-lb-chad"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.flask_sg.id]
  subnets            = ["subnet-0a8e1a148918059f0", "subnet-09afa4f34c839bc67"]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "flask_tg" {
  name     = "flask-tg-chad"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "vpc-0f18fbe78893c6397"

  health_check {
    interval            = 30
    path                = "/"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.flask_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_tg.arn
  }
}

resource "aws_lb_target_group_attachment" "flask_tg_attachment" {
  count            = length(aws_instance.flask_instance[*].id)
  target_group_arn = aws_lb_target_group.flask_tg.arn
  target_id        = element(aws_instance.flask_instance[*].id, count.index)
  port             = 80
}

output "elb_dns_name" {
  value = aws_lb.flask_lb.dns_name
}

