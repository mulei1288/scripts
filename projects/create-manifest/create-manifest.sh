#!/bin/bash
rm -rf ~/.docker/manifests
#docker pull $1-amd64
#docker pull $1-arm64
docker manifest create --insecure $1 $1-amd64 $1-arm64
docker push $1-amd64
docker push $1-arm64
docker manifest push --insecure $1
#docker rmi $1-amd64
#docker rmi $1-arm64
