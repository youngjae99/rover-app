#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

./build.sh
echo "→ launching Rover.app"
open Rover.app
