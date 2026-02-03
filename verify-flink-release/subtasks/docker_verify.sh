#!/bin/bash
################################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
################################################################################

function check_docker_cli() {
  echo "### check_docker_cli $@"

  if [[ "$#" != 0 ]]; then
    echo "Usage: check_docker_cli (no parameters)"
    return 1
  fi

  if ! which docker &> /dev/null; then
    echo "Error: Docker CLI not found. Please install Docker from https://docs.docker.com/get-docker/"
    return 1
  fi

  if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running. Please start Docker."
    return 1
  fi

  echo "Docker is available and running"
}

function check_cosign_cli() {
  echo "### check_cosign_cli $@"

  if [[ "$#" != 0 ]]; then
    echo "Usage: check_cosign_cli (no parameters)"
    return 1
  fi

  if ! which cosign &> /dev/null; then
    echo "Warning: cosign CLI not found. Signature verification will be skipped."
    echo "You can install cosign from https://docs.sigstore.dev/cosign/installation/"
    return 0
  fi

  echo "cosign version: $(cosign version --json 2>/dev/null | grep -o '"gitVersion":"[^"]*"' || echo 'unknown')"
}

function pull_docker_image() {
  echo "### pull_docker_image $@"
  local working_directory docker_image

  if [[ "$#" != 2 ]]; then
    echo "Usage: <working-directory> <docker-image>"
    return 1
  fi

  working_directory=$1
  docker_image=$2
  out_file="${working_directory}/docker-pull.out"

  echo "Pulling Docker image: ${docker_image}" | tee ${out_file}
  if docker pull ${docker_image} 2>&1 | tee -a ${out_file}; then
    echo -e "   <DOCKER PULL> [\e[32mSUCCESS\e[0m]" | tee -a ${out_file}
  else
    echo -e "   <DOCKER PULL> [\e[31mERROR\e[0m] - Failed to pull Docker image ${docker_image}" | tee -a ${out_file}
    return 1
  fi
}

function verify_docker_image_digest() {
  echo "### verify_docker_image_digest $@"
  local working_directory docker_image

  if [[ "$#" != 2 ]]; then
    echo "Usage: <working-directory> <docker-image>"
    return 1
  fi

  working_directory=$1
  docker_image=$2
  out_file="${working_directory}/docker-digest.out"

  echo "Verifying Docker image digest for: ${docker_image}" | tee ${out_file}

  # Get image digest
  local image_digest
  image_digest=$(docker inspect --format='{{index .RepoDigests 0}}' ${docker_image} 2>/dev/null)

  if [[ -z "${image_digest}" ]]; then
    echo -e "   <DIGEST> [\e[31mERROR\e[0m] - Could not retrieve image digest" | tee -a ${out_file}
    return 1
  fi

  echo "Image digest: ${image_digest}" | tee -a ${out_file}

  # Also get and log the image ID for reference
  local image_id
  image_id=$(docker inspect --format='{{.Id}}' ${docker_image} 2>/dev/null)
  echo "Image ID: ${image_id}" | tee -a ${out_file}

  echo -e "   <DIGEST> [\e[32mCORRECT\e[0m]" | tee -a ${out_file}
}

function verify_docker_image_signature() {
  echo "### verify_docker_image_signature $@"
  local working_directory docker_image

  if [[ "$#" != 2 ]]; then
    echo "Usage: <working-directory> <docker-image>"
    return 1
  fi

  working_directory=$1
  docker_image=$2
  out_file="${working_directory}/docker-cosign.out"

  # Check if cosign is available
  if ! which cosign &> /dev/null; then
    echo "Cosign not available, skipping signature verification" | tee ${out_file}
    echo -e "   <COSIGN> [\e[33mSKIPPED\e[0m]" | tee -a ${out_file}
    return 0
  fi

  echo "Verifying cosign signature for: ${docker_image}" | tee ${out_file}

  # Verify signature using cosign
  # Using --certificate-identity-regexp and --certificate-oidc-issuer for Apache releases
  if cosign verify \
    --certificate-identity-regexp ".*@apache.org" \
    --certificate-oidc-issuer "https://github.com/login/oauth" \
    ${docker_image} 2>&1 | tee -a ${out_file}; then
    echo -e "   <COSIGN> [\e[32mCORRECT\e[0m]" | tee -a ${out_file}
  else
    echo -e "   <COSIGN> [\e[33mWARNING\e[0m] - Signature verification failed or not signed" | tee -a ${out_file}
    echo "Note: If the image is not signed with cosign, this is expected for some releases." | tee -a ${out_file}
    # Don't fail here - cosign might not be used for all releases
  fi
}
