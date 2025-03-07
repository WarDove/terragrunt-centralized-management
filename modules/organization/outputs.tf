output "org_ou_ids" {
  value = { for org_ou_id in aws_organizations_organizational_unit.main : lower(org_ou_id.name) => org_ou_id.id }
}

output "org_root_id" {
  value = aws_organizations_organization.main.roots[0].id
}

output "org_id" {
  value = aws_organizations_organization.main.id
}