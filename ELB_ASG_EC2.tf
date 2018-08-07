provider "aws" {
  region = "${var.region}"
}


resource "aws_launch_configuration" "chef" {
  name          = "chef_config"
  image_id             = "ami-14c5486b"
  instance_type        = "t2.micro"
  key_name             = "MyKeyPairChef2"
  iam_instance_profile = "Ec2CodeDeployRole"
  security_groups = ["${aws_security_group.instance.id}"]

  
  

  # security_groups      = ["sg-0486379f977fbe0c6"]

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update
              yum install -y aws-cli
              sudo yum install java-1.8.0
              sudo yum remove java-1.7.0-openjdk
              sudo yum install wget
              cd /home/ec2-user
              wget https://aws-codedeploy-us-east-1.s3.amazonaws.com/latest/install
              chmod +x ./install
              sed -i "s/sleep(.*)/sleep(10)/" install
              sudo ./install auto              
              EOF

}


resource "aws_security_group" "instance" {
  name = "DMZ"
 
  description = "ONLY HTTP INBOUD"
 

  ingress {
        from_port = 80
        to_port = 80
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

  # Auto scaling group

  resource "aws_autoscaling_group" "chef" {
  availability_zones = ["us-east-1a"]
  desired_capacity = 2
  max_size = 3
  min_size = 2
  health_check_type = "EC2"
  wait_for_capacity_timeout = 0
  name = "Chef-asg"
  metrics_granularity = "5 minutes"
  force_delete              = true
  # vpc_zone_identifier = ["subnet-b578fdff", "subnet-33e0116f"]
  vpc_zone_identifier = ["subnet-33e0116f"] 
  launch_configuration = "${aws_launch_configuration.chef.id}" 

   tags = [
    {
      key                 = "explicit1"
      value               = "value1"
      propagate_at_launch = true
    }   
    ]

  }

    # load_balancers = ["${aws_lb.chef.name}"]
 #  health_check_type = "ALB"

 # tag {
 #    key = "Name"
 #    value = "terraform-asg-example"
 #    propagate_at_launch = true
 #  }

   
resource "aws_lb" "chef"{
  name               = "${var.alb_name}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-0486379f977fbe0c6"]
  subnets            = ["subnet-b578fdff", "subnet-33e0116f"]
  name = "ALB-Webserver"

  enable_deletion_protection = false

  # access_logs {
  #   bucket  = "${aws_s3_bucket.lb_logs.bucket}"
  #   prefix  = "alb_logs"
  #   enabled = true
  # }

  tags {
    Environment = "production"
  }
}


resource "aws_alb_target_group" "chef" {  
  name     = "${var.target_group_name}"  
  port     = "${var.svc_port}"  
  protocol = "HTTP"  
  vpc_id   = "vpc-bcb495c7"   
    # load_balancer_type = "application"
  tags {    
    name = "tg-chef"    
  }   
  # stickiness {    
  #   type            = "lb_cookie"    
  #   cookie_duration = 1800    
  #   enabled         = "${var.target_group_sticky}"  
  # }   
  health_check {    
    healthy_threshold   = 3  
    unhealthy_threshold = 2  
    timeout             = 2   
    interval            = 5    
    path                = "/index.html"    
    port                = 80 
  }
}

# # Create a new ALB Target Group attachment
# resource "aws_autoscaling_attachment" "chef" {
#   autoscaling_group_name = "${aws_autoscaling_group.asg.id}"
#   alb_target_group_arn   = "${aws_alb_target_group.test.arn}"
# }



resource "aws_lb_listener" "chef" {
  load_balancer_arn = "${aws_lb.chef.id}"
  port              = "80"
  protocol          = "HTTP"
  

  default_action {
    target_group_arn = "${aws_alb_target_group.chef.arn}"
    type             = "forward"
  }
}

// Target Group//

# Create a new ALB Target Group attachment
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = "${aws_autoscaling_group.chef.id}"
  alb_target_group_arn   = "${aws_alb_target_group.chef.arn}"
}


//mysql database//

# resource "aws_db_instance" "default" {
#   allocated_storage    = 10
#   storage_type         = "gp2"
#   engine               = "mysql"
#   engine_version       = "5.7"
#   instance_class       = "db.t2.micro"
#   name                 = "mydb"
#   username             = "foo"
#   password             = "foobarbaz"
#   parameter_group_name = "default.mysql5.7"
# }
