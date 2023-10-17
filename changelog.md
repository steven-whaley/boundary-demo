# 10-17-2023
* Promoted cost-control branch to main
* Cost control branch includes the following changes
  * Replaced EKS cluster with EC2 instance running K3s
  * Replaced RDS database with Postgres DB running under EKS
  * K8s target uses Vault K8s secret engine to generate SA token
    * k8s-connect.sh script avalable in /scripts folder to set up K8s auth environment using boundary connect command
  * Replaced pie_user2@boundary.lab with global_user@boundary.lab in Okta.  global_user has the ability to connect to all targets
  