data "tfe_outputs" "boundary_demo_init" {
  organization = var.organization
  workspace    = "boundary-demo-init"
}

data "tfe_outputs" "boundary_demo_targets" {
  organization = var.organization
  workspace    = "boundary-demo-targets"
}