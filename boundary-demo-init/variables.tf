variable "public_key" {
  type        = string
  description = "The public key to use when creating the EC2 key pair to access AWS systems"
}

variable "region" {
  type        = string
  description = "The region to create instrastructure in"
  default     = "us-west-2"
}