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

set -e

# properties file
source "${PWD}"/properties.env
# functions to check existence of resources
source "${SHARED_DIR}"/verify-functions.sh

# Delete all created Istio and Kubernetes resources
if directory_exists "${SHARED_DIR}"; then
  "${SHARED_DIR}/istio-${ISTIO_VERSION}/bin/istioctl" delete -f \
    "${SHARED_DIR}/istio-${ISTIO_VERSION}/samples/bookinfo/routing/route-rule-all-v1.yaml"
  "${SHARED_DIR}/istio-${ISTIO_VERSION}/bin/istioctl" delete -f \
    "${SHARED_DIR}/istio-${ISTIO_VERSION}/samples/bookinfo/routing/bookinfo-gateway.yaml"
  kubectl delete -f <("${SHARED_DIR}/istio-${ISTIO_VERSION}/bin/istioctl" kube-inject -f \
    "${SHARED_DIR}/istio-${ISTIO_VERSION}/samples/bookinfo/kube/bookinfo-ratings-v2-mysql-vm.yaml") \
    --ignore-not-found="true"
  kubectl delete -f <("${SHARED_DIR}/istio-${ISTIO_VERSION}/bin/istioctl" kube-inject -f \
    "${SHARED_DIR}/istio-${ISTIO_VERSION}/samples/bookinfo/kube/bookinfo.yaml") \
    --ignore-not-found="true"
fi

kubectl delete -f "${SHARED_DIR}/istio-${ISTIO_VERSION}/install/kubernetes/mesh-expansion.yaml" --ignore-not-found="true"
kubectl delete -f "${SHARED_DIR}/istio-${ISTIO_VERSION}/install/kubernetes/istio-demo.yaml" --ignore-not-found="true"
kubectl delete clusterrolebinding cluster-admin-binding --ignore-not-found="true"

# Wait for Kubernetes resources to be deleted before deleting the cluster
# Also, filter out the resources to what would specifically be created for
# the GKE cluster
until [[ $(gcloud --project="${PROJECT}" compute target-pools list \
              --format="value(name)" \
              --filter="instances[]:gke-${CLUSTER_NAME}") == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

until [[ $(gcloud --project="${PROJECT}" compute forwarding-rules list --format yaml \
              --filter "description:istio-system OR description:kube-system/dns-ilb") == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

until [[ $(gcloud --project="${PROJECT}" compute firewall-rules list \
             --filter "name:k8s AND targetTags.list():gke-${CLUSTER_NAME}" \
             --format "value(name)") == "" ]]; do
  echo "Waiting for cluster to become ready for destruction..."
  sleep 10
done

# Delete kubernetes resources
if cluster_exists "${PROJECT}" "${CLUSTER_NAME}" ; then
  # delete istio cluster
  echo ""
  echo " deleting istio cluster"
  echo ""
  gcloud container clusters delete "${CLUSTER_NAME}" --project "${PROJECT}" --zone "${ZONE}" --quiet
  echo ""
  echo ""
fi

# Delete any firewalls created by the cluster for node communication
if firewall_exists "${PROJECT}" "${CLUSTER_NAME}" ; then
  echo ""
  echo " deleting cluster firewalls"
  echo ""
  while IFS= read -r RESULT
  do
      gcloud compute --project "${PROJECT}" firewall-rules delete "${RESULT}" --quiet
  done < <(gcloud compute firewall-rules list --project "${PROJECT}" --filter "name=${CLUSTER_NAME}" --format "value(name)")
  echo ""
  echo ""
fi

# Delete any firewalls created by GKE to allow for load balancer communication
if firewall_exists "${PROJECT}" "k8s" ; then
  echo ""
  echo " deleting k8s firewalls"
  echo ""
  while IFS= read -r RESULT
  do
      gcloud compute --project "${PROJECT}" firewall-rules delete "${RESULT}" --quiet
  done < <(gcloud compute firewall-rules list --project "${PROJECT}" | grep "k8s" | awk '{print $1}')
  echo ""
  echo ""
fi

# Prompt the user about whether they want to delete the network created for the
# cluster
if network_exists "${PROJECT}" "${NETWORK_NAME}" && network_is_not_last "${PROJECT}" "${NETWORK_NAME}"; then
  echo "Do you want to delete the network used by the cluster? (y/n)"
  read -r DELETE_NETWORK
  if [[ $DELETE_NETWORK == "y" ]]; then
    gcloud compute --project "${PROJECT}" networks delete "${NETWORK_NAME}" --quiet
  else
    echo "Not deleting the network used."
  fi
fi

# Remove Istio components
if directory_exists "${ISTIO_DIR}" ; then
  rm -rf "${ISTIO_DIR}"
fi

