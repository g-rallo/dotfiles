#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

home-manager switch --flake .#gilrallo
