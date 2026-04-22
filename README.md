# 🧠 Vault Template

基于 **Obsidian + Git + Submodule** 的个人知识库模板，开箱即用。

---

## ✨ 包含内容

- 预置目录结构（含 `.gitkeep` 占位）
- 精选插件（`main.js` + `manifest.json`），首次启动 Obsidian 后即可直接启用
- Minimal 主题
- `vault.sh` 一键同步脚本（支持主仓库 + 多子模块）

> 插件配置（`data.json`）不包含在模板中，请在 Obsidian 内自行配置，避免个人偏好或凭证被意外提交。

---

## 📁 目录结构

```
.
├── 00-inbox        临时记录、待处理内容
├── 01-personal     个人笔记
├── 02-knowledge    知识沉淀
├── 03-projects     项目文档
├── 04-shared       外部共享仓库（submodule）
├── 05-company      公司 / 团队相关
├── 99-resources    附件资源
└── vault.sh        同步脚本
```

---

## 🚀 快速开始

```bash
git clone https://github.com/YOUR_USERNAME/vault-template my-vault
cd my-vault
```

用 Obsidian 打开 `my-vault` 目录，在「社区插件」中启用所需插件即可。

---

## 🔌 预置插件

| 插件 | 用途 |
|------|------|
| [Git](https://github.com/Vinzent03/obsidian-git) | Git 版本控制与自动备份 |
| [Dataview](https://github.com/blacksmithgu/obsidian-dataview) | 数据查询与动态视图 |
| [Excalidraw](https://github.com/zsviczian/obsidian-excalidraw-plugin) | 手绘风格白板 |
| [Remotely Save](https://github.com/remotely-save/remotely-save) | S3/WebDAV/OneDrive 同步 |
| [Notebook Navigator](https://github.com/johansan/notebook-navigator) | 双栏文件浏览器 |
| [Folder Notes](https://github.com/LostPaul/obsidian-folder-notes) | 文件夹笔记 |
| [File Explorer++](https://github.com/kelszo/obsidian-file-explorer-plus) | 文件过滤与置顶 |
| [Minimal Theme Settings](https://github.com/kepano/obsidian-minimal) | Minimal 主题配置 |
| [BRAT](https://github.com/TfTHacker/obsidian42-brat) | Beta 插件安装器 |
| [Claudian](https://github.com/YishenTu/claudian) | Claude AI 集成 |
| [Terminal](https://github.com/polyipseity/obsidian-terminal) | 内嵌终端 |
| [Importer](https://github.com/obsidianmd/obsidian-importer) | 多格式笔记导入 |

---

## 🔗 共享仓库（Submodule）

`04-shared/` 用于挂载团队或外部仓库：

```bash
# 添加
git submodule add <repo-url> 04-shared/<name>
git commit -m "add submodule <name>"

# 初始化（克隆后）
git submodule update --init --recursive

# 更新所有子模块
git submodule update --remote
```

---

## 🔄 vault.sh 同步脚本

```bash
# 交互模式（方向键选择）
./vault.sh

# CLI 模式
./vault.sh all          # 全部同步
./vault.sh vault        # 仅主仓库
./vault.sh shared       # 全部子模块
./vault.sh shared <name> # 指定子模块
```

---

## 📋 .gitignore 说明

以下文件已排除，**不会**提交到仓库：

- `.obsidian/workspace.json` — 窗口布局（因机器而异）
- `.obsidian/plugins/remotely-save/data.json` — 云存储凭证
- `.obsidian/plugins/terminal/data.json` — 终端历史
- `.claudian/sessions/` — AI 会话记录
