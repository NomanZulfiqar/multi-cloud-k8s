# AKS Application Access Guide

## 🚀 Your AKS Application is Live!

### **Application URL:**
```
http://4.156.92.86
```

### **Service Details:**
- **Service Name:** `myapp`
- **Service Type:** `LoadBalancer`
- **External IP:** `4.156.92.86`
- **Port:** `80`
- **Internal IP:** `10.0.153.111`

### **How to Access:**

1. **Web Browser:**
   ```
   Open: http://4.156.92.86
   ```

2. **curl Command:**
   ```bash
   curl http://4.156.92.86
   ```

3. **Test API Endpoints:**
   ```bash
   # Health check
   curl http://4.156.92.86/health
   
   # API endpoints
   curl http://4.156.92.86/api/users
   ```

### **Database Connection:**
- **PostgreSQL Service:** `postgres-postgresql`
- **Internal IP:** `10.0.215.75`
- **Port:** `5432`
- **Connection from pods:** `postgres-postgresql:5432`

### **Cluster Information:**
- **Cluster Name:** `my-aks-cluster`
- **Resource Group:** `aks-rg`
- **Region:** `East US`

### **Useful Commands:**

```bash
# Get cluster credentials
az aks get-credentials --resource-group aks-rg --name my-aks-cluster

# Check all services
kubectl get services

# Check application pods
kubectl get pods -l app=myapp

# Check application logs
kubectl logs -l app=myapp

# Check service details
kubectl describe service myapp

# Port forward for local testing (alternative)
kubectl port-forward service/myapp 8080:80
# Then access: http://localhost:8080
```

### **Troubleshooting:**

If the external IP shows `<pending>`:
```bash
# Check service status
kubectl get service myapp -w

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```

### **Security Note:**
- The application is publicly accessible on the internet
- Consider adding authentication/authorization if needed
- Monitor access logs for security

---
**✅ Your AKS application is successfully deployed and accessible!**