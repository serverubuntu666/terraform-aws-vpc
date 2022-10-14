data "aws_ami" "test_instance_ami" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = [var.ami_name]
  }
}

resource "random_id" "test_instance_id" {
  byte_length = 2
  count       = var.instance_count
  keepers = {
    key_name = var.key_name
  }

}
resource "aws_key_pair" "test_instance_auth" {
  key_name   = var.key_name
  public_key = file(var.pub_key_path)

}
resource "aws_instance" "test_instance" {
  count                  = var.instance_count
  ami                    = data.aws_ami.test_instance_ami.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.test_instance_auth.id
  vpc_security_group_ids = [var.public_sg]
  subnet_id              = var.public_subnets[count.index]

  # user_data = <<-EOF
  #             #!/bin/bash
  #             sudo apt-get update
  #             sudo apt-get install -y apache2
  #             sudo systemctl start apache2
  #             sudo systemctl enable apache2
  #             echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
  #             EOF
  tags = {
    Name = "test_instance-${random_id.test_instance_id[count.index].dec}"
  }

  root_block_device {
    volume_size = var.volume_size
  }
}
#If provisioner is used within aws_instance resource the terraform.*.sh in tmp folder might not run properly and it might throw error as packages may be broken while installing since all the cmd are not executed in one go on a single machine.So best option is to used provisioner in separate resource as it will be executed in a single go for each machine
resource "null_resource" "instance" {
  count = var.instance_count
  depends_on = [
    aws_instance.test_instance
  ]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = aws_instance.test_instance[count.index].public_ip
      private_key = file(var.pvt_key_path)
    }

    inline = [
      templatefile("${path.cwd}/user_data.tpl",
        { public_ip         = aws_instance.test_instance[count.index].public_ip
          availability_zone = aws_instance.test_instance[count.index].availability_zone
      })
    ]

  }
}

resource "aws_lb_target_group_attachment" "attach_instance_tg" {
  count            = var.instance_count
  target_group_arn = var.lb_target_group_arn
  target_id        = aws_instance.test_instance[count.index].id
  port             = var.tg_port

}
