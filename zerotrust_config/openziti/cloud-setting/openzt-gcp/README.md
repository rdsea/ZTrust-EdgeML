#  GCP

## Terraform base

- setting a VM gcp for openziti 
- loading basic installation for openZT, but need to add more configuration later (check more doc from [ZT deployment](https://openziti.io/docs/guides/deployments/linux/controller/deploy))

```bash
terraform init 
terraform init -upgrade
terraform apply
```

## Controller setting
- copy from ctrl_boostrap.env to /opt/openziti/etc/controller/bootstrap.env

```env
# the controller's permanent FQDN (required)
ZITI_CTRL_ADVERTISED_ADDRESS='ctrl.cloud.hong3nguyen.com'

# the controller's advertised and listening port (default: 1280)
ZITI_CTRL_ADVERTISED_PORT='1280'

# name of the default user (default: admin)
ZITI_USER='admin'

# password will be scrubbed from this file after creating default admin during database initialization
ZITI_PWD='admin'

# additional arguments to: ziti create config controller
ZITI_BOOTSTRAP_CONFIG_ARGS=''
```

```bash
sudo /opt/openziti/etc/controller/bootstrap.bash

sudo systemctl enable --now ziti-controller.service

sudo ss -tlnp | grep ziti
```

- Using a ZT console to connect 
  - edit /etc/hosts file with 
```bash
echo "<Public_IP_VM> ctrl.cloud.hong3nguyen.com" | sudo tee -a /etc/hosts

# if using the VM machine
echo "127.0.0.1 ctrl.cloud.hong3nguyen.com" | sudo tee -a /etc/hosts

```
- login with the command:
> ziti edge login https://ctrl.cloud.hong3nguyen.com:1280

## Router setting
- generate a JWT token for the router
```bash
ziti edge create edge-router "router_cloud" \
    --jwt-output-file router_cloud.jwt \
    --tunneler-enabled
```

- edit the configuration file

```env
# the controller's DNS name (required)
ZITI_CTRL_ADVERTISED_ADDRESS='ctrl.cloud.hong3nguyen.com'

# the controller's port (default: 1280)
ZITI_CTRL_ADVERTISED_PORT='1280'

# this router's DNS name or IP address (default: localhost)
ZITI_ROUTER_ADVERTISED_ADDRESS='router.cloud.hong3nguyen.com'

# this router's port (default: 3022), if <= 1024, then grant the NET_BIND_SERVICE ambient capability in
# /etc/systemd/system/ziti-router.service.d/override.conf
ZITI_ROUTER_PORT='3022'

# token will be scrubbed from this file after enrollment
ZITI_ENROLL_TOKEN='/home/hong3nguyen/router_cloud.jwt'

# additional arguments to:
#  ziti create config ${ZITI_ROUTER_TYPE:-edge} --tunnelerMode ${ZITI_ROUTER_MODE:-host}
ZITI_BOOTSTRAP_CONFIG_ARGS=''
```
