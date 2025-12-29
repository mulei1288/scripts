#!/bin/bash
set -eo pipefail


systemArch=`arch`
if [ "$systemArch" = "x86_64" ]; then
	systemArch="amd64"
elif [ "$systemArch" = "aarch64" ]; then
	systemArch="arm64"
fi
globalPath=$PATH
buildArch=multiarch

basePath=$(cd `dirname $0`; pwd)
codePath=${1:-"/root/code"}
clusterImageDir=${basePath}/cluster-image
k8sVersion="v1.25.26-tenant"
cachePath=/root/kube-build/cache

source ~/.bashrc
source ~/.gvm/scripts/gvm
export GOINSECURE="gitlab.bingosoft.net"
export GONOPROXY="gitlab.bingosoft.net"
export GONOSUMDB="gitlab.bingosoft.net"
export GOPRIVATE="gitlab.bingosoft.net"

# get args
for arg in $@
do
	case $arg in
    #multiarch、amd64、arm64（不填默认使用当前机器架构）
		--buildArch=*)
		buildArch="${arg#*=}"
		shift
		;;
		*)
		;;
	esac
done

# log print
print_m() {
	type="info"
	if [ "$2" != "" ]; then
		type="$2"
	fi
	echo "[$type] $1"
}

function switch_go23() {
   print_m "start switch go1.23.2"
   gvm use go1.23.2
   print_m "switch go done" "success"
}

function switch_go22() {
   print_m "start switch go22"
   gvm use go1.22
   print_m "switch go done" "success"
}

function switch_go17() {
    print_m "start switch go17"
    gvm use go1.17
    print_m "switch go done" "success"
}


#编译k8s镜像
function build_kubernete_image() {
    switch_go17
    #进入k8s目录
    cd "$codePath/kubernetes"
    print_m "start build kubernetes image arm64"
    KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PULL_LATEST_IMAGES=n KUBE_BUILD_PLATFORMS=linux/arm64 KUBE_BUILD_CONFORMANCE=n KUBE_BUILD_HYPERKUBE=n  make release-images
    print_m "start build kubernetes image amd64"
    KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PULL_LATEST_IMAGES=n KUBE_BUILD_PLATFORMS=linux/amd64 KUBE_BUILD_CONFORMANCE=n KUBE_BUILD_HYPERKUBE=n  make release-images

    create_manifest registry.bingosoft.net/bingokube/kube-apiserver:$k8sVersion
    create_manifest registry.bingosoft.net/bingokube/kube-controller-manager:$k8sVersion
    create_manifest registry.bingosoft.net/bingokube/kube-scheduler:$k8sVersion
    create_manifest registry.bingosoft.net/bingokube/kube-proxy:$k8sVersion

#    if [ "$buildArch" = "multiarch" ]; then
#      #arm64
#      print_m "start build kubernetes binary arm64"
#      KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PLATFORMS=linux/arm64 make WHAT=cmd/kubeadm
#      KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PLATFORMS=linux/arm64 make WHAT=cmd/kubelet
#      KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PLATFORMS=linux/arm64 make WHAT=cmd/kubectl
#      #amd64
#      print_m "start build kubernetes binary amd64"
#      KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PLATFORMS=linux/amd64 make WHAT=cmd/kubeadm
#      KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PLATFORMS=linux/amd64 make WHAT=cmd/kubelet
#      KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PLATFORMS=linux/amd64 make WHAT=cmd/kubectl
#      mkdir -p $cachePath/kube/{arm64,amd64}
#      cp $codePath/kubernetes/_output/local/bin/linux/arm64/kubectl $cachePath/kube/arm64
#      cp $codePath/kubernetes/_output/local/bin/linux/arm64/kubelet $cachePath/kube/arm64
#      cp $codePath/kubernetes/_output/local/bin/linux/amd64/kubectl $cachePath/kube/amd64
#      cp $codePath/kubernetes/_output/local/bin/linux/amd64/kubelet $cachePath/kube/amd64
#    else
#      print_m "start build kubernetes binary ${buildArch}"
#      KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PLATFORMS=linux/$buildArch make WHAT=cmd/kubeadm
#      KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PLATFORMS=linux/$buildArch make WHAT=cmd/kubelet
#      KUBE_GIT_VERSION=$k8sVersion KUBE_BUILD_PLATFORMS=linux/$buildArch make WHAT=cmd/kubectl
#      mkdir -p $cachePath/kube/$systemArch
#      cp $codePath/kubernetes/_output/local/bin/linux/$systemArch/kubeadm $cachePath/kube/$systemArch
#      cp $codePath/kubernetes/_output/local/bin/linux/$systemArch/kubectl $cachePath/kube/$systemArch
#      cp $codePath/kubernetes/_output/local/bin/linux/$systemArch/kubelet $cachePath/kube/$systemArch
#    fi

    print_m "build kubernetes done" "success"
}

function create_manifest() {
    rm -rf ~/.docker/manifests
    image=$1
    docker push $image-amd64
    docker push $image-arm64
    docker manifest create --insecure $image $image-amd64 $image-arm64
    docker manifest push --insecure $image
}

build_uam() {
  print_m "start build uam"
  cd ${clusterImageDir}/uam
  make VERSION=v1.1.0-gkd-0917 REGISTRY_PREFIX=registry.bingosoft.net/bingokube/cluster-image
  print_m "build uam done" "success"
}

