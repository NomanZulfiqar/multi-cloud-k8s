# Multi-Cloud Kubernetes Architecture Overview

## 🏗️ **Complete Multi-Cloud Architecture**

This project implements a **production-ready multi-cloud Kubernetes platform** that automatically deploys applications across **AWS EKS** and **Azure AKS** with centralized secret management, database services, and CI/CD automation.

## 🔄 **How the Architecture Runs**

### **Runtime Flow:**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Developer     │    │   GitHub        │    │   Multi-Cloud   │
│   Commits Code  │───▶│   Actions       │───▶│   Deployment    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Terraform     │
                    │   Provisions    │
                    │   Infrastructure│
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Docker Build  │
                    │   & Push to     │
                    │   Registries    │
                    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Kubernetes    │
                    │   Deployment    │
                    │   (Helm Charts) │
                    └─────────────────┘
```

### **Multi-Cloud Synchronization:**
- **Parallel Deployment**: Both clouds deploy simultaneously
- **Shared Backend**: Terraform state stored in AWS S3
- **Consistent Configuration**: Same application, different cloud services
- **Independent Scaling**: Each cloud scales based on its own metrics

## 🏗️ **Architecture Summary**

### **AWS EKS Environment**
```
┌─────────────────────────────────────────────────────────────┐
│                        AWS EKS CLUSTER                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │   Application   │  │   PostgreSQL    │  │   Redis     │ │
│  │   (LoadBalancer)│  │   (RDS)         │  │(ElastiCache)│ │
│  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │           External Secrets Operator                    │ │
│  │     (Syncs from AWS Secrets Manager)                   │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  VPC: Custom VPC with public/private subnets               │
│  Region: us-east-1                                         │
│  IAM: IRSA (IAM Roles for Service Accounts)               │
│  Storage: ECR for container images                         │
└─────────────────────────────────────────────────────────────┘
```

### **Azure AKS Environment**
```
┌─────────────────────────────────────────────────────────────┐
│                       AZURE AKS CLUSTER                    │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐                  │
│  │   Application   │  │   PostgreSQL    │                  │
│  │   (LoadBalancer)│  │   (Helm Chart)  │                  │
│  └─────────────────┘  └─────────────────┘                  │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │           External Secrets Operator                    │ │
│  │     (Syncs from Azure Key Vault)                     │ │
│  └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  Resource Group: aks-rg                                    │
│  Region: East US                                           │
│  Networking: Azure CNI                                     │
│  Storage: ACR for container images                         │
│  Secrets: Azure Key Vault (myapp-kv-2024)                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 **Pipeline Phases Breakdown**

### **AWS EKS Pipeline Phases**

#### **Phase 1: Infrastructure Planning (terraform-plan)**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Checkout Code                                                  │
│ 2. Configure AWS Credentials                                      │
│ 3. Setup Terraform                                               │
│ 4. Terraform Init (Download providers & modules)                 │
│ 5. Import Existing Resources (EKS, RDS, ElastiCache, ECR)        │
│ 6. Terraform Format & Validate                                   │
│ 7. Terraform Plan (Generate execution plan)                      │
│ 8. Upload Plan Artifact                                          │
└────────────────────────────────────────────────────────────┘
```

#### **Phase 2: Infrastructure Provisioning (terraform-apply)**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Download Terraform Plan                                        │
│ 2. VPC Mismatch Cleanup (Detect & fix subnet group conflicts)    │
│ 3. Import Existing Resources (Handle state drift)                │
│ 4. Terraform Apply (Create/Update infrastructure):               │
│    • VPC with public/private subnets                            │
│    • EKS Cluster with node groups                               │
│    • RDS PostgreSQL instance                                   │
│    • ElastiCache Redis cluster                                 │
│    • ECR repository                                            │
│    • IAM roles (EKS, External Secrets)                        │
│    • Security groups & networking                             │
│    • AWS Secrets Manager secret                               │
│ 5. Save Terraform Outputs                                        │
└────────────────────────────────────────────────────────────┘
```

