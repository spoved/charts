#!/bin/bash
set -e

docker run --rm -ti -v $(pwd):/app -w /app/charts/ quay.io/helmpack/chart-testing /bin/sh -c "ct lint --chart-dirs /app/charts/ --all --config /app/ct.yaml"
