# 脚本规范：package.sh

## 基本信息

- **脚本名称**：`package.sh`
- **严格性级别**：简单
- **脚本类型**：可执行脚本
- **作者**：pengzhaozun
- **创建日期**：2025-12-19
- **版本**：v1.0.0

## 功能概述
打包安装包的脚本

## 核心流程
### kube 包打包
```bash
basePath=$(cd `dirname $0`; pwd)
packageDir=${basePath}/deliver-manifest

cd ${packageDir}
make PRODUCT=kube VERSION=v1.6.0-gkd MULTIARCH=system
```

### docker包打包
```bash
basePath=$(cd `dirname $0`; pwd)
packageDir=${basePath}/docker-deliver-manifest

cd ${packageDir}/docker
./export-images.sh

cd ${packageDir}/
tar -zcvf docker-installer.tar.gz docker

```


## 使用方法
```bash
# 打包 kube 安装包
./package.sh --type kube

# 打包 docker 安装包
./package.sh --type docker
```






