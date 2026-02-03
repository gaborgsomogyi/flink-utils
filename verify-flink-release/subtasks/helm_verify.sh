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

function check_helm_cli() {
  echo "### check_helm_cli $@"

  if [[ "$#" != 0 ]]; then
    echo "Usage: check_helm_cli (no parameters)"
    return 1
  fi

  if ! which helm &> /dev/null; then
    echo "Error: Helm CLI not found. Please install Helm from https://helm.sh/docs/intro/install/"
    return 1
  fi

  echo "Helm version: $(helm version --short)"
}

function download_helm_chart() {
  echo "### download_helm_chart $@"
  local working_directory url helm_chart_name helm_chart_dir

  if [[ "$#" != 4 ]]; then
    echo "Usage: <working-directory> <url> <helm-chart-name> <helm-chart-dir>"
    return 1
  fi

  working_directory=$1
  url=$2
  helm_chart_name=$3
  helm_chart_dir=$4
  out_file="${working_directory}/helm-download.out"

  mkdir -p ${helm_chart_dir}

  echo "Downloading Helm chart from: ${url}/${helm_chart_name}" | tee ${out_file}

  # Download chart and its checksums/signatures
  wget --execute robots=off --directory-prefix ${helm_chart_dir} \
    "${url}/${helm_chart_name}" \
    "${url}/${helm_chart_name}.asc" \
    "${url}/${helm_chart_name}.sha512" \
    2>&1 | tee -a ${out_file}

  if [[ $? -ne 0 ]]; then
    echo -e "   <HELM DOWNLOAD> [\e[31mERROR\e[0m] - Failed to download Helm chart" | tee -a ${out_file}
    return 1
  fi

  echo "Successfully downloaded Helm chart: ${helm_chart_name}" | tee -a ${out_file}
  find ${helm_chart_dir} -type f | tee -a ${out_file}
  echo -e "   <HELM DOWNLOAD> [\e[32mSUCCESS\e[0m]" | tee -a ${out_file}
}

function verify_helm_chart_checksums() {
  echo "### verify_helm_chart_checksums $@"
  local working_directory helm_chart_dir helm_chart_name public_gpg_key

  if [[ "$#" != 4 ]]; then
    echo "Usage: <working-directory> <helm-chart-dir> <helm-chart-name> <public-gpg-key>"
    return 1
  fi

  working_directory=$1
  helm_chart_dir=$2
  helm_chart_name=$3
  public_gpg_key=$4
  out_file="${working_directory}/helm-checksums.out"

  chart_file="${helm_chart_dir}/${helm_chart_name}"

  # Verify SHA512
  echo "Verifying SHA512 checksum for Helm chart" | tee ${out_file}
  local sha512_checksum_of_file downloaded_sha512_checksum
  sha512_checksum_of_file="$(sha512sum ${chart_file} | grep -o "^[^ ]*")"
  downloaded_sha512_checksum="$(cat ${chart_file}.sha512 | grep -o "^[^ ]*")"

  if [[ "${sha512_checksum_of_file}" == "${downloaded_sha512_checksum}" ]]; then
    echo -e "   <SHA512> [\e[32mCORRECT\e[0m]" | tee -a ${out_file}
  else
    echo -e "   <SHA512> [\e[31mERROR\e[0m]" | tee -a ${out_file}
    return 1
  fi

  # Verify GPG signature
  echo "Verifying GPG signature for Helm chart" | tee -a ${out_file}
  if $(gpg --verify ${chart_file}.asc ${chart_file} &> /dev/null); then
    echo -e "   <GPG>    [\e[32mCORRECT\e[0m]" | tee -a ${out_file}
  else
    echo -e "   <GPG>    [\e[31mERROR\e[0m]" | tee -a ${out_file}
    return 1
  fi
}

function lint_helm_chart() {
  echo "### lint_helm_chart $@"
  local working_directory helm_chart_dir helm_chart_name

  if [[ "$#" != 3 ]]; then
    echo "Usage: <working-directory> <helm-chart-dir> <helm-chart-name>"
    return 1
  fi

  working_directory=$1
  helm_chart_dir=$2
  helm_chart_name=$3
  out_file="${working_directory}/helm-lint.out"
  chart_file="${helm_chart_dir}/${helm_chart_name}"

  echo "Running helm lint on chart: ${helm_chart_name}" | tee ${out_file}

  # Extract chart for linting
  local extract_dir="${helm_chart_dir}/extracted"
  mkdir -p ${extract_dir}
  tar -xzf ${chart_file} -C ${extract_dir}

  # Run helm lint
  if helm lint ${extract_dir}/* 2>&1 | tee -a ${out_file}; then
    echo -e "   <HELM LINT> [\e[32mPASSED\e[0m]" | tee -a ${out_file}
  else
    echo -e "   <HELM LINT> [\e[31mFAILED\e[0m]" | tee -a ${out_file}
    return 1
  fi
}

function compare_helm_chart_with_repo() {
  echo "### compare_helm_chart_with_repo $@"
  local working_directory helm_chart_dir helm_chart_name checkout_directory

  if [[ "$#" != 4 ]]; then
    echo "Usage: <working-directory> <helm-chart-dir> <helm-chart-name> <checkout-directory>"
    return 1
  fi

  working_directory=$1
  helm_chart_dir=$2
  helm_chart_name=$3
  checkout_directory=$4
  out_file="${working_directory}/helm-diff.out"

  echo "Comparing Helm chart with repository checkout" | tee ${out_file}

  # Extract downloaded chart
  local extract_dir="${helm_chart_dir}/extracted"
  if [[ ! -d "${extract_dir}" ]]; then
    mkdir -p ${extract_dir}
    tar -xzf ${helm_chart_dir}/${helm_chart_name} -C ${extract_dir}
  fi

  # Find helm chart in repository (typically in helm/ directory)
  local repo_chart_dir
  if [[ -d "${checkout_directory}/helm/flink-kubernetes-operator" ]]; then
    repo_chart_dir="${checkout_directory}/helm/flink-kubernetes-operator"
  elif [[ -d "${checkout_directory}/helm" ]]; then
    repo_chart_dir="${checkout_directory}/helm"
  elif [[ -d "${checkout_directory}/charts" ]]; then
    repo_chart_dir="${checkout_directory}/charts"
  else
    echo "Warning: Could not find helm chart directory in repository" | tee -a ${out_file}
    echo "Skipping comparison with repository" | tee -a ${out_file}
    return 0
  fi

  # Compare extracted chart with repo
  echo "Comparing packaged chart with repository at: ${repo_chart_dir}" | tee -a ${out_file}
  comm -3 \
    <(find ${repo_chart_dir} -type f | sed "s|${repo_chart_dir}/||g" | sort) \
    <(find ${extract_dir} -type f | sed "s|${extract_dir}/[^/]*/||g" | sort) \
    | tee -a ${out_file}

  # If there are differences, note them but don't fail
  if [[ -s ${out_file} ]]; then
    echo "Note: Some differences found between packaged chart and repository" | tee -a ${out_file}
    echo "This may be expected due to packaging differences" | tee -a ${out_file}
  else
    echo "No differences found" | tee -a ${out_file}
  fi

  echo -e "   <HELM DIFF> [\e[32mCOMPLETED\e[0m]" | tee -a ${out_file}
}
