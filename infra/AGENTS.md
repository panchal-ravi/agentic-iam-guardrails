# Copilot instructions for this repository

## Scope and Terraform root

This directory is the Terraform root for the repository. Run Terraform from `infra/` or use `terraform -chdir=infra ...`.

Prefer small, reviewable changes that preserve the current bootstrap flow. Do not restructure modules, rename generated artifacts, or change resource naming conventions unless the task explicitly requires it.

## Recommended Terraform workflow

Use this order for any Terraform change:

```bash
terraform -chdir=infra fmt -recursive
terraform -chdir=infra init
terraform -chdir=infra validate
terraform -chdir=infra plan
```

If you need a narrower verification pass, target the module you changed:

```bash
terraform -chdir=infra plan -target=module.common
terraform -chdir=infra plan -target=module.servers
terraform -chdir=infra plan -target=module.clients
terraform -chdir=infra plan -target='module.workload-identity'
```

There is no dedicated automated test suite here, so `fmt`, `validate`, and a relevant `plan` are the expected verification steps.

## Global Terraform authoring guidance

- Follow HashiCorp style conventions for Terraform.
- Keep files organized by purpose: version requirements in `providers.tf` or `terraform.tf`, providers in `providers.tf`, primary composition in `main.tf`, inputs in `variables.tf`, outputs in `outputs.tf`, and locals in `locals` blocks or `locals.tf` when needed.
- Use lowercase snake_case for variable names, locals, outputs, and resource names.
- Add `description` and `type` for every new variable.
- Add `description` for every new output, and mark sensitive outputs with `sensitive = true`.
- Prefer explicit types such as `list(string)` over loose types such as `list(any)`.
- Prefer `for_each` over `count` when creating multiple named resources. Use `count` mainly for conditional creation.
- Keep arguments and nested blocks ordered consistently, with meta-arguments such as `count`, `for_each`, and `depends_on` near the top of a block.
- Do not hardcode secrets, tokens, private keys, or certificates in `.tf` files.
- Preserve provider version constraints unless the task is specifically about upgrading providers.

## Repository-specific architecture

`main.tf` is the composition root. It creates a deployment-scoped identifier from `var.owner` and `random_string.suffix`, then wires together four child modules:

- `module.common`: shared AWS infrastructure such as networking, security groups, load balancer, IAM instance profile, bastion access, and generated SSH material.
- `module.servers`: the control-plane instance that bootstraps Vault, Consul, and Nomad server components and emits certificates, tokens, and other bootstrap artifacts.
- `module.clients`: Nomad client instances that consume server-generated PKI and token material.
- `module.workload-identity`: post-bootstrap identity configuration that uses the root `consul` and `vault` providers against the deployed control plane.

The root provider configuration is part of the runtime flow, not just static plumbing. In particular, the `vault` provider reads `generated/vault_token`, and the `consul` and `vault` providers depend on outputs from the infrastructure that Terraform is also creating.

## Change safety rules for this repo

- Treat `infra/generated/` as runtime-generated material, not hand-authored source. Do not replace reads from that directory with literals.
- Preserve the deployment naming pattern based on `local.deployment_id` so parallel environments do not collide.
- Keep module interfaces synchronized. If you change bootstrap, PKI, or token-related outputs in `module.servers`, update dependent inputs in `module.clients` or `module.workload-identity` in the same change.
- Be careful with `${path.root}` references. This codebase relies on root-relative paths for templates and generated artifacts.
- Expect plan diffs on bastion ingress when the operator IP changes; this repository intentionally scopes some access rules to the caller's current IP.
- Do not remove or casually alter lifecycle behavior on long-lived EC2 bootstrap instances without understanding the operational impact.

## Security expectations

- Prefer least-privilege changes for IAM policies, instance profiles, and security groups.
- Default to private networking unless public exposure is intentionally required.
- Avoid introducing new sensitive outputs unless they are necessary for operator workflows.
- If you must expose a secret-like value as an output or local file, mark it sensitive where Terraform supports that and keep the existing generated-file workflow intact.

## When updating Terraform in this repo

- Update related variables, outputs, and module wiring together.
- Re-run `terraform -chdir=infra fmt -recursive` after edits.
- Run `terraform -chdir=infra validate` after `init`.
- Run at least one relevant `terraform -chdir=infra plan` before finishing.
