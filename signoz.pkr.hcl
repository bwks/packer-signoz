packer {
  required_version = ">= 1.9.0"
  required_plugins {
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "signoz" {
  # ── Base image ────────────────────────────────────────────────────────────
  iso_url      = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  iso_checksum = "file:https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
  disk_image   = true

  # ── Output ────────────────────────────────────────────────────────────────
  output_directory = var.output_directory
  vm_name          = var.vm_name
  format           = "qcow2"

  # ── Disk ──────────────────────────────────────────────────────────────────
  disk_size      = var.disk_size
  disk_interface = "virtio"

  # ── Machine ───────────────────────────────────────────────────────────────
  accelerator  = var.accelerator
  machine_type = "q35"
  memory       = var.memory
  cpus         = var.cpus
  net_device   = "virtio-net"
  headless     = true
  qemuargs     = [["-cpu", "host"]]

  # ── Cloud-init seed ISO (NoCloud datasource) ──────────────────────────────
  cd_files = ["cloud-init/meta-data", "cloud-init/user-data"]
  cd_label = "cidata"

  # ── SSH communicator ──────────────────────────────────────────────────────
  communicator           = "ssh"
  ssh_username           = "ubuntu"
  ssh_password           = var.build_ssh_password
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100

  # ── Boot ──────────────────────────────────────────────────────────────────
  boot_wait        = "20s"
  shutdown_command = "sudo shutdown -P now"
}

build {
  name    = "signoz"
  sources = ["source.qemu.signoz"]

  # ── Create upload staging directories ─────────────────────────────────────
  provisioner "shell" {
    inline = [
      "mkdir -p /tmp/packer/clickhouse /tmp/packer/zookeeper /tmp/packer/systemd /tmp/packer/otel-collector"
    ]
  }

  # ── Upload static config files ────────────────────────────────────────────
  provisioner "file" {
    source      = "files/clickhouse/"
    destination = "/tmp/packer/clickhouse"
  }

  provisioner "file" {
    source      = "files/zookeeper/"
    destination = "/tmp/packer/zookeeper"
  }

  provisioner "file" {
    source      = "files/systemd/"
    destination = "/tmp/packer/systemd"
  }

  provisioner "file" {
    source      = "files/otel-collector/"
    destination = "/tmp/packer/otel-collector"
  }

  # ── Installation scripts (run as root via NOPASSWD sudo) ──────────────────
  # {{.Vars}} expands to the KEY=VALUE pairs from environment_vars so they are
  # visible inside the script even though sudo drops the caller's environment.
  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/01-install-deps.sh"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/02-install-clickhouse.sh"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "CLICKHOUSE_PASSWORD=${var.clickhouse_password}",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/03-install-zookeeper.sh"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "ZOOKEEPER_VERSION=${var.zookeeper_version}",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/04-run-migrations.sh"
    environment_vars = [
      "CLICKHOUSE_PASSWORD=${var.clickhouse_password}",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/05-install-signoz.sh"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "CLICKHOUSE_PASSWORD=${var.clickhouse_password}",
      "SIGNOZ_JWT_SECRET=${var.signoz_jwt_secret}",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/06-install-otel-collector.sh"
    environment_vars = [
      "DEBIAN_FRONTEND=noninteractive",
      "CLICKHOUSE_PASSWORD=${var.clickhouse_password}",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/07-enable-services.sh"
  }

  provisioner "shell" {
    execute_command = "sudo env {{ .Vars }} bash '{{ .Path }}'"
    script          = "scripts/99-cleanup.sh"
  }

  # ── Sparsify the output qcow2 ─────────────────────────────────────────────
  post-processor "shell-local" {
    inline = [
      "echo '==> Sparsifying ${var.output_directory}/${var.vm_name}'",
      "mv '${var.output_directory}/${var.vm_name}' '${var.output_directory}/${var.vm_name}.pre-sparse'",
      "qemu-img convert -O qcow2 -S 4k '${var.output_directory}/${var.vm_name}.pre-sparse' '${var.output_directory}/${var.vm_name}'",
      "rm '${var.output_directory}/${var.vm_name}.pre-sparse'",
      "echo '==> Final image info:'",
      "qemu-img info '${var.output_directory}/${var.vm_name}'",
    ]
  }
}
