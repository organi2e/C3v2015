#!/usr/bin/env bash

CIFAR10_DIR="https://www.cs.toronto.edu/~kriz"
CIFAR10_PATH="cifar-10-batches-bin"
CIFAR10_FILE="cifar-10-binary"

pushd $(dirname $0)
if [ ! -d "${CIFAR10_PATH}" ];
then
	curl "${CIFAR10_DIR}/${CIFAR10_FILE}.tar.gz" | tar zvx 2>/dev/null
fi
popd
