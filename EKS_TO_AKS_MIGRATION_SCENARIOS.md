# EKS to AKS Migration Scenarios & Strategies

## 🎯 **Migration Scenarios Overview**

This document outlines different scenarios and strategic approaches for migrating from **AWS EKS** to **Azure AKS**, with recommendations based on business requirements, downtime tolerance, and complexity.

---

## 📊 **Migration Scenario Matrix**

| **Scenario** | **Downtime** | **Complexity** | **Cost** | **Risk** | **Best For** |
|--------------|--------------|----------------|----------|----------|--------------|
| **Big Bang** | High (4-8h) | Low | Low | High | Dev/Test environments |
| **Blue-Green** | Minimal (5-15min) | Medium | High | Medium | Production with budget |
| **Rolling** | None | High | Medium | Low | Critical production |
| **Phased** | Minimal | Medium | Medium | Low | Large applications |
| **Hybrid** | None | High | High | Low | Multi-region apps |

---

## 🚀 **Scenario 1: Big Bang Migration**

### **When to Use:**
- ✅ **Development/Testing environments**
- ✅ **Non-critical applications**
- ✅ **Limited budget and time**
- ✅ **Small to medium applications**
- ✅ **Acceptable downtime window available**

### **Approach:**
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   EKS Running   │───▶│  Maintenance    │───▶│   AKS Running   │
│   (Active)      │    │  Window         │    │   (Active)      │
│                 │    │  (4-8 hours)    │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Migration Steps:**
1. **Preparation Phase (1-2 days)**
   - Deploy AKS infrastructure
   - Build and push images to ACR
   - Migrate secrets to Azure Key Vault
   - Prepare database backup

2. **Execution Phase (4-8 hours)**
   - Put application in maintenance mode
   - Export database from RDS
   - Deploy applications to AKS
   - Import database to PostgreSQL pod
   - Update DNS to point to AKS
   - Verify functionality

3. **Cleanup Phase (1 day)**
   - Monitor AKS application
   - Destroy EKS infrastructure

### **Pros & Cons:**
| **Pros** | **Cons** |
|----------|----------|
| ✅ Simple and straightforward | ❌ Extended downtime |
| ✅ Lower cost | ❌ High risk if issues occur |
| ✅ Faster execution | ❌ No rollback during migration |
| ✅ Less complex coordination | ❌ User impact during downtime |

### **Implementation Script:**
```bash
#!/bin/bash
# Big Bang Migration Script

echo "🚨 Starting Big Bang Migration - Application will be down"

# Step 1: Put application in maintenance mode
kubectl patch deployment myapp -p '{"spec":{"replicas":0}}'

# Step 2: Backup database
kubectl exec postgres-pod -- pg_dump -U postgres myapp > database-backup.sql

# Step 3: Deploy to AKS
az aks get-credentials --resource-group aks-rg --name my-aks-cluster
helm install myapp ./aks/helm-charts/application

# Step 4: Restore database
kubectl cp database-backup.sql postgres-pod:/tmp/
kubectl exec postgres-pod -- psql -U postgres myapp < /tmp/database-backup.sql

# Step 5: Update DNS (manual step)
echo "🌐 Update DNS to point to AKS LoadBalancer IP"
kubectl get service myapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

echo "✅ Big Bang Migration Complete"
```

---

## 🔄 **Scenario 2: Blue-Green Migration**

### **When to Use:**
- ✅ **Production applications**
- ✅ **Budget available for dual infrastructure**
- ✅ **Quick rollback capability required**
- ✅ **Minimal downtime tolerance (5-15 minutes)**
- ✅ **Stateless or easily replicable applications**

### **Approach:**
```
┌─────────────────┐    ┌─────────────────┐
│   EKS (Blue)    │    │   AKS (Green)   │
│   Production    │    │   Standby       │
│   Traffic: 100% │    │   Traffic: 0%   │
└─────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│   EKS (Blue)    │    │   AKS (Green)   │
│   Standby       │    │   Production    │
│   Traffic: 0%   │    │   Traffic: 100% │
└─────────────────┘    └─────────────────┘
```

### **Migration Steps:**
1. **Green Environment Setup (2-3 days)**
   - Deploy complete AKS infrastructure
   - Deploy applications (not receiving traffic)
   - Sync database to AKS environment
   - Perform thorough testing

2. **Traffic Switch (5-15 minutes)**
   - Update DNS/Load Balancer to point to AKS
   - Monitor application health
   - Verify all functionality

