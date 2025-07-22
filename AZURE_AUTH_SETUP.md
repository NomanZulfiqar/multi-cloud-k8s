# Simple Azure Authentication Setup for GitHub Actions

This guide explains how to set up a service principal for Azure authentication in GitHub Actions.

## Create a Service Principal

1. **Install Azure CLI** (if not already installed):
   ```bash
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
   ```

2. **Login to Azure**:
   ```bash
   az login
   ```

3. **Create a Service Principal**:
   ```bash
   az ad sp create-for-rbac --name "GitHubActionsAKS" \
                            --role contributor \
                            --scopes /subscriptions/<SUBSCRIPTION_ID> \
                            --sdk-auth
   ```
   
   Note: This grants contributor access to the entire subscription. The service principal will be able to create and manage the resource group.

   This command will output a JSON object like:
   ```json
   {
     "clientId": "<GUID>",
     "clientSecret": "<STRING>",
     "subscriptionId": "<GUID>",
     "tenantId": "<GUID>",
     "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
     "resourceManagerEndpointUrl": "https://management.azure.com/",
     "activeDirectoryGraphResourceId": "https://graph.windows.net/",
     "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
     "galleryEndpointUrl": "https://gallery.azure.com/",
     "managementEndpointUrl": "https://management.core.windows.net/"
   }
   ```

## Add the Service Principal to GitHub Secrets

1. **Copy the entire JSON output** from the previous command.

2. **In your GitHub repository**:
   - Go to Settings > Secrets and variables > Actions
   - Click "New repository secret"
   - Name: `AZURE_CREDENTIALS`
   - Value: Paste the entire JSON output
   - Click "Add secret"

## Credential Rotation

For security, rotate your service principal credentials periodically:

```bash
az ad sp credential reset --name "GitHubActionsAKS" --sdk-auth
```

Then update the `AZURE_CREDENTIALS` secret in GitHub with the new JSON output.

## Benefits of This Approach

- **Simplicity**: Easier to set up than OIDC
- **Familiarity**: Standard approach for Azure authentication
- **Compatibility**: Works with all Azure services

## Limitations

- **Security**: Requires storing a secret in GitHub
- **Maintenance**: Requires periodic credential rotation
- **Scope**: Service principal has fixed permissions