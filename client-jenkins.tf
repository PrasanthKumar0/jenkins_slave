# Slave "general builds"

resource "aws_instance" "jenkins_node" {
  ami             = data.aws_ami.redhat.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web_traffic.name]
  key_name        = "jenkins"
  user_data       = data.template_file.userdata_jenkins_worker_linux.rendered

  tags = {
    Name = "Jenkins-node"
  }

  depends_on = [aws_instance.jenkins, null_resource.os_update, null_resource.install_jenkins]

  root_block_device {
    volume_type = "gp2"
    volume_size = 10
  }
}

data "aws_ssm_parameter" "private_key" {
  name       = "${module.key_pair.key_pair_name}-private"
  depends_on = [resource.aws_ssm_parameter.private_key]
}


data "template_file" "userdata_jenkins_worker_linux" {
  template = file("userdata/jenkins-node.sh")

  vars = {
    jenkins_url      = "jenkins.robofarming.link"
    jenkins_username = "admin"
    jenkins_password = "password"
    device_name      = "eth0"
    worker_pem       = data.aws_ssm_parameter.private_key.value
  }
}