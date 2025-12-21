terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.67.0"
    }
  }
}

provider "aws" {
  region = var.region_name
}

# STEP1: CREATE SG
resource "aws_security_group" "my-sg" {
  name        = "JENKINS-SERVER-SG"
  description = "Jenkins Server Ports"
  vpc_id      = aws_vpc.my-vpc.id
  
  # Port 22 is required for SSH Access
  ingress {
    description     = "SSH Port"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 80 is required for HTTP
  ingress {
    description     = "HTTP Port"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 443 is required for HTTPS
  ingress {
    description     = "HTTPS Port"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Port 2379-2380 is required for etcd-cluster
  ingress {
    description     = "etc-cluster Port"
    from_port       = 2379
    to_port         = 2380
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  # Port 3000 is required for Grafana
  ingress {
    description     = "NPM Port"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  # Port 6443 is required for KubeAPIServer
  ingress {
    description     = "Kube API Server"
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  # Port 8080 is required for Jenkins
  ingress {
    description     = "Jenkins Port"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  # Port 9000 is required for SonarQube
  ingress {
    description     = "SonarQube Port"
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  # Port 9090 is required for Prometheus
  ingress {
    description     = "Prometheus Port"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  # Port 9100 is required for Prometheus metrics server
  ingress {
    description     = "Prometheus Metrics Port"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 

  # Port 10250-10260 is required for K8s
  ingress {
    description     = "K8s Ports"
    from_port       = 10250
    to_port         = 10260
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  # Port 30000-32767 is required for NodePort
  ingress {
    description     = "K8s NodePort"
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }  

  # Define outbound rules to allow all
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# STEP2: CREATE EC2 USING PEM & SG

# STEP1: CREATE VPC
resource "aws_vpc" "my-vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "my-vpc"
  }
}

# STEP1.5: CREATE SUBNET IN THE VPC
resource "aws_subnet" "my-subnet" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = var.subnet_cidr
  availability_zone = var.availability_zone
  tags = {
    Name = "my-subnet"
  }
}

# Add after aws_subnet
resource "aws_internet_gateway" "my-igw" {
  vpc_id = aws_vpc.my-vpc.id
  tags = {
    Name = "my-igw"
  }
}

resource "aws_route_table" "my-rt" {
  vpc_id = aws_vpc.my-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-igw.id
  }
  tags = {
    Name = "my-rt"
  }
}

resource "aws_route_table_association" "my-rta" {
  subnet_id      = aws_subnet.my-subnet.id
  route_table_id = aws_route_table.my-rt.id
}

# NEW: CREATE EBS VOLUME FOR JENKINS PERSISTENCE
resource "aws_ebs_volume" "jenkins-data" {
  availability_zone = var.availability_zone
  size              = 20  # GB; adjust as needed
  type              = "gp3"  # General-purpose SSD
  tags = {
    Name = "jenkins-data-volume"
  }
}

resource "aws_volume_attachment" "jenkins-data-attachment" {
  device_name = "/dev/xvdf"  # Device name; ensure it matches in provisioner
  volume_id   = aws_ebs_volume.jenkins-data.id
  instance_id = aws_instance.my-ec2.id
}

# STEP2: CREATE EC2 USING PEM & SG
resource "aws_instance" "my-ec2" {
  ami           = var.ami   
  instance_type = var.instance_type
  key_name      = var.key_name        
  vpc_security_group_ids = [aws_security_group.my-sg.id]
  subnet_id     = aws_subnet.my-subnet.id # Reference the created subnet
  associate_public_ip_address = true  # Add this for public IP (needed for provisioner)
  
  root_block_device {
    volume_size = var.volume_size
  }
  
  tags = {
    Name = var.server_name
  }
  
    # USING REMOTE-EXEC PROVISIONER TO INSTALL PACKAGES
  provisioner "remote-exec" {
    # ESTABLISHING SSH CONNECTION WITH EC2
    connection {
      type        = "ssh"
      private_key = file("./devops-lab2-KP.pem") # replace with your key-name 
      user        = "ubuntu"
      host        = self.public_ip
      timeout     = "5m"  # Increased timeout
    }

    inline = [
    "sleep 30",  # Delay to ensure SSH is ready
    # Install AWS CLI
    # Ref: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
    "sudo apt install unzip -y",
    "curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'",
    "unzip awscliv2.zip",
    "sudo ./aws/install",

    # Install Docker
    # Ref: https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository
    "sudo apt-get update -y",
    "sudo apt-get install -y ca-certificates curl",
    "sudo install -m 0755 -d /etc/apt/keyrings",
    "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc",
    "sudo chmod a+r /etc/apt/keyrings/docker.asc",
    "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
    "sudo apt-get update -y",
    "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
    "sudo usermod -aG docker ubuntu",
    "sudo chmod 777 /var/run/docker.sock",
    "docker --version",

    # Install SonarQube (as container)
    "docker run -d --name sonar -p 9000:9000 sonarqube:lts-community",
    "docker run -d   --name jenkins   -p 8080:8080   -p 50000:50000   -v /data/jenkins:/var/jenkins_home   jenkins/jenkins:lts-jdk17",


    # Install Trivy
    # Ref: https://aquasecurity.github.io/trivy/v0.18.3/installation/
    "sudo apt-get install -y wget apt-transport-https gnupg",
    "wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null",
    "echo 'deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main' | sudo tee -a /etc/apt/sources.list.d/trivy.list",
    "sudo apt-get update -y",
    "sudo apt-get install trivy -y",

    # Install Kubectl
    # Ref: https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html#kubectl-install-update
    "curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.4/2024-09-11/bin/linux/amd64/kubectl",
    "curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.4/2024-09-11/bin/linux/amd64/kubectl.sha256",
    "sha256sum -c kubectl.sha256",
    "openssl sha1 -sha256 kubectl",
    "chmod +x ./kubectl",
    "mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH",
    "echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc",
    "sudo mv $HOME/bin/kubectl /usr/local/bin/kubectl",
    "sudo chmod +x /usr/local/bin/kubectl",
    "kubectl version --client",
    "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml",  # Added comma here

    # Install Helm
    # Ref: https://helm.sh/docs/intro/install/
    # Ref (for .tar.gz file): https://github.com/helm/helm/releases
    "wget https://get.helm.sh/helm-v3.16.1-linux-amd64.tar.gz",
    "tar -zxvf helm-v3.16.1-linux-amd64.tar.gz",
    "sudo mv linux-amd64/helm /usr/local/bin/helm",
    "helm version",

    # Install ArgoCD
    # Ref: https://argo-cd.readthedocs.io/en/stable/cli_installation/
    "VERSION=$(curl -L -s https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)",
    "curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/v$VERSION/argocd-linux-amd64",
    "sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd",
    "rm argocd-linux-amd64",

    # Install Java 17
    # Ref: https://www.rosehosting.com/blog/how-to-install-java-17-lts-on-ubuntu-20-04/
    # Install Java 17
    "sudo apt update -y",
    "sudo apt install openjdk-17-jdk openjdk-17-jre -y",
    "java -version",

    # Set JAVA_HOME and PATH globally for all users (including jenkins)
    "echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' | sudo tee -a /etc/environment",
    "echo 'export PATH=$$PATH:$$JAVA_HOME/bin' | sudo tee -a /etc/environment",
    "source /etc/environment",  # Reload for the current session

    # Install Jenkins
    # Ref: https://www.jenkins.io/doc/book/installing/linux/#debianubuntu
    "sudo wget -O /usr/share/keyrings/jenkins-keyring.asc https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key",
    "echo \"deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/\" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null",
    "sudo apt-get update -y",
    "sudo apt-get install -y jenkins",
    # Stop Jenkins temporarily for data migration
    "sudo systemctl stop jenkins",

    # Format and mount EBS volume for Jenkins data persistence
    "sudo mkfs.ext4 /dev/xvdf",  # Assuming /dev/xvdf; adjust if device name differs
    "sudo mkdir -p /var/lib/jenkins-data",
    "sudo mount /dev/xvdf /var/lib/jenkins-data",
    "sudo chown -R jenkins:jenkins /var/lib/jenkins-data",

    # Move existing Jenkins data to the mounted volume (if any)
    "sudo mv /var/lib/jenkins/* /var/lib/jenkins-data/ 2>/dev/null || true",
    "sudo rm -rf /var/lib/jenkins",
    "sudo ln -s /var/lib/jenkins-data /var/lib/jenkins",
    "sudo chown -R jenkins:jenkins /var/lib/jenkins",

    # Add to fstab for auto-mount on reboot
    "echo '/dev/xvdf /var/lib/jenkins-data ext4 defaults 0 0' | sudo tee -a /etc/fstab",

    "sudo systemctl start jenkins",
    "sudo systemctl enable jenkins",

    # Get Jenkins initial login password
    "ip=$(curl -s ifconfig.me)",
    "pass=$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)",

    # Output
    "echo 'Access Jenkins Server here --> http://'$ip':8080'",
    "echo 'Jenkins Initial Password: '$pass''",
    "echo 'Access SonarQube Server here --> http://'$ip':9000'",
    "echo 'SonarQube Username & Password: admin'",
  ]
  }
}

# STEP3: GET EC2 USER NAME AND PUBLIC IP 
output "SERVER-SSH-ACCESS" {
  value = "ubuntu@${aws_instance.my-ec2.public_ip}"
}

# STEP4: GET EC2 PUBLIC IP 
output "PUBLIC-IP" {
  value = "${aws_instance.my-ec2.public_ip}"
}

# STEP5: GET EC2 PRIVATE IP 
output "PRIVATE-IP" {
  value = "${aws_instance.my-ec2.private_ip}"
}
