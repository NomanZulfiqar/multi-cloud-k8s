# EKS Application Deployment with Database (Cost-Optimized)

This project provides infrastructure as code to deploy a full-fledged application with a database on Amazon EKS (Elastic Kubernetes Service).

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (v1.0.0+)
- kubectl installed
- Helm installed (v3.0.0+)
- Docker (if building your own application images)

## Directory Structure

```
eks/
├── terraform/           # Terraform files for EKS cluster setup
├── helm-charts/         # Helm chart values for deployments
│   ├── database/        # Database Helm chart values
│   └── application/     # Application Helm chart values
├── k8s-manifests/       # Kubernetes manifests (if not using Helm)
└── deploy.sh            # Deployment script
```

## Deployment Steps

1. **Customize Configuration**:
   - Update `terraform/main.tf` with your preferred AWS region and cluster configuration
   - Update `helm-charts/database/postgres-values.yaml` with secure passwords
   - Update `helm-charts/application/values.yaml` with your application details

2. **Deploy the Infrastructure**:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

3. **Access Your Application**:
   After deployment, your application will be accessible via the ALB (Application Load Balancer) created by the AWS Load Balancer Controller.

## Database Connection

Your application connects to the Amazon RDS PostgreSQL database using these environment variables:
- `DB_HOST`: RDS endpoint (automatically configured)
- `DB_PORT`: 5432
- `DB_NAME`: app_database
- `DB_USER`: app_user
- `DB_PASSWORD`: app_password (use AWS Secrets Manager in production)

## Customization

- **Database**: You can switch to a different database by using a different Helm chart from Bitnami or other providers
- **Application**: Create your own Helm chart or use Kubernetes manifests in the `k8s-manifests` directory

## Cost Considerations

This setup has been optimized for minimal cost, but be aware of the following:

- EKS control plane costs $0.10 per hour (~$73 per month) - this is unavoidable with EKS
- EC2 instances use t3.micro Spot instances to minimize costs
- RDS uses db.t3.micro instance which is free tier eligible (for 12 months)
- All other resources are minimized

**Free Tier Notes**:
- The RDS instance is free tier eligible (for 12 months)
- The EKS control plane is NOT free tier eligible
- The EC2 instances for EKS nodes are NOT free tier eligible

**Important:** To avoid unexpected charges, make sure to delete all resources when you're done.

## Cleanup

To delete all resources and avoid ongoing charges:

```bash
cd terraform
terraform destroy -auto-approve
```

Verify in the AWS Console that all resources have been properly deleted.