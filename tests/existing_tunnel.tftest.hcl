run "cloudflared" {
    module {
        source = "./examples/existing_tunnel"
    }

    assert {
        condition     = can(cidrnetmask("${module.cloudflared.vm_private_ip}/32"))
        error_message = "VM private IP should be a valid IP address"
    }

    assert {
        condition     = module.cloudflared.vm_id != null
        error_message = "VM should be created"
    }

    assert {
        condition     = module.cloudflared.vm_health_check != null
        error_message = "VM health check should be executed"
    }

    assert {
        condition     = module.cloudflared.vm_health_check.triggers.timestamp != null
        error_message = "VM health check should have a timestamp"
    }

    # Check if the VM health check completed successfully
    assert {
        condition     = module.cloudflared.vm_health_check.id != null
        error_message = "VM health check should complete successfully"
    }
}
