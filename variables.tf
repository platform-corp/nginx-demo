variable "hostname" {
  description = "Hostname of the machine."
  type        = string
}

variable "vault_address" {
  description = "Address of the Vault server."
  type        = string
}

variable "approle_mount_path" {
  description = "Path of the AppRole auth backend."
  type        = string
}

variable "approle_role_name" {
  description = "Name of the AppRole role."
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket."
  type        = string
}

variable "coreos_ami_id" {
  description = "AMI ID of the CoreOS image."
  type        = string
}

variable "domain_name" {
  description = "Domain name of the machine."
  type        = string
}

variable "ebs_volume_size" {
  description = "The size of the EBS volume to attach to the Vault instances."
  type        = number
  default     = 10
}

variable "ebs_volume_type" {
  description = "The type of the EBS volume to attach to the Vault instances."
  type        = string
  default     = "gp2"
}

variable "ebs_device_name" {
  description = "The device name to use for the EBS volume."
  type        = string
  default     = "/dev/xvdb"
}

variable "instance_type" {
  description = "Type of the instance."
  type        = string
}

variable "key_name" {
  description = "Name of the SSH key."
  type        = string
}

variable "route53_zone_id" {
  description = "ID of the Route53 zone."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet."
  type        = string
}

variable "vpc_security_group_ids" {
  description = "IDs of the security groups."
  type        = list(string)
}

variable "proxy" {
  description = "Proxy server address."
  type        = string
  default = ""
}

variable "no_proxy" {
  description = "No proxy addresses."
  type        = string
  default = ""
}