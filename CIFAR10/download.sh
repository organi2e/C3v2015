#!/usr/bin/env bash
URL="https://www.cs.toronto.edu/~kriz/cifar-10-binary.tar.gz"
pushd $(dirname $0)
curl "$URL" | tar zvx 2>/dev/null
popd
