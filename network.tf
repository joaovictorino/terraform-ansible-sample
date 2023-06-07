resource "azurerm_virtual_network" "vnet_aula" {
  name                = "myVnetAnsible"
  address_space       = ["10.80.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_aula.name

  tags = {
    environment = "aula infra"
  }

  depends_on = [azurerm_resource_group.rg_aula]
}

resource "azurerm_subnet" "subnet_aula" {
  name                 = "mySubnetAnsible"
  resource_group_name  = azurerm_resource_group.rg_aula.name
  virtual_network_name = azurerm_virtual_network.vnet_aula.name
  address_prefixes     = ["10.80.4.0/24"]

  depends_on = [azurerm_resource_group.rg_aula,
  azurerm_virtual_network.vnet_aula]
}

resource "azurerm_network_security_group" "sg_aula" {
  name                = "myNetworkSecurityGroupAnsible"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg_aula.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPInbound"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "aula infra"
  }

  depends_on = [azurerm_resource_group.rg_aula]
}