3. **Blue Environment Cleanup (1-2 days)**
   - Keep EKS running for 24-48 hours
   - Monitor AKS stability
   - Destroy EKS infrastructure

### **Database Sync Strategy:**
```bash
# Option 1: Database Replication
# Set up read replica from RDS to AKS PostgreSQL
pg_basebackup -h rds-endpoint -D /var/lib/postgresql/data -U postgres -v -P

# Option 2: Final Sync During Cutover
# Stop writes, sync final changes, switch traffic
kubectl scale deployment myapp --replicas=0  # Stop writes
pg_dump -h rds-endpoint | kubectl exec -i postgres-pod -- psql -U postgres myapp
# Switch DNS
```

### **Pros & Cons:**
| **Pros** | **Cons** |
|----------|----------|
| ✅ Minimal downtime (5-15 min) | ❌ Higher cost (dual infrastructure) |
| ✅ Easy rollback | ❌ Complex database synchronization |
| ✅ Thorough testing possible | ❌ Resource intensive |
| ✅ Low risk | ❌ Requires careful coordination |

---

## 🔄 **Scenario 3: Rolling Migration**

### **When to Use:**
- ✅ **Zero downtime requirement**
- ✅ **Microservices architecture**
- ✅ **Critical production systems**
- ✅ **Service-by-service migration possible**
- ✅ **Complex applications with multiple components**

### **Approach:**
```
EKS Services:     [Auth] [User] [Order] [Payment] [Notification]
                    ↓
Migration Wave 1: [Auth] ────────────────────────────────────────▶ AKS
                         [User] [Order] [Payment] [Notification]
                           ↓
Migration Wave 2:         [User] ──────────────────────────────▶ AKS
                                [Order] [Payment] [Notification]
                                  ↓
Migration Wave 3:                [Order] ────────────────────▶ AKS
                                        [Payment] [Notification]
```

### **Migration Waves:**

#### **Wave 1: Stateless Services**
- Authentication service
- API Gateway
- Static content services

#### **Wave 2: Business Logic Services**
- User management
- Catalog services
- Search services

#### **Wave 3: Data Services**
- Order processing
- Payment processing
- Database-dependent services

#### **Wave 4: Supporting Services**
- Notification services
- Reporting services
- Background jobs

### **Implementation Strategy:**
```bash
# Wave 1: Migrate Authentication Service
echo "🌊 Wave 1: Migrating Authentication Service"

# Deploy auth service to AKS
helm install auth-service ./aks/helm-charts/auth-service

# Update service discovery to include both EKS and AKS endpoints
kubectl patch configmap service-discovery --patch '
data:
  auth-service: "http://auth-aks.example.com,http://auth-eks.example.com"
'

# Gradually shift traffic using weighted routing
# 10% to AKS, 90% to EKS
# 50% to AKS, 50% to EKS  
# 100% to AKS, 0% to EKS

# Remove EKS auth service
kubectl delete deployment auth-service -n eks-cluster
```

### **Traffic Splitting Options:**

#### **Option 1: DNS-based Weighted Routing**
```yaml
# Route53 Weighted Routing
auth-service.example.com:
  - Weight: 90, Target: auth-eks-lb.amazonaws.com
  - Weight: 10, Target: auth-aks-lb.azure.com
```

#### **Option 2: Service Mesh (Istio)**
```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: auth-service
spec:
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: auth-service-aks
  - route:
    - destination:
        host: auth-service-eks
      weight: 90
    - destination:
        host: auth-service-aks
      weight: 10
```

### **Pros & Cons:**
| **Pros** | **Cons** |
|----------|----------|
| ✅ Zero downtime | ❌ Very complex coordination |
| ✅ Gradual risk reduction | ❌ Long migration timeline |
| ✅ Easy rollback per service | ❌ Service dependency management |
| ✅ Continuous validation | ❌ Requires advanced tooling |

---

## 📈 **Scenario 4: Phased Migration**

### **When to Use:**
- ✅ **Large monolithic applications**
- ✅ **Multiple environments (dev, staging, prod)**
- ✅ **Risk-averse organizations**
- ✅ **Complex data dependencies**
- ✅ **Regulatory compliance requirements**

