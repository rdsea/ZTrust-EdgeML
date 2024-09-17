#1
# ziti edge create identity http-client -a 'http-clients' -o http.client.jwt

ziti edge create identity web-client -a 'web-clients' -o web.client.jwt


#2 Skip
ziti edge create identity http-server -o http.server.jwt


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

ziti edge create service-policy web.policy.bind Bind --service-roles '@web.svc' --identity-roles "@"


#8 Skip
# enroll the server identity using ziti-edge-tunnel
./ziti-edge-tunnel enroll --jwt /tmp/http.server.jwt --identity /tmp/http.server.json
# run ziti-edge-tunnel for the client
sudo ./ziti-edge-tunnel run -i /tmp/http.server.json


#9
# Copy the jwt client identity file to the client machine
docker cp <containerId>:/file/path/within/container /host/path/target

# enroll the client identity using ziti-edge-tunnel
ziti-edge-tunnel enroll --jwt http.client.jwt --identity http.client.json
# run ziti-edge-tunnel for the client
sudo ziti-edge-tunnel run -i http.client.json