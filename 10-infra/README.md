[< back](../README.md)

# 10-infra

In this stage we create all the infrastructure that the homelab stands on.

- the VMs ([cloud-init](https://cloud-init.io) Ubuntu 22.04 LTS) and their [Proxmox](https://www.proxmox.com) configuration
- the network bridges, LAN plus an internal network
- S3 buckets and the CSI credentials
- the inventory and infra values the later stages consume

## VMs

We create the VMs for the [Kubernetes](https://kubernetes.io) cluster, and the VM that will run the [Tailscale](https://tailscale.com) VPN such that I can have remote access to my home network.

## Networking

Each VM has two virtual NICs, each for a different purpose.

- LAN network: each VM gets an IP on the LAN such that it can be reached directly from it.
- Internal network: configured without a gateway, purely for VMs to talk to each other without going through the LAN.

## State

State and secret variables, as stated in [the main README](../README.md), are encrypted in place with [SOPS](https://github.com/getsops/sops) such that they can't be read by you (sorry!).
