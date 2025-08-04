# EKS Infrastructure Pipeline

This project provides infrastructure as code and CI/CD pipelines for deploying applications on Amazon EKS (Elastic Kubernetes Service).

## Features

- **EKS Cluster** with managed node groups
- **RDS PostgreSQL** database
- **ElastiCache Redis** for caching
- **ECR** for container images
- **AWS Secrets Manager** integration with auto-sync
- **GitHub Actions** CI/CD pipelines
- **Terraform** infrastructure as code

## Quick Start

1. **Configure AWS credentials** in GitHub Secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **Run Infrastructure Pipeline**:
   - Go to GitHub Actions → "EKS Infrastructure Pipeline" → Run workflow

3. **Run Deployment Pipeline**:
   - Go to GitHub Actions → "EKS Deployment Pipeline" → Run workflow

## Directory Structure

```
eks/
├── terraform/           # Infrastructure as code
├── app/                 # Application source code
├── helm-charts/         # Kubernetes deployment charts
└── kubernetes/          # Additional K8s manifests
```

## Pipelines

- **EKS Infrastructure Pipeline** - Creates AWS resources
- **EKS Deployment Pipeline** - Deploys application to EKS

## Access Your Application

After deployment, your application will be accessible via the LoadBalancer URL provided in the pipeline output.