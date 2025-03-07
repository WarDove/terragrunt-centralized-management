include "root" {
  path = find_in_parent_folders()
}

dependency "organization" {
  config_path = "../organization"
}

inputs = {
  org_id      = dependency.organization.outputs.org_id
  org_ou_ids  = dependency.organization.outputs.org_ou_ids
  org_root_id = dependency.organization.outputs.org_root_id
}