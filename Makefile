# Git 自动化推送
# 使用: make 或 make push

# 自动获取当前分支
CURRENT_BRANCH := $(shell git branch --show-current 2>/dev/null || echo "unknown")
COMMIT_TIME := $(shell date '+%Y-%m-%d_%H-%M-%S')
COMMIT_MSG ?= "Auto commit at $(COMMIT_TIME)"

.PHONY: push

# 默认目标：提交并推送当前分支
push:
	@echo "🚀 开始处理分支: $(CURRENT_BRANCH)"
	@echo "=== 添加所有更改 ==="
	git add .
	@echo ""
	@echo "=== 提交更改 ==="
	@if git diff --cached --quiet; then \
		echo "没有需要提交的更改"; \
	else \
		git commit -m $(COMMIT_MSG) && echo "提交完成"; \
	fi
	@echo ""
	@echo "=== 推送到远程 ($(CURRENT_BRANCH)) ==="
	git push origin $(CURRENT_BRANCH)
	@echo ""
	@echo "✅ 分支 $(CURRENT_BRANCH) 推送完成！"

