#!/bin/bash
set -eo pipefail
set -x

systemArch=`arch`
if [ "$systemArch" = "x86_64" ]; then
	systemArch="amd64"
elif [ "$systemArch" = "aarch64" ]; then
	systemArch="arm64"
fi

basePath=$(cd `dirname $0`; pwd)
dependPath=${basePath}/depends


# log print
print_m() {
	type="info"
	if [ "$2" != "" ]; then
		type="$2"
	fi
	echo "[$type] $1"
}

function install_nodejs() {
    print_m "start to install nodejs"
    cd "${dependPath}/node"
    tar xf node-v16.19.0-linux-${systemArch}.tar.xz -C /usr/local/
    echo "export PATH=/usr/local/node-v16.19.0-linux-${systemArch}/bin:\$PATH" >> ~/.bashrc
    source ~/.bashrc
    node -v
    print_m "start to install nodejs" "success"
}

function install_docker(){
    print_m "start to install docker"
    if ! systemctl status docker --no-pager > /dev/null 2>&1; then
        cd "${dependPath}/docker/${systemArch}"
        tar -zxvf docker-20.10.7.tgz
        mv docker/* /usr/bin/
        cd "${dependPath}/docker/"
        mkdir -p /etc/docker
        mkdir -p ~/.docker
        cp daemon.json /etc/docker/daemon.json
        cp config.json ~/.docker/daemon.json
        cp docker.service /usr/lib/systemd/system/docker.service
        echo "127.0.0.1 registry.bingosoft.net" >> /etc/hosts
        systemctl daemon-reload
        systemctl start docker
        systemctl enable docker
    fi
    print_m "install docker done" "success"
}

function install_buildx() {
    print_m "start to install buildx"
    if ! docker buildx ls > /dev/null 2>&1; then
      cd "${dependPath}/images/${systemArch}"
      ls
      docker load -i buildkit.tar.gz
      mkdir -p ~/.docker/cli-plugins
      cp ${dependPath}/binary/buildx-v0.8.2.linux-$systemArch ~/.docker/cli-plugins/docker-buildx
      cd "${dependPath}/docker/"
      mkdir -p /etc/buildkit
      cp buildkitd.toml /etc/buildkit/
      docker buildx create --use --name builder --driver-opt network=host --driver-opt image="registry.bingosoft.net/devops/buildkit:buildx-stable-1" --platform linux/arm64,linux/amd64 --config /etc/buildkit//buildkitd.toml
    fi
    print_m "install buildx done" "success"
}

function start_registry() {
    print_m "start to install registry"
    if ! docker ps --filter "name=registry" 2>/dev/null | grep -v NAMES | wc -l; then
        cd "${dependPath}/images/${systemArch}"
        docker load -i registry.tar.gz
        rm -rf /var/lib/registry
        cp -r ${dependPath}/images/registry /var/lib/
        docker run -d \
          -p 80:5000 \
          -p 443:5000 \
          --restart=always \
          --name registry \
          -v /var/lib/registry:/var/lib/registry \
          registry:2
    fi
    print_m "start to install registry" "success"
}

function install_build_tool() {
    print_m "start to install build tools"
    if ! kubepilot version > /dev/null 2>&1; then
      cp ${dependPath}/binary/kubepilot-v1.2.0-linux-$systemArch /usr/local/bin/kubepilot
    fi

    if ! buildah version > /dev/null 2>&1; then
      cp ${dependPath}/binary/buildah-v1.30.0-$systemArch /usr/local/bin/buildah
    fi

    print_m "start to install build tools" "success"
}

install_go_depends(){
  print_m "start to install go depends"
  cd "${dependPath}"
  tar -zxf gvm.tar.gz -C /root
  source /root/.gvm/scripts/gvm
  gvm use go1.22
  go version
  print_m "install go depends done" "success"
}

install_rpm() {
  print_m "start to install rpm"
  yum install -y git make bison gcc mercurial glibc-devel bc
  print_m "install rpm done" "success"
}

main(){
  install_rpm
  install_go_depends
  install_docker
  install_buildx
  start_registry
  install_build_tool
  install_nodejs
}

main 2>&1 | tee "${basePath}/prepare.log"
print_m "prepare done" "success"
