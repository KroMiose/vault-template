#!/bin/bash

set -e

ROOT_DIR=$(pwd)

print_header() {
  echo "================================"
  echo "🧠 Vault Sync Tool"
  echo "📂 $ROOT_DIR"
  echo "================================"
}

has_changes() {
  [[ -n $(git status --porcelain) ]]
}

commit_if_needed() {
  msg="$1"
  if has_changes; then
    echo "📝 commit: $msg"
    git add .
    git commit -m "$msg"
  else
    echo "✔ 无需提交"
  fi
}

safe_pull_rebase() {
  echo "⬇️ pull (rebase)..."

  # 如果有未提交变更，先 stash
  if has_changes; then
    echo "📦 stash 本地修改"
    git stash push -u -m "auto-stash $(date '+%Y-%m-%d %H:%M:%S')" >/dev/null
    STASHED=1
  else
    STASHED=0
  fi

  # pull
  if ! git pull --rebase; then
    echo "❌ pull 失败（可能冲突），请手动处理"
    return 1
  fi

  # 恢复 stash
  if [ "$STASHED" -eq 1 ]; then
    echo "📤 恢复 stash"
    if ! git stash pop >/dev/null; then
      echo "⚠️ stash 恢复冲突，请手动处理"
      return 1
    fi
  fi
}

sync_repo() {
  repo_path="$1"
  name="$2"

  echo ""
  echo "📂 处理仓库: $repo_path"

  cd "$repo_path"

  # 1️⃣ 先 pull（保证最新）
  if ! safe_pull_rebase; then
    echo "⚠️ 跳过该仓库"
    cd "$ROOT_DIR"
    return
  fi

  # 2️⃣ commit 本地变更
  commit_if_needed "$name: update $(date '+%Y-%m-%d %H:%M:%S')"

  # 3️⃣ push
  echo "⬆️ push..."
  if ! git push; then
    echo "❌ push 失败"
    cd "$ROOT_DIR"
    return
  fi

  cd "$ROOT_DIR"
}

sync_vault() {
  sync_repo "$ROOT_DIR" "vault"
}

sync_all_shared() {
  for dir in "$ROOT_DIR"/04-shared/*; do
    if [ -d "$dir/.git" ]; then
      name=$(basename "$dir")
      sync_repo "$dir" "submodule($name)" || echo "⚠️ 子仓库失败: $name"
    fi
  done
}

sync_one_shared() {
  name="$1"
  path="$ROOT_DIR/04-shared/$name"

  if [ ! -d "$path" ]; then
    echo "❌ 不存在: $name"
    exit 1
  fi

  sync_repo "$path" "submodule($name)"
}

sync_all() {
  # ⚠️ 顺序很关键：先子仓库，再主仓库
  sync_all_shared
  sync_vault
}

# =====================
# CLI 模式
# =====================

case "$1" in
  vault)
    sync_vault
    exit
    ;;
  shared)
    if [ -z "$2" ]; then
      sync_all_shared
    else
      sync_one_shared "$2"
    fi
    exit
    ;;
  all)
    sync_all
    exit
    ;;
esac

# =====================
# 交互模式
# =====================

MENU_OPTIONS=(
  "全部同步"
  "仅同步 Vault"
  "仅同步全部共享仓库"
  "仅同步指定共享仓库"
  "退出"
)

_draw_menu() {
  local sel=$1
  for i in "${!MENU_OPTIONS[@]}"; do
    if [ "$i" -eq "$sel" ]; then
      printf "\r\033[K  \033[1;32m❯\033[0m \033[1;7m ${MENU_OPTIONS[$i]} \033[0m\n"
    else
      printf "\r\033[K    ${MENU_OPTIONS[$i]}\n"
    fi
  done
}

_restore_cursor() {
  tput cnorm 2>/dev/null
}
trap _restore_cursor EXIT

print_header
echo ""
printf "  请选择操作 \033[2m(↑↓ / j k 移动，Enter 确认)\033[0m\n"
echo ""

SELECTED=0
NUM_OPTIONS=${#MENU_OPTIONS[@]}

tput civis 2>/dev/null
_draw_menu $SELECTED

while true; do
  read -rsn1 key
  if [[ "$key" == $'\x1b' ]]; then
    read -rsn1 key2
    if [[ "$key2" == '[' ]]; then
      read -rsn1 key3
      case "$key3" in
        'A') key='UP' ;;
        'B') key='DOWN' ;;
        *) key='' ;;
      esac
    else
      key=''
    fi
  fi

  case "$key" in
    UP|k)
      ((SELECTED--))
      [[ $SELECTED -lt 0 ]] && SELECTED=$((NUM_OPTIONS - 1))
      ;;
    DOWN|j)
      ((SELECTED++))
      [[ $SELECTED -ge $NUM_OPTIONS ]] && SELECTED=0
      ;;
    '')
      break
      ;;
  esac

  tput cuu $NUM_OPTIONS 2>/dev/null
  _draw_menu $SELECTED
done

tput cnorm 2>/dev/null
echo ""
printf "  \033[1;32m✔\033[0m 已选择: \033[1m${MENU_OPTIONS[$SELECTED]}\033[0m\n"
echo ""

case $SELECTED in
  0)
    sync_all
    ;;
  1)
    sync_vault
    ;;
  2)
    sync_all_shared
    ;;
  3)
    read -p "  输入仓库名: " name
    sync_one_shared "$name"
    ;;
  4)
    echo "  👋 再见"
    exit 0
    ;;
esac
