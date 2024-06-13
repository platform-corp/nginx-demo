
locals {
    ignition_directories = [
        {
            path = "/usr/local/etc/services"
            uid = 100
        },
        {
            path = "/usr/local/etc/vault-agent"
            uid = 100
            gid = 0
        },
        {
            path = "/usr/local/etc/vault-agent/templates"
            uid = 100
            gid = 0
        },
        {
            path = "/usr/local/etc/vault-agent/pki"
            uid = 100
            gid = 0
        },
        {
            path = "/usr/local/etc/provisioner"
            uid = 100
            gid = 0
        },
        {
            path = "/usr/local/etc/getcert"
            uid = 100
            gid = 0
        },
        {
            path = "/usr/local/share/services"
            uid = 100
        }
    ]

    ignition_disks = [
        {
            device     = "/dev/vdb"
            wipe_table = false
            partitions = [
                {
                    label   = "var"
                    sizemib = 10240
                },
                {
                    label   = "share"
                    sizemib = 10240
                }
            ]
        }
    ]

    ignition_files = [
        {
            path = "/etc/hostname"
            overwrite = true
            content = {
                mime = "text/plain"
                content = "${var.hostname}"
            }
        },
        # {
        #     path = "/etc/pki/ca-trust/source/anchors/${var.ca_cert_file}"
        #     content = {
        #         mime = "text/plain"
        #         content = file("${path.root}/files/${var.ca_cert_file}")
        #     }
        # }, 
        {
            path = "/etc/ssh/trusted-user-ca-keys.pem"
            content = {
                mime = "text/plain"
                content = "${data.terraform_remote_state.vault_config.outputs.ssh_public_key}\n"
            }
            mode = 384
        },
        {
            path = "/etc/ssh/sshd_config.d/99-vault-ssh.conf"
            content = {
                mime = "text/plain"
                content = "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem\n"
            }
        },
        {
            path = "/usr/local/etc/provisioner/reload"
            uid = 100
            content = {
                mime = "text/plain"
                content = ""
            }
        }, 
        {
            path = "/usr/local/etc/getcert/getcert.conf"
            content = {
                mime = "text/plain"
                content = templatefile("${path.root}/templates/getcert.tftpl", {
                    vault_address = var.vault_address
                    config_dir="/usr/local/etc/vault-agent"
                    vault_ca_mount_path = data.terraform_remote_state.vault_config.outputs.ca_mount_path
                    vault_ca_role=data.terraform_remote_state.vault_config.outputs.intermediate_ca_backend_role_name
                    vault_approle_mount_path = data.terraform_remote_state.vault_config.outputs.approle_mount_path
                    pki_owner="100:100"
                })
            }
        },
        {
            path = "/usr/local/etc/vault-agent/role-id"
            content = {
                mime = "text/plain"
                content = "${data.terraform_remote_state.vault_config.outputs.approle_role_id}\n"
            }
        }, 
        {
            path = "/usr/local/etc/vault-agent/secret-id"
            content = {
                mime = "text/plain"
                content = "${vault_approle_auth_backend_role_secret_id.secret_id.secret_id}\n"
            }
        }, 
        {
            path = "/usr/local/etc/vault-agent/agent-config.hcl"
            content = {
                mime = "text/plain"
                content = templatefile("${path.root}/templates/agent-config.hcl.tftpl", {
                    vault_address = var.vault_address
                    vault_auth_month_path = data.terraform_remote_state.vault_config.outputs.cert_auth_mount_path
                })
            }
        },
        {
            path = "/usr/local/etc/vault-agent/templates/provisioner.cfg.ctmpl"
            content = {
                mime = "text/plain"
                content = templatefile("${path.root}/templates/key-value.tftpl", {
                    secret_path = "cfg/data/provisioner",
                })
            }
        },
        {
            path = "/usr/local/bin/getcert.sh"
            mode = 493
            content = {
                mime = "text/plain"
                content = file("${path.root}/files/getcert.sh")
            }
        }, 
        {
            path = "/usr/local/bin/provisioner.sh"
            mode = 493
            content = {
                mime = "text/plain"
                content = file("${path.root}/files/provisioner.sh")
            }
        },
        {
            path = "/etc/environment"
            overwrite = true
            content = {
                mime = "text/plain"
                content = templatefile("${path.module}/files/proxy.conf.tftpl",
                    {
                        proxy   = var.proxy == "" ? "http://proxy.${var.domain_name}:3128" : var.proxy
                        no_proxy = var.no_proxy == "" ? "localhost,127.0.0.1,${var.domain_name},amazonaws.com" : var.no_proxy
                    })
            }
        },
        {
            path = "/etc/proxy.conf"
            overwrite = true
            content = {
                mime = "text/plain"
                content = templatefile("${path.module}/files/proxy.conf.tftpl",
                    {
                        proxy   = var.proxy == "" ? "http://proxy.${var.domain_name}:3128" : var.proxy
                        no_proxy = var.no_proxy == "" ? "localhost,127.0.0.1,${var.domain_name},amazonaws.com" : var.no_proxy
                    })
            }
        }
    ]

    ignition_filesystems = [
        {
            device          = "/dev/disk/by-partlabel/var"
            format          = "xfs"
            label           = "var"
            path            = "/var"
            with_mount_unit = true
        },
        {
            device          = "/dev/disk/by-partlabel/share"
            format          = "xfs"
            label           = "share"
            path            = "/var/usrlocal/share"
            with_mount_unit = true
        }
    ]

    ignition_systemd_units = [
        {
            name = "podman.socket"
            enabled = true
            dropin = [
                {
                    name    = "10-podman-socket.conf"
                    content = "[Socket]\nSocketMode=0660\nSocketGroup=podman\n"
                }
            ]
        },
        {
            name = "systemd-timesyncd.service"
            enabled = true
        },
        {
            name = "getcert.service"
            enabled = true
            content = file("${path.root}/files/getcert.service")
        },
        {
            name = "vault-agent.service"
            enabled = true
            content = file("${path.root}/files/vault-agent.service")
        },
        {
            name = "provisioner.service"
            enabled = true
            content = file("${path.root}/files/provisioner.service")
        },
        {
            name = "rpm-ostreed.service"
            dropin = [
                {
                    name = "99-proxy.conf"
                    content = "[Service]\nEnvironmentFile=/etc/proxy.conf\n"
                }
            ]
        },
        {
            name = "zincati.service"
            dropin = [
                {
                    name = "99-proxy.conf"
                    content = "[Service]\nEnvironmentFile=/etc/proxy.conf\n"
                }
            ]
        },
        {
            name = "rpm-ostree-countme.service"
            dropin = [
                {
                    name = "99-proxy.conf"
                    content = "[Service]\nEnvironmentFile=/etc/proxy.conf\n"
                }
            ]
        }
    ]

    ignition_groups = [
        {
            name = "podman"
            gid  = 500
        }
    ]

    ignition_users = [
        {
            name = "core"
        },
        {
            name = "config"
            uid = 100
            no_create_home = false
            shell = "/usr/sbin/nologin"
            groups = [ "podman" ]
        }
    ]
}