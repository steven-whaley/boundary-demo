# 7-9-2023

* Changed Okta account provisioning process.  
  - Terraform code now creates the Okta Users and Groups so they do not need to be pre-created.  
* Added session recording configuration to ssh target
  - Session recording buckets cannot be deleted so tearing down the environment requires removing both the bucket and pie_org objects from state
* Setting the region variable on the workspaces actually works properly now
  - Tested deploying to us-west-2, us-east-1 and eu-west-1
* The windows target now gets an Administrator password set on it at creation time using the admin_pass variable in the eks workspace
* The TF code now generates an AWS key pair to use, rather than requiring a pre-existing one.  
  - The public key to to use to create this key pair is set in the public_key variable on the eks workspace
