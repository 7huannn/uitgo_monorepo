resource "aws_launch_template" "this" {
  name_prefix            = "${var.name}-lt-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  user_data              = var.user_data == "" ? null : base64encode(var.user_data)
  vpc_security_group_ids = var.security_group_ids

  dynamic "iam_instance_profile" {
    for_each = var.iam_instance_profile_name != "" ? [1] : []
    content {
      name = var.iam_instance_profile_name
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = var.tags
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.name}-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 60
  capacity_rebalance        = true
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = var.name
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.name}-cpu"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.cpu_target
    disable_scale_in = false
  }
}

output "asg_name" {
  value = aws_autoscaling_group.this.name
}
