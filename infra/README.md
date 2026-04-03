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

5. After `module.common` completes successfully, optionally provision the observability stack in the EKS cluster:

   ```bash
   terraform plan -input=false -target=module.observability
   terraform apply -input=false -auto-approve -target=module.observability
   ```

6. After `module.common` completes successfully, review and apply the servers:

   ```bash
   terraform plan -input=false -target=module.servers
   terraform apply -input=false -auto-approve -target=module.servers
   ```

7. Stop here. Do **not** provision:

- `module.clients`
- `module.workload-identity`

## Notes

- `module.common` creates `generated/ssh_key`.
- `module.observability` installs `kube-prometheus-stack`, Loki, and Promtail into the `monitoring` namespace using Helm values from `config/observability/`.
- Grafana is deployed by `kube-prometheus-stack` and is preconfigured with a Loki datasource pointing at `loki-gateway.monitoring.svc.cluster.local`.
- Loki is configured in single-binary mode with a single replica, filesystem storage, and both `chunksCache` and `resultsCache` disabled for the demo environment.
- Promtail extracts a top-level JSON `request_id` field from container logs and sends it to Loki as a label.
- `module.servers` bootstraps Vault and writes `generated/vault_token` and `generated/nomad_management_token`.
- If Terraform returns `InvalidClientTokenId`, refresh or replace the AWS credentials in your shell and rerun step 4.
