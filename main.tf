################## VPC Creation ################## 
resource "aws_vpc" "dunnhumby-vpc" {
  cidr_block = "10.0.0.0/16"
tags = {
    Name = "dunnhumby-vpc"
  }
}


########### Subnet Creation #####################
resource "aws_subnet" "dunnhumby-subnet" {
  vpc_id     = aws_vpc.dunnhumby-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "dunnhumby-subnet"
  }
}

########### security group creation ##############
resource "aws_security_group" "dunnhumby-sg" {
  name        = "dunnhumby-sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.dunnhumby-vpc.id

  ingress {
    description      = "all Traffic"
    from_port        = 0
    to_port          = 0    #all ports
    protocol         = "-1"   #all traffic
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = null
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "dunnhumby-SG"
  }
}


############## Internet Gatway ################
resource "aws_internet_gateway" "dh-igw" {
  vpc_id = aws_vpc.dunnhumby-vpc.id

  tags = {
    Name = "dh-igw"
  }
}

#############Route table associatation #######
resource "aws_route_table_association" "dh-route-association" {

  subnet_id     = "${aws_subnet.dunnhumby-subnet.id}"

  route_table_id  = "${aws_route_table.dh-route_table.id}"

}

######## Route Table creation ##############
resource "aws_route_table" "dh-route_table" {

  vpc_id    = "${aws_vpc.dunnhumby-vpc.id}"

  route {

   cidr_block    = "0.0.0.0/0"

    gateway_id    = "${aws_internet_gateway.dh-igw.id}"

  }
}

#########Creating Role ##################

resource "aws_iam_role" "dh-s3-role" {
name = "dh-s3-role"
assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}


########## Creating policy ##################
resource "aws_iam_policy" "dh-s3-policy" {
  name        = "dh-s3-policy"
  description = "dh-s3-policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": ["arn:aws:s3:::dunnhumby-kuldeep"]
        },
        {
            "Sid": "AllObjectActions",
            "Effect": "Allow",
            "Action": "s3:*Object",
            "Resource": ["arn:aws:s3:::dunnhumby-kuldeep/*"]
        }
    ]
}
EOF
}

########### attaching policy to Iam role #########

resource "aws_iam_role_policy_attachment" "dh-role-attach" {
  role       = aws_iam_role.dh-s3-role.name
  policy_arn = aws_iam_policy.dh-s3-policy.arn
}

####### Attaching role to ec2 instance ################

resource "aws_iam_instance_profile" "dh-iam-role-profile" {
  name = "dh-iam-role-profile"
  role = aws_iam_role.dh-s3-role.name
}




########## EC2 Instance Linux ##################

resource "aws_instance" "dh-datapipeline" {
  ami           = "ami-0d527b8c289b4af7f" # eu-central-1
  instance_type = "t2.micro"
  associate_public_ip_address	= true
  vpc_security_group_ids = ["${aws_security_group.dunnhumby-sg.id}"]
  iam_instance_profile  = "dh-iam-role-profile"
  key_name      = "dunnhumby-key"
    subnet_id   = aws_subnet.dunnhumby-subnet.id
    user_data   = <<-EOF
		#! /bin/bash
                sudo apt-get update
                sudo apt install docker.io -y #intall docker
                sudo docker container run -d -p 8080:80 --name hello_containter tutum/hello-world  #create container and exposing on port 8080
                echo "sudo systemctl start docker" >> .profile   #docker service come up automatically if VM restart happens
	EOF
tags = {
  Name = "dh-datapipeline"
}
}


################## S3 bucker creation #########
resource "aws_s3_bucket" "dunnhumby-bucket" {
  bucket = "dunnhumby-kuldeep"
  acl    = "private"

  tags = {
    Name        = "dunnhumby_kuldeep"
  }
}
