#!/bin/bash
# SPDX-FileCopyrightText: © 2024 Matt Williams <matt.williams@bristol.ac.uk>
# SPDX-License-Identifier: MIT
set -euo pipefail

# Build the project and create an OCI image containing it.

function artifact_path {
  echo "${1}" | jq --raw-output 'select(.reason == "compiler-artifact") | select(.target.name == "'"${2}"'") | .executable'
}

case "$(uname -m)" in
  x86_64)
    rust_target=x86_64-unknown-linux-musl
    image_arch=amd64
    ;;
  arm64|aarch64)
    rust_target=aarch64-unknown-linux-musl
    image_arch=arm64
    ;;
  *)
    echo "Unsupported host architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

out=$(cargo build --target="${rust_target}" --message-format=json ${@-})
cp "$(artifact_path "${out}" "conch")" oci

cd oci

version=$(./conch --version | tail -n1 | cut -d' ' -f 2)
image_id=$(
  podman build . --platform="linux/${image_arch}" --tag=conch:latest --tag=conch:"${version}" \
    --annotation="org.opencontainers.image.source=https://github.com/isambard-sc/conch" \
    --annotation="org.opencontainers.image.description=Conch SSH CA" \
    --annotation="org.opencontainers.image.licenses=MIT" \
    | tee /dev/fd/2 \
    | tail -n1
)
rm conch
echo "Built conch image:" 1>&2
echo "${image_id}"
