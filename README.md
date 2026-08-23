# Novel Style Distiller

一个可以直接克隆使用的 AI 长篇小说工作台：先从你提供的完整小说中蒸馏写作风格，再根据你的主题建立原创长篇；以后每次写章都会自动加载同一份风格契约和最新的分层记忆。

它不是“模仿某作者”的 Prompt，也不要求你手工维护几十个文件。仓库内已经部署了蒸馏流程、长篇技法库、记忆系统、项目模板、章节状态机和配置检查工具。

## 最短使用流程

### 1. 克隆并打开仓库

```bash
git clone https://github.com/guilinmini/novel-style-distiller.git
cd novel-style-distiller
```

使用能够读取项目 `AGENTS.md` 和本地文件的 Agent 打开这个目录。无需把本仓库另外复制到 Skills 目录。

### 2. 在对话中给出原著路径

```text
蒸馏这本小说：/path/to/novel.txt
```

Agent 会自动：

1. 登记路径、格式、大小和文件哈希，不复制原著；
2. 建立整书剧情、人物、信息、场景、文风与声音模型；
3. 用跨章节证据、反例和 holdout 验证规律；
4. 生成私有 `audit/`；
5. 编译并检查不含作者名、书名、原作人物、引文和情节映射的 `runtime-style-pack/`。

TXT/Markdown 可以直接处理。PDF/EPUB 需要当前 Agent 环境具备文本提取能力；提取结果仍是本地忽略文件，不进入 Git。

### 3. 直接告诉它原创主题

```text
我要写一部小说：一座每天遗忘一条街道的城市里，地图修复师寻找失踪的姐姐。
```

如果只有一个合格风格包，Agent 会自动使用它，然后完成：

- 原创 premise、人物、世界规则、结局方向和全书/分卷规划；
- 锁定的风格包快照；
- Story Bible、章节蓝图和长期记忆；
- 项目内置长篇技法库；
- 项目专属 `.agents/skills/<project>-writer/SKILL.md`；
- 项目激活和配置体检。

### 4. 开始自然对话写作

```text
写第一章。
接受这一章，继续下一章。
重写第二章，让冲突更早发生，但不要改变结尾事实。
检查最近五章的文风漂移和伏笔欠账。
```

不需要反复指定原著或风格。项目 writer 每次都会读取锁定的 `WRITING_STYLE_CONTRACT.md`。

## 长篇为什么不会只靠聊天记忆

项目采用分层文件记忆：

| 记忆层 | 保存内容 |
|---|---|
| Story Bible | 稳定世界规则、人物身份、秘密和术语 |
| Master Outline | 结局方向、分幕/分卷、未来章节功能 |
| Current State | 写下一章必需的紧凑现状 |
| Character / Entity State | 人物、地点、物件、组织的当前状态 |
| Relationship Ledger | 信任、权力、债务、关系变化 |
| Knowledge Ledger | 作者真相、人物知识、读者知识 |
| Timeline / Continuity | 已发生事件与时间、身体、物件、规则约束 |
| Plot Threads | 主线、支线、伏笔、承诺与兑现窗口 |
| Chapter Records | 每章验收后产生的事实增量 |
| Arc/Volume Summaries | 远期历史的因果压缩，而不是流水账 |
| Decision / Revision Logs | 用户决定、重要假设和修订影响 |

写章前只组装与本章相关的临时 context pack，不把整部小说、全部设定和所有旧章节塞进上下文。

## 内置长篇技法

[`knowledge/INDEX.md`](knowledge/INDEX.md) 按当前问题选择加载以下模块：

- 故事发动机、因果主线、分幕/分卷与升级；
- 人物弧、能动性、关系变化和角色声音；
- 世界规则、系统后果、机构、术语和说明信息；
- 场景转折、章节边界与 scene/sequel；
- 节奏、张力、压缩和延展；
- POV、人物知识、读者信息和公平揭示；
- 对白目标、策略、潜台词和说明信息；
- 伏笔、读者承诺、线程老化与兑现；
- 类型承诺、连载章节回报和分卷更新；
- 连续性、已验收章节修订和影响传播；
- 蒸馏风格在不同场景中的稳定应用。

通用技法不会覆盖用户要求、已验收事实、POV、章节任务或蒸馏风格契约。

## 每章工作流

```text
PREPARE
  读取风格契约 + 记忆索引，构建本章 context pack
→ PLAN
  明确本章变化、场景卡、线程和技法模块
→ DRAFT
  用稳定风格常量和场景模式写作
→ REVIEW
  检查任务、连续性、知识、POV、文风和来源泄漏
→ DELIVER
  交付草稿，不修改 canon
→ ACCEPT / COMMIT
  用户接受后才回写全部记忆层
```

这里的 `COMMIT` 指提交小说 canon，不是执行 Git commit。

## 仓库与生成目录

```text
novel-style-distiller/
├── AGENTS.md                # 克隆后自然语言入口
├── SKILL.md                 # 蒸馏、建书、写章核心协议
├── scripts/novelctl.sh      # 工作区登记、激活、状态与体检
├── knowledge/               # 内置长篇写作技法
├── references/              # 蒸馏、项目编排和记忆规范
├── extractors/              # 六路小说提取器
├── templates/               # 审计、风格、项目与记忆模板
├── tests/                   # 无外部依赖的隔离冒烟测试
├── distillations/           # 本地生成，Git 忽略
├── novel-projects/          # 本地生成，Git 忽略
└── .novel/                  # 活动来源/项目指针，Git 忽略
```

## 可选维护命令

普通用户不需要手动运行；Agent 会调用它们。

```bash
sh scripts/novelctl.sh register-source "/path/to/novel.txt"
sh scripts/novelctl.sh activate-pack "distillations/my-source/runtime-style-pack"
sh scripts/novelctl.sh scaffold-project "my-project" "distillations/my-source/runtime-style-pack"
sh scripts/novelctl.sh activate-project "novel-projects/my-project"
sh scripts/novelctl.sh status
sh scripts/novelctl.sh doctor
sh tests/smoke.sh
```

`novelctl.sh` 使用 POSIX Shell，不需要 Python、数据库、RAG、图数据库或第三方包。没有 Shell 的 Agent 也可以按照模板完成同样配置。

## 作为独立 Skill 安装

如果不想使用完整工作台，也可以安装到用户级 Skills 目录：

```bash
git clone https://github.com/guilinmini/novel-style-distiller ~/.agents/skills/novel-style-distiller
```

此时仍可显式使用 `$novel-style-distiller`，但工作区活动指针和根 `AGENTS.md` 路由只在完整仓库模式下生效。

## 边界

- 只处理小说，并且只基于用户实际提供的文本；
- 一部小说只能支持对该作品、版本和译本的判断；
- 不续写原著，不复用人物、世界、专名、独特表达或情节骨架；
- 原著、OCR 文件、审计证据和生成项目默认不进入 Git；
- 写原创章节时不会重新打开原著或 `audit/`；
- 节选只能生成实验结果，不能冒充完整小说的稳定风格包。

贡献规范见 [CONTRIBUTING.md](CONTRIBUTING.md)。本项目采用 GNU AGPL v3.0，参见 [LICENSE](LICENSE)；来源说明见 [NOTICE](NOTICE)。
