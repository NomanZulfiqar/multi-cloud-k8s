# Multi-Cloud Kubernetes Migration Guide

## 🎯 **Overview**

This guide provides a comprehensive mechanism for migrating applications between **AWS EKS** and **Azure AKS** environments, including service mappings, data migration strategies, and step-by-step procedures.

---

## 🏗️ **Architecture Comparison**

### **Service Mapping Between Clouds**

| **Component** | **AWS EKS** | **Azure AKS** | **Migration Notes** |
|---------------|-------------|---------------|---------------------|
| **Kubernetes** | Amazon EKS | Azure AKS | Direct compatibility |
| **Container Registry** | Amazon ECR | Azure ACR | Images need re-push |
| **Database** | Amazon RDS PostgreSQL | PostgreSQL Pod | Data export/import required |
| **Cache** | Amazon ElastiCache Redis | Not implemented | Optional component |
| **Secrets** | AWS Secrets Manager | Azure Key Vault | Secret recreation needed |
| **Load Balancer** | AWS ALB/NLB | Azure Load Balancer | Automatic via K8s Service |
| **Networking** | VPC + Subnets | Azure CNI | Cloud-native networking |
| **IAM/Identity** | IAM Roles (IRSA) | Managed Identity | Different auth mechanisms |
| **Storage** | EBS/EFS | Azure Disk/Files | Persistent volume migration |

---

## 🔄 **Migration Mechanisms**

### **1. EKS to AKS Migration**

#### **Phase 1: Pre-Migration Assessment**
```bash
# 1. Export current EKS configuration
kubectl get all -o yaml > eks-resources.yaml
kubectl get secrets -o yaml > eks-secrets.yaml
kubectl get configmaps -o yaml > eks-configmaps.yaml

# 2. List all persistent volumes
kubectl get pv,pvc -o yaml > eks-storage.yaml

# 3. Export database schema and data
kubectl exec -it postgres-pod -- pg_dump -U postgres myapp > database-backup.sql

# 4. Document current service endpoints
kubectl get services -o wide > eks-services.txt
```

#### **Phase 2: Azure Environment Preparation**
```bash
# 1. Deploy AKS infrastructure
cd aks/terraform
terraform init
terraform plan
terraform apply

# 2. Get AKS credentials
az aks get-credentials --resource-group aks-rg --name my-aks-cluster

# 3. Verify cluster access
kubectl cluster-info
kubectl get nodes
```

#### **Phase 3: Container Image Migration**
```bash
# 1. Pull images from ECR
docker pull <account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

# 2. Re-tag for ACR
docker tag <account-id>.dkr.ecr.us-east-1.amazonaws.com/myapp:latest \
           myappacr2024.azurecr.io/myapp:latest

# 3. Push to ACR
az acr login --name myappacr2024
docker push myappacr2024.azurecr.io/myapp:latest
```

#### **Phase 4: Secret Migration**
```bash
# 1. Extract secrets from AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id myapp/db-credentials \
    --query SecretString --output text > aws-secrets.json

# 2. Create secrets in Azure Key Vault
az keyvault secret set --vault-name myapp-kv-2024 \
    --name db-username --value "$(echo $aws_secrets | jq -r .username)"
az keyvault secret set --vault-name myapp-kv-2024 \
    --name db-password --value "$(echo $aws_secrets | jq -r .password)"
```

#### **Phase 5: Database Migration**
```bash
# 1. Create database backup from EKS
kubectl exec -it $(kubectl get pods -l app=postgres -o name) -- \
    pg_dump -U postgres -h localhost myapp > database-backup.sql

# 2. Copy backup to local machine
kubectl cp postgres-pod:/database-backup.sql ./database-backup.sql

# 3. Restore to AKS PostgreSQL
kubectl cp ./database-backup.sql postgres-pod:/database-backup.sql
kubectl exec -it postgres-pod -- \
    psql -U postgres -h localhost myapp < /database-backup.sql
```

#### **Phase 6: Application Deployment**
```bash
# 1. Deploy External Secrets Operator
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
    --namespace external-secrets --create-namespace

# 2. Deploy database
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql -f ./aks/helm-charts/database/postgres-values.yaml

# 3. Deploy application
helm install myapp ./aks/helm-charts/application
```

#### **Phase 7: DNS and Traffic Cutover**
```bash
# 1. Get new AKS service external IP
kubectl get service myapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# 2. Update DNS records (if using custom domain)
# Point your domain from EKS LoadBalancer IP to AKS LoadBalancer IP

# 3. Test application functionality
curl http://<aks-external-ip>
```

