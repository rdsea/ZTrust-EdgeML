IoT CLIENT - WEB-SERVER

#1
# ziti edge create identity http-client -a 'http-clients' -o http.client.jwt
ziti edge create identity web-client -a 'web-clients' -o web.client.jwt

#2
# ziti edge create identity http-server -o http.server.jwt
ziti edge create identity web-server -a 'web-server' -o web.server.jwt

#3
# ziti edge create config http.intercept.v1 intercept.v1 '{"protocols":["tcp"],"addresses":["http.ziti"], "portRanges":[{"low":8000, "high":8000}]}'
ziti edge create config web.intercept.v1 intercept.v1 '{"protocols":["tcp"],"addresses":["ziti.web-server"], "portRanges":[{"low":5004, "high":5004}]}'

#4
# ziti edge create config http.host.v1 host.v1 '{"protocol":"tcp", "address":"http://localhost", "port":5004}'
ziti edge create config web.host.v1 host.v1 '{"protocol":"tcp", "address":"web-server", "port":5004}'

#5
#ziti edge create service http.svc --configs http.intercept.v1,http.host.v1
ziti edge create service web.svc --configs web.intercept.v1,web.host.v1

#6
# ziti edge create service-policy http.policy.dial Dial --service-roles "@http.svc" --identity-roles '#http-clients'
ziti edge create service-policy web.policy.dial Dial --service-roles "@web.svc" --identity-roles '#web-clients'

#7
# Get the @${http_server_id} from the identity associated to the router by running "ziti edge list identities"
# ziti edge create service-policy http.policy.bind Bind --service-roles '@http.svc' --identity-roles "@aYeKogwDQK"
ziti edge create service-policy web.policy.bind Bind --service-roles '@web.svc' --identity-roles "@${web_server_id}"

#8
# enroll the server identity using ziti-edge-tunnel
ziti-edge-tunnel enroll --jwt web.server.jwt --identity web.server.json
# run ziti-edge-tunnel for the server
sudo ziti-edge-tunnel run -i web.server.json

#9
# Copy the jwt client identity file to the client machine
docker cp <containerId>:/file/path/within/container /host/path/target

# enroll the client identity using ziti-edge-tunnel
ziti-edge-tunnel enroll --jwt web.client.jwt --identity web.client.json
# run ziti-edge-tunnel for the client
sudo ziti-edge-tunnel run -i web.client.json

________________________________________________________________________________________________________________________

WEB-SERVER - PREPROCESSOR

#1
ziti edge create identity preprocessor -a 'preprocessor' -o preprocessor.jwt

#2
ziti edge create config web-to-preprocessor.intercept.v1 intercept.v1 \
'{"protocols":["tcp"],"addresses":["ziti.preprocessor"], "portRanges":[{"low":5003, "high":5003}]}'

#3
ziti edge create config preprocessor.host.v1 host.v1 \
'{"protocol":"tcp", "address":"preprocessor", "port":5003}'

#4
ziti edge create service web-to-preprocessor.svc --configs web-to-preprocessor.intercept.v1,preprocessor.host.v1

#5
ziti edge create service-policy web-to-preprocessor.dial Dial \
--service-roles "@web-to-preprocessor.svc" --identity-roles '#web-server'

#6
ziti edge create service-policy web-to-preprocessor.bind Bind \
--service-roles '@web-to-preprocessor.svc' --identity-roles '@${preprocessor-id}'

#7
# Enroll and run the preprocessor identity with ziti-edge-tunnel

________________________________________________________________________________________________________________________

PREPROCESSOR - INFERENCE-SERVER

#1
ziti edge create identity inference -a 'inference' -o inference.jwt

#2
ziti edge create config preprocessor-to-inference.intercept.v1 intercept.v1 \
'{"protocols":["tcp"],"addresses":["ziti.inference"], "portRanges":[{"low":5002, "high":5002}]}'

#3
ziti edge create config inference.host.v1 host.v1 \
'{"protocol":"tcp", "address":"inference", "port":5002}'

#4
ziti edge create service preprocessor-to-inference.svc --configs preprocessor-to-inference.intercept.v1,inference.host.v1

#5
ziti edge create service-policy preprocessor-to-inference.dial Dial \
--service-roles "@preprocessor-to-inference.svc" --identity-roles '#preprocessor'

#6
ziti edge create service-policy preprocessor-to-inference.bind Bind \
--service-roles '@preprocessor-to-inference.svc' --identity-roles '@${inference-id}'

#7
# Enroll and run the inference identity with ziti-edge-tunnel

________________________________________________________________________________________________________________________

INFERENCE-SERVER - RABBITMQ

#1
ziti edge create identity rabbitmq -a 'rabbitmq' -o rabbitmq.jwt

#2
ziti edge create config inference-to-rabbitmq.intercept.v1 intercept.v1 \
'{"protocols":["tcp"],"addresses":["ziti.rabbitmq"], "portRanges":[{"low":5672, "high":5672}]}'

#3
ziti edge create config rabbitmq.host.v1 host.v1 \
'{"protocol":"tcp", "address":"rabbitmq", "port":5672}'

#4
ziti edge create service inference-to-rabbitmq.svc --configs inference-to-rabbitmq.intercept.v1,rabbitmq.host.v1

#5
ziti edge create service-policy inference-to-rabbitmq.dial Dial \
--service-roles "@inference-to-rabbitmq.svc" --identity-roles '#inference'

#6
ziti edge create service-policy inference-to-rabbitmq.bind Bind \
--service-roles '@inference-to-rabbitmq.svc' --identity-roles '@${rabbitmq-id}'

#7
# Update /etc/hosts file in the rabbitmq-server to bind the rabbitmq hostname to 127.0.0.1

#8
# Enroll and run the rabbitmq identity with ziti-edge-tunnel