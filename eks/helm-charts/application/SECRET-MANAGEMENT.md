# Secret Management - Production Approach

## Single Source of Truth

This Helm chart follows production best practices for secret management:

### Architecture
```
AWS Secrets Manager → SecretProviderClass → Kubernetes Secret → Pod Environment Variables
```

### Files and Responsibilities

1. **secret-provider.yaml** - SINGLE SOURCE OF TRUTH
   - Defines mapping from AWS Secrets Manager to Kubernetes secrets
   - Only place where secret field definitions exist
   - Configures auto-sync behavior

2. **values.yaml** - Configuration Only
   - Contains secret names and references
   - No secret field definitions
   - Environment variable values (non-secret)

3. **deployment.yaml** - Consumer Only
   - References the Kubernetes secret created by SecretProviderClass
   - Uses `secretKeyRef` to access secret values
   - No secret field definitions

### Adding New Secrets

To add a new secret field:

1. **Add to AWS Secrets Manager** - Update the JSON in `myapp/db-credentials-v2`
2. **Update secret-provider.yaml** - Add jmesPath mapping and secretObjects entry
3. **Use in deployment.yaml** - Add environment variable with `secretKeyRef`

### Benefits

- ✅ Single point of change for secret mappings
- ✅ No duplication across files
- ✅ Production-ready architecture
- ✅ Easy maintenance and updates
- ✅ Clear separation of concerns