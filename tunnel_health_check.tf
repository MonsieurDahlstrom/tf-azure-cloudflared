resource "null_resource" "vm_health_check" {
  triggers = {
    vm_id = azurerm_linux_virtual_machine.vm.id
    timestamp = timestamp()
    # Store OS information for cross-platform support
    is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  }

  provisioner "local-exec" {
    command = self.triggers.is_windows ? (
      "powershell.exe -Command \"(Get-AzVM -Id ${azurerm_linux_virtual_machine.vm.id}).ProvisioningState\""
    ) : (
      "az vm show --ids ${azurerm_linux_virtual_machine.vm.id} --query provisioningState -o tsv"
    )
    interpreter = self.triggers.is_windows ? ["cmd", "/c"] : ["/bin/bash", "-c"]
  }

  depends_on = [
    azurerm_linux_virtual_machine.vm
  ]
} 