### **Approach:**
```
Phase 1: Development Environment
┌─────────────┐    ┌─────────────┐
│ EKS Dev     │───▶│ AKS Dev     │
└─────────────┘    └─────────────┘

Phase 2: Staging Environment  
┌─────────────┐    ┌─────────────┐
│ EKS Staging │───▶│ AKS Staging │
└─────────────┘    └─────────────┘

Phase 3: Production Environment
┌─────────────┐    ┌─────────────┐
│ EKS Prod    │───▶│ AKS Prod    │
└─────────────┘    └─────────────┘
```

### **Phase Timeline:**

#### **Phase 1: Development (Week 1-2)**
- Deploy AKS development environment
- Migrate development applications
- Test all functionality
- Train development team
- Document issues and solutions

#### **Phase 2: Staging (Week 3-4)**
- Deploy AKS staging environment
- Migrate staging applications
- Perform comprehensive testing
- Load testing and performance validation
- Security and compliance testing

#### **Phase 3: Production (Week 5-6)**
- Deploy AKS production environment
- Choose migration strategy (Big Bang or Blue-Green)
- Execute production migration
- Monitor and validate
- Cleanup EKS environments

### **Validation Checklist per Phase:**
```bash
# Development Phase Validation
echo "🧪 Development Phase Validation"
- [ ] All applications deploy successfully
- [ ] Database connections work
- [ ] External integrations function
- [ ] CI/CD pipelines updated
- [ ] Monitoring and logging configured

# Staging Phase Validation  
echo "🎭 Staging Phase Validation"
- [ ] Performance meets requirements
- [ ] Load testing passes
- [ ] Security scans pass
- [ ] Backup and restore procedures work
- [ ] Disaster recovery tested

# Production Phase Validation
echo "🚀 Production Phase Validation"
- [ ] Zero data loss confirmed
- [ ] All user journeys work
- [ ] Performance monitoring active
- [ ] Alerting configured
- [ ] Rollback procedures tested
```

### **Pros & Cons:**
| **Pros** | **Cons** |
|----------|----------|
| ✅ Risk mitigation through testing | ❌ Longer overall timeline |
| ✅ Team learning and adaptation | ❌ Multiple environment maintenance |
| ✅ Issue identification early | ❌ Higher temporary costs |
| ✅ Confidence building | ❌ Coordination complexity |

---

## 🌐 **Scenario 5: Hybrid Multi-Cloud**

### **When to Use:**
- ✅ **Multi-region applications**
- ✅ **Disaster recovery requirements**
- ✅ **Vendor lock-in avoidance**
- ✅ **Compliance with data residency**
- ✅ **High availability requirements**

### **Approach:**
```
┌─────────────────────────────────────────────────────────────┐
│                    Global Load Balancer                     │
│                   (CloudFlare/Route53)                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
        ┌─────────────┴─────────────┐
        ▼                           ▼
┌─────────────────┐         ┌─────────────────┐
│   AWS EKS       │         │   Azure AKS     │
│   (Primary)     │◀────────▶│   (Secondary)   │
│   US-East       │         │   Europe        │
└─────────────────┘         └─────────────────┘
```

### **Architecture Patterns:**

#### **Pattern 1: Active-Active**
- Both clusters serve traffic simultaneously
- Data synchronization between regions
- Global load balancer distributes traffic

#### **Pattern 2: Active-Passive**
- EKS serves primary traffic
- AKS serves as disaster recovery
- Automatic failover capability

#### **Pattern 3: Geographic Split**
- EKS serves North American users
- AKS serves European users
- Data residency compliance

### **Implementation Strategy:**
```bash
# Global Load Balancer Configuration
echo "🌍 Configuring Global Load Balancer"

# CloudFlare Load Balancer
curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/load_balancers" \
  -H "Authorization: Bearer $CF_TOKEN" \
  -d '{
    "name": "myapp.example.com",
    "default_pools": ["eks-pool", "aks-pool"],
    "fallback_pool": "aks-pool",
    "region_pools": {
      "WNAM": ["eks-pool"],
      "EEUR": ["aks-pool"]
    }
  }'

# Database Replication Setup
echo "🔄 Setting up database replication"
# PostgreSQL streaming replication between EKS RDS and AKS PostgreSQL
```

### **Data Synchronization Strategies:**

#### **Strategy 1: Database Replication**
```bash
# Master-Slave Replication
# EKS RDS (Master) -> AKS PostgreSQL (Slave)
pg_basebackup -h eks-rds-endpoint -D /var/lib/postgresql/data -U postgres -v -P -R
```

