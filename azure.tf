data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

locals {
  vm_name = var.vm_name
}

# Create Network Interface
resource "azurerm_network_interface" "vm" {
  name                = "cloudflared-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  tags = local.common_tags
}

# Create Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                            = local.vm_name
  resource_group_name             = data.azurerm_resource_group.rg.name
  location                        = data.azurerm_resource_group.rg.location
  size                            = "Standard_B2s"
  admin_username                  = "cloudflared"
  admin_password                  = "Cloudflared123!" # This should be stored in a secure way in production
  disable_password_authentication = false

  # Add managed identity
  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      tags
    ]
  }

  boot_diagnostics {
    storage_account_uri = null # Uses managed storage account
  }

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = base64encode(<<-EOF
#cloud-config
output: {all: '| tee -a /var/log/cloud-init-output.log'}
package_update: true
package_upgrade: true
packages:
  - curl
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release

write_files:
  - path: /opt/cleanup-cloudflared.sh
    content: |
      #!/bin/bash
      set -x
      echo "Starting cloudflared cleanup at $(date)" > /var/log/cloudflared-cleanup.log 2>&1
      
      # Stop the cloudflared service
      systemctl stop cloudflared >> /var/log/cloudflared-cleanup.log 2>&1
      
      # Clean up any stale connections
      cloudflared tunnel cleanup >> /var/log/cloudflared-cleanup.log 2>&1
      
      echo "Completed cloudflared cleanup at $(date)" >> /var/log/cloudflared-cleanup.log 2>&1
    permissions: '0755'
  - path: /opt/install-cloudflared.sh
    content: |
      #!/bin/bash
      set -x  # Enable debugging
      echo "Starting cloudflared installation at $(date)" > /var/log/cloudflared-install.log 2>&1
      
      curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb >> /var/log/cloudflared-install.log 2>&1
      
      echo "Downloaded cloudflared package at $(date)" >> /var/log/cloudflared-install.log 2>&1
      
      dpkg -i cloudflared.deb >> /var/log/cloudflared-install.log 2>&1
      
      echo "Installed cloudflared package at $(date)" >> /var/log/cloudflared-install.log 2>&1
      
      # Install the tunnel
      cloudflared service install ${var.tunnel_token_secret} >> /var/log/cloudflared-install.log 2>&1
      
      echo "Completed cloudflared service install at $(date)" >> /var/log/cloudflared-install.log 2>&1
      
      # Disable the cloudflared account (lock it)
      passwd -l cloudflared >> /var/log/cloudflared-install.log 2>&1
      
      echo "Completed cloudflared account lockdown at $(date)" >> /var/log/cloudflared-install.log 2>&1
    permissions: '0755'
  - path: /opt/tag-vm.sh
    content: |
      #!/bin/bash
      set -x  # Enable debugging
      echo "Starting VM tagging script at $(date)" > /var/log/tag-vm.log 2>&1
      
      # Install Azure CLI
      echo "Installing Azure CLI" >> /var/log/tag-vm.log 2>&1
      curl -sL https://aka.ms/InstallAzureCLIDeb | bash >> /var/log/tag-vm.log 2>&1
      
      # Function to attempt tagging with exponential backoff
      function tag_with_retry {
        local max_attempts=12
        local initial_timeout=30
        local max_timeout=600  # 10 minutes in seconds
        local timeout=$initial_timeout
        local attempt=0
        local exitCode=0

        while [[ $attempt < $max_attempts ]]
        do
          attempt=$(($attempt+1))
          echo "Attempt $attempt of $max_attempts: Tagging VM as cloud-init-complete" >> /var/log/tag-vm.log 2>&1
          
          # Use managed identity to authenticate
          echo "Attempting to login with managed identity" >> /var/log/tag-vm.log 2>&1
          az login --identity >> /var/log/tag-vm.log 2>&1
          
          # Get existing tags
          echo "Getting existing tags" >> /var/log/tag-vm.log 2>&1
          existing_tags=$(az resource show --ids "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/${data.azurerm_resource_group.rg.name}/providers/Microsoft.Compute/virtualMachines/${local.vm_name}" --query tags -o json)
          
          # Convert JSON tags to space-separated key=value pairs
          formatted_tags=$(echo "$existing_tags" | jq -r 'to_entries | map("\(.key)=\(.value)") | join(" ")')
          
          # Debug: Show the exact command that will be executed
          echo "Debug: Full command will be:" >> /var/log/tag-vm.log 2>&1
          echo "az resource tag --tags $formatted_tags cloud-init-complete=true -g ${data.azurerm_resource_group.rg.name} -n ${local.vm_name} --resource-type Microsoft.Compute/virtualMachines" >> /var/log/tag-vm.log 2>&1
          
          # Tag the VM, merging with existing tags
          echo "Attempting to tag VM" >> /var/log/tag-vm.log 2>&1
          az resource tag --tags $formatted_tags cloud-init-complete=true -g ${data.azurerm_resource_group.rg.name} -n ${local.vm_name} --resource-type "Microsoft.Compute/virtualMachines" >> /var/log/tag-vm.log 2>&1
          
          if [ $? -eq 0 ]
          then
            echo "Successfully tagged VM after $attempt attempts" >> /var/log/tag-vm.log 2>&1
            return 0
          fi
          
          # Calculate next timeout with exponential backoff but cap at max_timeout
          timeout=$(($timeout*2))
          if [ $timeout -gt $max_timeout ]; then
            timeout=$max_timeout
          fi
          
          echo "Failed to tag VM. Waiting $timeout seconds before retry..." >> /var/log/tag-vm.log 2>&1
          sleep $timeout
        done
        
        echo "Failed to tag VM after $max_attempts attempts" >> /var/log/tag-vm.log 2>&1
        return 1
      }
      
      # Call the retry function
      tag_with_retry
    permissions: '0755'

runcmd:
  - echo "Starting cloud-init runcmd section" > /var/log/runcmd.log 2>&1
  - echo "Running install-cloudflared.sh" >> /var/log/runcmd.log 2>&1
  - /opt/install-cloudflared.sh
  - echo "Running tag-vm.sh" >> /var/log/runcmd.log 2>&1
  - /opt/tag-vm.sh
  - echo "Completed cloud-init runcmd section" >> /var/log/runcmd.log 2>&1
EOF
  )
  depends_on = [
    azurerm_network_interface.vm
  ]
  tags = local.common_tags
}

