# Setting Up OIDC Authentication for GitHub Actions

This guide explains how to set up OIDC authentication for GitHub Actions to securely authenticate with AWS and Azure without storing long-lived credentials.

## AWS OIDC Setup

1. **Create an IAM OIDC Identity Provider**:
   ```bash
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```

2. **Create an IAM Role with Trust Policy**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringEquals": {
             "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
           },
           "StringLike": {
             "token.actions.githubusercontent.com:sub": "repo:<GITHUB_USERNAME>/<REPO_NAME>:*"
           }
         }
       }
     ]
   }
   ```

3. **Attach Required Policies to the Role**:
   - Attach policies that grant permissions needed for EKS deployment (AmazonEKSClusterPolicy, etc.)

4. **Add Role ARN to GitHub Secrets**:
   - Add the role ARN as `AWS_ROLE_TO_ASSUME` in your GitHub repository secrets

## Azure OIDC Setup

1. **Register a new application in Azure AD**:
   ```bash
   az ad app create --display-name "GitHub-Actions-OIDC"
   ```

2. **Create a service principal**:
   ```bash
   az ad sp create --id <APP_ID>
   ```

3. **Assign a role to the service principal**:
   ```bash
   az role assignment create --role Contributor \
     --subscription <SUBSCRIPTION_ID> \
     --assignee-object-id <SERVICE_PRINCIPAL_OBJECT_ID> \
     --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>
   ```

4. **Configure the federated credentials**:
   ```bash
   az ad app federated-credential create \
     --id <APP_ID> \
     --parameters "{\"name\":\"github-federated\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:<GITHUB_USERNAME>/<REPO_NAME>:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"
   ```

5. **Add credentials to GitHub Secrets**:
   - Add `AZURE_CLIENT_ID` (the application ID)
   - Add `AZURE_TENANT_ID` (your Azure tenant ID)
   - Add `AZURE_SUBSCRIPTION_ID` (your Azure subscription ID)

## Updating GitHub Actions Workflows

The workflows have been updated to use OIDC authentication:

1. **EKS Pipeline**: Now uses `aws-actions/configure-aws-credentials@v2` with `role-to-assume`
2. **AKS Pipeline**: Now uses `azure/login@v1` with client-id, tenant-id, and subscription-id

## Benefits of OIDC Authentication

- **Enhanced Security**: No long-lived credentials stored in GitHub
- **Simplified Management**: No need to rotate credentials
- **Granular Control**: Precise permissions based on repository and branch
- **Audit Trail**: Better visibility into which actions are using cloud resources