#### **Strategy 2: Event-Driven Sync**
```yaml
# Kafka/Event Hub for data synchronization
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-sync-service
spec:
  template:
    spec:
      containers:
      - name: sync-service
        image: myapp/data-sync:latest
        env:
        - name: KAFKA_BROKERS
          value: "kafka-eks:9092,kafka-aks:9092"
```

#### **Strategy 3: API-based Sync**
```bash
# Scheduled synchronization via APIs
kubectl create cronjob data-sync --image=myapp/sync:latest \
  --schedule="*/5 * * * *" \
  --restart=OnFailure
```

### **Pros & Cons:**
| **Pros** | **Cons** |
|----------|----------|
| ✅ High availability | ❌ Highest complexity |
| ✅ Disaster recovery | ❌ Data consistency challenges |
| ✅ Geographic distribution | ❌ Highest cost |
| ✅ Vendor independence | ❌ Network latency issues |

---

## 🎯 **Migration Strategy Recommendations**

### **Based on Application Type:**

#### **Stateless Web Applications**
- **Recommended:** Blue-Green or Rolling
- **Reason:** Easy to replicate, minimal data concerns

#### **Microservices Architecture**
- **Recommended:** Rolling Migration
- **Reason:** Service-by-service migration reduces risk

#### **Monolithic Applications**
- **Recommended:** Phased or Blue-Green
- **Reason:** Complex dependencies require careful planning

#### **Data-Heavy Applications**
- **Recommended:** Phased Migration
- **Reason:** Database migration needs extensive testing

#### **Real-time Applications**
- **Recommended:** Rolling or Hybrid
- **Reason:** Zero downtime requirement

### **Based on Business Requirements:**

#### **Cost-Sensitive**
- **Recommended:** Big Bang or Phased
- **Reason:** Minimal dual infrastructure costs

#### **Risk-Averse**
- **Recommended:** Phased Migration
- **Reason:** Extensive testing and validation

#### **Time-Sensitive**
- **Recommended:** Big Bang
- **Reason:** Fastest execution time

#### **High Availability Required**
- **Recommended:** Rolling or Hybrid
- **Reason:** Zero downtime capability

---

## 📋 **Decision Matrix**

Use this matrix to choose the best migration scenario:

| **Criteria** | **Big Bang** | **Blue-Green** | **Rolling** | **Phased** | **Hybrid** |
|--------------|--------------|----------------|-------------|------------|------------|
| **Downtime Tolerance** | High | Low | None | Low | None |
| **Budget Available** | Low | High | Medium | Medium | High |
| **Risk Tolerance** | High | Medium | Low | Low | Low |
| **Team Expertise** | Low | Medium | High | Medium | High |
| **Application Complexity** | Low | Medium | High | High | High |
| **Timeline Pressure** | High | Medium | Low | Low | Low |

### **Scoring System:**
- **3 points:** Excellent fit
- **2 points:** Good fit  
- **1 point:** Acceptable fit
- **0 points:** Poor fit

**Choose the scenario with the highest total score for your specific situation.**

---

## 🚨 **Risk Mitigation Strategies**

### **Common Risks & Mitigations:**

#### **Data Loss Risk**
- **Mitigation:** Multiple backups, replication, validation scripts
- **Testing:** Restore procedures in non-production

#### **Extended Downtime Risk**
- **Mitigation:** Thorough testing, rollback procedures, monitoring
- **Testing:** Practice runs in staging environment

#### **Performance Degradation Risk**
- **Mitigation:** Load testing, resource sizing, monitoring
- **Testing:** Performance benchmarking pre/post migration

#### **Integration Failure Risk**
- **Mitigation:** Service discovery updates, endpoint testing
- **Testing:** End-to-end integration testing

---

## 🚀 **Zero Downtime Migration: Detailed Implementation**

### **🎯 Core Strategy: Rolling Migration with Traffic Splitting**

**Approach Overview:**
```
EKS (100% traffic) → Gradual Split → AKS (100% traffic)
     ↓                    ↓                ↓
   Active            Both Active        Active
```

**Timeline:** 7-8 days with continuous traffic serving

---

## 🛠️ **Required Services & Infrastructure for Zero Downtime**

### **Traffic Management Layer**
| **Service** | **Purpose** | **Configuration** |
|-------------|-------------|-------------------|
| **AWS Route 53** | Weighted DNS routing | 90%→10% gradual shift |
| **Azure Traffic Manager** | Geographic routing | Backup routing option |
| **CloudFlare Load Balancer** | Global distribution | Advanced health checks |
| **Istio Service Mesh** | Precise traffic control | Header-based routing |

