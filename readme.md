# Boundary Demo

## Demo Environment
This terraform code builds an HCP Boundary enviroment that inclues connectivity to HCP Vault for credential brokering and injection, Okta integration for OIDC authentication and managed groups, and a number of AWS resources that are used as workers and Boundary targets.  

### Features
- SSH with Vault generated SSH Certificates and username templating
- RDP Target with brokered AD credentials from Vault LDAP Secrets Engine
- Okta integration using managed groups with different targets for each group
- Session Recording
- K8s target
- Database target with brokered credentials from Vault DB Secrets Engine
- Multi-hop using HCP ingress worker and private egress worker

### Boundary Organization Structure
![image](./org-structure.png)

### Demo Environment Diagram
![image](./diagram.png)

### Components
| Component | Purpose |
| ----------- | ----------- |
| HCP Boundary | Boundary Control Plane |
| HCP Vault | Boundary Credential Store |
| Boundary Worker | Boundary EC2 Worker |
| Okta | OIDC Authentication |
| EKS Cluster | K8s Target |
| EC2 Linux Instance | SSH Cert Auth Target |
| RDS Postgres Database | Database Target |
| EC2 Windows Instance | RDP Target |
| EC2 Bastion Host | For Troubleshooting |

## Setup
### Workspaces and Variables
This repo was built to run on Terraform Cloud or Enterprise.  It uses the tfe_outputs data source to pass parameters between the boundary_demo_init workspace and other workspaces.  If you want to run this locally you will need to modify the code to use cross state sharing to populate those values.  

The ***providers.tf*** file in each workspace includes a cloud block that targets a TFC/TFE organization.  You will need to update this block to reflect your TFC/TFE org name.  

This repo consists of four modules:
 
**boundary-demo-tfc-build** - This module is run using local terraform execution and build the boundary-demo-init and boundary-demo-targets workspaces in TFC/TFE

**boundary-demo-init** - This workspace builds an HCP Boundary cluster and HCP Vault cluster along with an associated HVN for the Vault cluster.  

**boundary-demo-targets** - This workspace does the bulk of the work, building out all of the Boundary and Vault configuration as well as the AWS components used as workers and targets.

**boundary-demo-ad-secrets** - This workspace configures the Vault LDAP secrets engine to generate dynamic AD credentials on the windows target and brokers those credentials to the it-rdp-target-admin Boundary target.


The following variables need to be set in the *boundary-demo-tfc-build* module.  These variables will be propogated into the TFC/TFE workspaces built by that module.  

| Variable | Type | Sensitive | Purpose |
| --------- | -------- | -------- | -------- |
| **organization** | terraform | No | The TFC/TFE Organization Name |
| **boundary_user** | terraform | No | The username the default admin user created in the HCP Boundary Cluster |
| **boundary_password** | terraform | Yes | The password of the default admin user created in the HCP Boundary Cluster |
| **region** | terraform | No | The AWS region into which to deploy the Hashicorp Virtual Network and AWS resources |
| **okta_baseurl** | terraform | No | The base url of the Okta organization to use for OIDC integration.  Usually okta.com |
| **okta_org_name** | terraform | No | The organization name of hte OKta organization to use for OIDC integration i.e dev-32201783 |
| **okta_user_password** | terraform | Yes | The password to set on the Okta users created and added to the Boundary application |
| **admin_pass** | terraform | Yes | The password to set for the Administrator account on the Windows target |
| **public_key** | terraform | No | The SSH public key to set on the AWS EC2 instances as the default login |
| **aws_varset** | terraform | No | The name of a pre-existing Variable Set that contains AWS credentials set as environment variables |
| **OKTA_API_TOKEN** | environment | Yes | The API token used to authenticate the Okta provider |
| **HCP_CLIENT_ID** | environment | Yes | The Client ID used to authenticate the HCP provider |
| **HCP_CLIENT_SECRET** | environment | Yes | The Secret Key used to authenticate the HCP provider |

It is recommended that you pass any variables marked sensitive as environment variables or through CLI flags.  