build_front() {
  print_m "start build front image"
  cd "$codePath/kube-verse"
  npm run build
  docker buildx build -f Dockerfile \
      -t registry.bingosoft.net/bingokube/kubeverse-front:v1.6.0 ./ \
      --platform="linux/amd64,linux/arm64" --push
  print_m "build front image done" "success"
}

build_scheduler() {
  print_m "start build scheduler image"
  cd "$codePath/bingokube-scheduler"
  switch_go22
  make image.multiarch VERSION=v1.22.25-tenant REGISTRY_PREFIX=registry.bingosoft.net/bingokube
  print_m "build scheduler image done" "success"
}

build_kubealived() {
  print_m "start build kubealived"
  cd "$codePath/kubealived"
  switch_go22
  make image.multiarch VERSION=v1.0.3 REGISTRY_PREFIX=registry.bingosoft.net/bingokube
  print_m "build kubealived done" "success"
}

build_kubepilot(){
  print_m "start build kubepilot"
  mkdir -p $cachePath/kubepilot/{arm64,amd64}
  cd "$codePath/kubepilot"
  switch_go17
  go mod vendor
  make build.multiarch BINS=kubepilot
  \cp _output/platforms/linux/arm64/kubepilot $cachePath/kubepilot/arm64/
  \cp _output/platforms/linux/amd64/kubepilot $cachePath/kubepilot/amd64/

  cd ${clusterImageDir}/kubepilot
  make VERSION=v1.0.4-gkd-0820 REGISTRY_PREFIX=registry.bingosoft.net/bingokube/cluster-image
  print_m "build kubepilot done" "success"
}

build_k8s(){
  print_m "start build kubernetes"
  build_kubernete_image
  cd "$codePath/bingokube-scheduler"
  switch_go22
  go mod tidy
  make image.multiarch VERSION=v1.22.25-tenant REGISTRY_PREFIX=registry.bingosoft.net/bingokube
  print_m "build kubernetes done" "success"
}

build_kubedupont(){
  print_m "start build kubedupont"
  switch_go22
  cd "$codePath/kubedupont"
  make image.multiarch VERSION=v1.2.0-gkd REGISTRY_PREFIX=registry.bingosoft.net/bingokube
  cd ${clusterImageDir}/kubedupont
  make VERSION=v1.1.0-gkd-20251125 REGISTRY_PREFIX=registry.bingosoft.net/bingokube/cluster-image
  print_m "build kubedupont done" "success"
}

build_kubeverse(){
  print_m "start build kubeverse"
  build_front
  #编译后端
  cd "$codePath/kubeverse"
  switch_go22
  make image.multiarch VERSION=v1.6.0-gkd REGISTRY_PREFIX=registry.bingosoft.net/bingokube
  #编译集群镜像
  cd ${clusterImageDir}/kubeverse
  make VERSION=v1.6.0-gkd-20251223 REGISTRY_PREFIX=registry.bingosoft.net/bingokube/cluster-image
  print_m "build kubeverse"  "success"
}

build_resource_manager_front() {
  print_m "start build front image"
  cd "$codePath/ccpc-project/bcc-hci"
  npm run build
  print_m "build front image done" "success"
}

build_resource_manager(){
  print_m "start build resource-manager"
  build_resource_manager_front
  #编译后端
  cd "$codePath/ccpc-project/resource-manager"
  switch_go23
  make docker-manifest -e VERSION=v1.3.6 -e RVDay=20251215
  #编译集群镜像
  cd ${clusterImageDir}/resource-manager
  make VERSION=v1.3.6-gkd-20251215 REGISTRY_PREFIX=registry.bingosoft.net/bingokube/cluster-image
  print_m "build resource-manager"  "success"
}


build_nvs(){
  print_m "start build nvs"
  cd ${clusterImageDir}/kube-nvs
  make VERSION=v1.6.1-gkd REGISTRY_PREFIX=registry.bingosoft.net/bingokube/cluster-image
  print_m "build nvs done" "success"
}

build_setup_assistant(){
  print_m "start build setup-assistant"
  cd ${codePath}/ccpc-project/bcc-hci
  npm run build
  print_m "build setup-assistant done" "success"
}

prepare_dep(){
  print_m "start prepare dep"
  cd ${basePath}/depends
  ./unpack_db.sh
  print_m "prepare dep done" "success"
}


clean_dep(){
  cd ${basePath}/depends
  ./3_clean_db.sh > /dev/null 2>&1
}

cleanup() {
  exit 0
  print_m "clean ..."
  clean_dep
  cd ${basePath}
  ./clean.sh
}

#trap cleanup EXIT

# 读取 .apps 配置文件
load_apps_config() {
    declare -gA apps_config
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue  # 跳过注释
        [[ -z "$key" ]] && continue                  # 跳过空行
        # 移除前后空格
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        apps_config["$key"]="$value"
    done < ${basePath}/.apps
}

# 检查应用是否应该被构建
should_build() {
    local app_name=$1
    [[ "${apps_config[$app_name]}" == "true" ]]
}

main(){
    load_apps_config
    #prepare_dep
    should_build "kubepilot" && build_kubepilot
    should_build "k8s" && build_k8s
    should_build "kubedupont" && build_kubedupont
    should_build "uam" && build_uam
    should_build "kube-nvs" && build_nvs
    should_build "kubealived" && build_kubealived
    should_build "kubeverse" && build_kubeverse
    should_build "setup-assistant" && build_setup_assistant
    should_build "resource-manager" && build_resource_manager

}

main 2>&1 | tee "${basePath}/build.log"
print_m "build done" "success"