### **Database Synchronization Services**
| **Service** | **Use Case** | **Implementation** |
|-------------|--------------|--------------------|
| **AWS DMS** | Real-time replication | RDS → AKS PostgreSQL |
| **PostgreSQL Streaming** | Native replication | Master-slave setup |
| **Debezium** | Change data capture | Event-driven sync |
| **Azure Database Migration** | Schema migration | One-time setup |

### **Container & Secret Sync**
| **Component** | **Source** | **Target** | **Method** |
|---------------|------------|------------|------------|
| **Container Images** | Amazon ECR | Azure ACR | Docker pull/push |
| **Secrets** | AWS Secrets Manager | Azure Key Vault | External Secrets sync |
| **Configurations** | EKS ConfigMaps | AKS ConfigMaps | kubectl export/import |

### **Zero Downtime Supporting Services**
| **Service Category** | **AWS Services** | **Azure Services** | **Third-Party Tools** |
|---------------------|------------------|-------------------|----------------------|
| **Traffic Management** | Route 53, ALB, NLB | Traffic Manager, App Gateway | CloudFlare, F5 |
| **Database Replication** | DMS, RDS Read Replica | Database Migration Service | Debezium, Kafka |
| **Service Discovery** | AWS Cloud Map | Azure Service Fabric | Consul, Eureka |
| **Monitoring** | CloudWatch, X-Ray | Azure Monitor, App Insights | Datadog, New Relic |
| **Service Mesh** | AWS App Mesh | Azure Service Mesh | Istio, Linkerd |
| **CI/CD Integration** | CodePipeline, CodeBuild | Azure DevOps, ACR Tasks | Jenkins, GitLab CI |
| **Secret Management** | Secrets Manager, Parameter Store | Key Vault, App Configuration | HashiCorp Vault |
| **Container Registry** | ECR | ACR | Docker Hub, Harbor |

---

## 📋 **Zero Downtime Migration Implementation**

### **Phase 1: Parallel Infrastructure Setup (Day 1-2)**

#### **Infrastructure Deployment**
```bash
# Deploy AKS infrastructure
echo "🏗️ Deploying AKS infrastructure..."
cd aks/terraform
terraform apply -auto-approve

# Get AKS credentials
az aks get-credentials --resource-group aks-rg --name my-aks-cluster

# Verify cluster readiness
kubectl cluster-info
kubectl get nodes
```

#### **Container Image Synchronization**
```bash
# Sync images from ECR to ACR
echo "🐳 Syncing container images..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Pull from ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
docker pull $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/myapp:latest

# Push to ACR
az acr login --name myappacr2024
docker tag $ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/myapp:latest myappacr2024.azurecr.io/myapp:latest
docker push myappacr2024.azurecr.io/myapp:latest
```

#### **Application Deployment (No Traffic)**
```bash
# Deploy applications to AKS (standby mode)
echo "🚀 Deploying applications to AKS..."
helm install myapp ./aks/helm-charts/application --set service.type=ClusterIP

# Verify deployment
kubectl get pods -l app=myapp
kubectl get services
```

### **Phase 2: Advanced Database Replication Setup (Day 2-3)**

#### **Option 1: AWS DMS with CDC (Recommended for Zero Downtime)**
```bash
# Create DMS replication instance with high availability
echo "🔄 Setting up AWS DMS for real-time replication..."
aws dms create-replication-instance \
  --replication-instance-identifier myapp-replication \
  --replication-instance-class dms.r5.large \
  --multi-az \
  --publicly-accessible

# Create source endpoint (EKS RDS)
aws dms create-endpoint \
  --endpoint-identifier eks-rds-source \
  --endpoint-type source \
  --engine-name postgres \
  --server-name $EKS_RDS_ENDPOINT \
  --port 5432 \
  --database-name myapp \
  --username postgres \
  --password $DB_PASSWORD \
  --extra-connection-attributes "heartbeatEnable=true;heartbeatFrequency=1"

# Create target endpoint (AKS PostgreSQL)
aws dms create-endpoint \
  --endpoint-identifier aks-postgres-target \
  --endpoint-type target \
  --engine-name postgres \
  --server-name $AKS_POSTGRES_ENDPOINT \
  --port 5432 \
  --database-name myapp \
  --username postgres \
  --password $DB_PASSWORD

# Create replication task with CDC
aws dms create-replication-task \
  --replication-task-identifier myapp-cdc-sync \
  --source-endpoint-arn $SOURCE_ENDPOINT_ARN \
  --target-endpoint-arn $TARGET_ENDPOINT_ARN \
  --replication-instance-arn $REPLICATION_INSTANCE_ARN \
  --migration-type full-load-and-cdc

# Start replication task
aws dms start-replication-task \
  --replication-task-arn $REPLICATION_TASK_ARN \
  --start-replication-task-type start-replication

# Monitor replication progress
echo "📊 Monitoring replication progress..."
while true; do
  STATUS=$(aws dms describe-replication-tasks \
    --filters Name=replication-task-id,Values=myapp-cdc-sync \
    --query 'ReplicationTasks[0].Status' --output text)
  
  echo "Status: $STATUS"
  
  if [ "$STATUS" = "running" ]; then
    echo "✅ CDC replication active"
    break
  fi
  
  sleep 30
done
```

