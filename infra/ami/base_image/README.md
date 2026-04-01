# Base image build

This directory contains the Packer template used to build the AWS base AMI for the agentic runtime security demo environment.

The image is based on the latest `hc-base-ubuntu-2404-amd64-*` AMI in the selected region and bakes in the core runtime dependencies used by the demo, including:

- Java, `unzip`, `jq`, `net-tools`, `zsh`, and Oh My Zsh
- Envoy, installed with `func-e`
- Docker Engine, Buildx, and Compose
- CNI plugins and the Consul CNI plugin
- Nomad Enterprise
- Consul Enterprise

The resulting AMI is named `<owner>-consul-nomad-enterprise-<timestamp>` and tagged with the selected Consul and Nomad versions.

## Files

- `AWS_linux_image.pkr.hcl`: main Packer template and provisioning steps
- `variables.pkr.hcl`: input variable definitions and defaults
- `variables.pkrvars.hcl`: example variable values for a build

## Prerequisites

- Packer installed locally
- AWS credentials configured in your shell or AWS profile
- Permission to create temporary EC2 instances, EBS-backed AMIs, and related resources in the target region

## Build the base image

1. Move into this directory:

   ```bash
   cd infra/ami/base_image
   ```

2. Review and update `variables.pkrvars.hcl` for your environment. At minimum, confirm:

   - `owner`
   - `aws_region`
   - `consul_version`
   - `nomad_version`
   - `envoy_version`
   - `cni_version`
   - `consul_cni_version`

3. Initialize the Amazon plugin:

   ```bash
   packer init .
   ```

4. Validate the template with your variables:

   ```bash
   packer validate -var-file=variables.pkrvars.hcl AWS_linux_image.pkr.hcl
   ```

5. Build the AMI:

   ```bash
   packer build -var-file=variables.pkrvars.hcl AWS_linux_image.pkr.hcl
   ```

## Notes

- The build uses the Ubuntu `ubuntu` SSH user during provisioning.
- The AMI is created in the AWS region defined by `aws_region`.
- If you want different software versions, update `variables.pkrvars.hcl` before running `packer build`.
