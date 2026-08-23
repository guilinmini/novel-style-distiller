# Novel Style Distiller

把一部完整小说的剧情架构、人物弧光、叙事技法、语言风格、语气与叙述声音，蒸馏成一组有证据、可迁移、可测试的 AI 写作 Skills。

它不是摘要器，也不是作者模仿 Prompt。它把作品中的写法拆成可观察机制，再将适合迁移的部分用于原创小说。

## 能得到什么

- 整书模型：核心冲突、因果链、支线、伏笔、叙事顺序与人物弧光；
- 文风画像：用词、句法、节奏、段落、意象、感官与描写配置；
- 声音画像：叙述姿态、视角距离、情绪温度、可靠性、反讽与对白纹理；
- 原子 Skills：例如延迟揭示因果、用动作外化情绪、控制限知视角距离；
- 证据与测试：正文定位、反例、holdout 验证、路由测试和原创性检查。

## 工作方式

```text
来源与版本登记
      ↓
长篇切分 + 稳定定位符 + holdout
      ↓
剧情 / 人物 / 叙事信息 / 场景节奏 / 文风 / 语气对白 六路提取
      ↓
证据、反例、迁移性与非复制性验证
      ↓
STYLE_PROFILE + VOICE_PROFILE + 原子 Skills
      ↓
盲测、兄弟 Skill 混淆测试、原创性检查
      ↓
INDEX + CRAFT_REPORT + 可安装 Skill pack
```

完整规范见 [SKILL.md](./SKILL.md)。

## 安装

克隆整个仓库到用户级 Agent Skills 目录：

```bash
git clone https://github.com/guilinmini/novel-style-distiller ~/.agents/skills/novel-style-distiller
```

项目级安装位置：

```text
<project>/.agents/skills/novel-style-distiller/
```

其他 Agent 宿主可将整个仓库放入其 Skills 发现目录。若宿主没有自动发现机制，直接提供根目录的 `SKILL.md`，并保留相对目录结构。

本 Skill 由 Markdown 指令、提取器和模板组成，不要求安装 Python 或第三方运行时。

## 使用

准备一部你有权在本地分析的完整小说，推荐使用 UTF-8 TXT 或 Markdown。PDF/EPUB 应先完整提取并检查章节顺序和文本质量。

```text
使用 $novel-style-distiller，把 /path/to/novel.txt
蒸馏成用于原创小说写作的 Skills。
```

未指定输出位置时，默认写入：

```text
distillations/<novel-slug>/
```

源小说不会进入生成的 Skill，也不应提交到 Git。

## 关键边界

- 只处理小说，不处理散文、非虚构、剧本或方法论书；
- 只基于用户提供的文本，不凭模型记忆补写；
- 一部小说只能支持当前作品和版本的结论，不能代表作者全部创作；
- 译本的具体语言特征不能直接归因于原作者；
- 输出用于原创写作，不续写原著，不复用人物、世界观或情节骨架；
- “风格”必须拆成可观察、可调节、可测试的特征，不能只写“像某作者”。

## 仓库结构

```text
novel-style-distiller/
├── SKILL.md                 # Agent 入口
├── agents/openai.yaml       # UI 元数据
├── references/              # 各阶段方法与质量规范
├── extractors/              # 六个独立提取器
├── templates/               # 蒸馏产物与子 Skill 模板
└── examples/                # 可公开的合成示例
```

## 贡献与许可

参见 [CONTRIBUTING.md](./CONTRIBUTING.md)。只提交合成文本或明确可再分发的测试材料，不要提交未经授权的小说原文。

本项目采用 GNU Affero General Public License v3.0，参见 [LICENSE](./LICENSE)。本项目由 `cangjie-skill` 大幅重构而来，来源说明见 [NOTICE](./NOTICE)。