### To Build
- Set the non-sensitive variables for the *boundary-demo-tfc-build* module in a terraform.tfvars file.  
- Set the sensitive variables as environment variables. 

    - For example:

    - `export TF_VAR_HCP_CLIENT_SECRET=123456789`
- Update the **cloud block** in the providers.tf file in the *boundary-demo-init* and *boundary-demo-targets* workspaces to reflect your TFE/TFC organization name.  
- Once all variables have been set, perform a terraform init and apply on the *boundary-demo-tfc-build* module.  

    - `boundary-demo-tfc-build % terraform init`

    - `boundary-demo-tfc-build % terraform apply -auto-approve`

    - This will create two workspaces in your TFC environment: *boundary-demo-init* and *boundary-demo-targets*.  
- Run the *boundary-demo-init* workspace first.  

    - `boundary-demo-init % terraform init`

    - `boundary-demo-init % terraform apply -auto-approve`

- Run build the *boundary-demo-targets* workspace 

    - `boundary-demo-targets % terraform init`

    - `boundary-demo-targets % terraform apply -auto-approve`
    
- Wait about 10 minutes after building the *boundary-demo-targets* workspace for the rdp-target EC2 instance to finish running it's cloudinit script which requires two reboots.  The *boundary-demo-ad-secrets* workspace run will fail if the cloudinit has not completely finished.  

- Run the *boundary-demo-ad-secrets* workspace

    - `boundary-demo-ad-secrets % terraform init`
    
    - `boundary-demo-ad-secrets % terraform apply -auto-approve`

**Important Notes**
- If you do not wish to use the Okta integration you can delete or comment out the okta.tf file from the *boundary-demo-targets* folder in the repo.  
- The Dynamic Host Set setup uses an IAM role and User configuration that is specific to Hashicorp Employee AWS sandbox accounts.  If used in account without restrictions on the ability to create IAM users and policies then you will want to modify the configuration at the top of the boundary.tf config file to create the required IAM user and policy directly.  
- The terraform code is generally stable and completes in a single run but if you experience issues a second run is usually enough to correct them.  
- If the self-managed worker does not come up properly or dies for some reason you can rebuild it by tainting the boundary_worker and aws_instance resources in the created in the worker.tf file and then rerunning the terraform apply on the boundary-demo-eks workspace.  

    - `terraform taint boundary_worker.hcp_pki_worker`

    - `terraform taint aws_instance.worker`

### To Destroy
Destroy the workspaces in the reverse order that you created them.  Run a `terraform destroy` first on the *boundary-demo-ad-secrets* workspace, then on the *boundary-demo-targets* workspace, then on the *boundary-demo-init* workspace and finally on the *boundary-demo-tfc-build* module.  

The TF code creates a Session Recording Bucket object in the global scope.  **Boundary does not currently support deleting Session Recording Buckets so when attempting to run `terraform destroy` on the *boundary-demo-targets* workspace TF will throw an error.**  Currently the workaround is remove the boundary_storage_bucket resource from state and then run the destroy.  

- `terraform state rm boundary_storage_bucket.pie_session_recording_bucket` 

## Connecting to Targets
### Okta Users
When using the Okta integration four users are created in your directory.  

**Passwords** - All Okta users have the same password which is the value of the okta_user_password terraform variable that you set in the *boundary-demo-tfc-build* workspace. 

| User | Okta Group | Boundary Org | Description |
| --------- | -------- | -------- | -------- |
| pie_user@boundary.lab | pie_users | pie_org | Has rights to connect to all targets in PIE org |
| pie_user2@boundary.lab | pie_users | pie_org| Has rights to connect to all targets in PIE org |
| dev_user@boundary.lab | dev_users | dev_org | Has rights to connect to all targets in DEV org |
| it_user@boundary.lab | it_users | it_org | Has rights to connect to all targets in IT org |

  

