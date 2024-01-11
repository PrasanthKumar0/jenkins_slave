# AWS Provider
provider "aws" {
  region = "us-east-1"
}


# Security Group
resource "aws_security_group" "web_traffic" {
  name        = "Allow web traffic"
  description = "inbound ports for ssh and standard http and everything outbound"
  dynamic "ingress" {
    for_each = var.ingressrules
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "Terraform" = "true"
  }
}

# key pair create
module "key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  key_name   = "jenkins"
  public_key = file(var.public_key)
}

resource "aws_ssm_parameter" "private_key" {
  name        = "${module.key_pair.key_pair_name}-private"
  description = "private master key"
  type        = "SecureString"
  value       = file(var.private_key)
}

resource "aws_ssm_parameter" "public_key" {
  name        = "${module.key_pair.key_pair_name}-public"
  description = "public master key"
  type        = "SecureString"
  value       = file(var.public_key)
}


# resource block
resource "aws_instance" "jenkins" {
  ami             = data.aws_ami.redhat.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web_traffic.name]
  key_name        = "jenkins"
  tags = {
    Name = "Jenkins-server"
  }
}

# Domain block 
resource "aws_route53_record" "domainName" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.domainName
  type    = "A"
  ttl     = 300
  records = [aws_instance.jenkins.public_ip]
}

# null resource 
resource "null_resource" "os_update" {
  depends_on = [aws_instance.jenkins]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key)
    host        = aws_instance.jenkins.public_ip
    timeout     = "50s"
  }

  provisioner "file" {
    connection {
      host        = aws_instance.jenkins.public_ip
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key)
      timeout     = "50s"
    }

    source      = "~/.ssh"
    destination = "/tmp/"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y java-11-openjdk",
      "sudo yum -y install wget",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key",
      "sudo yum upgrade -y",
      "sleep 10",
      "sudo yum install nc -y",
      "sleep 10",
      "sudo yum install xmlstarlet -y",
      "sleep 10",
    ]
  }
}

# null resource 
resource "null_resource" "install_jenkins" {
  depends_on = [aws_instance.jenkins, null_resource.os_update]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key)
    host        = aws_instance.jenkins.public_ip
    timeout     = "20s"
  }

  # https://kodekloud.com/community/t/while-installing-jenkins-on-vm-getting-below-error/86030/8
  provisioner "remote-exec" {
    inline = [
      "sudo yum install jenkins -y",
      "sleep 10",
      "sudo systemctl restart jenkins",
      "sleep 10",
      "sudo mv /tmp/.ssh/id_rsa /home/ec2-user/.ssh &> /dev/null",
      "sudo mv /tmp/.ssh/id_rsa.pub /home/ec2-user/.ssh &> /dev/null",
      "sudo chmod 0600 /home/ec2-user/.ssh/id*",
    ]
  }
}


# null resource 
resource "null_resource" "install_plugin" {
  depends_on = [aws_instance.jenkins, null_resource.os_update, null_resource.install_jenkins]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key)
    host        = aws_instance.jenkins.public_ip
    timeout     = "20s"
  }

  provisioner "file" {
    source      = "files/get-InitialPassword.sh"
    destination = "/tmp/get-InitialPassword.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/get-InitialPassword.sh",
      "sudo sh -x /tmp/get-InitialPassword.sh",
    ]
  }
}