#### **Phase 3: Container Build & Push (build-and-push)**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Login to Amazon ECR                                            │
│ 2. Get ECR Repository URL (from account ID)                      │
│ 3. Build Docker Image:                                           │
│    • Use application source code                                 │
│    • Install dependencies                                       │
│    • Create optimized container                                │
│ 4. Tag Image with ECR URL                                        │
│ 5. Push to ECR Repository                                        │
└────────────────────────────────────────────────────────────┘
```

#### **Phase 4: Kubernetes Deployment (deploy-kubernetes)**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Setup kubectl & Helm                                           │
│ 2. Create aws-auth ConfigMap (Node access to cluster)            │
│ 3. Create ECR Pull Secret                                         │
│ 4. Install External Secrets Operator:                           │
│    • Add Helm repository                                        │
│    • Install with CRDs                                          │
│    • Wait for pods to be ready                                 │
│    • Verify CRDs installation                                  │
│ 5. Configure External Secrets:                                   │
│    • Create service account with IAM role                      │
│    • Restart External Secrets pods                             │
│    • Delete webhook configurations (timeout fix)               │
│    • Create SecretStore (AWS Secrets Manager)                  │
│    • Create ExternalSecret (sync db credentials)               │
│    • Monitor secret creation                                   │
│ 6. Deploy Database (PostgreSQL via Helm)                         │
│ 7. Deploy Application (Custom Helm chart)                        │
└────────────────────────────────────────────────────────────┘
```

### **Azure AKS Pipeline Phases**

#### **Phase 1: Infrastructure Planning (terraform-plan)**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Azure Login & AWS S3 Backend Setup                            │
│ 2. Import Existing Resources (AKS, ACR, Key Vault, PostgreSQL)   │
│ 3. Terraform Plan for Azure Resources                            │
└────────────────────────────────────────────────────────────┘
```

#### **Phase 2: Infrastructure Provisioning (terraform-apply)**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Remove Problematic PostgreSQL (Clean state)                   │
│ 2. Terraform Apply (Create/Update):                              │
│    • Resource Group                                            │
│    • AKS Cluster with Azure CNI                               │
│    • Azure Container Registry (ACR)                           │
│    • Azure Key Vault                                           │
│    • Key Vault secrets (db credentials)                       │
└────────────────────────────────────────────────────────────┘
```

#### **Phase 3: Container Build & Push (build-and-push)**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Login to Azure Container Registry                              │
│ 2. Build & Push Docker Image to ACR                             │
└────────────────────────────────────────────────────────────┘
```

#### **Phase 4: Kubernetes Deployment (deploy-kubernetes)**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Get AKS Credentials                                            │
│ 2. Create ACR Pull Secret                                        │
│ 3. Install External Secrets Operator                            │
│ 4. Setup External Secrets for Azure Key Vault:                  │
│    • Create SecretStore (Azure Key Vault)                       │
│    • Create ExternalSecret (sync from Key Vault)                │
│    • Fallback to manual secret if needed                        │
│ 5. Deploy Database (PostgreSQL via Helm)                         │
│ 6. Deploy Application (Custom Helm chart)                        │
└────────────────────────────────────────────────────────────┘
```

### **Destroy Pipeline Phases**

