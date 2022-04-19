# Open Ondemand on docker

## Volumes

- `/etc/ood` must be mounted as a persistent volume since generated configurations will be stored here, including yours.
- `/etc/slurm` must contains `slurm.conf` for Slurm.
- `/secrets/sssd` must contains `sssd.conf` for LDAP.
- `/secrets/munge` must contains `munge.key` for Slurm auth.

## Ports

- 8080 HTTP
- 5556 OIDC (HTTP auth)

Recommendation: Use a reverse proxy other than the one included in the docker to add SSL.
