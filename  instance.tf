# Get latest AMI ID for Amazon Linux2 OS
data "aws_ami" "amzlinux2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-gp2"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "ec2" {
  ami                         = data.aws_ami.amzlinux2.id
  instance_type               = var.instance_type
  key_name                    = "gt-terraform-key"
  vpc_security_group_ids      = [aws_security_group.vpc-ssh.id, aws_security_group.vpc-web.id]
  count                       = var.total_instances
  user_data                   = file("script.sh")
  associate_public_ip_address = true

  connection {
    host        = self.public_ip
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("private-key/gt-terraform-key.pem")
  }

  provisioner "file" {
    source      = "private-key/gt-terraform-key.pem"
    destination = "/home/ec2-user/gt-terraform-key"
  }

  provisioner "file" {
    source      = "index.html"
    destination = "/tmp/index.html"
  }

  provisioner "local-exec" {
    command = "echo ${self.private_ip} >> private_ips.txt"
  }

  provisioner "file" {
    source      = "mongod.conf"
    destination = "/tmp/mongod.conf"
  }

  provisioner "local-exec" {
    command = "echo ${self.private_ip} >> private_ips.txt"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo amazon-linux-extras enable nginx1.12",
      "sudo yum -y install nginx",
      "sudo systemctl start nginx",
      "sudo cp /tmp/index.html  /usr/share/nginx/html/index.html",
    ]
  }
}


################################################
# Create AMI from newly created EC2 instance
################################################
resource "aws_ami_from_instance" "mongoami" {
  name               = "mongoami"
  source_instance_id = aws_instance.ec2[0].id
  tags = {
    ENV = "${var.environment_tag}"
  }
}

################################################
# Create Launch Tempate for ASG
################################################

resource "aws_launch_template" "mongolt" {
  name_prefix   = "mongolt"
  image_id      = aws_ami_from_instance.mongoami.id
  instance_type = var.instance_type
  key_name      = "gt-terraform-key"
  tags = {
    Name = "mongoUI"
  }
}

#############################s###################
# Create placement group
################################################

resource "aws_placement_group" "mongoplacement" {
  name     = "mongoplacement"
  strategy = "spread"
}

################################################
# Create ASG
################################################

resource "aws_autoscaling_group" "mongoasg" {
  name                      = "mongo-ASG"
  max_size                  = 3
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 4
  placement_group           = aws_placement_group.mongoplacement.id
  availability_zones        = ["${aws_instance.ec2[0].availability_zone}"]
  target_group_arns         = ["${aws_lb_target_group.mongotargetgroup.arn}"]

  launch_template {
    id      = aws_launch_template.mongolt.id
    version = "$Default"
  }
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

################################################
# Create Loadbalancer target group
################################################

resource "aws_lb_target_group" "mongotargetgroup" {
  name        = "mongotargetgroup"
  port        = "27017"
  protocol    = "HTTP"
  vpc_id      = aws_default_vpc.default.id
  target_type = "instance"
  tags = {
    name = "mongoUItarget"
    ENV  = "${var.environment_tag}"
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/"
    port                = "27017"
  }
}


################################################
# Create ELB - Application loadbalancer
################################################

resource "aws_lb" "mongoelb" {
  name               = "mongoelb"
  subnets            = ["subnet-3c199757", "subnet-0387407e", "subnet-d9381795"]
  internal           = false
  load_balancer_type = "application"
  # security_groups    = ["${aws_security_group.CF2TF-SG-Web.id}"]

  tags = {
    Name = "mongodp"
    ENV  = "${var.environment_tag}"
  }
}

################################################
# Create Application LB listener
################################################

resource "aws_lb_listener" "mongolistener" {
  load_balancer_arn = aws_lb.mongoelb.arn
  port              = "27017"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.mongotargetgroup.arn
    type             = "forward"
  }
}



##############################################################
# Cloudwatch Alarm if EC2 instance CPU usage reached 80 %    #
##############################################################

resource "aws_cloudwatch_metric_alarm" "mongohealth" {
  alarm_name = "ASG_Instance_CPU"
  #  depends_on            = [
  #      #aws_sns_topic.mongotopic, 
  #      aws_autoscaling_group.mongoasg,
  #      ]
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  #  alarm_actions       = ["${aws_sns_topic.mongotopic.arn}"]
  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.mongoasg.name}"
  }
}

/*
##############################################################
# Terminate instance after creating AMI
##############################################################

resource "null_resource" "postexecution" {
  depends_on    = ["aws_ami_from_instance.mongoami"]
  connection {

    host        = aws_instance.ec2[0].public_ip
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("private-key/gt-terraform-key.pem")
  }
  provisioner "remote-exec" {
    inline = [
      "sudo init 0"
    ]
  }
}

##############################################################
# SNS notification if EC2 cpu usage more than 80%
##############################################################

resource "aws_sns_topic" "mongotopic" {
  name = "alarms-topic"
  provisioner "local-exec" {
    command = "export AWS_ACCESS_KEY_ID=${var.access_key} ; export AWS_SECRET_ACCESS_KEY=${var.secret_key}; aws sns subscribe --topic-arn ${aws_sns_topic.gogotopic.arn} --protocol email --notification-endpoint ${var.emails} --region ${var.region}"
  }
}
*/