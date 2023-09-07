# Boundary Demo

## Demo Environment
This terraform code builds an HCP Boundary enviroment that inclues connectivity to HCP Vault for credential brokering and injection, Okta integration for OIDC authentication and managed groups, and a number of AWS resources that are used as workers and Boundary targets.  

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
This repo was built to run on Terraform Cloud or Enterprise.  It uses the tfe_outputs data source to pass parameters from the init module to the build module.  If you want to run this locally you will need to modify the code to use cross state sharing to populate those values.  Additionally, you will need to update or remote the cloud provider block to match your Terraform configuration. 

This repo consists of two modules that need to be run in the below order:
 
**boundary-demo-init** - This module builds an HCP Boundary Cluster and HCP Vault Cluster along with an associated HVN for the Vault Cluster.  
**boundary-demo-eks** - This module does the bulk of the work, building out all of the Boundary and Vault configuration as well as the AWS components used as workers and targets.

#### boundary-demo-init
| Variable | Type | Purpose |
| --------- | -------- | -------- |
| boundary_user | terraform | The user name you would like to use for the default admin user created in the HCP Boundary Cluster |
| boundary_password | terraform | The password you would like to use for the default admin user created in the HCP Boundary Cluster |
| region | terraform | The AWS region into which to deploy the Hashicorp Virtual Network |
| HCP_CLIENT_ID | environment | The Client ID used to authenticate to HCP |
| HCP_CLIENT_SECRET | environment | The Secret Key used to authenticate to HCP |


#### boundary-demo-eks
| Variable | Type | Purpose |
| --------- | -------- | -------- |
| region | terraform | The AWS region into which to deploy the worker and targets |
| boundary_user | terraform | The Boundary admin user that will be set in the provider | 
| boundary_password | terraform | The Boundary admin user password that will be set in the provider |
| db_user | terraform | The username to set on the Postgres database Boundary target |
| db_password | terraform | The password to set on the Postgres database Boundary target |
| okta_baseurl | terraform | The base url for the Okta organization used for OIDC integration.  Probably okta.com |
| okta_org_name | terraform | The organization name for the Okta organization use for OIDC integration i.e. dev-32201783 |
| okta_user_password | terraform | The password to set on the PIE, DEV and IT users created in Okta |
| HCP_CLIENT_ID | environment | The Client ID used to authenticate the HCP provider |
| HCP_CLIENT_SECRET | environment | The Secret Key used to authenticate the HCP provider |
| OKTA_API_TOKEN | environment | The token used to authenticate the Okta provider |
| TFE_TOKEN | environment | The token used to authenticate the Terraform provider to use the tfe_outputs data source |
| AWS_ACCESS_KEY_ID | environment | The AWS Access Key used to authenticate the AWS provider |
| AWS_SECRET_ACCESS_KEY | environment | The AWS Secret Key used to authenticate the AWS provider |

**Notes**
- If you do not wish to use the Okta integration you can delete or comment out the okta.tf file.  
- The Dynamic Host Set setup uses an IAM role and User configuration that is specific to Hashicorp Employee AWS sandbox accounts.  If used in account without restrictions on the ability to create IAM users and policies then you will want to modify the configuration at the top of the boundary.tf config file to create the required IAM user and policy directly.  

### To Build
Set the variables to appropriate values and update the cloud block in the providers.tf files in each module as appropriate.  
Init and apply the boundary-demo-init terraform first

`boundary-demo-init % terraform init`

`boundary-demo-init % terraform apply -auto-approve`

Once the boundary-demo-init run has completed init and apply the boundary-demo-eks terraform

`boundary-demo-eks % terraform init`

`boundary-demo-eks % terraform apply -auto-approve`

**Notes**: 
- The terraform code is generally stable and completes in a single run but if you experience issues a second run is usually enough to correct them.  
- If the self-managed worker does not come up properly you can rebuild it by tainting the boundary_worker and aws_instance resources in the created in the worker.tf file and then rerunning the terraform apply on the boundary-demo-eks workspace.  

`terraform taint boundary_worker.hcp_pki_worker`

`terraform taint aws_instance.worker`

### To Destroy
The TF code creates a Session Recording Bucket object in the pie_org scope.  Boundary does not currently support deleting Session Recording Buckets so when attempting to run `terraform destroy` TF will throw an error.  This will prevent both the bucket from being removed and the associated pie_org scope in Boundary (since the bucket is a member of that scope).  Currently the workaround is to remove both the bucket and the pie_org object from TF state and then completely destroy the eks workspace.  Once that's completed run a destroy on the init workspace to delete the Boundary cluster, which will also delete the project and session recording bucket.  

## Connecting to Targets
If you are using the Okta integration then:
- Members of the dev_users group in Okta have permissions to connect to the targets in the dev_w2_project scope
- Members of the pie_users group in Okta have permissions to connect to the targets in the pie_w2_project scope
- Members of the it_users group in Okta have permissions to connect to the targets in the it_w2_project scope

### Connect to the SSH certificate target
`boundary connect ssh -target-scope-name pie_aws_project -target-name pie-ssh-cert-target`

### Connecting to SSH TCP taget with brokered credentials for some admin user configured on the server
You can use the private key that matches the public key supplied in the public_key terraform variable to connect to the SSH target by passing the -i flag to ssh

`boundary connect ssh -target-scope-name pie_aws_project -target-name pie-ssh-tcp-target -- -l ec2-user -i <path/to/private_key>`

### Connect to the K8s target
You will still need credentials to connect to the EKS cluster via K8s, which you can get via the AWS CLI.  Be sure to set the appropriate region where you deployed your AWS resources.

`aws eks update-kubeconfig --name boundary-demo-cluster --region $AWS_REGION`

`boundary connect kube -target-scope-name pie_aws_project -target-name pie-k8s-target -- get pods`

### Connect to the Postgres database target
`boundary connect postgres -target-scope-name dev_aws_project -target-name dev-db-target -dbname postgres`

### Connect to the RDP target
**Username:** Administrator   
**Password:** The value of the *admin_pass* terraform variable in the boundary-demo-eks workspace

**On Windows**

`boundary connect rdp -target-scope-name it_aws_project -target-name it-rdp-target `

**On Mac**

The Mac RDP client requires using -exec to open it and the sleep command at the end controls how long before the session closes.  This is a limitation specifically on the RDP client on newer versions of OSX and has nothing to do with Boundary specifically.   

`boundary connect rdp -exec bash -target-scope-name it_aws_project -target-name it-rdp-target -- -c "open rdp://full%20address=s={{boundary.addr}} && sleep 600"`