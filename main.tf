#creating vpc
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "main"
  }
}


# Create Internet Gateway
resource "aws_internet_gateway" "internet-gateway-wp" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "internet-gateway-wp"
  }
  depends_on = [aws_vpc.main]
}

# Create Route Table for public subnets
resource "aws_route_table" "route_table_public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway-wp.id
  }
  depends_on = [aws_internet_gateway.internet-gateway-wp]
  tags = {
    Name = "wp-route-table"
  }
}

#creating public subnets
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidr_blocks
  availability_zone = var.availability_zones
  map_public_ip_on_launch = true
  tags = {
    Name = "public"
  }
#  route_table_id    = aws_route_table.route_table_public.id
  depends_on = [aws_internet_gateway.internet-gateway-wp]
}

# Create a route table association for the public subnet
resource "aws_route_table_association" "public_as" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route_table_public.id
}


#creating private subnets
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_blocks
  availability_zone = var.availability_zones
  depends_on = [aws_vpc.main]
  tags = {
    Name = "private"
  }
}


# Security Group for EC2 Instances
resource "aws_security_group" "instance_security_group" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "instance-sg"
  }

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
  tags = {
    Name = "db-sg"
  }

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

resource "aws_db_subnet_group" "db-subnet-group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private.id]  # Specify the ID of your private subnet(s)
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
  db_subnet_group_name      = aws_db_subnet_group.db-subnet-group.name
 # subnet_ids = [aws_subnet.private.id]
  publicly_accessible       = false
  vpc_security_group_ids = [aws_security_group.rds_security_group.id]
  depends_on = [aws_subnet.private]
}


resource "aws_launch_configuration" "wordpress_instance" {
  name          = "wordpress_instance"
  image_id      = "ami-094729b931e96f9c1"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.instance_security_group.id]
  associate_public_ip_address = true
#  description   = "Example launch template with user data"

  root_block_device {
#    device_name = "/dev/sda1"

      volume_size = 20
      volume_type = "gp2"

  }

  user_data_base64 = base64encode(<<EOF
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
  depends_on = [aws_subnet.public]
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



# Auto Scaling Setup
resource "aws_autoscaling_group" "wordpress_asg" {
  name = "wordpress_asg"
  launch_configuration = aws_launch_configuration.wordpress_instance.id
  min_size             = 1
  max_size             = 2
  desired_capacity     = 1
  vpc_zone_identifier  = [aws_subnet.public.id]
  depends_on = [aws_subnet.public]
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
