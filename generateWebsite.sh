set -e

BASEDIR=$(dirname "$BASH_SOURCE")
ABSOLUTE_BASEDIR=$(realpath "$BASEDIR")

DOCKER_IMAGE=ghcr.io/rohankanojia/rohankanojia.github.io:main

docker run                                                   \
  --rm                                                       \
  -v "$ABSOLUTE_BASEDIR":/usr/src                            \
  -w /usr/src/                                               \
  -e LOCAL_USER="$(id -u):$(id -g)"                          \
  $DOCKER_IMAGE "$@"
