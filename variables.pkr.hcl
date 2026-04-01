variable "output_directory" {
  type        = string
  default     = "output"
  description = "Directory where the qcow2 image will be written."
}

variable "vm_name" {
  type        = string
  default     = "signoz.qcow2"
  description = "Output filename for the qcow2 image."
}

variable "disk_size" {
  type        = string
  default     = "40G"
  description = "Size of the root disk. Must be larger than the Ubuntu cloud image virtual size (~3G)."
}

variable "memory" {
  type        = number
  default     = 4096
  description = "RAM in MB for the build VM. SigNoz recommends at least 4GB."
}

variable "cpus" {
  type        = number
  default     = 2
  description = "vCPUs for the build VM."
}

variable "accelerator" {
  type        = string
  default     = "kvm"
  description = "QEMU accelerator. Use 'kvm' when building on a KVM-capable host (strongly recommended)."
}

variable "build_ssh_password" {
  type        = string
  default     = "packer-build-only"
  sensitive   = true
  description = "Ephemeral password for the ubuntu user during the Packer build. Locked out in the cleanup phase."
}

variable "clickhouse_password" {
  type        = string
  default     = "changeme"
  sensitive   = true
  description = "Password for the ClickHouse default user. Used in all SigNoz DSN strings."
}

variable "signoz_jwt_secret" {
  type        = string
  default     = "change-me-use-a-long-random-secret"
  sensitive   = true
  description = "JWT secret for SigNoz. Must be set to a secure random value for production."
}

variable "zookeeper_version" {
  type        = string
  default     = "3.8.5"
  description = "Apache Zookeeper version to install."
}
