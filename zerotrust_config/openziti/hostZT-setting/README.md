# ZT
![Figure to show the setting](ZThost_setting.svg)

### Note and prepare for setting
```bash
ssh-copy-id -i ~/.ssh/<public_key> <user>@<device IP>

ssh <username>@$(terraform output -raw controller_ip)  

sudo ss -tlnp | grep ziti

# check policy
ziti edge policy-advisor identities -q

```
## Terraform base

- setting a VM gcp for openziti 
- loading basic installation for openZT, but need to add more configuration later (check more doc from [ZT deployment](https://openziti.io/docs/guides/deployments/linux/controller/deploy))

```bash
terraform init 
terraform init -upgrade
terraform apply
```

## Controller setting along with router at cloud
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

- to run message-queue
```bash
export OPENZITI="true"; uv run python ml_consumer.py
```

# Edge
##  setting loadbalancer with nginx 
- remember to start the service 
```bash
http {
    upstream backend_servers {
        server preprocessing.ziti-controller.private:5010;
    }

    server {
        listen 5009;

        location /preprocessing {
            proxy_pass http://backend_servers;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```

## setting router at the edge
- execute startup_edgerouter.sh on the machine presenting the router
- update the PUBLIC_IP from the controller and the router of the cloud

```bash

chmod +x startup_edgerouter
sudo ./startup_edgerouter.sh

sudo ss -tlnp | grep ziti
```

# Sum up
- cloud setting
```bash
cd cloud-gcp

terraform apply

```
- edit IP address from cloud, edge router, edge application, and sensors
```bash
CTRL_IP=$(cd cloud-gcp && terraform output -raw controller_ip)
CLOUD_ROUTER_IP=$(cd cloud-gcp && terraform output -raw controller_ip)

EDGE_ROUTER_IP=""
EDGE_APP_IP=""
SENSOR_IP_2=""
SENSOR_IP_1=""
```

- run
```bash
./script_settup_sensor_edge.sh
```

# Sensor 
```bash
# 0 copy image
scp -r image aaltosea@<sensor>:/home/aaltosea/hong3nguyen/loadgen/

# 1 Install uv for hong3nguyen
curl -Ls https://astral.sh/uv/install.sh | bash

# 2 Setup PATH  shell permanently
source $HOME/.local/bin/env
#echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/hong3nguyen/.bashrc

# 3 Use uv as hong3nguyen
cd /home/hong3nguyen/loadgen && $HOME/.local/bin/uv venv install 

#  set python version
uv python pin 3.10.12

# 4 run
uv run python client_processing.py --url http://loadbalancer.ziti-controller.private:5009/preprocessing

```

## Debug
```bash
tail -f /var/log/ziti-edge-tunnel.log


# check nginx works or not 
# Test config is valid:
sudo nginx -t

# Restart nginx:
sudo systemctl restart nginx

```

- ziti
```bash

ziti edge list service-policies 'limit 1000'
```

**After changing router attribute, affecting the router policies, need to reload the ziit-edge-tunnel for all services**

- remove edge services/cloud
```bash
#!/bin/bash

# === Service Policies ===
ziti edge delete service-policy "loadbalancer-bind-policy"
ziti edge delete service-policy "loadbalancer-dial-policy"
ziti edge delete service-policy "preprocessing-bind-policy"
ziti edge delete service-policy "preprocessing-dial-policy"
ziti edge delete service-policy "ensemble-bind-policy"
ziti edge delete service-policy "ensemble-dial-policy"
ziti edge delete service-policy "mobilenetv2-bind-policy"
ziti edge delete service-policy "mobilenetv2-dial-policy"
ziti edge delete service-policy "efficientnetb0-bind-policy"
ziti edge delete service-policy "efficientnetb0-dial-policy"
ziti edge delete service-policy "message-queue-bind-policy"
ziti edge delete service-policy "message-queue-dial-policy"
ziti edge delete service-policy "database-bind-policy"
ziti edge delete service-policy "database-dial-policy"

# === Services ===
ziti edge delete service "loadbalancer-service"
ziti edge delete service "preprocessing-service"
ziti edge delete service "ensemble-service"
ziti edge delete service "mobilenetv2-service"
ziti edge delete service "efficientnetb0-service"
ziti edge delete service "message-queue-service"
ziti edge delete service "database-service"

# === Configs ===
ziti edge delete config "client-intercept-config"
ziti edge delete config "loadbalancer-host-config"
ziti edge delete config "loadbalancer-intercept-config"
ziti edge delete config "preprocessing-host-config"
ziti edge delete config "preprocessing-intercept-config"
ziti edge delete config "ensemble-host-config"
ziti edge delete config "ensemble-intercept-mobilenetv2-config"
ziti edge delete config "mobilenetv2-host-config"
ziti edge delete config "ensemble-intercept-efficientnetb0-config"
ziti edge delete config "efficientnetb0-host-config"
ziti edge delete config "ensemble-intercept-message-queue-config"
ziti edge delete config "message-queue-host-config"
ziti edge delete config "message-queue-intercept-database-config"
ziti edge delete config "database-host-config"

# === Edge Router Policies ===
ziti edge delete edge-router-policy "public-routers"
ziti edge delete service-edge-router-policy "public-routers"

ziti edge delete edge-router-policy "allow.id.router_edge"
ziti edge delete service-edge-router-policy "allow.svc.router_edge"

ziti edge delete edge-router-policy "allow.id.router_cloud"
ziti edge delete service-edge-router-policy "allow.svc.router_cloud"

echo "✅ Cleanup completed."

```


>  uv run python client_processing.py --url http://loadbalancer.ziti-controller.private:5009/preprocessing  --ds_path ../image
> locust -f /home/aaltosea/hong3nguyen/loadgen/load_test_para.py --ds-path /home/aaltosea/hong3nguyen/image/ --device-id $(hostname) --host http://loadbalancer.ziti-controller.private:5009 --headless --users 10 --spawn-rate 1 --run-time 1m --csv /home/aaltosea/hong3nguyen/locust_results.csv --csv-full-history


# Note
- The current setting allow for add routers and very flexibility

- Somethings could be improved:
  - the add/delete cloud routers: since the Openziti cloud setting is based on centralization, our setting now support a single pair of ctrl and router at cloud
  - docker containers need to be build before, although we can give some parameters to allow the docker be built but yeah if have time to do it more
  - id, roles, policy could be find a way to define easier
