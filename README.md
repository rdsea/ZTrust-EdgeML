# Zero-Trust-Communication

## Overview

The repository contains test cases demonstrating the application of Zero Trust (ZT) architecture in an IoT-Edge-Cloud continuum. The test cases represent a simulated CCTV monitoring system that utilizes edge computing for image processing (object detection) before securely transmitting the data to a cloud-based database for storage and analysis.

## System Architecture

The test environment consists of:

1. IoT Device:
A CCTV camera acting as a client that sends images to the edge microservices for processing.

2. Edge System:
Composed of several microservices that perform image processing tasks (e.g., object detection).

3. Cloud System:
A cloud-based database that stores the processed images for further analysis.

## Test Scenario

- Objective: To demonstrate Bthe application of ZT architecture in an IoT-Edge-Cloud environment.

- Components:
  - Windows machine: Functions as the IoT device, communicating with the edge system.
  - Ubuntu machine:
    - Runs the OpenZiti overlay network.
    - Acts as the edge system, processing the images received from the IoT device.

- ZT implementation:
  - Utilizes the OpenZiti framework to create a secure overlay network between the IoT device and the edge system.

- Stakeholders:

  - Security company: Owns and operates image processing microservices on the Edge
  - Client: Owns the CCTV camera and cloud DB where observed data is stored

## Setup Steps

- Setup the overlay network on the Ubuntu machine according to the [Local - No Docker](https://openziti.io/docs/learn/quickstarts/network/local-no-docker/).

- Also on the Ubuntu machine, follow the [Your First Service](https://openziti.io/docs/learn/quickstarts/network/local-no-docker/) guide as below:

> cd controller
> ./install-ziti-edge-tunnel.sh <client> <server> <port> # output client.jwt and server.jwt

  1. Create an identity for the HTTP client and assign an attribute "http-clients". We'll use this attribute when authorizing the clients to access the HTTP service
  2. Create an identity for the HTTP server if you are not using an edge-router with the tunneling option enabled. Also note that if you are using the docker-compose quickstart or just plan to use an edge-router with tunneling enabled you can also skip this step.
  3. Create an `intercept.v1` config. This config is used to instruct the client-side tunneler how to correctly intercept the targeted traffic and put it onto the overlay.
  4. Create a `host.v1` config. This config is used to instruct the server-side tunneler how to offload the traffic from the overlay, back to the underlay.
  5. Create a service to associate the two configs created previously into a service.
  6. Create a service-policy to authorize "HTTP Clients" to "dial" the service representing the HTTP server.
  7. Create a service-policy to authorize the "HTTP Server" to "bind" the service representing the HTTP server.
  8. Start the server-side tunneler with the HTTP server identity, providing access to the HTTP server.
  9. Start the client-side tunneler from the Windows machine using the HTTP client identity by:

  - Copy the `http.client.jwt` from step 1 to the Windows machine.
> cd controller
> docker cp controller:client.jwt client:/client
> docker cp controller:server.jwt server:/server

  - Enroll the client identity using `ziti-edge-tunnel` binary.
> cd client
> ziti-edge-tunnel enroll -j client.jwt -i client.json

> cd server
> ziti-edge-tunnel enroll -j server.jwt -i server.json

  - Edit host from client and server to know the controller and router IP
``` bash
vim /etc/hosts
192.168.1.235 ziti-edge-controller
192.168.1.235 ziti-edge-router
```
  - Run the `ziti-edge-tunnel` for the client.
> cd client
> ziti-edge-tunnel run -i client.json
> cd server
> ziti-edge-tunnel run -i server.json

  10. Access the HTTP server securely over the OpenZiti zero trust overlay

## Encountered Issues

- Problem: "CONTROLLER_UNAVAILABLE" error when trying to enroll the client identity on the Windows machine.
  - Cause: DNS issue - The Windows machine could not resolve the host name of the Ubuntu machine.
  - Solution: Added a new entry (the Ubuntu machine's IP address and hostname) in the `/etc/hosts` on the Windows machine side.

- Problem: Unauthorized computer can still access the HTTP server.
  - Cause: Incorrect configuration at step 3 and 4?

- Problem: Ziti Admin Console (ZAC) not discovering the controller.

