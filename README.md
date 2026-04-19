# Kubernetes Voting App — End-to-End DevOps Pipeline

> A production-grade microservices application fully deployed on a self-managed Kubernetes cluster on AWS, demonstrating a complete DevOps lifecycle: Infrastructure as Code → Configuration Management → Containerisation → GitOps CI/CD → Observability.

![Architecture](./architecture.excalidraw.png)

---

## Table of Contents

- [Project Overview](#-project-overview)
- [Application Architecture](#-application-architecture)
- [Technology Stack](#-technology-stack)
- [DevOps Implementation](#-devops-implementation)
  - [1. Infrastructure as Code — Terraform](#1-infrastructure-as-code--terraform)
  - [2. Configuration Management — Ansible](#2-configuration-management--ansible)
  - [3. Containerisation — Docker](#3-containerisation--docker)
  - [4. Kubernetes Manifests](#4-kubernetes-manifests)
  - [5. CI/CD Pipeline — GitHub Actions](#5-cicd-pipeline--github-actions)
  - [6. GitOps — ArgoCD](#6-gitops--argocd)
  - [7. Observability — Prometheus & Grafana](#7-observability--prometheus--grafana)
- [Getting Started](#-getting-started)
- [Security Highlights](#-security-highlights)
- [Skills Demonstrated](#-skills-demonstrated)

---

## Project Overview

This project takes the classic Docker sample voting application and transforms it into a **fully automated, production-ready deployment** on a self-managed Kubernetes cluster. Every layer of the stack — from raw AWS infrastructure to application delivery — is automated and codified.

The goal is to demonstrate real-world DevOps engineering: not just *running* Kubernetes, but *building the platform that runs Kubernetes*, end to end.

---

## Application Architecture

The application is a distributed, event-driven system composed of five microservices:

```
  [User] → Vote UI (Python/Flask)
                ↓
            Redis (queue)
                ↓
            Worker (.NET)
                ↓
          PostgreSQL (DB)
                ↓
  [User] → Result UI (Node.js)
```

| Service    | Language / Image       | Role                                                        |
|------------|------------------------|-------------------------------------------------------------|
| `vote`     | Python / Flask         | Front-end web app — accepts user votes (Cat vs Dog)         |
| `redis`    | Redis Alpine           | In-memory message queue — buffers votes from the front-end  |
| `worker`   | .NET                   | Background processor — dequeues from Redis, writes to DB    |
| `db`       | PostgreSQL 15-Alpine   | Persistent store — holds aggregated vote counts             |
| `result`   | Node.js                | Front-end web app — displays real-time vote results         |

---

## Technology Stack

| Category              | Technology                                  |
|-----------------------|---------------------------------------------|
| Cloud Provider        | AWS (EC2, VPC, Subnets, Security Groups)    |
| Infrastructure as Code| Terraform                                   |
| Configuration Mgmt    | Ansible + Dynamic EC2 Inventory             |
| Container Runtime     | containerd                                  |
| Container Images      | Docker (multi-stage builds)                 |
| Container Registry    | Docker Hub                                  |
| Orchestration         | Kubernetes (kubeadm — self-managed)         |
| GitOps / CD           | ArgoCD (Helm-deployed)                      |
| CI Pipeline           | GitHub Actions                              |
| Monitoring            | Prometheus + Grafana (kube-prometheus-stack)|
| Local Development     | Docker Compose                              |
| Security Scanning     | Gitleaks, kube-linter                       |

---

## DevOps Implementation

### 1. Infrastructure as Code — Terraform

**Location:** [`terraform/`](./terraform/)

Terraform provisions the complete AWS networking and compute layer from scratch — no manual clicking in the console.

**What is provisioned:**
- **VPC** with DNS support enabled (`10.0.0.0/16`)
- **Public Subnet** with auto-assigned public IPs (`10.0.1.0/24`)
- **Internet Gateway** and **Route Table** wired to the subnet
- **Security Group** with port rules defined precisely per Kubernetes component:
  - `22` — SSH (remote management)
  - `6443` — Kubernetes API Server (public)
  - `2379–2380` — etcd client/peer API (VPC-internal only)
  - `10250` — Kubelet API (VPC-internal only)
  - `30000–32767` — NodePort Services (public)
  - Self-referencing rule for all intra-cluster CNI traffic
- **1 Master node** (t3.small) + **2 Worker nodes** (t3.small) via `count`
- Minimal `cloud-init` that only installs Python 3 — all K8s config is intentionally deferred to Ansible
- **Outputs** expose the SSH command, public IPs, and Ansible inventory verification command for immediate use after `apply`

**Key decisions:**
- Separation of concerns: Terraform owns infrastructure, Ansible owns configuration. No overlap.
- `gp3` EBS volumes for better baseline performance at the same cost as `gp2`.

---

### 2. Configuration Management — Ansible

**Location:** [`ansible/`](./ansible/)

Ansible fully automates Kubernetes cluster bootstrap from bare EC2 instances to a running, production-ready cluster — no manual SSH steps required.

**Dynamic Inventory:** Uses the `amazon.aws.aws_ec2` plugin to auto-discover nodes by their EC2 `Role` tag (`master`/`worker`), eliminating the need for any static host files. Hosts are automatically grouped as `tag_Role_master` and `tag_Role_worker`.

**Playbook execution order (`site.yml`):**

| Play | Target                 | Role               | Action                                                    |
|------|------------------------|--------------------|-----------------------------------------------------------|
| 1    | All nodes              | `common`           | Install containerd, kubeadm, kubelet, kubectl; sysctl tuning; swap disabled |
| 2    | Master                 | `kubernetes_master`| `kubeadm init`, Flannel CNI, capture join command as a fact |
| 3    | Workers                | `kubernetes_worker`| `kubeadm join` using the join command from the master's facts |
| 4    | Master                 | `argocd`           | Install Helm, deploy ArgoCD via Helm chart, apply ArgoCD Application CR |
| 5    | Master                 | `prometheus`       | Deploy `kube-prometheus-stack` via Helm (Prometheus, Grafana, Alertmanager, node-exporter) |

**Performance optimisations in `ansible.cfg`:**
- `forks = 10` for parallel task execution
- `gathering = smart` + `fact_caching` (jsonfile, 24h TTL) to skip redundant fact gathering
- SSH connection multiplexing with `ControlMaster=auto` and `ControlPersist=60s`
- `pipelining = True` to reduce SSH round-trips

---

### 3. Containerisation — Docker

**Location:** [`vote/Dockerfile`](./vote/Dockerfile), [`result/`](./result/), [`worker/`](./worker/)

- **Multi-stage Dockerfiles** — separate `base`, `dev`, and `final` build targets. The production image uses Gunicorn with 4 workers; the dev image uses Flask's built-in server with `watchdog` for hot-reload.
- **Local development** via `docker-compose.yml`: all five services with `healthcheck`-gated `depends_on`, named volumes, and isolated `front-tier` / `back-tier` networks.
- **Seeding** via an optional Compose profile (`--profile seed`) for populating the database without polluting the default service set.
- Images are tagged with the **Git commit SHA** for exact traceability between a running container and its source code.

---

### 4. Kubernetes Manifests

**Location:** [`k8s-specifications/`](./k8s-specifications/)

All nine manifests (Deployments + Services for all five services) follow production security standards:

**Security hardening applied to every workload:**
- `readOnlyRootFilesystem: true` — prevents container filesystem writes
- `runAsNonRoot: true` + explicit `runAsUser` — no root processes
- `emptyDir` volumes mounted at `/tmp` (and `/var/run/postgresql`) to satisfy read-only FS requirements
- PostgreSQL uses an `initContainer` to `chown` the data volume, with a kube-linter suppression annotation explaining the intentional exception

**Resource management on every container:**
- CPU and memory `requests` and `limits` defined — ensures the scheduler has accurate data and prevents noisy-neighbour OOM kills

---

### 5. CI/CD Pipeline — GitHub Actions

**Location:** [`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml)

A three-stage pipeline triggered on pushes to the `dev` branch with **path filtering** — only the changed service is rebuilt:

```
┌─────────────────────┐     ┌───────────────────────┐     ┌────────────────────────┐
│  Job 1              │────▶│  Job 2                │────▶│  Job 3                 │
│  Secret & IaC Scan  │     │  Build & Push Images  │     │  Update K8s Manifests  │
│                     │     │  (matrix: vote,       │     │  (GitOps commit)       │
│  - Gitleaks         │     │   result, worker)     │     │                        │
│  - kube-linter      │     │  - SHA-tagged images  │     │  - sed image tag       │
└─────────────────────┘     └───────────────────────┘     │  - git push to dev     │
                                                          └────────────────────────┘
```

**Key design choices:**
- **Job dependencies** (`needs:`) enforce a strict gate: security scan must pass before any image is built; all images must push successfully before manifests are updated.
- **Matrix strategy** builds the three application services in parallel, reducing total pipeline time.
- **Path filtering** (`dorny/paths-filter`) ensures a change to `vote/` does not trigger a `worker` or `result` rebuild.
- **GitOps manifest update** (Job 3) uses `sed` to write the new SHA-tagged image into the deployment YAML and commits it back to the repo — this is the trigger for ArgoCD to sync.

---

### 6. GitOps — ArgoCD

ArgoCD is deployed via Helm (managed by the `argocd` Ansible role) and configured with an `Application` Custom Resource that watches this repository:

```yaml
source:
  repoURL: 'https://github.com/tasbirul/k8s-voting-app.git'
  targetRevision: HEAD
  path: k8s-specifications

syncPolicy:
  automated:
    prune: true      # Remove resources deleted from Git
    selfHeal: true   # Revert any manual kubectl changes
  syncOptions:
    - CreateNamespace=true
```

This creates a complete **GitOps loop**: a push to `vote/` triggers the CI pipeline → images are built and pushed → the manifest YAML in Git is updated with the new SHA → ArgoCD detects the change and automatically deploys to the cluster. Git is the single source of truth.

---

### 7. Observability — Prometheus & Grafana

The `kube-prometheus-stack` Helm chart is deployed by the `prometheus` Ansible role, giving the cluster a full observability stack out of the box:

- **Prometheus** — scrapes metrics from all Kubernetes components (API server, kubelet, nodes, pods)
- **Grafana** — pre-built dashboards for cluster health, node resource utilisation, and pod-level metrics
- **node-exporter** — host-level CPU, memory, disk, and network metrics from every node
- **kube-state-metrics** — Kubernetes object-level metrics (Deployment replicas, Pod status, etc.)
- **Alertmanager** — alert routing and deduplication

The Grafana admin password is read securely from a git-ignored `ansible/.env` file at playbook runtime — never stored in code or CI secrets.

---

## Getting Started

### Prerequisites

- AWS account with programmatic access (Access Key + Secret Key)
- Terraform ≥ 1.5 installed
- Ansible ≥ 2.14 installed
- `boto3` and `botocore` Python packages (`pip install boto3 botocore`)
- An EC2 SSH key pair created in your target region
- Docker Hub account (for the CI pipeline)

### Step 1 — Provision Infrastructure

```bash
cd terraform/
terraform init
terraform apply
```

Note the outputs — they include the SSH command and the Ansible inventory verification command.

### Step 2 — Install Ansible Dependencies

```bash
cd ansible/
ansible-galaxy collection install -r requirements.yml
```

### Step 3 — Configure Environment

```bash
# Set your AWS credentials
export AWS_ACCESS_KEY_ID=<your-key>
export AWS_SECRET_ACCESS_KEY=<your-secret>
export AWS_DEFAULT_REGION=us-east-1

# Set your Grafana admin password
echo 'GRAFANA_ADMIN_PASSWORD=<your-strong-password>' >> ansible/.env

# Verify Ansible can discover your EC2 instances
ansible-inventory -i inventory/aws_ec2.yml --graph
```

### Step 4 — Bootstrap the Cluster

```bash
cd ansible/
ansible-playbook playbooks/site.yml
```

This single command provisions containerd, bootstraps the cluster with kubeadm, joins worker nodes, deploys ArgoCD, and installs the full monitoring stack.

### Step 5 — Configure CI/CD

Add the following secrets to your GitHub repository (`Settings → Secrets and variables → Actions`):

| Secret            | Value                             |
|-------------------|-----------------------------------|
| `DOCKER_USERNAME` | Your Docker Hub username          |
| `DOCKER_PASSWORD` | Your Docker Hub access token      |

Push a change to any service directory on the `dev` branch to trigger the pipeline.

### Local Development

```bash
# Run all services locally
docker compose up

# Run with seeded vote data
docker compose --profile seed up
```

- Vote UI: http://localhost:8080
- Result UI: http://localhost:8081

---

## Security Highlights

| Area                    | Implementation                                                                 |
|-------------------------|--------------------------------------------------------------------------------|
| Secret detection        | Gitleaks scans full Git history on every CI run                                |
| IaC security scanning   | kube-linter validates all Kubernetes manifests before any image is built       |
| Container hardening     | `readOnlyRootFilesystem`, `runAsNonRoot`, no privileged containers             |
| Least-privilege ports   | etcd and Kubelet API ports scoped to VPC CIDR only — not exposed to the internet |
| Sensitive config        | Grafana password sourced from a git-ignored `.env` file — never in plaintext  |
| Image traceability      | Every image tagged with its exact Git commit SHA                               |
| GitOps self-healing     | ArgoCD `selfHeal: true` prevents config drift from manual cluster changes      |

---



## Credits
The initial application source code for this project was forked from the official Docker Samples repository: [dockersamples/example-voting-app](https://github.com/dockersamples/example-voting-app).