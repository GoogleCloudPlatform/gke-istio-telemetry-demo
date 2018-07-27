#! /usr/bin/env bash

# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# shellcheck source=../gke-istio-shared/verify-functions.sh

# This script creates a GKE cluster with Istio installed in it using scripts
# in the SHARED_DIR directory.

set -e

# Include the user set variables
source "${PWD}/properties.env"

# Source utility functions for checking the existence of various resources.
source "${SHARED_DIR}/verify-functions.sh"

# Ensure that the directory containing all of the necessary scripts exists
if ! directory_exists "${SHARED_DIR}" ; then
  echo "${SHARED_DIR} does not exist, please check the variable "
  echo "settings in the properties file."
  echo "Exiting..."
  exit 1
fi

# Ensure that the selected project exists
if ! project_exists "${PROJECT}" ; then
  echo "The ${PROJECT} specified for use the with the demo does not exist."
  echo "Please update the properties file with a project that exists."
  echo "Terminating..."
  exit 1
fi

# Ensure the necessary dependencies are installed
if ! dependency_installed "gcloud"; then
  echo "I require gcloud but it's not installed. Aborting."
fi

if ! dependency_installed "kubectl"; then
  echo "I require gcloud but it's not installed. Aborting."
fi

if ! dependency_installed "curl" ; then
  echo "I require curl but it's not installed. Aborting."
fi

# Ensure the required APIs are enabled
enable_project_api "${PROJECT}" "compute.googleapis.com"
enable_project_api "${PROJECT}" "container.googleapis.com"

# Begin creating the GCP resources necessary to run Istio

# Download Istio components to be used in installation
# Globals:
#   None
# Arguments:
#   ISTIO_VERSION - Version of Istio to use for deployment
#   SHARED_DIR    - Directory containing scripts shared by other demos
#   SHARED_DIR    - Directory containing the verify-functions.sh file
# Returns:
#   None
"${SHARED_DIR}/download-istio.sh" "${ISTIO_VERSION}" "${SHARED_DIR}"

if ! directory_exists "$ISTIO_DIR" ; then
  echo "${ISTIO_DIR} does not exist, please check the variable settings in the"
  echo "properties file."
  echo ""
  echo "Aborting..."
  exit 1
fi

# Create the network to be used by the cluster.
# TODO: the assumption is currently that the network will be an auto-mode
# network. Does this assumption break anything? What happens if a user provides
# their own custom mode network?
if ! network_exists "${PROJECT}" "${NETWORK_NAME}"; then
  gcloud compute networks create "${NETWORK_NAME}" --project "${PROJECT}"
fi

# Create a cluster to install Istio on if it doesn't exist
# Globals:
#   None
# Arguments:
#   PROJECT            - Project to contain istio cluster
#   CLUSTER_NAME       - Name to use for GKE cluster
#   ZONE               - Zone to locate created cluster
#   ISTIO_NETWORK_NAME - Name of network to use for cluster
# Returns:
#   None
if ! cluster_exists "${PROJECT}" "${CLUSTER_NAME}"; then
  "${SHARED_DIR}/create-istio-cluster.sh" "${PROJECT}" "${CLUSTER_NAME}" "${ZONE}" "${NETWORK_NAME}"
fi

# Install Istio control plane into the cluster
# Globals:
#   None
# Arguments:
#   ISTIO_DIR         - Directory containing Istio components
#   ISTIO_YAML        - Name of the file used to deploy the Istio k8s resources
#   ISTIO_NAMESPACE   - Namespace containing Istio components
#   SHARED_DIR        - Directory containing scripts shared by other demos
# Returns:
#   None
"${SHARED_DIR}/install-istio.sh" "${ISTIO_DIR}" "${ISTIO_YAML}" "${ISTIO_NAMESPACE}" "${SHARED_DIR}"

# Install the BookInfo application into the cluster
# Globals:
#   None
# Arguments:
#   ISTIO_DIR         - Directory containing Istio components
#   NAMESPACE         - Namespace containing BookInfo services
#   SHARED_DIR        - Directory containing scripts shared by other demos
#   ISTIO_AUTH_POLICY - Whether MUTUAL_TLS authentication is turned on
# Returns:
#   None
"${SHARED_DIR}/install-bookinfo-1.0.0.sh" "${ISTIO_DIR}" "default" "${SHARED_DIR}" \
  "${ISTIO_AUTH_POLICY}"

# Validate that the BookInfo application has all of the components installed
# Globals:
#   None
# Arguments:
#   ISTIO_NAMESPACE - Namespace containing Istio components
#   SHARED_DIR      - Directory containing scripts shared by other demos
# Returns:
#   None
"${SHARED_DIR}/verify-bookinfo-setup.sh" "${ISTIO_NAMESPACE}" "${SHARED_DIR}"

# Install Grafana Istio addon
# Globals:
#   None
# Arguments:
#   ISTIO_DIR
#   NAMESPACE
#   SHARED_DIR
# Returns:
#   None
"${SHARED_DIR}/setup-istio-grafana.sh" "${ISTIO_DIR}" "${ISTIO_NAMESPACE}" "${SHARED_DIR}"

INGRESS_HOST=$(kubectl get -n "$ISTIO_NAMESPACE" service istio-ingressgateway -o \
  jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl get -n "$ISTIO_NAMESPACE" service istio-ingressgateway -o \
  jsonpath='{.spec.ports[?(@.name=="http")].port}')

echo ""
echo "Visit http://$INGRESS_HOST:$INGRESS_PORT/productpage in a browser to"
echo "see the bookinfo application"
echo ""
echo "Installation completed"
