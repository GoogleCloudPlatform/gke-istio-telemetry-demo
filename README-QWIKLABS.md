# Istio in a Kubernetes Engine Cluster

## Table of Contents
<!--ts-->
- [Istio in a Kubernetes Engine Cluster](#istio-in-a-kubernetes-engine-cluster)
  * [Table of Contents](#table-of-contents)
  * [Introduction](#introduction)
  * [Architecture](#architecture)
    + [Istio Overview](#istio-overview)
      - [Istio Control Plane](#istio-control-plane)
      - [Istio Data Plane](#istio-data-plane)
    + [BookInfo Sample Application](#bookinfo-sample-application)
    + [Putting it All Together](#putting-it-all-together)
  * [Initialize GCP](#initialize-gcp)
  * [Deployment steps](#deployment-steps)
  * [Validation](#validation)
    + [View Prometheus UI](#view-prometheus-ui)
    + [View Grafana UI](#view-grafana-ui)
    + [View Jaeger UI](#view-jaeger-ui)
  * [Tear Down](#tear-down)
  * [Relevant Material](#relevant-material)
<!--te-->

## Introduction

[Istio](http://istio.io/) is part of a new category of products known as "service mesh" software
designed to manage the complexity of service resilience in a microservice
infrastructure. It defines itself as a service management framework built to
keep business logic separate from the logic to keep your services up and
running. In other words, it provides a layer on top of the network that will
automatically route traffic to the appropriate services, handle [circuit
breaker](https://en.wikipedia.org/wiki/Circuit_breaker_design_pattern) logic,
enforce access and load balancing policies, and generate telemetry data to
gain insight into the network and allow for quick diagnosis of issues.

For more information on Istio, please refer to the [Istio
documentation](https://istio.io/docs/). Some familiarity with Istio is assumed.

This repository contains demonstration code to create an Istio service mesh in
a single GKE cluster and use [Prometheus](https://prometheus.io/),
[Jaeger](https://www.jaegertracing.io/), and [Grafana](https://grafana.com/) to
collect metrics and tracing data and then visualize that data.

## Architecture

### Istio Overview

Istio has two main pieces that create the service mesh: the control plane and
the data plane.

#### Istio Control Plane

The control plane is made up of the following set of components that act
together to serve as the hub for the infrastructure's service management:

* _[Mixer](https://istio.io/docs/concepts/what-is-istio/#mixer)_: a platform-independent component responsible for enforcing access control and usage policies across the service mesh and collecting telemetry data from the [Envoy](https://istio.io/docs/concepts/what-is-istio/#envoy) proxy and other services

* _[Pilot](https://istio.io/docs/concepts/what-is-istio/#pilot)_: provides service discovery for the Envoy sidecars, traffic management capabilities for intelligent routing, (A/B tests, canary deployments, etc.), and resiliency (timeouts, retries, circuit breakers, etc.)

* _[Citadel](https://istio.io/docs/concepts/what-is-istio/#citadel)_: provides strong service-to-service and end-user authentication using mutual TLS, with built-in identity and credential management.

#### Istio Data Plane

The data plane comprises all the individual service proxies that are
distributed throughout the infrastructure. Istio uses
[Envoy](https://www.envoyproxy.io/) with some Istio-specific extensions as its
service proxy. It mediates all inbound and outbound traffic for all services in
the service mesh. Istio leverages Envoy’s many built-in features such as
dynamic service discovery, load balancing, TLS termination, HTTP/2 & gRPC
proxying, circuit breakers, health checks, staged roll-outs with
percentage-based traffic splits, fault injection, and rich metrics.

### BookInfo Sample Application

The sample [BookInfo](https://istio.io/docs/guides/bookinfo.html)
application displays information about a book, similar to a single catalog entry
of an online book store. Displayed on the page is a description of the book,
book details (ISBN, number of pages, and so on), and a few book reviews.

The BookInfo application is broken into four separate microservices and calls on
various language environments for its implementation:

- **productpage** - The productpage microservice calls the details and reviews
  microservices to populate the page.
- **details** - The details microservice contains book information.
- **reviews** - The reviews microservice contains book reviews. It also calls the
  ratings microservice.
- **ratings** - The ratings microservice contains book ranking information that
  accompanies a book review.

There are 3 versions of the reviews microservice:

- **Version v1** doesn’t call the ratings service.
- **Version v2** calls the ratings service, and displays each rating as 1 to 5
  black stars.
- **Version v3** calls the ratings service, and displays each rating as 1 to 5
  red stars.

![](./images/bookinfo.png)

To learn more about Istio, please refer to the
[project's documentation](https://istio.io/docs/).

### Putting it All Together

The pods and services that make up the Istio control plane are the first components of the architecture that will be installed into Kubernetes Engine. An Istio service proxy is installed along with each microservice during the installation of the BookInfo application, as are our telemetry add-ons. At this point, in addition to the application microservices there are two tiers that make up the Istio architecture: the Control Plane and the Data Plane.

In the diagram, note:
* All input and output from any BookInfo microservice goes through the service proxy.
* Each service proxy communicates with each other and the Control Plane to implement the features of the service mesh, circuit breaking, discovery, etc.
* The Mixer component of the Control Plane is the conduit for the telemetry add-ons to get metrics from the service mesh.
* The Istio ingress component provides external access to the mesh.
* The environment is setup in the Kubernetes Engine default network.

![](./images/istio-gke.png)

## Initialize GCP

```console
gcloud init
```

## Deployment steps

_NOTE: The following instructions are applicable for deployments performed both with and without Cloud Shell._

Copy the `properties` file to `properties.env` and set the following variables in the `properties.env` file:
 * `YOUR_PROJECT` - the name of the project you want to use
 * `YOUR_REGION` - the region in which to locate all the infrastructure
 * `YOUR_ZONE` - the zone in which to locate all the infrastructure

```console
make create
```

The script should deploy all of the necessary infrastructure and install Istio. The script will end with a line like this, though the IP address will likely be different:
```
Update istio service proxy environment file
104.196.243.210/productpage
```

You can open this URL in your browser and see the simple web application provided by the demo.

## Validation

1. On the command line, run the following command:
```console
echo "http://$(kubectl get -n istio-system service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):$(kubectl get -n istio-system service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http")].port}')/productpage"
```
1. Visit the generated URL in your browser to see the BookInfo application.

### View Prometheus UI

1. To forward the Prometheus UI port locally so you can use the browser to access it, run the following command on the command line:
```console
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}') 9090:9090
```
1. Visit the following URL in your web browser: http://localhost:9090/graph

Press `CTRL-C` to quit forwarding the port.

For more information on how to use Prometheus with Istio, please refer to the
[Istio documentation](https://istio.io/docs/tasks/telemetry/querying-metrics/)

### View Grafana UI

1. To forward the Grafana UI port locally so you can use the browser to access it, run the following command:
```console
kubectl -n istio-system port-forward $(kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000
```
1.  Visit the following url in your web browser:
http://localhost:3000/dashboard/db/istio-dashboard

Press `CTRL-C` to quit forwarding the port.

For more information on how to use Grafana with Istio, please refer to the
[Istio documentation](https://istio.io/docs/tasks/telemetry/using-istio-dashboard/)

### View Jaeger UI

1. To forward the Jaeger UI port locally so you can use the browser to access it, run the following command:
```console
kubectl port-forward -n istio-system $(kubectl get pod -n istio-system -l app=jaeger -o jsonpath='{.items[0].metadata.name}') 16686:16686
```

1. Visit the following url in your web browser: http://localhost:16686

Press `CTRL-C` to quit forwarding the port.

For more information on how to generate sample traces, please refer to the [Istio
documentation](https://istio.io/docs/tasks/telemetry/distributed-tracing/).

## Tear Down

To tear down the resources created by this demonstration, run:

```console
make teardown
```

## Relevant Material

This demo was created with help from the following links:

* https://cloud.google.com/kubernetes-engine/docs/tutorials/istio-on-gke
* https://cloud.google.com/compute/docs/tutorials/istio-on-compute-engine
* https://istio.io/docs/guides/bookinfo.html
* https://istio.io/docs/tasks/telemetry/querying-metrics/
* https://istio.io/docs/tasks/telemetry/using-istio-dashboard/
* https://istio.io/docs/tasks/telemetry/distributed-tracing/


**This is not an officially supported Google product**
