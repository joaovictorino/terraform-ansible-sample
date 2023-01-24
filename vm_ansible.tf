resource "random_string" "random_ansible" {
  length           = 20
  upper            = false
  special          = false
}

resource "azurerm_storage_account" "storage_aula_ansible" {
    name                        = random_string.random_ansible.result
    resource_group_name         = azurerm_resource_group.rg_aula.name
    location                    = var.location
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "aula infra",
        tool = "ansible"
    }

    depends_on = [ azurerm_resource_group.rg_aula ]
}

resource "azurerm_linux_virtual_machine" "vm_aula_ansible" {
    name                  = "myVMAnsibleSample"
    location              = var.location
    resource_group_name   = azurerm_resource_group.rg_aula.name
    network_interface_ids = [azurerm_network_interface.nic_aula_ansible.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsAnsibleDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "myvmansiblesample"
    admin_username = var.user
    admin_password = var.password
    disable_password_authentication = false

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.storage_aula.primary_blob_endpoint
    }

    tags = {
        environment = "aula infra",
        tool = "ansible"
    }

    depends_on = [  azurerm_resource_group.rg_aula, 
                    azurerm_network_interface.nic_aula_ansible, 
                    azurerm_network_interface.nic_aula, 
                    azurerm_storage_account.storage_aula_ansible, 
                    azurerm_public_ip.publicip_aula_ansible,
                    azurerm_public_ip.publicip_aula,
                    azurerm_linux_virtual_machine.vm_aula ]
}

resource "time_sleep" "wait_30_seconds" {
  depends_on = [azurerm_linux_virtual_machine.vm_aula_ansible]
  create_duration = "30s"
}

resource "local_file" "inventory" {
    filename = "./ansible/hosts"
    content     = <<EOF
[web]
${azurerm_network_interface.nic_aula.private_ip_address}

[web:vars]
ansible_user=${var.user}
ansible_ssh_pass=${var.password}
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
    depends_on = [ time_sleep.wait_30_seconds ]
}

resource "null_resource" "upload" {
    provisioner "file" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = azurerm_public_ip.publicip_aula_ansible.ip_address
        }
        source = "ansible"
        destination = "/home/${var.user}"
    }

    depends_on = [ time_sleep.wait_30_seconds ]
}

resource "null_resource" "deploy_ansible" {
    triggers = {
        order = null_resource.upload.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = azurerm_public_ip.publicip_aula_ansible.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y software-properties-common",
            "sudo apt-add-repository --yes --update ppa:ansible/ansible",
            "sudo apt-get -y install python3 ansible"
        ]
    }

    depends_on = [ null_resource.upload ]
}

resource "null_resource" "run_ansible" {
    triggers = {
        order = null_resource.deploy_ansible.id
    }
    provisioner "remote-exec" {
        connection {
            type = "ssh"
            user = var.user
            password = var.password
            host = azurerm_public_ip.publicip_aula_ansible.ip_address
        }
        inline = [
            "ansible-playbook -i /home/${var.user}/ansible/hosts /home/${var.user}/ansible/main.yml"
        ]
    }
    
    depends_on = [ null_resource.deploy_ansible ]
}