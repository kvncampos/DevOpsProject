provider "aws" {
  region = "us-west-1"  # Set your desired region here
  # Set Environement Variables First using Script
}

# ---------------------------------------------- VPC-SUBNET SETUP ----------------------------------------------------

# Retrieve the default VPC
data "aws_vpc" "default" {
  default = true
}

# Retrieve the default subnet in the default VPC
data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  default_for_az    = true
}

# Retrieve the default security group ID
data "aws_security_group" "default" {
  vpc_id      = data.aws_vpc.default.id
  name        = "default"
}

# Create a subnet in the default VPC
resource "aws_subnet" "mindmeld_subnet" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = "172.31.100.0/28"
  availability_zone       = data.aws_subnet.default.availability_zone

  tags = {
    Name = "mindmeld_subnet"
  }
}

# ----------------------------------------------- REDIS SETUP --------------------------------------------------------

# Create a subnet group for ElastiCache
resource "aws_elasticache_subnet_group" "mindmeld_subnet_group" {
  name       = "mindmeld-subnet-group"
  subnet_ids = [data.aws_subnet.default.id, aws_subnet.mindmeld_subnet.id]
}

# Creates Elasticache Redis Cluster
resource "aws_elasticache_replication_group" "mindmeld-cache-cluster" {
    replication_group_id       = "mindmeld-cache-cluster-id"
    description                = "mindmeld-cache-cluster"
    node_type                  = "cache.t2.micro"
    port                       = 6379
    parameter_group_name       = "default.redis7.cluster.on"
    security_group_ids = [
      data.aws_security_group.default.id,
      aws_security_group.mindmeld_security_group.id
    ]
    depends_on                 = [ aws_security_group.mindmeld_security_group ]
    subnet_group_name          = aws_elasticache_subnet_group.mindmeld_subnet_group.name
    automatic_failover_enabled = true
    num_node_groups         = 1
    replicas_per_node_group = 1
}

# Output the cluster endpoint
output "redis_endpoint" {
  value = aws_elasticache_replication_group.mindmeld-cache-cluster.configuration_endpoint_address
}

output "redis_sg_list" {
  value = aws_elasticache_replication_group.mindmeld-cache-cluster.security_group_names
}

# -------------------------------------------------- APP NETWORK SETUP ----------------------------------------------

# Create APP EIP
resource "aws_eip" "mindmeld_eip_app" {
  domain   = "vpc"
}

# Outputs the EIP for EC2-APP and EC2-API
output "eip_address_app" {
  value = aws_eip.mindmeld_eip_app.public_ip
}

# Attach Elastic IPs to the EC2 instances
resource "aws_eip_association" "mindmeld_eip_assoc_app" {
  instance_id   = aws_instance.mindmeld_ec2_app.id
  allocation_id = aws_eip.mindmeld_eip_app.id
  depends_on    = [aws_instance.mindmeld_ec2_app] 
}

# -------------------------------------------------- SSH KEY/PAIR --------------------------------------------------
resource "aws_key_pair" "mindmeld_key_pair" {
 key_name   = "mindmeld_key_pair"
 public_key = file("key/ssh.pub")
}

# -------------------------------------------------- APP SETUP -----------------------------------------------------
resource "aws_instance" "mindmeld_ec2_app" {
  ami                    = "ami-0a31b1d679a45dda9"  # Set your desired AMI ID here
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.mindmeld_subnet.id
  /* subnet_id              = "subnet-0458806eea4ce1d3c" */
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  depends_on             = [aws_instance.mindmeld_ec2_api_test]
  vpc_security_group_ids = [aws_security_group.mindmeld_security_group.id]
  key_name               = aws_key_pair.mindmeld_key_pair.key_name
  
  provisioner "local-exec" {
    command = "echo 'EC2_APP instance is up and running!'"
  }

  tags = {
    Name        = "mindmeld-app-ec2"
    Description = "This is my EC2 instance for the MindMeld application"
  }

  user_data = <<-EOF
#!/bin/bash
# sleep 30
# Install AWS CLI components for S3 and ElastiCache
sudo yum install -y awscli

# Pull API Repo from S3
aws s3 cp s3://mindmeld-bucket-terraform/app /home/ec2-user --recursive

# Change script.sh ownership and permissions
echo "Updating script.sh permissions..."
sudo chmod +x /home/ec2-user/script.sh
EOF
}

# --------------------------------------- SETUP TO RUN APP SCRIPT IN BACKGROUND -------------------------------------
data "aws_key_pair" "mindmeld_key_pair" {
  key_name = aws_key_pair.mindmeld_key_pair.key_name
}

resource "null_resource" "ssh_to_ec2_app" {
  depends_on = [aws_instance.mindmeld_ec2_app]

  provisioner "remote-exec" {
    connection {
      type          = "ssh"
      user          = "ec2-user"  # Change this to the appropriate SSH user for your AMI
      host          = aws_eip.mindmeld_eip_app.public_ip
      private_key   = file("key/ssh")  # Update the path to your private key file
      bastion_host  = aws_instance.mindmeld_ec2_app.public_ip  # Use the instance's own public IP as the bastion host
    }
    inline = [
      "echo Waiting for S3 Bucket Pull",
      "sleep 30",
      "echo 'Running remote-exec provisioner'",
      "echo Running script for EC2-API setup...",
      "nohup /home/ec2-user/script.sh >> /home/ec2-user/app_setup.log 2>&1 &",
      "sleep 5",
      "echo Script running in the background...Should take around 5 min to begin.",
      "echo Check Logs at /home/ec2-user/app_setup.log...",
      "sleep 15",
      "echo Logging Off...",
      "exit",     # Disconnect from the SSH session immediately
    ]
  }
}


# ----------------------------------------------- API SETUP ---------------------------------------------------------

resource "aws_eip" "mindmeld_eip_api" {
  domain = "vpc"
}

output "eip_address_api" {
  value = aws_eip.mindmeld_eip_api.public_ip
}

resource "aws_eip_association" "mindmeld_eip_assoc_api" {
  instance_id   = aws_instance.mindmeld_ec2_api_test.id
  allocation_id = aws_eip.mindmeld_eip_api.id
}

# Create EC2-API
resource "aws_instance" "mindmeld_ec2_api_test" {
  ami                    = "ami-0a31b1d679a45dda9"  # Set your desired AMI ID here
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.mindmeld_subnet.id
  /* subnet_id              = "subnet-0458806eea4ce1d3c" */
  depends_on             = [
    aws_elasticache_replication_group.mindmeld-cache-cluster,
    aws_s3_bucket.mindmeld-bucket-terraform
  ]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  vpc_security_group_ids = [aws_security_group.mindmeld_security_group.id]

  provisioner "local-exec" {
    command = "echo 'EC2_API instance is up and running!'"
  }

  tags = {
    Name        = "mindmeld-api-ec2-test"
    Description = "This is my EC2 instance for the MindMeld API"
  }

  user_data = <<-EOF
#!/bin/bash
sleep 30
# Install aws cli
sudo yum install -y awscli

# Pull API Repo from S3
aws s3 cp s3://mindmeld-bucket-terraform/api /home/ec2-user --recursive
ls -l

# Change script.sh ownership and permissions
echo "Updating script.sh permissions..."
sudo chown ec2-user:ec2-user /home/ec2-user/script.sh
sudo chmod +x /home/ec2-user/script.sh

# Run script
echo "Running script for EC2-API setup..."
sudo /home/ec2-user/script.sh
echo "Script finished"
EOF
}
