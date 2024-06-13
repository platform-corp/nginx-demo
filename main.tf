terraform { }

# Providers
provider "vault" { }


resource "vault_approle_auth_backend_role_secret_id" "secret_id" {
  backend   = var.approle_mount_path
  role_name = var.approle_role_name
}


module "ignition_config" {
    source           = "github.com/platform-corp/tf-ignition-config.git"

    directories      = local.ignition_directories
    # disks            = local.ignition_disks
    files            = local.ignition_files
    # filesystems      = local.ignition_filesystems
    systemd_units    = local.ignition_systemd_units
    users            = local.ignition_users
    groups           = local.ignition_groups
}

resource "aws_s3_object" "ignition_file" {
  bucket   = var.bucket_name
  key      = "nginx-demo/ignition.json"
  content  = module.ignition_config.ignition_config

  tags = {
    Name        = "nginx-demo-ignition"
  }
}

resource "aws_instance" "nginx_demo" {
  ami                    = var.coreos_ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = var.vpc_security_group_ids
  subnet_id              = var.subnet_id
  user_data = base64encode("{\"ignition\":{\"config\":{\"replace\":{\"source\":\"s3://${var.bucket_name}/${aws_s3_object.ignition_file.key}\"}},\"version\":\"3.4.0\"}}")
    
  # ebs_block_device {
  #   device_name = var.ebs_device_name
  #   volume_size = var.ebs_volume_size
  #   volume_type = var.ebs_volume_type
  # }

  iam_instance_profile = var.iam_config.instance_profile_name
  tags = {
    Name = "nginx-demo"
  }
}

resource "aws_route53_record" "host_record" {
  depends_on = [aws_instance.nginx_demo]
  zone_id = var.route53_zone_id
  name    = "${var.hostname}.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [ aws_instance.nginx_demo.private_ip ]
}

resource "aws_route53_record" "proxy_record" {
  depends_on = [aws_instance.nginx_demo]
  zone_id = var.route53_zone_id
  name    = "proxy.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [ aws_instance.nginx_demo.private_ip ]
}
