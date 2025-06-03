# 
- Give network 192.168.132.0/24 for ziti and application
- add host to local to turn the host machine as the client (not yet test with docker client)
```bash
echo "192.168.132.2 ziti-edge-controller" | sudo tee -a /etc/hosts
echo "192.168.132.3 ziti-edge-router" | sudo tee -a /etc/hosts

```
- Clean all docker compose
```bash
docker compose -f docker-compose.yml down --volumes
docker compose -f ../ziti-deployment/docker-compose.yml down --volumes --remove-orphans
```

## Building docker (if needed)
```bash
cd applications/machine_learning/src/preprocessing
docker build -t rdsea/preprocessing -f Dockerfile.ziti ..

cd applications/machine_learning/src/ensemble
docker build -t rdsea/ensemble -f Dockerfile.ziti ..

# docker cp recursing_almeida:/object_classification/inference/onnx_model .
cd applications/machine_learning/src/inference
docker build -t rdsea/inference -f Dockerfile.cpu.ziti ..
```

## start ziti docker compose (options)
> docker compose -f ziti-deployment/docker-compose.yml up

## start setting up ZT to app
- Remove all previous key
```bash
sudo rm -r /tmp/*.json
sudo rm -r /tmp/*.jwt

```
- **run docker ps** to be sure the router and controller work well
- all key.jwt and key.json are in /tmp
> ./dung_create_id.sh

- add application services to the ziti network
```bash
ZITI_NETWORK="ziti-deployment_ziti"
SERVICES=(
  preprocessing-service
  ensemble
  efficientnetb0-service
  mobilenetv2-service
)

for service in "${SERVICES[@]}"; do
  echo "Connecting $service to $ZITI_NETWORK"
  cmd="docker network connect $ZITI_NETWORK $service"
  eval $cmd
done
```

# **All in a script**
- ./app/setting-ZT-2-app.sh <ziti-network-name>

> ./setting-ZT-2-app.sh ziti-deployment_ziti                                                                                                                           ─╯

## Testing with client

> sudo ziti-edge-tunnel run -i /tmp/object-detection-client.json                                                                                                       ─╯

> python client_processing.py --url http://preprocessing.ziti-controller.private:5010/preprocessing                                                                    ─╯

