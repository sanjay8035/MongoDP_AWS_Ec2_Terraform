variable "region" {
  default = "us-east-2"
}
variable "access_key" {
  default = ""
}

variable "secret_key" {
  default = ""
}

variable "instance_type" {
  description = "Instance AWS type"
  default     = "t2.micro"
}

variable "total_instances" {
  default = 1
}

variable "aws_default_user" {
  description = "Instance user to use into instance"
  default     = "ec2-user"
}



variable "environment_tag" {
  description = "Environment Tag"
  default     = "DEV"
}

/*
variable "emails" {
  default = "iambharathwaj.ks@gmail.com, "
}


# Vpc



# Subnet
variable "subnet_ids" {
  type = map(string)

  default = {
    "us-west-1a" = "subnet-0251b14e"
    "us-west-1b" = "subnet-63bde03c"
    
  }
}
*/

variable "vpc_id" {
  description = "Mongo VPC"
  default     = "vpc-b78debdc"
}