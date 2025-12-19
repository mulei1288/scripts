#!/bin/bash

# 删除 Go 语言代码中的行注释
# 用法: ./remove-go-comments.sh <文件或目录>

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 显示用法信息
show_usage() {
    echo "用法: $0 <文件或目录>"
    echo "删除 Go 语言代码中的行注释 (// 注释)"
    echo ""
    echo "选项:"
    echo "  -r, --recursive   递归处理目录"
    echo "  -b, --backup      删除前创建备份文件 (.bak)"
    echo "  -h, --help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 main.go                     # 处理单个文件"
    echo "  $0 -r ./src                    # 递归处理目录"
    echo "  $0 -b main.go                  # 创建备份并处理文件"
}

# 处理单个文件
process_file() {
    local file="$1"
    local backup="$2"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}错误: 文件不存在: $file${NC}"
        return 1
    fi

    # 检查是否为 Go 文件
    if [[ "$file" != *.go ]]; then
        echo -e "${YELLOW}跳过: 不是 Go 文件: $file${NC}"
        return 0
    fi

    echo -e "${GREEN}处理文件: $file${NC}"

    # 创建备份
    if [[ "$backup" == "true" ]]; then
        cp "$file" "${file}.bak"
        echo "已创建备份: ${file}.bak"
    fi

    # 使用 sed 删除行注释
    # 注意: 这不会处理字符串中的 "//"，但会处理大多数情况
    sed -i.tmp -E '/^[[:space:]]*\/\//d; s/([^:])\/\/.*$/\1/' "$file"

    # 删除 sed 创建的临时文件
    rm -f "${file}.tmp"

    echo "完成"
}

# 递归处理目录
process_directory() {
    local dir="$1"
    local backup="$2"

    if [[ ! -d "$dir" ]]; then
        echo -e "${RED}错误: 目录不存在: $dir${NC}"
        return 1
    fi

    echo -e "${GREEN}处理目录: $dir${NC}"

    # 查找所有 .go 文件
    while IFS= read -r -d '' file; do
        process_file "$file" "$backup"
    done < <(find "$dir" -type f -name "*.go" -print0)
}

# 主函数
main() {
    local target=""
    local recursive=false
    local backup=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--recursive)
                recursive=true
                shift
                ;;
            -b|--backup)
                backup=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo -e "${RED}错误: 未知选项: $1${NC}"
                show_usage
                exit 1
                ;;
            *)
                target="$1"
                shift
                ;;
        esac
    done

    # 检查目标是否存在
    if [[ -z "$target" ]]; then
        echo -e "${RED}错误: 请指定文件或目录${NC}"
        show_usage
        exit 1
    fi

    # 处理文件或目录
    if [[ -f "$target" ]]; then
        process_file "$target" "$backup"
    elif [[ -d "$target" ]]; then
        if [[ "$recursive" == "true" ]]; then
            process_directory "$target" "$backup"
        else
            echo -e "${YELLOW}提示: 使用 -r 选项递归处理目录${NC}"
            echo "当前目录下的 Go 文件:"
            find "$target" -maxdepth 1 -name "*.go"
        fi
    else
        echo -e "${RED}错误: 文件或目录不存在: $target${NC}"
        exit 1
    fi
}

# 更精确的版本 - 使用 awk 处理，避免删除字符串中的内容
process_file_precise() {
    local file="$1"
    local backup="$2"

    if [[ ! -f "$file" ]]; then
        echo -e "${RED}错误: 文件不存在: $file${NC}"
        return 1
    fi

    if [[ "$file" != *.go ]]; then
        echo -e "${YELLOW}跳过: 不是 Go 文件: $file${NC}"
        return 0
    fi

    echo -e "${GREEN}处理文件 (精确模式): $file${NC}"

    # 创建备份
    if [[ "$backup" == "true" ]]; then
        cp "$file" "${file}.bak"
        echo "已创建备份: ${file}.bak"
    fi

    # 使用 awk 删除行注释，同时保留字符串中的内容
    awk '
    {
        line = $0
        result = ""
        in_string = 0
        string_char = ""

        for (i = 1; i <= length(line); i++) {
            char = substr(line, i, 1)
            next_char = substr(line, i+1, 1)

            # 处理字符串
            if (!in_string) {
                if (char == "\"" || char == "'\''" || char == "`") {
                    in_string = 1
                    string_char = char
                    result = result char
                } else if (char == "/" && next_char == "/") {
                    # 找到行注释，跳出循环
                    break
                } else {
                    result = result char
                }
            } else {
                result = result char
                # 检查字符串结束，但忽略转义字符
                if (char == string_char) {
                    # 检查前一个字符是否是转义字符
                    if (i == 1 || substr(line, i-1, 1) != "\\") {
                        in_string = 0
                        string_char = ""
                    }
                }
            }
        }

        print result
    }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    echo "完成"
}

# 运行主函数
main "$@"