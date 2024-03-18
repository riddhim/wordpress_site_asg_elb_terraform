variable "aws_region" {
  description = "AWS region where resources will be deployed"
  default     = "ap-south-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidr_blocks" {
  description = "CIDR blocks for public subnets"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr_blocks" {
  description = "CIDR blocks for private subnets"
  default     = "10.0.3.0/24"
}

variable "db_name" {
  description = "Name for the RDS database"
  default     = "wordpress-db"
}

variable "db_username" {
  description = "Username for the RDS database"
  default     = "admin"
}

variable "db_password" {
  description = "Password for the RDS database"
  default     = "password"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instances"
  default     = "ami-012069dbad4508db2"
}
