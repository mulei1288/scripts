#!/bin/bash

# 新 registry，取 $1，没有传就用默认值
DEFAULT_REGISTRY="registry.kube.io:5000"
NEW_REGISTRY="${1:-$DEFAULT_REGISTRY}"

IMAGE_FILE="images.txt"
OUTPUT_DIR="./imgs"
mkdir -p "$OUTPUT_DIR"

ARCHS=("amd64" "arm64")

echo "Using new registry: $NEW_REGISTRY"

while IFS= read -r IMAGE || [[ -n "$IMAGE" ]]; do
    IMAGE=$(echo "$IMAGE" | xargs)
    [ -z "$IMAGE" ] && continue

    for ARCH in "${ARCHS[@]}"; do
        echo "Pulling $IMAGE for $ARCH..."
        docker pull --platform linux/$ARCH "$IMAGE"

        # 提取去掉旧 registry 的部分
        if [[ "$IMAGE" == "$NEW_REGISTRY/"* ]]; then
            # 镜像本身已属于 new registry，则不去掉 registry
            NAME_TAG="${IMAGE#$NEW_REGISTRY/}"
        else
            # 有 registry（包含域名）
            if [[ "$IMAGE" == *"."*/* ]]; then
                NAME_TAG="${IMAGE#*/}"
            else
                NAME_TAG="$IMAGE"
            fi
        fi

        NEW_IMAGE="${NEW_REGISTRY}/${NAME_TAG}"

        echo "Retagging $IMAGE -> $NEW_IMAGE"
        docker tag "$IMAGE" "$NEW_IMAGE"

        TAR_FILE="$OUTPUT_DIR/$(echo "$NEW_IMAGE" | tr '/:' '_')_${ARCH}.tar"

        echo "Saving $NEW_IMAGE to $TAR_FILE..."
        docker save "$NEW_IMAGE" -o "$TAR_FILE"

        echo "Loading $TAR_FILE..."
        docker load -i "$TAR_FILE"
    done

done < "$IMAGE_FILE"

echo "Done. Tar files saved under $OUTPUT_DIR."