#### **Option 2: PostgreSQL Logical Replication (Alternative)**
```bash
# Enable logical replication on EKS RDS
echo "🔧 Configuring logical replication..."

# Modify RDS parameter group
aws rds modify-db-parameter-group \
  --db-parameter-group-name myapp-postgres-params \
  --parameters ParameterName=wal_level,ParameterValue=logical,ApplyMethod=pending-reboot

# Create publication on source (EKS RDS)
psql -h $EKS_RDS_ENDPOINT -U postgres -d myapp -c "
CREATE PUBLICATION myapp_pub FOR ALL TABLES;
"

# Create subscription on target (AKS PostgreSQL)
kubectl exec -it postgres-pod -- psql -U postgres -d myapp -c "
CREATE SUBSCRIPTION myapp_sub 
CONNECTION 'host=$EKS_RDS_ENDPOINT port=5432 user=postgres dbname=myapp password=$DB_PASSWORD' 
PUBLICATION myapp_pub;
"

# Monitor subscription status
kubectl exec postgres-pod -- psql -U postgres -d myapp -c "
SELECT subname, received_lsn, latest_end_lsn, latest_end_time
FROM pg_subscription;
"
```

### **Phase 3: Secret Synchronization (Day 3)**

```bash
# Sync secrets from AWS Secrets Manager to Azure Key Vault
echo "🔐 Synchronizing secrets..."

# Extract secrets from AWS
SECRETS=$(aws secretsmanager get-secret-value --secret-id myapp/db-credentials --query SecretString --output text)
USERNAME=$(echo $SECRETS | jq -r .username)
PASSWORD=$(echo $SECRETS | jq -r .password)

# Create secrets in Azure Key Vault
az keyvault secret set --vault-name myapp-kv-2024 --name db-username --value "$USERNAME"
az keyvault secret set --vault-name myapp-kv-2024 --name db-password --value "$PASSWORD"

# Verify External Secrets sync in AKS
kubectl get externalsecret db-credentials-external -o yaml
kubectl get secret db-credentials
```

### **Phase 4: Traffic Splitting Setup (Day 3-4)**

#### **Enable AKS LoadBalancer**
```bash
# Update AKS service to LoadBalancer type
echo "🌐 Enabling AKS LoadBalancer..."
kubectl patch service myapp -p '{"spec":{"type":"LoadBalancer"}}'

# Wait for external IP
kubectl get service myapp --watch
AKS_LB_IP=$(kubectl get service myapp -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "AKS LoadBalancer IP: $AKS_LB_IP"
```

#### **Configure Route 53 Weighted Routing**
```bash
# Get EKS LoadBalancer endpoint
aws eks update-kubeconfig --name my-eks-cluster --region us-east-1
EKS_LB_DNS=$(kubectl get service myapp -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create weighted routing policy
echo "⚖️ Setting up weighted routing..."
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "myapp.example.com",
          "Type": "CNAME",
          "SetIdentifier": "EKS-Primary",
          "Weight": 100,
          "TTL": 60,
          "ResourceRecords": [{"Value": "'$EKS_LB_DNS'"}]
        }
      },
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "myapp.example.com",
          "Type": "A",
          "SetIdentifier": "AKS-Secondary",
          "Weight": 0,
          "TTL": 60,
          "ResourceRecords": [{"Value": "'$AKS_LB_IP'"}]
        }
      }
    ]
  }'
```

### **Phase 5: Gradual Traffic Migration (Day 4-7)**

