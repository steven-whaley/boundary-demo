# 9-18-2023

* Added delay for storage bucket creation to allow worker to come up and register first. 
* Added TFC deployment module to build the init and targets workspaces in TFC
* Added username templating for SSH cert target
  - Users pie_user and pie_user2 can be used to log in via SSH certificates to the ssh-cert-target
* Windows target is now created as a domain controller

# 9-7-2023

* Changed Okta account provisioning process.  
  - Terraform code now creates the Okta Users and Groups so they do not need to be pre-created.  
* Added session recording configuration to ssh target
  - Session recording buckets cannot be deleted so tearing down the environment requires removing both the bucket and pie_org objects from state
* Setting the region variable on the workspaces actually works properly now
  - Tested deploying to us-west-2, us-east-1 and eu-west-1
* The windows target now gets an Administrator password set on it at creation time using the admin_pass variable in the eks workspace
* The TF code now generates an AWS key pair to use, rather than requiring a pre-existing one.  
  - The public key to to use to create this key pair is set in the public_key variable on the eks workspace
