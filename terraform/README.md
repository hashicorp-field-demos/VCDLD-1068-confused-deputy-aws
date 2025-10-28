# Secure Agentic Infrastructure with Terraform

This Terraform configuration deploys a comprehensive secure infrastructure for running agentic AI applications with end-to-end authentication, authorization, and zero-trust architecture principles. The infrastructure integrates HashiCorp Cloud Platform (HCP) Vault, AWS services, Keycloak, and AWS Bedrock to create a production-ready environment for secure AI workloads.

## Architecture Overview

The infrastructure consists of five main components that work together to provide a secure, scalable platform:

1. **HCP Vault Cluster**: Centralized secrets management and identity-based authentication
2. **AWS Networking**: VPC with public/private subnets and secure connectivity to HCP
3. **AWS DocumentDB**: MongoDB-compatible database for application data storage
4. **Bastion Host**: Secure access point with application deployment and management tools
5. **Keycloak**: Open-source OAuth/JWT authentication and authorization
6. **Vault Authentication**: JWT-based authentication bridge between Keycloak and Vault

## Keycloak Authentication

This infrastructure uses Keycloak as the identity provider:

**Features:**
- ✅ No cloud dependencies - runs locally or in Docker
- ✅ Fully automated Terraform configuration
- ✅ Free and open-source
- ✅ Complete control over users and groups

**Automated Setup:**
The Keycloak module (`terraform/modules/keycloak`) automatically creates:
- Realm: `confused-deputy-realm`
- Users: alice (readonly) and bob (admin)
- Groups: dbread and dbadmin
- Clients: products-web, products-agent, products-mcp
- Token exchange configuration for on-behalf-of flows

## Prerequisites

Before deploying this infrastructure, ensure you have the following prerequisites configured:

### 1. HashiCorp Cloud Platform (HCP)

- **HCP Account**: Active account with billing enabled
- **Service Principal**: Create an HCP service principal with the following permissions:
  - `Contributor` role on the HCP project
  - Ability to create and manage HVN and Vault clusters
- **Client Credentials**: Note the Client ID and Client Secret for the service principal

```bash
# Set HCP credentials (required for deployment)
export HCP_CLIENT_ID="your-hcp-client-id"
export HCP_CLIENT_SECRET="your-hcp-client-secret"
```

### 2. AWS Configuration

- **AWS Account**: Active AWS account with appropriate permissions
- **IAM Permissions**: Ensure your AWS credentials have permissions for:
  - VPC management (create/modify/delete VPCs, subnets, route tables, gateways)
  - EC2 management (instances, security groups, key pairs)
  - DocumentDB cluster management
  - Application Load Balancer management
  - Certificate Manager (for SSL certificates)
- **AWS CLI**: Configured with appropriate credentials

```bash
# Configure AWS CLI (required for deployment)
aws configure
```

### 3. Keycloak

- **Keycloak Server**: A running Keycloak instance (provided via Docker Compose)
- **Admin Access**: Default admin credentials (admin/admin) - change for production!

Keycloak will be configured automatically by Terraform. For local development:

```bash
# Start Keycloak (in docker-compose directory)
cd ../docker-compose
docker-compose up -d keycloak

# Keycloak will be available at http://localhost:8080
```

### 4. AWS Bedrock Configuration

- **Model Access**: Enable access to the **Nova Pro model** in the **us-east-1** region
  
**Important**: This application has been specifically tested with the **Nova Pro model** in the **us-east-1** region. Enable model access through the AWS Console:

1. Navigate to AWS Bedrock console in **us-east-1** region
2. Go to "Model Access" in the left sidebar
3. Request access to the **Nova Pro** model
4. Wait for approval (this may take some time)

### 5. Required Tools

- **Terraform**: Version >= 1.5
- **AWS CLI**: Latest version, properly configured
- **HCP CLI**: For HCP management (optional but recommended)

## Infrastructure Setup

### 1. Clone and Navigate

```bash
git clone <repository-url>
cd terraform
```

### 2. Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file with your specific values
nano terraform.tfvars
```

**Required Variables to Configure:**

```hcl
# General
resource_prefix = "ai"  # Will be combined with 3-char random suffix
aws_region      = "us-east-1"

# HCP Configuration
hcp_client_id     = "<hcp-client-id>"
hcp_client_secret = "<hcp-client-secret>" 

# DocumentDB Configuration
docdb_master_username    = "docdbadmin"
docdb_master_password    = "ChangeMe123!"  # Change this to a secure password
docdb_instance_class     = "db.t3.medium"
docdb_instance_count     = 1

# Bastion Host Configuration  
bastion_instance_type = "t3.medium"

