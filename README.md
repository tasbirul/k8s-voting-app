# Example Voting App

A simple distributed application running across multiple Docker containers.

## Getting started

Download [Docker Desktop](https://www.docker.com/products/docker-desktop) for Mac or Windows. [Docker Compose](https://docs.docker.com/compose) will be automatically installed. On Linux, make sure you have the latest version of [Compose](https://docs.docker.com/compose/install/).

This solution uses Python, Node.js, .NET, with Redis for messaging and Postgres for storage.

Run in this directory to build and run the app:

```shell
docker compose up
```

The `vote` app will be running at [http://localhost:8080](http://localhost:8080), and the `results` will be at [http://localhost:8081](http://localhost:8081).

Alternately, if you want to run it on a [Docker Swarm](https://docs.docker.com/engine/swarm/), first make sure you have a swarm. If you don't, run:

```shell
docker swarm init
```

Once you have your swarm, in this directory run:

```shell
docker stack deploy --compose-file docker-stack.yml vote
```



### 1. Provision Infrastructure

Navigate to the `terraform` directory, initialize the backend, and apply the plan:

```bash
cd terraform
terraform init
terraform apply
```

> [!TIP]
> This will create 1 Master and 2 Worker nodes (`t3.small`). You can customize the region and instance types in `variables.tf`.

Take note of the `master_public_ip` from the Terraform output.

### 2. Configure the Cluster

Navigate to the `ansible` directory and set up the environment:

#### Install Requirements
Install the required Ansible collections (AWS and General utilities):
```bash
cd ../ansible
ansible-galaxy collection install -r requirements.yml
```

#### Set Up SSH Key
Ensure your AWS PEM key (`aws-vm-ssh-key.pem`) is moved to `~/.ssh/` and has the correct permissions:
```bash
chmod 400 ~/Documents/aws-vm-ssh-key.pem
```

#### Run the Playbook
Execute the orchestration playbook. The dynamic inventory will automatically find your instances using the `Project: kubeadm` tag.

```bash
ansible-playbook playbooks/site.yml
```

---
## Architecture

![Architecture diagram](architecture.excalidraw.png)

* A front-end web app in [Python](/vote) which lets you vote between two options
* A [Redis](https://hub.docker.com/_/redis/) which collects new votes
* A [.NET](/worker/) worker which consumes votes and stores them in…
* A [Postgres](https://hub.docker.com/_/postgres/) database backed by a Docker volume
* A [Node.js](/result) web app which shows the results of the voting in real time

## Notes

The voting application only accepts one vote per client browser. It does not register additional votes if a vote has already been submitted from a client.

This isn't an example of a properly architected perfectly designed distributed app... it's just a simple
example of the various types of pieces and languages you might see (queues, persistent data, etc), and how to
deal with them in Docker at a basic level.
