# Multi-Cloud Kubernetes Deployment

This project demonstrates how to deploy the same application across multiple cloud providers (AWS EKS and Azure AKS) using infrastructure as code with Terraform and Kubernetes.

## Directory Structure

```
workspace/
├── eks/                  # AWS EKS deployment
│   ├── terraform/        # Terraform files for EKS
│   ├── helm-charts/      # Helm charts for application deployment on EKS
│   └── k8s-manifests/    # Kubernetes manifests for EKS
│
├── aks/                  # Azure AKS deployment
│   ├── terraform/        # Terraform files for AKS
│   └── helm-charts/      # Helm charts for application deployment on AKS
│
└── .github/              # GitHub Actions workflows
    ├── workflows/
    │   ├── eks-pipeline.yml  # Pipeline for EKS deployment
    │   └── aks-pipeline.yml  # Pipeline for AKS deployment
    └── README.md         # CI/CD documentation
```

## CI/CD Pipelines

We have implemented path-based CI/CD pipelines using GitHub Actions:

1. Changes to files in the `eks/` directory trigger the EKS pipeline
2. Changes to files in the `aks/` directory trigger the AKS pipeline

This allows for independent deployment to each cloud provider based on the changes made.

## Prerequisites

### For AWS EKS
- AWS account with appropriate permissions
- AWS CLI configured
- Terraform 1.0.0+
- kubectl
- Helm 3.0.0+

### For Azure AKS
- Azure subscription
- Azure CLI configured
- Terraform 1.0.0+
- kubectl
- Helm 3.0.0+

## Getting Started

1. Clone this repository
2. Set up the required secrets in your GitHub repository:
   - For EKS: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
   - For AKS: `AZURE_CREDENTIALS`
3. Push changes to the respective directories to trigger the appropriate pipeline

## Manual Deployment

### EKS Deployment
```bash
cd eks/terraform
terraform init
terraform apply
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1
cd ../helm-charts
helm upgrade --install myapp ./application
```

### AKS Deployment
```bash
cd aks/terraform
terraform init
terraform apply
az aks get-credentials --resource-group aks-resource-group --name my-aks-cluster
cd ../helm-charts
helm upgrade --install myapp ./application
```

## Migration Between Clouds

For guidance on migrating from EKS to AKS, see the [MIGRATION_TO_AKS.md](eks/MIGRATION_TO_AKS.md) document.

## Cleanup

To avoid incurring charges, remember to destroy resources when not in use:

```bash
# For EKS
cd eks/terraform
terraform destroy

# For AKS
cd aks/terraform
terraform destroy
```