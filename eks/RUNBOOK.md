# EKS Application Deployment Runbook

This runbook provides step-by-step instructions for deploying a full-fledged application with an RDS database on Amazon EKS using AWS Load Balancer Controller.

## Prerequisites

- AWS CLI installed and configured with appropriate permissions
- Terraform installed (v1.0.0+)
- kubectl installed
- Helm installed (v3.0.0+)
- Git installed

## Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/eks-app-deployment.git
cd eks-app-deployment
```

## Step 2: Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init -upgrade

# Apply Terraform configuration
terraform apply

# When prompted, type "yes" to confirm
```

This will create:
- VPC with public subnets
- EKS cluster with version 1.32
- RDS PostgreSQL database
- ElastiCache Redis cluster for caching
- IAM roles and policies for AWS Load Balancer Controller

## Step 3: Configure kubectl

```bash
aws eks update-kubeconfig --region $(terraform output -raw region) --name $(terraform output -raw cluster_name)
```

## Step 4: Set Up AWS Load Balancer Controller

```bash
# Create service account
kubectl create serviceaccount -n kube-system aws-load-balancer-controller

# Annotate service account with IAM role
kubectl annotate serviceaccount -n kube-system aws-load-balancer-controller \
  eks.amazonaws.com/role-arn=$(terraform output -raw aws_load_balancer_controller_role_arn)

# Install AWS Load Balancer Controller using Helm
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --set clusterName=$(terraform output -raw cluster_name) \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --namespace kube-system

# Wait for controller to be ready
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system
```

## Step 5: Update Application Configuration

Ensure your `helm-charts/application/values.yaml` has the following settings:

```yaml
service:
  type: LoadBalancer
  port: 80
  targetPort: 80
```

Update the database and Redis connection details in `values.yaml`:

```bash
# Get RDS endpoint
RDS_ENDPOINT=$(cd terraform && terraform output -raw rds_endpoint)

# Get Redis endpoint
REDIS_ENDPOINT=$(cd terraform && terraform output -raw elasticache_endpoint)

# Update the DB_HOST value in values.yaml
sed -i "s|value: \".*:5432\"|value: \"$RDS_ENDPOINT\"|" helm-charts/application/values.yaml

# Update the REDIS_HOST value in values.yaml
sed -i "s|\${REDIS_ENDPOINT}|$REDIS_ENDPOINT|" helm-charts/application/values.yaml
```

## Step 6: Deploy the Application

```bash
cd ..  # Return to project root if needed

# For new installation
helm install sample-app ./helm-charts/application -f helm-charts/application/values.yaml

# For updating existing installation
helm upgrade sample-app ./helm-charts/application -f helm-charts/application/values.yaml
```

## Step 7: Verify Deployment

```bash
# Check if pods are running
kubectl get pods

# Check if service is created with LoadBalancer
kubectl get services

# Wait for the load balancer to be provisioned
kubectl get service sample-app -o wide

# Get the load balancer URL
echo "Application URL: http://$(kubectl get service sample-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

## Step 8: Access Your Application

Open a web browser and navigate to the URL from Step 7.

## Database Connection Details

Your application connects to the RDS PostgreSQL database using these environment variables:
- DB_HOST: $(cd terraform && terraform output -raw rds_endpoint)
- DB_PORT: 5432
- DB_NAME: app_database
- DB_USER: app_user
- DB_PASSWORD: app_password (use AWS Secrets Manager in production)

## Redis Cache Details

Your application connects to the ElastiCache Redis cluster using these environment variables:
- REDIS_HOST: $(cd terraform && terraform output -raw elasticache_endpoint)
- REDIS_PORT: 6379

## Cleanup

When you're done with the deployment, you can clean up all resources:

```bash
# Delete the application
helm uninstall sample-app

# Delete AWS resources
cd terraform
terraform destroy

# When prompted, type "yes" to confirm
```

## Troubleshooting

If you encounter any issues during deployment, here are some common problems and their solutions:

### AWS Load Balancer Controller Issues

If you encounter webhook errors when deploying services or ingresses:

```bash
# Delete webhook configurations
kubectl delete mutatingwebhookconfiguration aws-load-balancer-webhook
kubectl delete validatingwebhookconfiguration aws-load-balancer-webhook

# Restart the controller
kubectl rollout restart deployment aws-load-balancer-controller -n kube-system
kubectl wait --for=condition=available --timeout=300s deployment/aws-load-balancer-controller -n kube-system
```

### Pod Scheduling Issues

If pods are stuck in "Pending" state:

```bash
kubectl describe pod <pod-name>
```

Common issues include:
- Insufficient resources (CPU/memory)
- Node capacity limits (t3.small instances can run more pods than t3.micro)
- Taints/tolerations preventing scheduling

### LoadBalancer Service Issues

If the LoadBalancer service doesn't get an external IP:

```bash
# Check service status
kubectl describe service sample-app

# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

Check for:
- AWS Load Balancer Controller logs for errors
- Security group configurations (ensure ports are open)
- VPC subnet configurations (ensure public subnets have the proper tags)
- IAM permissions (ensure the controller has the necessary permissions)