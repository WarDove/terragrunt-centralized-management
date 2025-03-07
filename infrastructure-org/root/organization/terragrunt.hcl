include "root" {
  path = find_in_parent_folders()
}

inputs = {
  // SCPs
  deny_cloudtrail_changes = true
  deny_config_changes     = true
}