# Assign Contributor role to the VM's managed identity for its own resource
resource "azurerm_role_assignment" "vm_self_management" {
  scope                = azurerm_linux_virtual_machine.vm.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
}

# Add role assignment for the network interface
resource "azurerm_role_assignment" "vm_nic_management" {
  scope                = azurerm_network_interface.vm.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
}

# Add role assignment to allow VM to access Azure AD and tag resources in the resource group
resource "azurerm_role_assignment" "vm_entra_reader" {
  scope                = data.azurerm_resource_group.rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
}

# Add Azure AD login extension
resource "azurerm_virtual_machine_extension" "aad_login" {
  name                 = "AADSSHLoginForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.ActiveDirectory"
  type                 = "AADSSHLoginForLinux"
  type_handler_version = "1.0"

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
}

# Handle cleanup when destroying the module
resource "null_resource" "cloudflared_cleanup" {
  triggers = {
    vm_id          = azurerm_linux_virtual_machine.vm.id
    resource_group = data.azurerm_resource_group.rg.name
    vm_name        = local.vm_name
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]

  provisioner "local-exec" {
    when    = destroy
    command = "az vm run-command invoke --resource-group ${self.triggers.resource_group} --name ${self.triggers.vm_name} --command-id RunShellScript --scripts '/opt/cleanup-cloudflared.sh'"
  }
} 