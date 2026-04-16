# Kubernetes Voting App - End-to-End DevOps Project

This repository serves as a comprehensive demonstration of modern DevOps practices, taking a distributed microservices application and deploying it via an automated, highly available, and observable pipeline. 

The project encompasses Infrastructure as Code (IaC), Configuration Management, Containerization, Continuous Integration/Continuous Deployment (CI/CD), and Cluster Monitoring.

## Project Overview and Purpose

The primary purpose of this project is to showcase standard DevOps methodologies and tools by deploying a multi-tier web application (the classic Docker Voting App) on a self-managed, cloud-native infrastructure. This project demonstrates the ability to architect, provision, configure, and automate the deployment lifecycle from code commit to production deployment.

## Architecture and Key Components

The application is a distributed voting system consisting of the following microservices:
* **Vote App** (Python): Frontend web interface allowing users to vote between two options.
* **Result App** (Node.js): Frontend web interface showing real-time voting results.
* **Worker** (.NET): Background service that consumes votes from Redis and stores them in PostgreSQL.
* **Redis** (In-Memory Data Store): Collects and queues incoming votes securely and quickly.
* **PostgreSQL** (Database): Persistent storage backed by Kubernetes volumes.

![Architecture diagram](architecture.excalidraw.png)

## Tech Stack Used

- **Cloud Provider:** AWS (EC2, VPC, Security Groups, Networking)
- **Infrastructure as Code (IaC):** Terraform
- **Configuration Management:** Ansible
- **Containerization:** Docker
- **Orchestration:** Kubernetes (Self-managed cluster via `kubeadm`)
- **CI/CD Pipeline:** GitHub Actions
- **Monitoring & Observability:** Prometheus & Grafana (deployed via Ansible roles)
- **GitOps:** ArgoCD (provisioned via Ansible)
- **Security:** Gitleaks, Kube-linter

## Deployment Workflow

1. **Infrastructure Provisioning**: Terraform defines and provisions the AWS VPC, Internet Gateway, Subnets, Security Groups, and EC2 instances (1 Master node, 2 Worker nodes).
2. **Configuration & Orchestration Setup**: Ansible uses dynamic inventory to target the AWS instances. It handles OS patching, dependency installation, and executing `kubeadm` to bootstrap the Kubernetes cluster.
3. **Application Deployment**: The `.github/workflows/cd.yaml` pipeline connects to the master node and deploys the Kubernetes Specification manifests (Services and Deployments for all application components).

## CI/CD Pipeline

The CI/CD workflow is fully automated through **GitHub Actions**:

### Continuous Integration (CI)
- **Security & Linting**: Pull requests and commits trigger secret scanning (Gitleaks) to prevent sensitive data leaks, and IaC scanning (Kube-linter) to ensure Kubernetes manifests follow best practices.
- **Build & Push**: Dynamically detects changes for each microservice (`vote`, `result`, `worker`). It builds the respective Docker image and pushes it to Docker Hub using secure credentials.
- **GitOps Manifest Update**: A script securely updates the image tags in the `k8s-specifications/*.yaml` files and pushes the modified code back to the repository (`dev` branch) with the latest SHA.

### Continuous Deployment & GitOps

- **GitOps approach (Active):** The cluster is pre-provisioned via Ansible with **ArgoCD**. As an in-cluster controller, ArgoCD operates on a pull-based model. It continuously monitors the repository's `k8s-specifications` for changes made during the CI process and automatically synchronizes the cluster state with the Git declarations. This ensures a declarative, secure, and single-source-of-truth deployment lifecycle.

## Monitoring and Observability Setup

The compute infrastructure and Kubernetes components are configured to emit telemetry data using Ansible roles. 
- **Prometheus** targets cluster node metrics, pod metrics, and API health. 
- **Grafana** (included in the Prometheus stack) visualizes these metrics to track CPU/Memory utilization, network IOps, and container restarts.
- **ArgoCD** is established as a role to manage continuous GitOps syncing of cluster capabilities.

## Project Structure

```bash
k8s-voting-app/
├── ansible/               # Configuration management (Kubeadm setup, ArgoCD, Prometheus)
├── terraform/             # AWS Infrastructure as code (VPC, EC2, SG, Routing)
├── k8s-specifications/    # Kubernetes YAML manifests for Deployments and Services
├── .github/workflows/     # CI/CD pipelines (ci.yaml, cd.yaml)
├── vote/                  # Python Voting Frontend microservice code + Dockerfile
├── result/                # Node.js Result Frontend microservice code + Dockerfile
├── worker/                # .NET Worker backend microservice code + Dockerfile
└── ...
```

## Skills Demonstrated

- **Infrastructure as Code (IaC):** Designing scalable, repeatable AWS architectures using Terraform.
- **Configuration Management:** Automating complex, multi-node setups (`kubeadm`) and securing components with Ansible.
- **Container Orchestration:** Deploying and managing Pods, Deployments, and Services in Kubernetes.
- **DevSecOps Automation:** Building robust GitHub Actions CI/CD workflows, integrating matrix builds, path filtering, automated Docker deployments, static manifest linting, and secret scanning.
- **GitOps Principles:** Updating git manifests dynamically during the CI process.
- **System Administration:** Linux troubleshooting, SSH securely structured automation, networking protocols, and port access controls.

## How to Run the Project

### 1. Provision Infrastructure
Navigate to the `terraform` directory, initialize the backend, and apply the plan:
```bash
cd terraform
terraform init
terraform apply --auto-approve
```
*Note the `master_public_ip` generated after completion.*

### 2. Configure the Cluster (Kubernetes Setup)
Install requirements configured for dynamic AWS inventory and execute the playbook:
```bash
cd ../ansible
ansible-galaxy collection install -r requirements.yml
chmod 400 ~/.ssh/aws-vm-ssh-key.pem 
ansible-playbook playbooks/site.yml
```

### 3. Deploy the Application
Trigger the GitHub Actions `CD Pipeline` manually or automatically, which connects to the generated cluster Master Node and runs:
```bash
kubectl apply -f k8s-specifications/
```
The applications will be exposed via standard NodePorts inside the cluster.

## Future Improvements

- Fully transition the CD Pipeline sequence to natively sink with **ArgoCD** for pure GitOps pull-based deployments.
- Implement highly available Etcd nodes and a backup mechanism (like Velero).
- Introduce **Ingress Controllers** (NGINX/Traefik) + SSL/TLS termination with cert-manager instead of exposing services via NodePort.
- Standardize the Kubernetes manifests using **Helm Charts** to quickly iterate configuration environment parameters (Dev/Staging/Prod).
- Move the state file of Terraform into an S3 backend encrypted securely with DynamoDB state locking.

## Credits

The initial application source code for this project was forked from the official Docker Samples repository: [dockersamples/example-voting-app](https://github.com/dockersamples/example-voting-app).

