resource "null_resource" "test" {
  triggers = {
    abc = timestamp()
  }
provisioner "local-exec" {
  command = "echo Hello World - dev"
}
}

#  connection {
#    type     = "ssh"
#    user     = "centos"
#    password = "DevOps321"
#    host     = self.public_ip
#  }
#  inline = [
#    "sudo labauto ansible",
#    "ansible-pull -i localhost, -U https://github.com/chaliashok/roboshop-ansible main.yml  -e role_name=${var.name}"
#  ]
#} }