### Available Targets
| Target | Org\Project | Credentials | Description |
| --------- | -------- | -------- | -------- |
| pie-ssh-cert-target | pie_org\pie_aws_project | **Injected** using Vault SSH Cert Secrets Engine | Connects to the SSH target as the logged in username.  **Only usable when logged in via Okta as pie_user or pie_user2** |
| pie-ssh-cert-target-admin | pie_org\pie_aws_project | **Injected** using Vault SSH Cert Secrets Engine | Connects to the SSH target as ec2-user |
| pie-ssh-tcp-target | pie_org\pie_aws_project | User supplied ssh key | Connect using user supplied SSH key |
| pie-k8s-target | pie_org\pie_aws_project | User supplied kubeconfig | Connect using user supplied kubeconfig |
| dev-db-target | dev_org\dev_aws_project | **Brokered** from Vault DB Secrets Engine | Connects using credentials brokered from Vault |
| it-rdp-target | it_org\it_aws_project | User supplied username and password | Connect using Administrator user and password set as admin_pass TF variable |
| it-rdp-target-admin | it_org\it_aws_project | **Brokered** from Vault LDAP Secrets Engine | Connect using username as password provided by Vault in connection info |

### Authenticate to Boundary
Connect as admin user.  The admin_auth_method_id can be found in the outputs of the boundary-demo-init workspace:
`boundary authenticate password -auth-method-id <admin_auth_method_id>`

Connect as Okta user:
`boundary authenticate`

### Connect to the SSH certificate target as Okta user

`boundary connect ssh -target-scope-name pie_aws_project -target-name pie-ssh-cert-target`

You can run this twice when logged in via Okta as pie_user and then as pie_user2 to show that Boundary is passing your identity on to Vault which providers you a certificate for the appropriate user.  

### Connect to the SSH certificate target as ec2-user admin account

`boundary connect ssh -target-scope-name pie_aws_project -target-name pie-ssh-cert-target-admin`

### Connect to SSH TCP target (no injected credentials)
When you set up the *boundary-demo-tfc-build* workspace you set a public key to install on the EC2 instances.  You will use the private key that matches that public key to log in to the SSH server.  You can use the -i flag to point to the private key.  

`boundary connect ssh -target-scope-name pie_aws_project -target-name pie-ssh-tcp-target -- -l ec2-user -i <path/to/private_key>`

### Connect to the K8s target
You will still need credentials to connect to the EKS cluster via K8s, which you can get via the AWS CLI.  Be sure to set the appropriate region where you deployed your AWS resources.  You will need the AWS CLI installed and configured to generate EKS credentials.  

`aws eks update-kubeconfig --name boundary-demo-cluster --region $AWS_REGION`

`boundary connect kube -target-scope-name pie_aws_project -target-name pie-k8s-target -- get nodes`

### Connect to the Postgres database target
`boundary connect postgres -target-scope-name dev_aws_project -target-name dev-db-target -dbname postgres`

### Connect to the RDP target with user supplied credentials
**Username:** BOUNDARY\Administrator   
**Password:** The value of the *admin_pass* terraform variable in the boundary-demo-eks workspace

**On Windows**

`boundary connect rdp -target-scope-name it_aws_project -target-name it-rdp-target `

**On Mac**

The Mac RDP client requires using -exec to open it and the sleep command at the end controls how long before the session closes.  This is a limitation specifically on the RDP client on newer versions of OSX and has nothing to do with Boundary specifically.   

`boundary connect rdp -exec bash -target-scope-name it_aws_project -target-name it-rdp-target -- -c "open rdp://full%20address=s={{boundary.addr}} && sleep 600"`

### Connect to the RDP target with Vault brokered Domain Admin credentials


**On Windows**

`boundary connect rdp -target-scope-name it_aws_project -target-name it-rdp-target-admin`

**On Mac**

The Mac RDP client requires using -exec to open it and the sleep command at the end controls how long before the session closes.  This is a limitation specifically on the RDP client on newer versions of OSX and has nothing to do with Boundary specifically.   

`boundary connect rdp -exec bash -target-scope-name it_aws_project -target-name it-rdp-target-admin -- -c "open rdp://full%20address=s={{boundary.addr}} && sleep 600"`