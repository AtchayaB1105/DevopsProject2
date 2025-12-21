# DEFINE ALL YOUR VARIABLES HERE

instance_type = "t3.large"
ami           = "ami-0e86e20dae9224db8"   # Ubuntu 24.04
key_name      = "devops-lab2-KP"                     # Replace with your key-name without .pem extension
volume_size   = 30
region_name   = "us-east-1"
server_name   = "JENKINS-SERVER"

# Note: 
# a. First create a pem-key manually from the AWS console
# b. Copy it in the same directory as your terraform code
