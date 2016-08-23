#!/usr/bin/env bash

DIR="http://yann.lecun.com/exdb/mnist"

TRAIN_LABEL="train-images-idx3-ubyte"
TRAIN_IMAGE="train-labels-idx1-ubyte"
T10K_LABEL="t10k-images-idx3-ubyte"
T10K_IMAGE="t10k-labels-idx1-ubyte"

pushd $(dirname $0)

for FILE in $TRAIN_LABEL $TRAIN_IMAGE $T10K_LABEL $T10K_IMAGE;
do
	if [ ! -e $FILE ];
	then
		curl "${DIR}/${FILE}.gz" | gunzip > "${FILE}" 
		echo "${DIR}/${FILE}"
	fi
done

popd
