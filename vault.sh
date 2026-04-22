#!/bin/bash

set -e

ROOT_DIR=$(pwd)
UNSAFE=0

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
    if [ "$UNSAFE" -eq 1 ]; then
      echo ""
      echo "❌ pull --rebase 失败，仓库当前处于 rebase 中间态。"
      echo "   你已启用 --unsafe 模式，请手动处理后继续："
      echo "     git rebase --continue   # 解决冲突后继续"
      echo "     git rebase --abort      # 放弃并恢复到 pull 之前"
    else
      echo ""
      echo "❌ pull --rebase 遇到冲突，已自动执行 git rebase --abort 以保护仓库状态。"
      echo "   本次同步已跳过，仓库内容保持 pull 前的状态，无任何损坏。"
      echo "   如需手动解决冲突，请加 --unsafe 参数重新运行："
      echo "     ./vault.sh --unsafe sync ..."
      git rebase --abort 2>/dev/null || true
    fi
    return 1
  fi

  # 恢复 stash
  if [ "$STASHED" -eq 1 ]; then
    echo "📤 恢复 stash"
    if ! git stash pop >/dev/null; then
      if [ "$UNSAFE" -eq 1 ]; then
        echo ""
        echo "⚠️ stash pop 遇到冲突，仓库工作区存在冲突标记。"
        echo "   你已启用 --unsafe 模式，请手动处理："
        echo "     1. 编辑冲突文件，删除 <<<< ==== >>>> 标记"
        echo "     2. git add <冲突文件>"
      else
        echo ""
        echo "⚠️ 恢复本地修改时遇到冲突，已停止操作，冲突文件已标记在工作区。"
        echo "   请手动解决后执行："
        echo "     1. 编辑冲突文件，删除 <<<< ==== >>>> 标记"
        echo "     2. git add <冲突文件>"
        echo "   如需直接丢弃本地修改（保留远端版本），可运行："
        echo "     git checkout --theirs . && git add ."
        echo "   下次运行时建议加 --unsafe 以便自行控制处理过程："
        echo "     ./vault.sh --unsafe sync ..."
      fi
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
    if [ -e "$dir/.git" ]; then
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

print_usage() {
  printf "\n"
  printf "  \033[1mUsage:\033[0m  vault.sh [--unsafe] <command> [subcommand] [args]\n"
  printf "\n"
  printf "  \033[1mCommands:\033[0m\n"
  printf "    \033[1;32msync all\033[0m               全部同步（子仓库 → 主仓库）\n"
  printf "    \033[1;32msync vault\033[0m             仅同步主仓库\n"
  printf "    \033[1;32msync shared\033[0m            仅同步全部共享仓库\n"
  printf "    \033[1;32msync shared\033[0m \033[2m<name>\033[0m     仅同步指定共享仓库\n"
  printf "    \033[1;32mhelp\033[0m                   显示此帮助信息\n"
  printf "\n"
  printf "  \033[1mOptions:\033[0m\n"
  printf "    \033[1;33m--unsafe\033[0m               冲突时不自动 abort，由用户手动处理\n"
  printf "                           （默认行为：冲突时自动 abort 并跳过，保护仓库状态）\n"
  printf "\n"
  printf "  \033[1mExamples:\033[0m\n"
  printf "    ./vault.sh sync all\n"
  printf "    ./vault.sh sync shared\n"
  printf "    ./vault.sh sync shared team-wiki\n"
  printf "    ./vault.sh --unsafe sync all\n"
  printf "\n"
  printf "  不带参数运行进入\033[2m交互模式\033[0m。\n"
  printf "\n"
}

cmd_sync() {
  case "$1" in
    all)
      sync_all
      ;;
    vault)
      sync_vault
      ;;
    shared)
      if [ -z "$2" ]; then
        sync_all_shared
      else
        sync_one_shared "$2"
      fi
      ;;
    "")
      echo "❌ sync 需要子命令，用法: vault.sh sync <all|vault|shared> [name]"
      print_usage
      exit 1
      ;;
    *)
      echo "❌ 未知子命令: sync $1"
      print_usage
      exit 1
      ;;
  esac
}

# 解析全局 --unsafe 标志（允许放在任意位置）
ARGS=()
for arg in "$@"; do
  if [ "$arg" = "--unsafe" ]; then
    UNSAFE=1
  else
    ARGS+=("$arg")
  fi
done
set -- "${ARGS[@]}"

if [ "$UNSAFE" -eq 1 ]; then
  printf "  \033[1;33m⚠️  --unsafe 模式：冲突时不会自动 abort，请做好手动处理准备。\033[0m\n"
fi

case "$1" in
  sync)
    shift
    cmd_sync "$@"
    exit
    ;;
  help|--help|-h)
    print_header
    print_usage
    exit
    ;;
  "")
    # 进入交互模式
    ;;
  *)
    echo "❌ 未知命令: $1"
    print_usage
    exit 1
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
  "帮助"
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
    print_usage
    ;;
  5)
    echo "  👋 再见"
    exit 0
    ;;
esac