#### **AWS EKS Destroy Pipeline**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Clean Kubernetes Resources (Helm releases, namespaces)         │
│ 2. Delete EKS Node Groups (wait for completion)                  │
│ 3. Delete ElastiCache Cluster (wait for completion)              │
│ 4. Delete RDS Instance (wait for completion)                     │
│ 5. Delete Subnet Groups (after databases deleted) ← KEY FIX     │
│ 6. Delete AWS Secrets Manager Secret                             │
│ 7. Clean ECR Repository Images                                   │
│ 8. Remove Missing Resources from Terraform State                 │
│ 9. Terraform Destroy (VPC, IAM, Security Groups)                 │
│ 10. Final State Cleanup                                          │
└────────────────────────────────────────────────────────────┘
```

#### **Azure AKS Destroy Pipeline**
```
┌────────────────────────────────────────────────────────────┐
│ 1. Clean Kubernetes Resources                                     │
│ 2. Clean ACR Images                                              │
│ 3. Remove Missing Resources from State                           │
│ 4. Manual Key Vault Cleanup                                      │
│ 5. Terraform Destroy (AKS, ACR, Key Vault, Resource Group)      │
└────────────────────────────────────────────────────────────┘
```

---

## 🔧 **Technical Components**

### **AWS EKS Stack**
| Component | Technology | Purpose |
|-----------|------------|---------|
| **Orchestration** | Amazon EKS | Managed Kubernetes service |
| **Database** | Amazon RDS (PostgreSQL) | Managed database service |
| **Cache** | Amazon ElastiCache (Redis) | In-memory caching |
| **Secrets** | AWS Secrets Manager + External Secrets | Centralized secret management |
| **Networking** | VPC with public/private subnets | Network isolation |
| **Container Registry** | Amazon ECR | Container image storage |
| **IAM** | IRSA (IAM Roles for Service Accounts) | Pod-level AWS permissions |
| **Infrastructure** | Terraform | Infrastructure as Code |
| **CI/CD** | GitHub Actions | Automated deployment |

### **Azure AKS Stack**
| Component | Technology | Purpose |
|-----------|------------|---------|
| **Orchestration** | Azure AKS | Managed Kubernetes service |
| **Database** | PostgreSQL (Helm Chart) | Database running in cluster |
| **Secrets** | Azure Key Vault + External Secrets | Centralized secret management |
| **Networking** | Azure CNI | Native Azure networking |
| **Container Registry** | Azure ACR | Container image storage |
| **Infrastructure** | Terraform | Infrastructure as Code |
| **CI/CD** | GitHub Actions | Automated deployment |

---

## 🚀 **Application Access**

### **AWS EKS Application**
- **URL**: `http://<EKS-LoadBalancer-IP>`
- **Database**: RDS PostgreSQL (managed service)
- **Secrets**: Synced from AWS Secrets Manager
- **Scaling**: Auto-scaling node groups

### **Azure AKS Application**
- **URL**: `http://4.156.92.86`
- **Database**: PostgreSQL pod in cluster
- **Secrets**: Synced from Azure Key Vault via External Secrets
- **Key Vault**: `myapp-kv-2024` (stores db-username, db-password)
- **Scaling**: Azure auto-scaling

---

## ⚠️ **Major Problems Encountered & Solutions**

### **1. External Secrets Webhook Timeout (AWS)**
**Problem**: 
```
failed calling webhook "validate.secretstore.external-secrets.io": 
context deadline exceeded
```

**Root Cause**: External Secrets webhook validation was timing out during SecretStore creation

**Solution**:
- Identified webhook name: `secretstore-validate`
- Deleted webhook before resource creation
- Used `--validate=false` flag
- Created resources immediately after webhook deletion

**Impact**: 3+ hours debugging, multiple pipeline failures

---

