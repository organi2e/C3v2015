#!/usr/bin/env bash

DIR="http://yann.lecun.com/exdb/mnist"

TRAIN_LABEL="train-images-idx3-ubyte"
TRAIN_IMAGE="train-labels-idx1-ubyte"
T10K_LABEL="t10k-images-idx3-ubyte"
T10K_IMAGE="t10k-labels-idx1-ubyte"

pushd $(dirname $0)

curl "${DIR}/${TRAIN_IMAGE}.gz" | gunzip > "${TRAIN_IMAGE}"
curl "${DIR}/${TRAIN_LABEL}.gz" | gunzip > "${TRAIN_LABEL}"

curl "${DIR}/${T10K_IMAGE}.gz" | gunzip > "${T10K_IMAGE}"
curl "${DIR}/${T10K_LABEL}.gz" | gunzip > "${T10K_LABEL}"

popd
