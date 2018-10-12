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

# Add the properties file to allow the make tests to pass
# shellcheck source=properties

set -e

ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

# Include the user set variables
# shellcheck source=properties.env
source "${ROOT}/properties.env"

ISTIO_SHARED_DIR="${ROOT}/gke-istio-shared"

# Source utility functions for checking the existence of various resources.
# shellcheck source=../gke-istio-shared/verify-functions.sh
source "${ISTIO_SHARED_DIR}/verify-functions.sh"

dependency_installed "kubectl"

# Get the IP address and port of the cluster's gateway to run tests against
INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "App is available at: http://$INGRESS_HOST/productpage"

# Test service availability
[ "$(curl -s -o /dev/null -w '%{http_code}' "$INGRESS_HOST/productpage")" \
  -eq 200 ] || exit 1

echo "App is successfully handling requests."