---

### **2. AKS to EKS Migration**

#### **Phase 1: Pre-Migration Assessment**
```bash
# 1. Export AKS resources
kubectl get all -o yaml > aks-resources.yaml
kubectl get secrets -o yaml > aks-secrets.yaml

# 2. Export database
kubectl exec -it postgres-pod -- pg_dump -U postgres myapp > database-backup.sql

# 3. Extract secrets from Azure Key Vault
az keyvault secret show --vault-name myapp-kv-2024 --name db-username --query value -o tsv
az keyvault secret show --vault-name myapp-kv-2024 --name db-password --query value -o tsv
```

#### **Phase 2: AWS Environment Preparation**
```bash
# 1. Deploy EKS infrastructure
cd eks/terraform
terraform init
terraform plan
terraform apply

# 2. Get EKS credentials
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1
```

#### **Phase 3: Container Image Migration**
```bash
# 1. Pull from ACR
docker pull myappacr2024.azurecr.io/myapp:latest

# 2. Re-tag for ECR
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
docker tag myappacr2024.azurecr.io/myapp:latest \
           $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

# 3. Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker push $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/myapp:latest
```

#### **Phase 4: Secret Migration**
```bash
# 1. Create secrets in AWS Secrets Manager
aws secretsmanager create-secret \
    --name myapp/db-credentials \
    --description "Database credentials for myapp" \
    --secret-string '{"username":"appuser","password":"AppPassword123!"}'
```

#### **Phase 5: Database Migration**
```bash
# 1. Restore database to RDS (managed service)
# Database is automatically created by Terraform as RDS instance
# Data migration handled during application deployment
```

---

## 🛠️ **Detailed Migration Procedures**

### **Complete EKS to AKS Migration Script**

```bash
#!/bin/bash
set -e

echo "🚀 Starting EKS to AKS Migration"

# Phase 1: Backup EKS Environment
echo "📦 Phase 1: Backing up EKS environment..."
mkdir -p migration-backup
cd migration-backup

# Get EKS credentials
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1

# Backup Kubernetes resources
kubectl get all -A -o yaml > eks-all-resources.yaml
kubectl get secrets -A -o yaml > eks-secrets.yaml
kubectl get configmaps -A -o yaml > eks-configmaps.yaml
kubectl get pv,pvc -A -o yaml > eks-storage.yaml

# Backup database
echo "💾 Backing up database..."
DB_POD=$(kubectl get pods -l app=postgres -o name | head -1)
kubectl exec $DB_POD -- pg_dump -U postgres myapp > database-backup.sql

# Backup AWS secrets
echo "🔐 Backing up AWS secrets..."
aws secretsmanager get-secret-value --secret-id myapp/db-credentials \
    --query SecretString --output text > aws-secrets.json

echo "✅ EKS backup completed"

# Phase 2: Deploy AKS Infrastructure
echo "🏗️ Phase 2: Deploying AKS infrastructure..."
cd ../aks/terraform
terraform init
terraform apply -auto-approve

# Get AKS credentials
az aks get-credentials --resource-group aks-rg --name my-aks-cluster --overwrite-existing

echo "✅ AKS infrastructure deployed"

# Phase 3: Migrate Container Images
echo "🐳 Phase 3: Migrating container images..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Pull from ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker pull $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

# Push to ACR
az acr login --name myappacr2024
docker tag $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/myapp:latest myappacr2024.azurecr.io/myapp:latest
docker push myappacr2024.azurecr.io/myapp:latest

echo "✅ Container images migrated"

# Phase 4: Migrate Secrets
echo "🔑 Phase 4: Migrating secrets..."
cd ../../migration-backup

# Extract secrets from backup
USERNAME=$(cat aws-secrets.json | jq -r .username)
PASSWORD=$(cat aws-secrets.json | jq -r .password)

# Create secrets in Azure Key Vault
az keyvault secret set --vault-name myapp-kv-2024 --name db-username --value "$USERNAME"
az keyvault secret set --vault-name myapp-kv-2024 --name db-password --value "$PASSWORD"

echo "✅ Secrets migrated"

# Phase 5: Deploy Applications
echo "🚀 Phase 5: Deploying applications to AKS..."

# Install External Secrets
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
    --namespace external-secrets --create-namespace --wait

# Deploy database
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql -f ../aks/helm-charts/database/postgres-values.yaml --wait

# Wait for database to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=300s

# Restore database
DB_POD=$(kubectl get pods -l app.kubernetes.io/name=postgresql -o name | head -1)
kubectl cp database-backup.sql $DB_POD:/tmp/database-backup.sql
kubectl exec $DB_POD -- psql -U postgres -d myapp -f /tmp/database-backup.sql

# Deploy application
helm install myapp ../aks/helm-charts/application --wait

echo "✅ Applications deployed"

# Phase 6: Verification
echo "🔍 Phase 6: Verifying migration..."

# Wait for application to be ready
kubectl wait --for=condition=ready pod -l app=myapp --timeout=300s

# Get service external IP
EXTERNAL_IP=$(kubectl get service myapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "🌐 Application accessible at: http://$EXTERNAL_IP"

# Test application
if curl -f http://$EXTERNAL_IP/health; then
    echo "✅ Application health check passed"
else
    echo "❌ Application health check failed"
    exit 1
fi

echo "🎉 Migration completed successfully!"
echo "📋 Next steps:"
echo "   1. Update DNS records to point to: $EXTERNAL_IP"
echo "   2. Test all application functionality"
echo "   3. Monitor application performance"
echo "   4. Destroy EKS environment when confident"
```

