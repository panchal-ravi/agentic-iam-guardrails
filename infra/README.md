# Provisioning sequence

Run all commands from `infra/`.

## Prerequisites

- Valid AWS credentials in the current shell.
- Terraform installed.
- A base AMI built for this environment before applying the Terraform modules. Follow the detailed Packer workflow in [`ami/base_image/README.md`](./ami/base_image/README.md).

## Build the base AMI

Before provisioning the Terraform modules, build the base image used by the deployment:

1. Move into the Packer directory:

   ```bash
   cd ami/base_image
   ```

2. Follow the full instructions in [`ami/base_image/README.md`](./ami/base_image/README.md) to review `variables.pkrvars.hcl`, initialize Packer, validate the template, and build the AMI.

3. Return to the Terraform root:

   ```bash
   cd ../..
   ```

## Apply modules in order

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

4. Review and apply `common` first:

   ```bash
   terraform plan -input=false -target=module.common
   terraform apply -input=false -auto-approve -target=module.common
   ```

5. After `module.common` completes successfully, review and apply `servers`:

   ```bash
   terraform plan -input=false -target=module.servers
   terraform apply -input=false -auto-approve -target=module.servers
   ```

6. After `module.servers` completes successfully, review and apply `client-k8s` (`module.consul_client_k8s`):

   ```bash
   terraform plan -input=false -target=module.consul_client_k8s
   terraform apply -input=false -auto-approve -target=module.consul_client_k8s
   ```

7. After `module.consul_client_k8s` completes successfully, review and apply `observability`:

   ```bash
   terraform plan -input=false -target=module.observability
   terraform apply -input=false -auto-approve -target=module.observability
   ```

8. Stop here. Do **not** provision:

- `module.clients`
- `module.workload-identity`

## Notes

- `module.common` creates `generated/ssh_key`.
- `module.servers` bootstraps Vault and writes `generated/vault_token` and `generated/nomad_management_token`.
- `module.consul_client_k8s` installs the Consul components needed in the EKS cluster after the servers are available.
- `module.observability` installs `kube-prometheus-stack`, Loki, and Promtail into the `monitoring` namespace using Helm values from `config/observability/`.
- Grafana is deployed by `kube-prometheus-stack` and is preconfigured with a Loki datasource pointing at `loki-gateway.monitoring.svc.cluster.local`.
- Loki is configured in single-binary mode with a single replica, filesystem storage, and both `chunksCache` and `resultsCache` disabled for the demo environment.
- Promtail extracts a top-level JSON `request_id` field from container logs and sends it to Loki as a label.
- If Terraform returns `InvalidClientTokenId`, refresh or replace the AWS credentials in your shell and rerun step 4.
