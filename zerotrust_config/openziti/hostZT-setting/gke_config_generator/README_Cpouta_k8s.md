# General concept
```pgsql
                         ┌───────────────────────────┐
                         │        Public Internet    │
                         └──────────────┬────────────┘
                                        │
                    ┌───────────────────┴───────────────────┐
                    │                                       │
        [ Floating IP #1 ]                        [ Floating IP #2 ]
        Bastion / Control VM                       Traefik Ingress (Cluster)
        - SSH / k8s / admin access                 - Single public entrypoint
        - Manage internal nodes                    - Routes to services via
                                                    hostname/path
                    │                                       │
                    └────────────────────┬──────────────────┘
                                         │
                              ┌──────────▼──────────┐
                              │   Neutron Router    │
                              │ NAT to external net │
                              └──────────┬──────────┘
                                         │
                           Internal Network (CIDR)
                              192.168.132.0/24
                                         │
            ┌──────────────────┬────────┴────────┬──────────────────┐
            │                  │                 │                  │
   Bastion / Ctrl VM   Traefik Ingress VM   Worker Node 1    Worker Node 2
   (192.168.132.2)     (192.168.132.3)      (192.168.132.4)  (192.168.132.5)
   - Has Floating IP   - Has Floating IP    - Internal only  - Internal only
   - Admin only        - Routes traffic     - Runs workloads - Runs workloads
                        to internal
                        services

```



