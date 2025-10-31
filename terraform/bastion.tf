##########################
# Security Group for Bastion
##########################
data "http" "my_ip" {
  url = "https://checkip.amazonaws.com/"
}

locals {
  my_public_ip = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Allow SSH access to bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_public_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

##########################
# Bastion EC2 Instance
##########################
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "bastion" {
  ami               = data.aws_ami.amazon_linux_2.id
  instance_type     = "t3.micro"
  subnet_id         = aws_subnet.public_subnet_1.id
  key_name          = "eks-keypair"
  vpc_security_group_ids   = [aws_security_group.bastion_sg.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
#lifecycle {
 # ignore_changes = [security_groups]
#}
  tags = {
    Name = "bastion-host"
  }
}

##########################
# Bastion Setup via null_resource (with triggers)
##########################
resource "null_resource" "bastion_setup" {
  # 👇 Trigger this block when the script changes
  triggers = {
    script_checksum = filemd5("${path.module}/scripts/bastion-setup.sh")
  }

  provisioner "file" {
    source      = "${path.module}/scripts/bastion-setup.sh"
    destination = "/home/ec2-user/bastion-setup.sh"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/eks-keypair.pem")
      host        = aws_instance.bastion.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ec2-user/bastion-setup.sh",
      "sudo /home/ec2-user/bastion-setup.sh"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/eks-keypair.pem")
      host        = aws_instance.bastion.public_ip
    }
  }

  depends_on = [aws_instance.bastion]
}