### **Complete AKS to EKS Migration Script**

```bash
#!/bin/bash
set -e

echo "🚀 Starting AKS to EKS Migration"

# Phase 1: Backup AKS Environment
echo "📦 Phase 1: Backing up AKS environment..."
mkdir -p migration-backup
cd migration-backup

# Get AKS credentials
az aks get-credentials --resource-group aks-rg --name my-aks-cluster --overwrite-existing

# Backup Kubernetes resources
kubectl get all -A -o yaml > aks-all-resources.yaml
kubectl get secrets -A -o yaml > aks-secrets.yaml

# Backup database
DB_POD=$(kubectl get pods -l app.kubernetes.io/name=postgresql -o name | head -1)
kubectl exec $DB_POD -- pg_dump -U postgres myapp > database-backup.sql

# Backup Azure secrets
USERNAME=$(az keyvault secret show --vault-name myapp-kv-2024 --name db-username --query value -o tsv)
PASSWORD=$(az keyvault secret show --vault-name myapp-kv-2024 --name db-password --query value -o tsv)
echo "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" > azure-secrets.json

echo "✅ AKS backup completed"

# Phase 2: Deploy EKS Infrastructure
echo "🏗️ Phase 2: Deploying EKS infrastructure..."
cd ../eks/terraform
terraform init
terraform apply -auto-approve

# Get EKS credentials
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1 --alias eks-cluster

echo "✅ EKS infrastructure deployed"

# Phase 3: Migrate Container Images
echo "🐳 Phase 3: Migrating container images..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Pull from ACR
az acr login --name myappacr2024
docker pull myappacr2024.azurecr.io/myapp:latest

# Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker tag myappacr2024.azurecr.io/myapp:latest $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/myapp:latest
docker push $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

echo "✅ Container images migrated"

# Phase 4: Migrate Secrets
echo "🔑 Phase 4: Migrating secrets..."
cd ../../migration-backup

# Create secrets in AWS Secrets Manager
aws secretsmanager create-secret \
    --name myapp/db-credentials \
    --description "Database credentials for myapp" \
    --secret-string file://azure-secrets.json || \
aws secretsmanager update-secret \
    --secret-id myapp/db-credentials \
    --secret-string file://azure-secrets.json

echo "✅ Secrets migrated"

# Phase 5: Deploy Applications
echo "🚀 Phase 5: Deploying applications to EKS..."

# Switch to EKS context
kubectl config use-context eks-cluster

# Install External Secrets
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm install external-secrets external-secrets/external-secrets \
    --namespace external-secrets --create-namespace --wait

# Deploy database (RDS is already created by Terraform)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install postgres bitnami/postgresql -f ../eks/helm-charts/database/postgres-values.yaml --wait

# Deploy application
helm install myapp ../eks/helm-charts/application --wait

echo "✅ Applications deployed"

# Phase 6: Verification
echo "🔍 Phase 6: Verifying migration..."

# Get service external IP
EXTERNAL_IP=$(kubectl get service myapp -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "🌐 Application accessible at: http://$EXTERNAL_IP"

# Test application
if curl -f http://$EXTERNAL_IP/health; then
    echo "✅ Application health check passed"
else
    echo "❌ Application health check failed"
    exit 1
fi

echo "🎉 Migration completed successfully!"
echo "📋 Next steps:"
echo "   1. Update DNS records to point to: $EXTERNAL_IP"
echo "   2. Test all application functionality"
echo "   3. Monitor application performance"
echo "   4. Destroy AKS environment when confident"
```