#### **Traffic Shift Schedule**
```bash
# Day 4: 10% to AKS
echo "📊 Day 4: Shifting 10% traffic to AKS"
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "myapp.example.com",
        "SetIdentifier": "EKS-Primary",
        "Weight": 90
      }
    }, {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "myapp.example.com",
        "SetIdentifier": "AKS-Secondary",
        "Weight": 10
      }
    }]
  }'

# Monitor for 24 hours
echo "🔍 Monitoring application health..."
for i in {1..24}; do
  EKS_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://myapp.example.com/health)
  AKS_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://$AKS_LB_IP/health)
  echo "Hour $i - EKS: $EKS_HEALTH, AKS: $AKS_HEALTH"
  sleep 3600
done

# Day 5: 30% to AKS (if Day 4 successful)
# Day 6: 50% to AKS
# Day 7: 80% to AKS
# Day 8: 100% to AKS
```

#### **Automated Health Monitoring**
```bash
# Health check script
#!/bin/bash
check_health() {
  local endpoint=$1
  local name=$2
  
  response=$(curl -s -o /dev/null -w "%{http_code}" $endpoint/health)
  if [ $response -eq 200 ]; then
    echo "✅ $name: Healthy ($response)"
    return 0
  else
    echo "❌ $name: Unhealthy ($response)"
    return 1
  fi
}

# Continuous monitoring
while true; do
  if ! check_health "http://myapp.example.com" "Application"; then
    echo "🚨 Health check failed - consider rollback"
    # Trigger alert
  fi
  
  # Check database replication lag
  LAG=$(kubectl exec postgres-pod -- psql -t -c "SELECT EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()));")
  if (( $(echo "$LAG > 5" | bc -l) )); then
    echo "⚠️ Database replication lag: ${LAG}s"
  fi
  
  sleep 60
done
```

### **Phase 6: Database Cutover (Day 8)**

```bash
# Final database cutover with zero downtime
echo "🔄 Performing zero-downtime database cutover..."

# 1. Verify replication is current (lag < 1 second)
REPL_LAG=$(aws dms describe-replication-tasks \
  --filters Name=replication-task-id,Values=myapp-cdc-sync \
  --query 'ReplicationTasks[0].ReplicationTaskStats.ElapsedTimeMillis' --output text)

if [ $REPL_LAG -gt 1000 ]; then
  echo "⚠️ Replication lag too high: ${REPL_LAG}ms - aborting cutover"
  exit 1
fi

# 2. Enable read-only mode on EKS RDS (brief moment)
psql -h $EKS_RDS_ENDPOINT -U postgres -d myapp -c "
ALTER DATABASE myapp SET default_transaction_read_only = on;
"

# 3. Wait for final CDC sync (usually < 5 seconds)
echo "⏳ Waiting for final CDC sync..."
sleep 10

# 4. Stop DMS replication task
aws dms stop-replication-task --replication-task-arn $REPLICATION_TASK_ARN

# 5. Update application configuration to use AKS database
kubectl patch configmap app-config --patch '{
  "data": {
    "DB_HOST": "postgres-postgresql",
    "DB_PORT": "5432",
    "DB_READ_ONLY": "false"
  }
}'

# 6. Rolling restart of applications (zero downtime)
kubectl rollout restart deployment myapp
kubectl rollout status deployment myapp --timeout=300s

# 7. Verify database write capability
kubectl exec -it $(kubectl get pods -l app=myapp -o name | head -1) -- \
  curl -X POST http://localhost:3000/api/health-check/db-write

# 8. Final traffic switch to 100% AKS
aws route53 change-resource-record-sets \
  --hosted-zone-id $HOSTED_ZONE_ID \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "myapp.example.com",
        "SetIdentifier": "AKS-Primary",
        "Weight": 100
      }
    }, {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "myapp.example.com",
        "SetIdentifier": "EKS-Primary"
      }
    }]
  }'

echo "✅ Database cutover completed - AKS is now primary"
```

### **Phase 7: Validation & Cleanup (Day 8-9)**

```bash
# Final validation
echo "✅ Final validation..."

# Application functionality test
curl -f http://myapp.example.com/api/users
curl -f http://myapp.example.com/api/health

# Database write test
kubectl exec -it $(kubectl get pods -l app=myapp -o name | head -1) -- \
  curl -X POST http://localhost:3000/api/test-write

# Performance test
ab -n 1000 -c 10 http://myapp.example.com/

# Monitor for 24 hours before cleanup
echo "🕐 Monitoring for 24 hours before EKS cleanup..."
sleep 86400

# Cleanup EKS infrastructure
echo "🧹 Cleaning up EKS infrastructure..."
cd eks/terraform
terraform destroy -auto-approve
```

