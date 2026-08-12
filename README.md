# Novel Style Distiller

把一部完整小说的剧情架构、人物弧光、叙事技法、语言风格、语气与叙述声音，蒸馏成一套有证据、可迁移、可测试的 AI 写作 Skills。

它不是小说摘要器，也不会让 Agent 扮演作者。它分析作品里可观察的写作机制，再把这些机制转换成能用于**原创小说**的工具。

## 它会产出什么

输入一部完整小说后，流水线会生成：

- 整书叙事模型：核心冲突、剧情因果链、伏笔兑现、叙事顺序与人物弧光；
- 文风画像：用词、句法、节奏、段落、意象、感官与描写配置；
- 声音画像：叙述姿态、视角距离、情绪温度、可靠性、幽默/反讽和对白纹理；
- 可安装 Skills：例如“延迟揭示因果”“用动作外化情绪”“控制限知视角距离”；
- 证据与测试：每项结论的原文位置、反例、holdout 验证、路由测试和防复制检查。

## 工作流

```text
来源与版本登记
      ↓
长篇切分 + 稳定定位符 + holdout
      ↓
剧情 / 人物 / 视角信息 / 场景节奏 / 文风 / 语气对白 六路提取
      ↓
证据链 + 反证 + 迁移性 + 非复制性验证
      ↓
STYLE_PROFILE + VOICE_PROFILE + 原子 Skills
      ↓
盲测、兄弟 Skill 混淆测试、原创性检查
      ↓
INDEX + CRAFT_REPORT + 可安装 Skill pack
```

完整执行规范见 [SKILL.md](./SKILL.md)。

## 安装

### Codex

克隆到用户级 Agent Skills 目录：

```bash
git clone https://github.com/guilinmini/novel-style-distiller ~/.agents/skills/novel-style-distiller
```

完整 pack 校验需要 Python 3.11+ 与 `jsonschema`；在你使用的 Python 环境中安装：

```bash
python3 -m pip install -r ~/.agents/skills/novel-style-distiller/requirements.txt
```

项目级安装位置是 `<project>/.agents/skills/novel-style-distiller/`。安装时保留整个仓库，不要只复制 `SKILL.md`。

然后用类似请求触发：

```text
使用 $novel-style-distiller，把 /path/to/novel.txt 蒸馏成小说写作 Skills。
```

### 其他 Agent 宿主

将整个仓库放入宿主可发现的 Skills 目录，确保宿主会读取根目录的 `SKILL.md`。例如项目级安装可使用：

```text
<project>/.claude/skills/novel-style-distiller/
<project>/.cursor/skills/novel-style-distiller/
```

如果宿主没有 Skill 自动发现机制，直接把 [SKILL.md](./SKILL.md) 作为执行说明提供给 Agent，并保持相对目录结构不变。

## 使用前准备

你需要提供：

1. 完整小说文本；TXT/Markdown 可直接处理，EPUB/PDF 必须先完整提取并校验为 TXT/Markdown 规范文本；
2. 书名、作者、版本、原文语言和译者信息；
3. 一个有权在本地分析的来源文件。

本仓库不提供、下载或内置任何小说原文。不要把受版权保护的源文件提交到 Git。

## 输出示例

```text
distillations/my-novel/
├── NOVEL_OVERVIEW.md
├── PLOT_MAP.md
├── CHARACTER_ARCS.md
├── STYLE_PROFILE.md
├── VOICE_PROFILE.md
├── verified.jsonl
├── skills/
│   ├── delayed-causal-reveal/
│   ├── action-borne-emotion/
│   └── close-limited-distance/
├── INDEX.md
├── CRAFT_REPORT.md
├── COPYRIGHT_REPORT.md
└── RELEASE_DECISION.json
```

构建产物默认写入被忽略的 `distillations/`。需要发布某个 Skill pack 时，请先检查证据、授权状态和 `COPYRIGHT_REPORT.md`，且不要一并发布小说原文。

## 设计边界

- 只处理小说，不处理散文、纪实文学、剧本或方法论书。
- 只基于用户实际提供的文本，不凭模型记忆补写。
- 单部小说只证明该作品/版本的特征，不能代表作者全部创作。
- 译本语言特征不能直接归因于原作者。
- 输出用于原创写作，不续写原著，不复用原著人物、世界观或情节骨架。
- “风格”必须拆成可观察、可测试的特征，不能只写“像某作者”。

## 仓库结构

```text
novel-style-distiller/
├── SKILL.md                 # Agent 入口和完整流程
├── agents/openai.yaml       # UI 元数据
├── references/              # 各阶段方法与质量规范
├── extractors/              # 六个独立提取器
├── templates/               # 蒸馏产物模板
├── schemas/                 # JSON 产物 Schema
├── scripts/                 # 校验与防复制工具
└── examples/                # 可公开的合成示例
```

## 参与贡献

参见 [CONTRIBUTING.md](./CONTRIBUTING.md)。请只提交可公开分享的合成文本或公版测试材料，不要提交未经授权的小说原文。

## License

GNU Affero General Public License v3.0。参见 [LICENSE](./LICENSE)。本项目由 `cangjie-skill` 大幅重构而来，来源说明见 [NOTICE](./NOTICE)。
