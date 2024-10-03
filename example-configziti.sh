# login to your controller - replace the host/port with the correct value
ziti edge login localhost:1280

# optional login: 
# if you're using docker and have exec'ed into your controller using docker you should be able to run the alias `zitiLogin` to login
# optional login:
# if you've sourced the .env file from a quickstart you should be able to run the alias `zitiLogin` to login

# 1. Create an identity for the HTTP client and assign an attribute "http-clients". We'll use this attribute when authorizing the clients to
#  access the HTTP service
ziti edge create identity user http-client -a 'http-clients' -o http.client.jwt 

                    # #2. Create an identity for the HTTP server if you are not using an edge-router with the tunneling option enabled
                    # ziti edge create identity user http-server -o http.server.jwt

#3. Create an intercept.v1 config. This config is used to instruct the client-side tunneler how to correctly intercept 
#   the targeted traffic and put it onto the overlay. 
ziti edge create config http.intercept.v1 intercept.v1 '{"protocols":["tcp"],"addresses":["http.ziti"], "portRanges":[{"low":8000, "high":8000}]}'
    
#4. Create a host.v1 config. This config is used instruct the server-side tunneler how to offload the traffic from 
#   the overlay, back to the underlay. Make sure the port used here is correct. For example, when running inside a 
#   docker container, the ${http_server} variable would likely be set to web.test.blue but the port for the http server
#   inside the container is listening on 8000, not 80. Be careful with the port and make sure the ${http_server}:port
#   is reachable from the ${http_server_id}.  
ziti edge create config http.host.v1 host.v1 '{"protocol":"tcp", "address":"web-test-blue", "port":8000}'
    
#5. Create a service to associate the two configs created previously into a service.
ziti edge create service http.svc --configs http.intercept.v1,http.host.v1

#6. Create a service-policy to authorize "HTTP Clients" to "dial" the service representing the HTTP server.
ziti edge create service-policy http.policy.dial Dial --service-roles "@http.svc" --identity-roles '#http-clients'

#7. Create a service-policy to authorize the "HTTP Server" to "bind" the service representing the HTTP server.
ziti edge create service-policy http.policy.bind Bind --service-roles '@http.svc' --identity-roles "@${http_server_id}"

                    #8. Start the server-side tunneler (unless using the docker-compose quickstart) with the HTTP server identity.
                    #   [optional] if you don't use an edge-router as your tunneler, you will need to download and run the tunneler for your OS
                    #   if you are using a ziti-router, skip to step 9 below
                    # 
                    #   This step is dependant on platform. For this demo we'll be using a virtual machine running linux and we'll be using the
                    #   ziti-edge-tunnel binary. Copy the http.server.jwt from step 2 to the server machine. For the example we'll use /tmp/http.server.jwt
                    #
                    # enroll the server identity using ziti-edge-tunnel
                    # ./ziti-edge-tunnel enroll --jwt /tmp/http.server.jwt --identity /tmp/http.server.json
                    # # run ziti-edge-tunnel for the client
                    # sudo ./ziti-edge-tunnel run -i /tmp/http.server.json

#9. Start the client-side tunneler using the HTTP client identity.
#   This step is dependant on platform. For this demo we'll be using a virtual machine running linux and we'll be using the
#   ziti-edge-tunnel binary. Copy the http.client.jwt from step 1 to the client machine. For the example we'll use /tmp/http.client.jwt
#
# enroll the client identity using ziti-edge-tunnel
./ziti-edge-tunnel enroll --jwt http.client.jwt --identity http.client.json
# run ziti-edge-tunnel for the client
sudo ./ziti-edge-tunnel run -i http.client.json

#10. Access the HTTP server securely over the OpenZiti zero trust overlay
curl http.ziti
<pre>
Hello World


                        ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
                        :::::::::::::::::::,::$77777777777777,:,::::::::::::::::::::
                        ::::::::::::::::::77777777777777777777777~,:::::::::::::::::
                        :::::::::::::::77777777777777II7777777777777,:::::::::::::::
                        ::::::::::::$777777777777777I.:7777777777777777,::::::::::::
                        ::::::::::77777777777777777I...I7777777777777777I:::::::::::
                        :::::::::77777777777777777I....?777777777777777777::::::::::
                        :::::::$77777777777777777I......77777777777777777777::::::::
                        ::::::777777777777777777I.......I77777777777777777777,::::::
                        :::::777777777777777777I....?...?777777777777777777777::::::
                        :::,777777777777777777I....I7?...777777777777777777777$:::::
                        :::777777777777777777I....I77I...I777777777777777777777$::::
                        :::77777777777777777I....I7777...?7777777777777777777777::::
                        ::77777777777777777I....I77777?..,77777777777777777777777:::
                        ::7777777777777777I....I777777I...I77777777777777$7$$$$7$,::
                        :$777777777777777I....I77777777...?7777777777777$$77777777::
                        :777777777777777I ...I777II7777?...I.I7777777$777777777777::
                        :77777777777777I....I777I..7777I.......?I777$$$$$77$$$$7$$::
                        :7777777777777I....?I77I...I7777..........I777777$$$$$7$$$,:
                        :77777777777777?..  .??.   ?7777?  ..??.   .?7$7$$$7$$$$$7::
                        ,7777777777777777I..........I$77I...I777?....77777$7$$$$$$,,
                        :7777777777777777777?.......I7$$7..I777I....7$$$$$$$$$$$$$::
                        :777777777777777777777I.I=..?77777777$7....77$$$$$$$$7$$$$::
                        :777777777777777777777777I...I$7777777....77$$$$$$$$$$$$$$::
                        ::77777777777777$7$7$$$$$I...?7$$7$77....7$$$$$$$$$$$$$$$:::
                        ::777777777777777777$$$777+..~77$$7I....77$$$$$$$$$$$$$$$:::
                        :::77777777777777777777$$7I...7$$$I....7$7$$$$$$$$$$$$$$::::
                        :::Z77777777$7777777777$77I...?$77....I$$$$$$$$$$$$$$$$$::::
                        ::::77777$$$$$7777$$$$$$$$7:..+77....I$$$$$$$$$$$$$$$$$:::::
                        :::::77777$777$$$$777$$$$77I...I....I$$$$$$$$$$$$$$$$$::::::
                        ::::::$7777777$7777$$$7$$$$I...... I$$$$$$$$$$$$$$$$7:::::::
                        :::::::?$$$$$$$$$$$$$$$$$$$7=.....I$$$$$$$$$$$$$$$$=::::::::
                        :::::::::7$$$$$7$$$$$$$$$$$$?....77$$$$$$$$$$$$$$$::::::::::
                        ::::::::::,7$$7$$$$$$$$$$$$$7...I$$$$$$$$$$$$$$$::::::::::::
                        ::::::::::::~$$$$$$$$$$$$$$$7?.I$$$$$$$$$$$$$$::::::::::::::
                        :::::::::::::::$$$$$$$$$$$$$$77$$$$$$$$$$$$$::::::::::::::::
                        ::::::::::::::::::7$$$$$$$$$$$$$$$$$$$$$$:::::::::::::::::::
                        :::::::::::::::::::::::$$$$$$$$$$$$$::::::::::::::::::::::::
                        ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::



</pre>