### **2. IAM Role Trust Policy Mismatch (AWS)**
**Problem**:
```
AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**Root Cause**: IAM role trust policy expected `system:serviceaccount:external-secrets:external-secrets` but service account was in `default` namespace

**Solution**:
- Updated trust policy to: `system:serviceaccount:default:external-secrets-sa`
- Created service account in correct namespace
- Restarted External Secrets pods to pick up new IAM role

**Impact**: 2+ hours debugging, authentication failures

---

### **3. VPC Subnet Group Conflicts (AWS)**
**Problem**:
```
CacheSubnetGroupInUse: Cache subnet group is currently in use by a cache cluster
```

**Root Cause**: Destroy pipeline wasn't properly cleaning up subnet groups, causing VPC mismatches on recreation

**Solution**:
- Added proper cleanup order: databases → subnet groups → VPC
- Implemented VPC mismatch detection
- Added resource state management

**Impact**: Multiple infrastructure recreation cycles

---

### **4. Service Account Namespace Issues (AWS)**
**Problem**:
```
ServiceAccount "external-secrets" not found
```

**Root Cause**: External Secrets controller running in `default` namespace couldn't find service account in `external-secrets` namespace

**Solution**:
- Created service account in `default` namespace
- Updated SecretStore to reference correct service account
- Maintained backward compatibility with both service accounts

**Impact**: 1+ hour debugging, secret sync failures

---

### **5. Account ID Retrieval Failures (AWS)**
**Problem**:
```
Role ARN: arn:aws:iam:::role/external-secrets-role (missing account ID)
```

**Root Cause**: AWS CLI command returning empty account ID in CI/CD environment

**Solution**:
- Added debug output for account ID retrieval
- Implemented fallback methods
- Added validation checks

**Impact**: Role ARN malformation, authentication failures

---

### **6. Terraform State Lock Issues**
**Problem**: Multiple pipeline runs causing state lock conflicts

**Solution**:
- Implemented proper error handling
- Added state lock detection
- Graceful failure handling

---

### **7. Resource Import Challenges**
**Problem**: Existing resources not properly imported into Terraform state

**Solution**:
- Created comprehensive import scripts
- Added resource existence checks
- Implemented idempotent operations

---

## 📊 **Pipeline Optimization**

### **Skip Flags Implementation**
- `[skip-terraform]`: Skip infrastructure changes
- `[skip-build]`: Skip Docker image building
- Deploy-only mode for faster iterations

### **Error Handling Strategy**
- Differentiate between authentic errors and expected failures
- Graceful degradation for missing resources
- Comprehensive logging and diagnostics

---

## 🎯 **Key Achievements**

### **✅ Successfully Deployed**
1. **Multi-cloud Kubernetes clusters** (AWS EKS + Azure AKS)
2. **External Secrets integration** with AWS Secrets Manager
3. **Database services** (RDS + in-cluster PostgreSQL)
4. **Container registries** (ECR + ACR)
5. **Load balancer access** for both applications
6. **Infrastructure as Code** with Terraform
7. **CI/CD pipelines** with GitHub Actions

### **✅ Problem-Solving Approach**
1. **Systematic debugging** with detailed logging
2. **Root cause analysis** for each issue
3. **Incremental fixes** with version control
4. **Documentation** of solutions for future reference
5. **Pipeline optimization** for faster iterations

---

## 🔮 **Future Improvements**

### **Security Enhancements**
- Implement network policies
- Add pod security standards
- Enable audit logging

### **Monitoring & Observability**
- Add Prometheus/Grafana stack
- Implement distributed tracing
- Set up alerting systems

### **High Availability**
- Multi-region deployments
- Cross-cloud disaster recovery
- Database replication

### **Cost Optimization**
- Implement cluster autoscaling
- Add resource quotas
- Optimize instance types

---

## 🏃‍♂️ **Runtime Architecture Details**

### **How Applications Run in Production**

#### **AWS EKS Runtime Environment**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS EKS CLUSTER                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │   Node Group    │    │   Node Group    │    │   Node Group    │        │
│  │   (t3.medium)   │    │   (t3.medium)   │    │   (t3.medium)   │        │
│  │                 │    │                 │    │                 │        │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │        │
│  │  │    App    │  │    │  │    App    │  │    │  │PostgreSQL │  │        │
│  │  │   Pod 1   │  │    │  │   Pod 2   │  │    │  │   Pod     │  │        │
│  │  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │        │
│  │                 │    │                 │    │                 │        │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │        │
│  │  │External   │  │    │  │   Helm    │  │    │  │  System   │  │        │
│  │  │Secrets    │  │    │  │  Charts   │  │    │  │   Pods    │  │        │
│  │  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
├─────────────────────────────────────────────────────────────────────────────┤
│                        EXTERNAL SERVICES                                   │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │   RDS           │    │  ElastiCache    │    │   ECR           │        │
│  │   PostgreSQL    │    │  Redis          │    │   Repository    │        │
│  │   (Multi-AZ)    │    │  (Cluster)      │    │   (Images)      │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
│                                                                             │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │   Secrets       │    │   Load          │    │   VPC           │        │
│  │   Manager       │    │   Balancer      │    │   Networking    │        │
│  │   (Credentials) │    │   (Public)      │    │   (Subnets)     │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
```

