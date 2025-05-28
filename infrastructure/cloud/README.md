# Setup cloud node

This document provides instructions for setting up a cloud node using Terraform and installing Docker.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Terraform](https://developer.hashicorp.com/terraform/install)
- A Google Cloud account with billing enabled
- Google Cloud SDK (optional, for managing your Google Cloud resources)

## Setting Up the Cloud Node

### Step 1: Configure Terraform Variables

Add `terraform.tfvars` file to set your Google Cloud project ID, SSH username, instance type, disk size, and paths to your SSH keys. Ensure that the keys exist at the specified paths.

### Step 2: Initialize Terraform

Run the following command to initialize Terraform. This will download the necessary provider plugins:

```bash
terraform init
```

### Step 3: Apply the Configuration

Deploy the resources defined in your Terraform configuration:

```bash
terraform apply
```

### Step 4: Install Docker

Run the following script to install Docker on your cloud node:

```bash
bash docker_install.sh
```

This script will:

- Update the package index
- Install necessary packages
- Add the Docker GPG key and repository
- Install Docker and Docker Compose

## Usage

Once the setup is complete, you can start using the cloud node for your applications. We have dockerize all the tested service and provide the `docker-compose.yml` that you can just use like following

```bash
docker-compose up -d
```

## Cleanup

To destroy the resources created by Terraform, run:

```bash
terraform destroy
```

You will be prompted to confirm the action. Type `yes` to proceed.