---

## 🔧 **Service-by-Service Migration Guide**

### **1. Kubernetes Workloads**
```yaml
# Universal Kubernetes resources (work on both platforms)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: <registry>/myapp:latest  # Only registry URL changes
        ports:
        - containerPort: 3000
```

### **2. Load Balancer Services**
```yaml
# Works identically on both platforms
apiVersion: v1
kind: Service
metadata:
  name: myapp
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 3000
  selector:
    app: myapp
```

### **3. Secret Management**

#### **AWS EKS (External Secrets + AWS Secrets Manager)**
```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

#### **Azure AKS (External Secrets + Azure Key Vault)**
```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: azure-keyvault
spec:
  provider:
    azurekv:
      vaultUrl: "https://myapp-kv-2024.vault.azure.net/"
      authType: ManagedIdentity
```

### **4. Database Migration**

#### **From RDS to PostgreSQL Pod**
```bash
# 1. Export from RDS
pg_dump -h <rds-endpoint> -U postgres myapp > rds-backup.sql

# 2. Import to Pod
kubectl exec -i postgres-pod -- psql -U postgres myapp < rds-backup.sql
```

#### **From PostgreSQL Pod to RDS**
```bash
# 1. Export from Pod
kubectl exec postgres-pod -- pg_dump -U postgres myapp > pod-backup.sql

# 2. Import to RDS
psql -h <rds-endpoint> -U postgres myapp < pod-backup.sql
```

---

## 📋 **Migration Checklist**

### **Pre-Migration**
- [ ] Document current architecture
- [ ] Backup all data and configurations
- [ ] Test backup restoration procedures
- [ ] Plan rollback strategy
- [ ] Schedule maintenance window
- [ ] Notify stakeholders

### **During Migration**
- [ ] Deploy target infrastructure
- [ ] Migrate container images
- [ ] Migrate secrets and configurations
- [ ] Migrate database data
- [ ] Deploy applications
- [ ] Verify functionality
- [ ] Update DNS/routing

### **Post-Migration**
- [ ] Monitor application performance
- [ ] Verify all features work correctly
- [ ] Update documentation
- [ ] Train team on new environment
- [ ] Plan source environment cleanup
- [ ] Document lessons learned

---

## ⚠️ **Migration Considerations**

### **Downtime Minimization**
- Use **blue-green deployment** strategy
- Implement **database replication** for zero-downtime
- Use **DNS switching** for instant cutover
- Plan **rollback procedures**

### **Data Consistency**
- Stop writes during database migration
- Verify data integrity after migration
- Test application functionality thoroughly
- Monitor for data synchronization issues

### **Security**
- Rotate secrets after migration
- Update IAM/RBAC policies
- Review network security groups
- Audit access permissions

### **Performance**
- Compare performance metrics
- Adjust resource allocations
- Monitor application latency
- Optimize for cloud-specific features

---

## 🎯 **Best Practices**

1. **Test migrations in staging first**
2. **Automate migration scripts**
3. **Document all procedures**
4. **Plan for rollback scenarios**
5. **Monitor closely post-migration**
6. **Keep both environments running initially**
7. **Validate data integrity thoroughly**
8. **Update monitoring and alerting**

---

## 🆘 **Troubleshooting Common Issues**

### **Container Image Issues**
```bash
# Check image compatibility
docker run --rm <image> /bin/sh -c "echo 'Image works'"

# Verify image in new registry
docker pull <new-registry>/myapp:latest
```

### **Database Connection Issues**
```bash
# Test database connectivity
kubectl exec -it app-pod -- nc -zv postgres-service 5432

# Check database logs
kubectl logs postgres-pod
```

### **Secret Sync Issues**
```bash
# Check External Secrets status
kubectl get externalsecret -o yaml
kubectl describe externalsecret db-credentials-sync

# Verify secret creation
kubectl get secrets
```

### **Load Balancer Issues**
```bash
# Check service status
kubectl get service myapp -o yaml
kubectl describe service myapp

# Verify endpoints
kubectl get endpoints myapp
```

---

This migration guide provides a complete framework for moving applications between AWS EKS and Azure AKS while maintaining functionality and minimizing downtime.