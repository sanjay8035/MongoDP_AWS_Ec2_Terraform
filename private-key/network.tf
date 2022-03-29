################################################
# Get default VPC
################################################

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}


################################################
# Get subnet zone1
################################################

resource "aws_default_subnet" "defaultsubnet1" {
  availability_zone = "us-east-1a"
  tags = {
    Name = "Default subnet1"
  }
}

################################################
# Get subnet zone2
################################################

resource "aws_default_subnet" "defaultsubnet2" {
  availability_zone = "us-east-1b"
  tags = {
    Name = "Default subnet2"
  }
}
