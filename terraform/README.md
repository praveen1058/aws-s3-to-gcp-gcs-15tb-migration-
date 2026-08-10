# Terraform Infrastructure

This directory contains the infrastructure-as-code required to support the AWS S3 → Google Cloud Storage migration.

## Responsibilities

Terraform manages:

* AWS migration IAM permissions
* GCP destination bucket
* Bucket security configuration
* IAM configuration
* Resource labels/tags
* Infrastructure outputs

Terraform does **not** transfer the 15 TB dataset.

Data transfer is handled separately by Google Cloud Storage Transfer Service.

---

## Directory Structure

```text
terraform/
├── aws/
│   ├── provider.tf
│   ├── variables.tf
│   ├── iam.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
├── gcp/
│   ├── provider.tf
│   ├── variables.tf
│   ├── storage.tf
│   ├── iam.tf
│   ├── outputs.tf
│   └── terraform.tfvars.example
│
└── modules/
```

---

## Design Principles

### Least Privilege

The AWS migration identity is granted only the permissions required to list and read source S3 objects.

### No Credentials in Git

Production credentials and Terraform state are never committed to the repository.

### Infrastructure as Code

Cloud resources are managed declaratively through Terraform rather than manually created through cloud consoles.

### Separation of Concerns

Terraform provisions infrastructure.

Storage Transfer Service performs the data movement.

Validation scripts verify the result.

---

## Terraform Workflow

```bash
terraform fmt -recursive
terraform init
terraform validate
terraform plan
terraform apply
```

Production changes should always be reviewed through `terraform plan` before being applied.

---

## Production Safety

Before applying Terraform:

1. Review the plan.
2. Verify target account/project.
3. Verify bucket names.
4. Verify IAM permissions.
5. Confirm no destructive changes.
6. Use remote state with locking for real production environments.

---

## State Management

For an actual production deployment, Terraform state should be stored in a secured remote backend with appropriate access controls and state locking.

Local state is used only for demonstration purposes in this repository.

---

## Security

Never commit:

* AWS access keys
* GCP service-account keys
* Terraform state
* Production credentials
* Production secrets
* Customer data

Use cloud-native identity mechanisms, CI/CD workload identity, or an approved secrets-management solution.
