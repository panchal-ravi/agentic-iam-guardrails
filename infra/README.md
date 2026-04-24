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

8. Optionally apply `edr` (Uptycs `k8sosquery` and `kubequery` Helm releases). The releases are gated by `enable_k8sosquery` and `enable_kubequery` in `terraform.tfvars`; skip this step if both are `false`:

   ```bash
   terraform plan -input=false -target=module.edr
   terraform apply -input=false -auto-approve -target=module.edr
   ```

9. Stop here. Do **not** provision:

- `module.clients`
- `module.workload-identity`

## Notes

- `module.common` creates `generated/ssh_key`.
- `module.servers` bootstraps Vault and writes `generated/vault_token` and `generated/nomad_management_token`.
- `module.consul_client_k8s` installs the Consul components needed in the EKS cluster after the servers are available.
- `module.observability` installs the Grafana + Prometheus + Loki stack into the `monitoring` namespace using Helm values from `config/observability/`:
  - `kube-prometheus-stack` provides Prometheus (with an extra `kubernetes-pods-all` scrape job for annotated pods) and Grafana, preconfigured with a Loki datasource pointing at `loki-gateway.monitoring.svc.cluster.local`.
  - Loki runs in single-binary mode with one replica, filesystem storage (10Gi `gp2` PVC), and both `chunksCache` and `resultsCache` disabled for the demo environment.
  - Promtail ships container logs to Loki, drops `/metrics` and self-logs (Loki, Grafana, Consul dataplane noise), and extracts a top-level JSON `request_id` field as a Loki label.
- `module.edr` installs the optional Uptycs `k8sosquery` and `kubequery` Helm releases into their own namespaces, each gated by its `enable_*` variable.
- If Terraform returns `InvalidClientTokenId`, refresh or replace the AWS credentials in your shell and rerun step 4.
