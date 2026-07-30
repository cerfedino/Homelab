[< back](../README.md)

# 20-bootstrap

In this stage we run [Ansible](https://docs.ansible.com) against the VMs from `10-infra` and leave behind a working k3s cluster.

- node OS configuration
- one [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) instance per VM
- [kube-vip](https://kube-vip.io) for the floating VIPs
- [k3s](https://k3s.io) itself, and the [Tailscale](https://tailscale.com) VPN for remote access

## DNS

Every VM runs its own dnsmasq: it answers the lab's internal names and forwards everything else to upstream DNS servers. The reason for having dnsmasq on each VM is to make it such that the cluster doesnt depend on any single DNS node.

```mermaid
flowchart TB
    subgraph vm1 ["VM N"]
        coredns1((CoreDNS)) --> dnsmasq1((dnsmasq))
    end
    subgraph vm2 ["VM N+1"]
        coredns2((CoreDNS)) --> dnsmasq2((dnsmasq))
    end
    dnsmasq1 --> upstream[(upstream DNS)]
    dnsmasq2 --> upstream
```

## High availability

Having high availability _within_ the k3s cluster is very easy. But when it comes to accessing the cluster from the LAN it's different.

I can't point `kubectl` at any single node IP, because if that node goes down I lose access. Same goes for applications that are exposed to the LAN only through [Traefik](https://traefik.io).

Therefore I created a floating virtual IP for the control plane, and one for Traefik. The nodes periodically elect a leader node for each VIP, and that node will answer ARP requests as long as it is the leader. When a node goes down, another leader is elected and the VIP moves.

This way all my tools and applications can point at a single IP, and I am guaranteed that its answered by a live node.

```mermaid
flowchart LR
    client(["I'm looking for the cluster<br/>at IP 192.168.1.69"])
    subgraph vm1 ["VM 1 (leader)"]
        kubevip1((kube-vip))
    end
    subgraph vm2 ["VM 2 (dead)"]
        kubevip2((kube-vip))
    end
    client -.-> kubevip1
    client -.-> kubevip2
    kubevip1 == "IT'S ME!" ==> client
    style vm2 stroke:#999,color:#999,stroke-dasharray:5
    style kubevip2 stroke:#999,color:#999,stroke-dasharray:5
```