---

## 🔍 **Monitoring & Validation During Migration**

### **Key Metrics Dashboard**
```bash
# Application metrics
kubectl top pods -l app=myapp
kubectl get pods -l app=myapp --field-selector=status.phase=Running

# Response time monitoring
curl -w "@curl-format.txt" -s -o /dev/null http://myapp.example.com

# Error rate tracking
kubectl logs -l app=myapp --tail=1000 | grep -c ERROR

# Database replication status
kubectl exec postgres-pod -- psql -c "
SELECT 
  client_addr,
  state,
  pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn) AS lag_bytes
FROM pg_stat_replication;
"
```

### **Automated Rollback Triggers**
```bash
# Rollback script
#!/bin/bash
rollback_to_eks() {
  echo "🔄 Rolling back to EKS..."
  
  # Immediate DNS switch back to EKS
  aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch '{
      "Changes": [{
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "myapp.example.com",
          "SetIdentifier": "EKS-Primary",
          "Weight": 100
        }
      }, {
        "Action": "DELETE",
        "ResourceRecordSet": {
          "Name": "myapp.example.com",
          "SetIdentifier": "AKS-Secondary"
        }
      }]
    }'
  
  echo "✅ Rollback completed - traffic back to EKS"
}

# Trigger conditions
ERROR_THRESHOLD=10
LATENCY_THRESHOLD=2000

if [ $(kubectl logs -l app=myapp --tail=100 | grep -c ERROR) -gt $ERROR_THRESHOLD ]; then
  rollback_to_eks
fi
```

---

## ⚡ **Zero Downtime Guarantees**

### **What Ensures Zero Downtime:**

#### **Infrastructure Level**
- ✅ **Parallel clusters** running simultaneously
- ✅ **Load balancer health checks** with automatic failover
- ✅ **DNS-based traffic splitting** with low TTL (60s)
- ✅ **Database replication** with <1s lag monitoring

#### **Application Level**
- ✅ **Stateless application design** (no session affinity)
- ✅ **Graceful shutdown** handling (SIGTERM)
- ✅ **Health check endpoints** (/health, /ready)
- ✅ **Circuit breaker patterns** for external dependencies

#### **Data Level**
- ✅ **Real-time database replication** with lag monitoring
- ✅ **Eventual consistency** acceptance for non-critical data
- ✅ **Transaction isolation** during cutover
- ✅ **Data validation** scripts post-migration

### **Success Criteria Checklist**
```bash
# Pre-migration validation
- [ ] Database replication lag < 1 second
- [ ] All health checks passing on both clusters
- [ ] Load balancer routing configured
- [ ] Monitoring and alerting active
- [ ] Rollback procedures tested

# During migration validation
- [ ] Traffic splitting working correctly
- [ ] No increase in error rates
- [ ] Response times within acceptable range
- [ ] Database writes functioning
- [ ] User sessions maintained

# Post-migration validation
- [ ] 100% traffic on AKS
- [ ] All application features working
- [ ] Database performance acceptable
- [ ] No data loss detected
- [ ] Monitoring systems updated
```

---

## 🎯 **Critical Success Factors**

### **Technical Requirements**
1. **Application must be stateless** or use external session storage
2. **Database replication lag must be <1 second**
3. **Health checks must be comprehensive** and reliable
4. **DNS TTL must be low** (60 seconds or less)
5. **Monitoring must be real-time** with automated alerts

### **Operational Requirements**
1. **24/7 monitoring team** during migration window
2. **Rollback decision authority** clearly defined
3. **Communication plan** for stakeholders
4. **Testing procedures** validated in staging
5. **Documentation** updated in real-time

### **Business Requirements**
1. **Maintenance window** not required
2. **User experience** remains consistent
3. **Performance** meets or exceeds current levels
4. **Data integrity** maintained throughout
5. **Compliance** requirements satisfied

**This zero downtime approach ensures continuous service availability while migrating from EKS to AKS through careful orchestration of parallel infrastructure, gradual traffic shifting, and real-time monitoring.**

---

This comprehensive guide provides multiple strategic approaches for migrating from EKS to AKS, allowing you to choose the best fit for your specific requirements, constraints, and risk tolerance.