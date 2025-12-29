#!/bin/bash

basePath=$(cd `dirname $0`; pwd)
packageDir=${basePath}/deliver-manifest

cd ${packageDir}
make PRODUCT=kube VERSION=v1.6.0-gkd MULTIARCH=system