# Keycloak Configuration
keycloak_url            = "http://localhost:8080"
keycloak_admin_username = "admin"
keycloak_admin_password = "admin"
user_password           = "password"  # For test users alice and bob
```

### 3. Initialize Terraform

```bash
# Initialize Terraform with all required providers
terraform init
```

This will download and configure the following providers:
- `hashicorp/hcp` - For HCP Vault and HVN management
- `hashicorp/aws` - For AWS resource management
- `mrparkers/keycloak` - For Keycloak configuration
- `hashicorp/vault` - For Vault configuration
- `hashicorp/tls` - For TLS certificate generation
- `hashicorp/random` - For random resource naming
- `hashicorp/local` - For local file operations

### 4. Plan Deployment

```bash
# Review the planned infrastructure changes
terraform plan
```

This command will show you:
- All resources that will be created
- Dependencies between resources  
- Any potential issues with your configuration

### 5. Deploy Infrastructure

```bash
# Apply the Terraform configuration
terraform apply
```

**Deployment Process:**
1. **Resource Creation Order**: Terraform will create resources in the correct dependency order
2. **Duration**: Full deployment typically takes 15-20 minutes
3. **Monitoring**: Watch the output for any errors or warnings
4. **Confirmation**: Type `yes` when prompted to proceed with deployment

**What Gets Created:**

- **HCP Resources**:
  - HashiCorp Virtual Network (HVN) with CIDR `172.25.16.0/20`
  - Vault Plus cluster with public endpoint access
  - Admin token for initial Vault access

- **AWS Resources**:
  - VPC with CIDR `10.0.0.0/16` (configurable)
  - Public and private subnets across multiple AZs
  - Internet Gateway and NAT Gateways
  - VPC peering connection to HCP HVN
  - DocumentDB cluster with security groups
  - EC2 bastion host with application services
  - Application Load Balancer with SSL certificate
  - Security groups and routing tables

- **Keycloak Resources**:
  - Realm configuration (confused-deputy-realm)
  - Client applications for web and API components
  - User groups for role-based access control (dbread, dbadmin)
  - Test users (alice, bob) with appropriate group memberships
  - Token exchange policies

- **Vault Configuration**:
  - JWT authentication method configured for Keycloak
  - Database secrets engine for DocumentDB
  - Policies for different access levels
  - Identity groups mapped to Keycloak groups

## Infrastructure Teardown

### Destroy Infrastructure

When you need to tear down the infrastructure:

```bash
# Destroy all Terraform-managed resources
terraform destroy
```

### Selective Resource Management

```bash
# Destroy specific resources
terraform destroy -target=module.bastion

# Recreate specific resources  
terraform apply -target=module.aws_documentdb

# Plan changes for specific resources
terraform plan -target=module.vault_auth
```

## Post-Deployment Configuration

After successful deployment, Terraform will output important connection details and URLs. Use these outputs to access and configure your deployed services.

### Access Information

```bash
# Get all Terraform outputs
terraform output

# Get specific outputs
terraform output vault_public_endpoint_url
terraform output bastion_public_ip
terraform output documentdb_cluster_endpoint
terraform output alb_https_url
```

### Application Deployment

The bastion host comes pre-configured with:
- Docker and Docker Compose for container deployment
- MongoDB tools for database management

### Next Steps

1. **Access Vault**: Use the admin token to review configured policies, AWS DocumentDB secrets engine, JWT authentication method and identity groups
2. **Database Setup**: Connect to DocumentDB and review the collection (produts) and sample documents
3. **Application Deployment**: Deploy your agentic applications to the bastion host using ../docker-compose


## Module Structure

```
terraform/
├── main.tf                    # Main infrastructure orchestration
├── variables.tf              # Input variable definitions  
├── outputs.tf               # Output value definitions
├── providers.tf             # Provider configurations
├── terraform.tfvars.example # Example configuration file
└── modules/
    ├── hcp-vault/           # HCP HVN and Vault cluster
    ├── aws-networking/      # VPC, subnets, and connectivity
    ├── aws-documentdb/      # DocumentDB cluster and security
    ├── bastion/            # EC2 bastion with application services
    ├── keycloak/           # Keycloak realm and client configuration
    └── vault-auth/         # Vault authentication configuration
```

## Network Configuration

### CIDR Blocks (Non-Overlapping)
- **HCP HVN**: `172.25.16.0/20` (172.25.16.1 - 172.25.31.254)
- **AWS VPC**: `10.0.0.0/16` (10.0.0.1 - 10.0.255.254)
- **Public Subnets**: `10.0.1.0/24`, `10.0.2.0/24`
- **Private Subnets**: `10.0.10.0/24`, `10.0.20.0/24`

### Security Groups
- **DocumentDB**: Allows MongoDB port 27017 from VPC and HVN CIDR blocks
- **Bastion**: Allows SSH (22) and HTTPS (443) with controlled access
- **Application Load Balancer**: Allows HTTP (80) and HTTPS (443) from internet

---

**⚠️ Important**: This infrastructure creates billable resources in HCP and AWS. Monitor costs and destroy resources when not needed for development/testing purposes.
