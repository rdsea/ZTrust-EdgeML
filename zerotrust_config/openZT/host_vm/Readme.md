# 

## CSC infrastructure
- Authentication
```bash
source <OpenSTACK_RC>
```

  ### Infrastructure
  - Using cpouta project to create two VM
  - assign floating IP to the messageQ

  ```bash
  terraform init

  terraform apply

  ```
  ### ZTA


## GCP
- Authentication:
```bash
gloud auth login

gcloud auth login --update-adc 

```
  ### Infrastructure

```bash
python  

ziti edge login https://ctrl.cloud.hong3nguyen.com:1280 --yes -u admin -p admin
```


- Rash PI
```bash
locust -f load_test_para.py  --ds-path ../image/  --device-id $(hostname) --host http://loadbalancer.ziti-controller.private:5009 --headless --user 10 --spawn-rate 1 --run-time 1m  

```

- check log
```bash
tail -f /var/log/ziti-edge-tunnel.log
```
