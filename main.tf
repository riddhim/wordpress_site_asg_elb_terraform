#creating vpc
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
}

#creating public subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidr_blocks)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr_blocks
  availability_zone = var.availability_zones[count.index]
  map_public_ip_on_launch = true
}

#creating private subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidr_blocks)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_blocks
  availability_zone = var.availability_zones[count.index]
}

# Security Group for EC2 Instances
resource "aws_security_group" "instance_security_group" {
  vpc_id = aws_vpc.main.id

  # Inbound rule to allow HTTP traffic from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for RDS Instance
resource "aws_security_group" "rds_security_group" {
  vpc_id = aws_vpc.main.id

  # Inbound rule to allow MySQL traffic from EC2 instances
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.instance_security_group.id]
  }

  # Outbound rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#creating mysql rds instance
resource "aws_db_instance" "db_instance" {
  identifier                = "wordpress-db"
  allocated_storage         = 20
  storage_type              = "gp2"
  engine                    = "mysql"
  engine_version            = "8.0.25"
  instance_class            = "db.t2.micro"
#  name                      = var.db_name
  username                  = var.db_username
  password                  = var.db_password
  db_subnet_group_name      = aws_subnet.private.id
  publicly_accessible       = false
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  depends_on = [aws_subnet.private]
}

#launching template for autoscaling
resource "aws_launch_template" "wordpress_instance" {
  name          = "wordpress_instance_template"
  image_id      = var.ami_id
  instance_type = "t2.micro"
  description   = "Example launch template with user data"

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = 10
      volume_type = "gp2"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    subnet_id                   = aws_subnet.public.id
    security_groups             = [aws_security_group.instance_security_group.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd php php-gd php-xml php-json php-mbstring sqlite

              # Start Apache web server
              systemctl start httpd
              systemctl enable httpd

              # Download and extract WordPress
              curl -O https://wordpress.org/latest.tar.gz
              tar -xzf latest.tar.gz -C /var/www/html/

              # Set permissions
              chown -R apache:apache /var/www/html/wordpress
              chmod -R 755 /var/www/html/wordpress

              # Create SQLite database
              mkdir /var/www/html/wordpress/database
              touch /var/www/html/wordpress/database/wp.sqlite

              # Configure WordPress to use SQLite
              cp /var/www/html/wordpress/wp-config-sample.php /var/www/html/wordpress/wp-config.php

              # Update wp-config.php to use SQLite
              sed -i "s/database_name_here/wp/g" /var/www/html/wordpress/wp-config.php
              sed -i "s/username_here/root/g" /var/www/html/wordpress/wp-config.php
              sed -i "s/password_here/password123/g" /var/www/html/wordpress/wp-config.php
              sed -i "s/localhost/localhost/g" /var/www/html/wordpress/wp-config.php
              sed -i "s/utf8/utf8mb4/g" /var/www/html/wordpress/wp-config.php
              sed -i "/#@-/a define('DB_FILE', '/var/www/html/wordpress/database/wp.sqlite');" /var/www/html/wordpress/wp-config.php

              # Restart Apache
              systemctl restart httpd

              # Install WP-CLI
              curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
              chmod +x wp-cli.phar
              mv wp-cli.phar /usr/local/bin/wp

              # Install and activate the to-do list plugin
              cd /var/www/html/wordpress/
              wp plugin install https://downloads.wordpress.org/plugin/wp-todo-list.zip --activate
              EOF
  )
}

#########This part containing aws_acm_certificate/aws_elb/aws_elb_attachment was not performed during assignment to make the project cost friendly##########

# ACM Certificate
resource "aws_acm_certificate" "acm_cert" {
  domain_name       = "wpsite.com"
  validation_method = "DNS"

  tags = {
    Name = "acm_cert"
  }
}

# Elastic Load Balancer (ELB) Setup
resource "aws_elb" "wordpress_elb" {
  name               = "wordpress-elb"
  availability_zones = var.availability_zones[count.index]
  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
    ssl_certificate_id = aws_acm_certificate.acm_cert.arn
  }
  health_check {
    target              = "HTTP:80/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  cross_zone_load_balancing   = true
  connection_draining         = true
  connection_draining_timeout = 400
}

# Define Target Group
resource "aws_lb_target_group" "lb_target" {
  name     = "lb_target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id  # Assuming you have a VPC defined
}

####################################################################################################################################

# Auto Scaling group Setup
resource "aws_autoscaling_group" "wordpress_asg" {
  launch_template {
    id = aws_launch_template.wordpress_instance.id
    version       = "$Latest"
  }
  min_size             = 2
  max_size             = 4
  desired_capacity     = 2
  vpc_zone_identifier  = [aws_subnet.public.id]
  target_group_arns = [aws_lb_target_group.lb_target.arn]
}


###############This part of domain(aws_route53_zone/aws_acm_certificate_validation) was also not perfomed to make project cost friendly####################


# Route 53 Setup
resource "aws_route53_zone" "r53_zone" {
  name = "wpsite.com"
}

resource "aws_route53_record" "acm_validation_record" {
  zone_id = aws_route53_zone.r53_zone.zone_id
  name    = aws_acm_certificate.acm_cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.acm_cert.domain_validation_options.0.resource_record_type
  records = [aws_acm_certificate.acm_cert.domain_validation_options.0.resource_record_value]
  ttl     = 60

  alias {
    name                   = aws_elb.wordpress_elb.dns_name
    zone_id                = aws_elb.wordpress_elb.zone_id
    evaluate_target_health = true
  }
}

# Validate ACM Certificate
resource "aws_acm_certificate_validation" "acm_cert_validation" {
  certificate_arn         = aws_acm_certificate.acm_cert.arn
  validation_record_fqdns = [aws_route53_record.acm_validation_record.fqdn]
}


####################################################################################################################################
