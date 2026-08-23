# Novel Style Distiller

把一部完整小说蒸馏成与来源隔离、可持续执行的写作风格契约；再根据你的主题建立一部原创长篇，并让以后每次写章、续写和修订都自动加载同一份风格契约与最新故事状态。

它不是摘要器，也不是“模仿某作者”的 Prompt。它提炼可观察、可调节、可测试的写作机制，同时把来源证据和实际写作环境分开。

## 现在能做什么

### 1. 蒸馏完整小说

- 建立剧情、人物、时间线、伏笔、信息控制和场景节奏模型；
- 提取文风、叙述声音、语气、对白、句法、节奏、意象与情绪呈现机制；
- 使用跨章节证据、反例和 holdout 验证结论；
- 生成私有审计区和不含来源身份的 `runtime-style-pack`。

### 2. 从主题建立原创长篇

- 创建原创 premise、世界规则、人物、主线、结局方向和章节大纲；
- 把选定的风格包复制并锁定到项目；
- 建立 Story Bible、当前状态、剧情线程、时间线和章节记录；
- 自动生成项目专属 `.agents/skills/<project>-writer/SKILL.md`。

### 3. 持续写章

每章都执行：

```text
加载风格与状态 → 章节蓝图 → 起草 → 连续性/文风/原创性检查
→ 交付草稿 → 用户接受 → 回写长期状态
```

风格契约每次必载，但会根据动作、对白、内省、过渡、高潮等场景切换强度，因此不会把所有章节写成同一种表面节奏。

## 为什么分成两个区

```text
distillations/<source>/
├── audit/                 # 来源身份、证据、画像、失败项，只用于审计
└── runtime-style-pack/    # 中性写作契约，供原创项目复制

novel-projects/<project>/
├── style/                 # 锁定的 runtime pack 快照
├── bible/                 # 稳定设定与人物事实
├── outline/               # 总纲与章节蓝图
├── state/                 # 当前状态、线程、时间线、章节记录
├── chapters/              # 小说正文
└── .agents/skills/<project>-writer/
```

写章时只读取原创项目，不读取原著或蒸馏证据。这既减少上下文噪声，也降低人物、专名、情节和独特表达泄漏到新书的风险。

## 安装

用户级安装：

```bash
git clone https://github.com/guilinmini/novel-style-distiller ~/.agents/skills/novel-style-distiller
```

项目级安装：

```text
<workspace>/.agents/skills/novel-style-distiller/
```

其他支持 Agent Skills 的宿主，将整个仓库复制到其 Skill 发现目录即可。必须保留 `SKILL.md`、`references/`、`extractors/` 与 `templates/` 的相对结构。

本项目是纯 Markdown Skill，不需要 Python、数据库、RAG、图数据库或第三方运行时。

## 使用方法

### 第一步：蒸馏

准备你有权在本地分析的完整小说，推荐 UTF-8 TXT 或 Markdown。PDF/EPUB 应先完整提取并检查章节顺序、缺页和乱码。

```text
使用 $novel-style-distiller，把 /path/to/novel.txt 蒸馏成一个
可用于原创长篇的 runtime style pack，输出到 distillations/my-source/。
```

默认输出为 `distillations/<source-slug>/`。节选或短样本只能生成实验性结果，不能冒充正式整书风格包。

### 第二步：给主题建书

```text
使用 $novel-style-distiller，采用
distillations/my-source/runtime-style-pack/，根据这个主题创建原创长篇：
“一座每天遗忘一条街道的城市里，地图修复师寻找失踪的姐姐。”
项目名暂定《失街图》，输出到 novel-projects/lost-streets/。
```

Skill 会生成项目专属 writer Skill，并把风格包版本锁定在项目中。上游风格包以后改变，不会静默改变这本小说。

### 第三步：写章、续写、修订

在原创项目目录内直接说：

```text
写第一章。
```

或显式调用：

```text
使用 $lost-streets-writer，写第一章。
```

以后可以说：

```text
下一章。
重写第二章，让冲突更早发生，但不要改变结尾事实。
检查最近三章有没有文风漂移。
```

章节交付时仍是草稿。你说“接受/定稿”，或在没有提出修订时直接要求“下一章”，才会把上一章写入 canon，并更新状态、时间线和剧情线程。

## 仓库结构

```text
novel-style-distiller/
├── SKILL.md                 # 三种模式与总入口
├── agents/openai.yaml       # UI 元数据
├── references/              # 蒸馏、建书与逐章状态规范
├── extractors/              # 六个独立小说提取器
├── templates/               # 审计、风格包与原创项目模板
└── examples/                # 可公开的合成示例
```

## 重要边界

- 只处理小说，不处理散文、非虚构、剧本或方法论书；
- 只基于用户提供的文本，不凭模型记忆补写原著；
- 一部小说只能支持当前作品和版本的结论，不能代表作者全部作品；
- 译本的具体语言特征不能直接归因于原作者；
- 不续写原著，不复用人物、世界观、专名、独特表达或情节骨架；
- 原著正文、OCR 文件和审计证据不进入项目 writer Skill，也不应提交到 Git；
- “风格”必须展开成可观察行为，不能只写“像某作者”。

## 贡献与许可

参见 [CONTRIBUTING.md](./CONTRIBUTING.md)。只提交合成文本或明确可再分发的测试材料，不要提交未经授权的小说原文。

本项目采用 GNU Affero General Public License v3.0，参见 [LICENSE](./LICENSE)。项目由 `cangjie-skill` 大幅重构而来，来源说明见 [NOTICE](./NOTICE)。
