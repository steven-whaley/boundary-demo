data "tfe_outputs" "boundary_demo_init" {
  organization = "swhashi"
  workspace    = "boundary-demo-init"
}

data "tfe_outputs" "boundary_demo_targets" {
  organization = "swhashi"
  workspace    = "boundary-demo-targets"
}