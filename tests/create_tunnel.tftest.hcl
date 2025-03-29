run "cloudflared" {
    module {
        source = "./example/create_tunnel"
    }

    assert {
        condition     = module.cloudflared.cloudflared_tunnel_id != null
        error_message = "Cloudflared tunnel should be created"
    }

    assert {
        condition     = can(cidrnetmask("${module.cloudflared.vm_private_ip}/32"))
        error_message = "Cloudflared tunnel should be created"
    }

    assert {
        condition     = module.cloudflared.vm_id != null
        error_message = "Cloudflared tunnel should be created"
    }

    assert {
        condition     = module.cloudflared.tunnel_health_check != null
        error_message = "Tunnel health check should be executed"
    }

    assert {
        condition     = module.cloudflared.tunnel_health_check.triggers.timestamp != null
        error_message = "Tunnel health check should have a timestamp"
    }

    # Check if the tunnel health check completed successfully
    assert {
        condition     = module.cloudflared.tunnel_health_check.id != null
        error_message = "Tunnel health check should complete successfully"
    }
}