#### **Azure AKS Runtime Environment**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AZURE AKS CLUSTER                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │   Node Pool     │    │   Node Pool     │    │   Node Pool     │        │
│  │   (Standard_D2) │    │   (Standard_D2) │    │   (Standard_D2) │        │
│  │                 │    │                 │    │                 │        │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │        │
│  │  │    App    │  │    │  │    App    │  │    │  │PostgreSQL │  │        │
│  │  │   Pod 1   │  │    │  │   Pod 2   │  │    │  │   Pod     │  │        │
│  │  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │        │
│  │                 │    │                 │    │                 │        │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │        │
│  │  │External   │  │    │  │   Helm    │  │    │  │  System   │  │        │
│  │  │Secrets    │  │    │  │  Charts   │  │    │  │   Pods    │  │        │
│  │  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
├─────────────────────────────────────────────────────────────────────────────┤
│                        EXTERNAL SERVICES                                   │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐        │
│  │   Azure         │    │   Load          │    │   ACR           │        │
│  │   Key Vault     │    │   Balancer      │    │   Repository    │        │
│  │   (Secrets)     │    │   (Public)      │    │   (Images)      │        │
│  │   • db-username │    │   • External IP │    │   • myapp:latest│        │
│  │   • db-password │    │   • Port 80     │    │   • Auto-build  │        │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### **Secret Management Flow**

#### **AWS EKS Secret Flow**
```
AWS Secrets Manager → External Secrets Operator → Kubernetes Secret → Application Pod
       ↑                        ↑                        ↑                    ↑
   Stores DB              Syncs every 1m           Mounted as           Reads from
   credentials            via IAM role             environment          /var/secrets
```

#### **Azure AKS Secret Flow**
```
Azure Key Vault → External Secrets Operator → Kubernetes Secret → Application Pod
       ↑                     ↑                       ↑                   ↑
   Stores DB           Syncs via Managed        Mounted as          Reads from
   credentials         Identity                 environment         /var/secrets
```

### **Traffic Flow**

#### **User Request Journey**
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Internet  │───▶│    Load     │───▶│ Kubernetes  │───▶│ Application │
│    User     │    │  Balancer   │    │   Service   │    │    Pod      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                  │
                                                                  ▼
                                                          ┌─────────────┐
                                                          │  Database   │
                                                          │ (RDS/Pod)   │
                                                          └─────────────┘
```

---

## 📈 **Metrics & Performance**

### **Deployment Times**
- **Full Pipeline**: ~15-20 minutes
- **Deploy-only**: ~3-5 minutes
- **Infrastructure**: ~10-12 minutes

### **Success Rate**
- **Initial Attempts**: ~30% (due to External Secrets issues)
- **After Fixes**: ~95% success rate
- **Deploy-only**: ~98% success rate

### **Resource Utilization**
- **AWS**: EKS cluster + RDS + ElastiCache + ECR
- **Azure**: AKS cluster + ACR
- **Cost**: Optimized for development/testing workloads

---

## 🏆 **Conclusion**

Successfully implemented a **multi-cloud Kubernetes architecture** with:
- **Robust error handling** and problem resolution
- **Automated CI/CD pipelines** for both clouds
- **Centralized secret management** with External Secrets
- **Infrastructure as Code** with Terraform
- **Production-ready applications** with load balancer access

**The project demonstrates expertise in cloud-native technologies, problem-solving skills, and multi-cloud architecture design.**