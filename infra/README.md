# Provisioning sequence

Run all commands from `infra/`.

## Prerequisites

- Valid AWS credentials in the current shell.
- Terraform installed.

## Provision only `common` and `servers`

1. Create the generated directory and placeholder files needed before bootstrap artifacts exist:

   ```bash
   mkdir -p generated
   touch generated/vault_token
   ```

2. Format and initialize Terraform:

   ```bash
   terraform fmt -recursive
   terraform init -input=false
   ```

3. Validate the configuration:

   ```bash
   terraform validate
   ```

4. Review and apply the shared infrastructure first:

   ```bash
   terraform plan -input=false -target=module.common
   terraform apply -input=false -auto-approve -target=module.common
   ```

5. After `module.common` completes successfully, review and apply the servers:

   ```bash
   terraform plan -input=false -target=module.servers
   terraform apply -input=false -auto-approve -target=module.servers
   ```

6. Stop here. Do **not** provision:

- `module.clients`
- `module.workload-identity`

## Notes

- `module.common` creates `generated/ssh_key`.
- `module.servers` bootstraps Vault and writes `generated/vault_token` and `generated/nomad_management_token`.
- If Terraform returns `InvalidClientTokenId`, refresh or replace the AWS credentials in your shell and rerun step 4.
