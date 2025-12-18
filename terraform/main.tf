## creating backend instance using open source module ##
module "backend" {
  source  = "terraform-aws-modules/ec2-instance/aws"

  name = "${var.project_name}-${var.environment}-backend"

  instance_type = "t2.micro"
  subnet_id     = local.private_subnet_id
  ami = data.aws_ami.ami_id.id
  security_group_vpc_id = data.aws_ssm_parameter.vpc_id.value
  vpc_security_group_ids = [data.aws_ssm_parameter.backend_sg_id.value]

  create_security_group = false
  

  tags = merge (
    var.common_tags,
    {
        Name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
    }
  )
}

## creating null resource to connect with backend ##
resource "null_resource" "backend" {
  # if backend instance created, then this null resource will trigger
  triggers = {
    instance_id = module.backend.id
  }

  # connection to backend server
  connection {
    type = "ssh"
    user = "ec2-user"
    password = "DevOps321"
    host = module.backend.private_ip
  }

 # transferring backend.sh from local to remote(backend)
 provisioner "file" {
    source = "backend.sh"
    destination = "/tmp/backend.sh"
 }

 # connecting backend server with remote exec
 provisioner "remote-exec" {
    inline = [
        "chmod +x /tmp/${var.common_tags.Component}.sh",
        "sudo sh /tmp/${var.common_tags.Component}.sh ${var.common_tags.Component} ${var.environment}"
    ]
 }
  
}

## stopping backend instance ##
resource "aws_ec2_instance_state" "backend" {
    instance_id = module.backend.id
    state = "stopped"

# when null resource is completed then only then only it will stop
    depends_on = [null_resource.backend]
}

## creating ami ##
resource "aws_ami_from_instance" "backend" {
    name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
    source_instance_id = module.backend.id

# when backend instance is stopped then we need to create ami
    depends_on = [aws_ec2_instance_state.backend]
}

## deleting backend server after creating ami ##
resource "null_resource" "backend_delete" {
  
  # if backend instance created, then this null resource will trigger
  triggers = {
    instance_id = module.backend.id
  }

 # connecting backend server with local exec
 provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${module.backend.id}"
 }
  
 depends_on = [aws_ami_from_instance.backend]

}

## creating alb target group ##
resource "aws_lb_target_group" "backend_tg" {
  name        = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = data.aws_ssm_parameter.vpc_id.value

  health_check {
    path                = "/health"
    port                = 8080 # or a specific port like "80"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200" # Accept HTTP 2xx status codes as healthy
  }
}

## creating launch template ##
resource "aws_launch_template" "backend_lt" {
  name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"

  image_id = aws_ami_from_instance.backend.id

  instance_initiated_shutdown_behavior = "terminate"

  instance_type = "t2.micro"

  vpc_security_group_ids = [data.aws_ssm_parameter.backend_sg_id.value]

  update_default_version = true

  tag_specifications {
    resource_type = "instance"

    tags = merge(
        var.common_tags,
        {
            Name = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
        }
    )
  }

}

## creating auto scaling group for backend ##
resource "aws_autoscaling_group" "backend_asg" {
  name                      = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  max_size                  = 5
  min_size                  = 1
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 1
  
  target_group_arns = [aws_lb_target_group.backend_tg.arn]

  vpc_zone_identifier       = split(",",data.aws_ssm_parameter.private_subnet_ids.value)

  launch_template {
    id = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling" #new servers will be created, old are deleted
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
    propagate_at_launch = true
  }

  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "Project"
    value               = "${var.project_name}"
    propagate_at_launch = false
  }
}

## creating asg policy ##
resource "aws_autoscaling_policy" "backend_asg_policy" {
  name                   = "${var.project_name}-${var.environment}-${var.common_tags.Component}"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 10.0
  }
}

## creating backend list ##
resource "aws_lb_listener_rule" "backend_lr" {
  listener_arn = data.aws_ssm_parameter.app_alb_listener_arn.value
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }

  condition {
    host_header {
      values = ["backend.app-${var.environment}.${var.zone_name}"]
    }
  }
}