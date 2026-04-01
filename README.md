# packer-signoz

Packer template that builds a [SigNoz](https://signoz.io) observability VM image (qcow2) from the Ubuntu 24.04 LTS cloud image, intended for QEMU/KVM/libvirt deployments.

The image comes with ClickHouse, Zookeeper, the SigNoz backend, and the SigNoz OTel Collector pre-installed, pre-migrated, and enabled as systemd services. Cloud-init is reset so the image can be further customised on first boot.

---

## Requirements

| Tool | Min version | Notes |
|------|-------------|-------|
| [Packer](https://developer.hashicorp.com/packer) | 1.9.0 | `apt install packer` (HashiCorp repo) |
| QEMU | any | `apt install qemu-system-x86_64 qemu-img` |
| KVM | — | Host must support hardware virtualisation (`/dev/kvm` present) |

Install Packer on Ubuntu/Debian:

```sh
curl -fsSL https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y packer
```

---

## Quick start

```sh
# 1. Install the QEMU Packer plugin
packer init .

# 2. Build with defaults (change passwords before using in production)
packer build \
  -var clickhouse_password=changeme \
  -var signoz_jwt_secret=change-me-use-a-long-random-secret \
  .

# Output: output/signoz.qcow2
```

---

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `clickhouse_password` | `changeme` | ClickHouse `default` user password. Used in all DSN strings. |
| `signoz_jwt_secret` | `change-me-…` | JWT signing secret for the SigNoz API. Must be a long random value in production. |
| `zookeeper_version` | `3.8.5` | Apache Zookeeper release to install. |
| `disk_size` | `40G` | Root disk size. Must be ≥ the cloud image virtual size (~3 GB). |
| `memory` | `4096` | Build VM RAM in MB. |
| `cpus` | `2` | Build VM vCPUs. |
| `accelerator` | `kvm` | QEMU accelerator. Use `none` if KVM is unavailable (much slower). |
| `output_directory` | `output` | Directory where `signoz.qcow2` is written. |
| `vm_name` | `signoz.qcow2` | Output filename. |
| `build_ssh_password` | `packer-build-only` | Ephemeral password for the ubuntu user during the build. Locked in the cleanup phase. |

Override any variable on the command line with `-var key=value`, or create a `signoz.auto.pkrvars.hcl` file:

```hcl
clickhouse_password = "my-secure-password"
signoz_jwt_secret   = "my-long-random-jwt-secret"
```

---

## What the build does

1. **Boot** — QEMU starts the Ubuntu 24.04 cloud image with a NoCloud cloud-init seed that enables SSH password auth for the build user.
2. **Install deps** — Java (required by Zookeeper), curl, gnupg.
3. **Install ClickHouse** — Adds the official apt repo, installs `clickhouse-server`, sets the password, and applies the single-node cluster config for Zookeeper coordination.
4. **Install Zookeeper 3.8.5** — Downloads the binary release, configures it as a systemd service.
5. **Run migrations** — Starts Zookeeper and ClickHouse, downloads the SigNoz OTel Collector binary, and runs the three schema migrations (`bootstrap`, `sync up`, `async up`).
6. **Install SigNoz** — Downloads the latest SigNoz binary, writes the environment file (JWT secret, ClickHouse DSN, SQLite path), creates the systemd service.
7. **Install OTel Collector** — Installs the already-downloaded collector binary, writes `config.yaml` (ClickHouse DSN substituted) and `opamp.yaml`, creates the systemd service.
8. **Enable services** — `systemctl enable` for all four services; stops ClickHouse and Zookeeper so the image is idle at capture time.
9. **Cleanup** — Locks the build password, removes SSH host keys, resets cloud-init and machine-id (both regenerated on first boot), cleans apt cache, zeroes free space.
10. **Sparsify** — `qemu-img convert -O qcow2 -S 4k` shrinks the output image by removing zero blocks.

---

## Deploying the image

Copy `output/signoz.qcow2` to your libvirt image store and create a VM:

```sh
sudo cp output/signoz.qcow2 /var/lib/libvirt/images/signoz.qcow2

virt-install \
  --name signoz \
  --memory 4096 \
  --vcpus 2 \
  --disk /var/lib/libvirt/images/signoz.qcow2,format=qcow2,bus=virtio \
  --import \
  --os-variant ubuntu24.04 \
  --network network=default,model=virtio \
  --noautoconsole
```

On first boot cloud-init will:
- Regenerate a unique machine-id and SSH host keys
- Apply any user-data you supply via a NoCloud or ConfigDrive source

---

## Sending telemetry to SigNoz

The OTel Collector listens on the following ports by default:

| Protocol | Port | Use |
|----------|------|-----|
| OTLP gRPC | 4317 | OpenTelemetry traces, metrics, logs |
| OTLP HTTP | 4318 | OpenTelemetry traces, metrics, logs |
| Jaeger gRPC | 14250 | Jaeger traces |
| Jaeger HTTP | 14268 | Jaeger traces |
| HTTP log (Heroku) | 8081 | Log ingestion |
| HTTP log (JSON) | 8082 | Log ingestion |

The SigNoz UI is served on **port 8080** once the `signoz` service is running.

```sh
curl http://<vm-ip>:8080/api/v1/health
# {"status":"ok"}
```

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  VM                                         │
│                                             │
│  ┌──────────┐    ┌────────────────────────┐ │
│  │ Zookeeper│───▶│      ClickHouse        │ │
│  │ :2181    │    │      :9000             │ │
│  └──────────┘    └────────────┬───────────┘ │
│                               │             │
│  ┌────────────────────────────▼───────────┐ │
│  │       SigNoz OTel Collector            │ │
│  │  OTLP :4317/:4318  Jaeger :14250/:14268│ │
│  └────────────────────────────┬───────────┘ │
│                               │             │
│  ┌────────────────────────────▼───────────┐ │
│  │         SigNoz Backend :8080           │ │
│  └────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

---

## File layout

```
packer-signoz/
├── signoz.pkr.hcl                # Packer template (QEMU builder)
├── variables.pkr.hcl             # Variable definitions
├── cloud-init/
│   ├── meta-data                 # NoCloud instance metadata
│   └── user-data                 # Build-time SSH user config
├── files/
│   ├── clickhouse/
│   │   └── cluster.xml           # ClickHouse cluster + Zookeeper config
│   ├── zookeeper/
│   │   ├── zoo.cfg               # Zookeeper config
│   │   └── zoo.env               # Zookeeper log dir env
│   ├── systemd/
│   │   ├── zookeeper.service
│   │   ├── signoz.service
│   │   └── signoz-otel-collector.service
│   └── otel-collector/
│       ├── config.yaml           # OTel Collector pipeline config (password substituted at build time)
│       └── opamp.yaml            # OpAMP manager endpoint
└── scripts/
    ├── 01-install-deps.sh
    ├── 02-install-clickhouse.sh
    ├── 03-install-zookeeper.sh
    ├── 04-run-migrations.sh
    ├── 05-install-signoz.sh
    ├── 06-install-otel-collector.sh
    ├── 07-enable-services.sh
    └── 99-cleanup.sh
```
