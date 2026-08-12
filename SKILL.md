---
name: novel-style-distiller
description: Distill a complete novel into an evidence-backed, reusable skill pack for original fiction writing. Use when the user explicitly wants to 蒸馏小说、把小说做成 Skill/技能包, or to turn a novel's plot architecture, character arcs, viewpoint, information control, scene pacing, prose patterns, dialogue, tone, or narrative voice into reusable writing skills or a complete craft pack. Accept novels only; do not use for ordinary one-off literary analysis, excerpt analysis, nonfiction, essays, screenplays, simple summaries, book reviews, author role-play, source-novel continuation, or passage reproduction.
---

# Novel Style Distiller

把一部小说的剧情组织、叙事技法、语言风格与叙述声音，蒸馏成有证据、可迁移、可测试的写作 Skills。分析作品中可观察的规律，不扮演作者，不复刻原句、人物、世界观或标志性情节。

## 开始前

1. 读取用户提供的完整小说文本或可访问文件。不得凭记忆蒸馏。
2. 确认书名、作者、出版版本、原文语言、译者（如有）和文本完整度。
3. 只处理小说。若输入不是小说，说明边界并停止本流程。
4. 若只有节选，允许生成 `partial` 探索报告，但不得声称代表整部小说或作者整体风格，不得生成最终 Skill pack。
5. 先检查目标目录中的 `PIPELINE_STATE.json`；存在时校验源文件哈希并从断点续跑。
6. 第一次使用时，优先处理一部小说，不要未经确认批量运行。

输入、版本归因和长篇切分规则见 [references/01-intake-and-segmentation.md](references/01-intake-and-segmentation.md)。

## 核心原则

- **作品级归因**：单部小说只能支持“这部作品/这个版本呈现的风格”，不能推断作者全部作品。
- **译本分离**：译本的句法、措辞和节奏归因于“作者叙事设计经该译者呈现的版本”；不得直接归因于原作者语言。
- **证据优先**：事实、风格结论和技法结论都必须有可复核定位符。摘要不能充当证据。
- **事实分层**：把记录标为 `fact`、`interpretation` 或 `hypothesis`；不要把解释写成事实。
- **机制而非标签**：把“冷峻、诗意、克制”等形容词拆成可观察模式、产生效果、适用条件和执行动作。
- **技法而非复制**：迁移作品的机制，不迁移专名、独特表达、人物关系或一一对应的情节节拍。
- **分析与生成分离**：来源画像用于分析和诊断；可迁移技法用于创作新故事。一个子 Skill 不得同时承担两者。
- **可回溯、可续跑**：保留候选、淘汰原因、证据账本、测试结果和流水线状态。

## 输出目录

在用户指定位置创建；未指定时使用 `distillations/<novel-slug>/`：

```text
distillations/<novel-slug>/
├── SOURCE_MANIFEST.json
├── PIPELINE_STATE.json
├── CHUNK_MANIFEST.json
├── NOVEL_OVERVIEW.md
├── PLOT_MAP.md
├── CHARACTER_ARCS.md
├── STYLE_PROFILE.md
├── VOICE_PROFILE.md
├── verified.jsonl
├── rejected.jsonl
├── candidates/
│   ├── plot-architecture.jsonl
│   ├── character-arcs.jsonl
│   ├── narration-information.jsonl
│   ├── scene-pacing.jsonl
│   ├── prose-style.jsonl
│   └── voice-tone-dialogue.jsonl
├── ledgers/
│   ├── canon.jsonl
│   ├── scenes.jsonl
│   └── evidence.jsonl
├── skills/<skill-slug>/
│   ├── SKILL.md
│   ├── metadata.json
│   ├── evidence-index.json
│   ├── test-prompts.json
│   ├── test-results.json
│   └── test-results.md
├── INDEX.md
├── CRAFT_REPORT.md
├── COPYRIGHT_REPORT.md
└── RELEASE_DECISION.json
```

不要把源小说复制进输出目录。默认不要把 `distillations/` 提交到本元 Skill 仓库。

## 流程

### 阶段 0：登记来源并建立文本索引

1. 按 `templates/SOURCE_MANIFEST.json.template` 记录来源、版本、完整度、授权状态、原文件 SHA-256，以及用于定位和重合检查的规范化 TXT/Markdown 文件及其 SHA-256。PDF/EPUB 必须先完整提取为规范文本；不得把二进制文件直接交给文本校验器。
2. 按卷、章、场景切分；给每个段落建立稳定定位符，例如 `ch03.s07.p014`。
3. 记录每个 chunk 的哈希、顺序、结构区段和相邻关系，生成 `CHUNK_MANIFEST.json`。
4. 从开端、中段、结尾分层抽取约 20% 文本作为 holdout；在阶段 2 的文风与声音提取中隐藏这些块。
5. 检查 OCR 质量。无法可靠定位的段落不得作为证据。

### 阶段 1：建立整书叙事模型

读取 [references/02-whole-novel-model.md](references/02-whole-novel-model.md)，生成：

- `NOVEL_OVERVIEW.md`：类型承诺、核心冲突、叙述契约、结构分区和情绪曲线；
- `PLOT_MAP.md`：故事时间、叙述顺序、因果链、支线、伏笔与兑现；
- `CHARACTER_ARCS.md`：欲望、恐惧、错误信念、选择、代价、知识状态与关系变化；
- `ledgers/canon.jsonl` 与 `ledgers/scenes.jsonl`：供后续一致性检查的事实账本，分别使用 `templates/canon-record.json.template` 与 `templates/scene-record.json.template`。

向用户展示整书模型的简要结果，确认作品理解与重点方向后再继续。

### 阶段 2：六路独立提取

读取 [references/03-parallel-extraction.md](references/03-parallel-extraction.md)。若环境支持子 Agent，独立并行运行以下六个提取器；否则以互不共享候选结论的六次干净扫描串行执行：

1. `extractors/plot-architecture-extractor.md`
2. `extractors/character-arc-extractor.md`
3. `extractors/narration-information-extractor.md`
4. `extractors/scene-pacing-extractor.md`
5. `extractors/prose-style-extractor.md`
6. `extractors/voice-tone-dialogue-extractor.md`

先逐 chunk 提取，再在每个类别内归并。使用 `templates/candidate-record.json.template` 与 `templates/evidence-record.json.template`。所有 `evidence_ids` 必须指向 `ledgers/evidence.jsonl` 中的记录，并由该记录回指源文本定位符；不能只指向阶段 1 的总结。

### 阶段 3：证据验证与筛选

读取 [references/04-evidence-validation.md](references/04-evidence-validation.md)。合并重复候选，对每条候选执行以下硬门：

1. **可追溯**：证据位置可重新打开，引用与结论一致。
2. **覆盖充分**：满足该类别的最低证据链，并用 holdout 再确认风格结论。
3. **反证扫描**：主动查找例外；有例外时缩小适用范围。
4. **可操作**：能写成明确动作、强度旋钮和判停条件。
5. **可迁移**：可用于不同人物、世界和情节。
6. **非复制**：不依赖原作专名、独特句子或一一对应的情节骨架。
7. **归因正确**：区分原作者叙事设计、译本语言和分析者推断。

通过项写入 `verified.jsonl`，淘汰项写入 `rejected.jsonl` 并保留原因。向用户展示“入选标题、类别、淘汰数量”，允许用户砍掉或要求复核，但不得在没有新证据时捞回失败项。

### 阶段 4：构造画像与原子 Skills

读取 [references/05-build-skills.md](references/05-build-skills.md)，先生成：

- `STYLE_PROFILE.md`：词汇、句法、节奏、段落、意象、感官和描写配置；
- `VOICE_PROFILE.md`：叙述者姿态、距离、温度、可靠性、幽默/反讽和对白机制。

再把验证通过的候选构造成原子 Skill。每个 Skill 只能有一种 `kind`：

- `source-profile`：分析、比较或诊断这部小说所呈现的风格；
- `transferable-technique`：把一个机制迁移到完全原创的小说任务。

`source-profile` 使用 `templates/SKILL.source-profile.md.template` 与 `templates/test-prompts.source-profile.json.template`；`transferable-technique` 使用 `templates/SKILL.transferable-technique.md.template` 与 `templates/test-prompts.transferable-technique.json.template`。两者共同使用 `templates/skill-metadata.json.template`。每个子 Skill 还要按 `templates/evidence-index.json.template` 保存最小证据索引，使其脱离构建目录安装后仍可核验定位与结论；不得内嵌大段原文。盲测结果按 `templates/test-results.json.template` 保存机器记录，并用 `templates/test-results.md.template` 生成人类报告。子 Skill frontmatter 只写 `name` 与 `description`；来源、证据和关系放进 `metadata.json`。

允许额外创建一个“风格配方”Skill，把 3–7 个相容技法组合成可调参数，但不得把作者姓名作为生成触发器，也不得承诺“精确模仿”。

### 阶段 5：建立关系并压力测试

1. 为 Skill 标注 `depends-on`、`pairs-with`、`modulates`、`conflicts-with` 或 `applies-after` 关系。
2. 读取 [references/06-evaluation.md](references/06-evaluation.md)，用看不到 oracle 的独立 Agent 盲测；没有独立 Agent 时标记为低置信度 fallback。
3. 检查触发、兄弟 Skill 混淆、剧情连续性、人物一致性、POV、目标效果、跨题材迁移和非复制性。
4. 生成类用例运行 3 次。任一次发生严重设定冲突、越权内心描写或文本复制，整条失败。
5. 失败时回到候选机制或 Skill 构造阶段，不得只改测试答案迎合结果。

只有全部硬门通过的 Skill 才能交付。

### 阶段 6：交付

读取 [references/07-delivery-and-copyright.md](references/07-delivery-and-copyright.md)：

1. 生成 `INDEX.md`、面向创作者的 `CRAFT_REPORT.md`、`COPYRIGHT_REPORT.md` 和机器可读的 `RELEASE_DECISION.json`。只有审计无阻断项时才把 `approved` 设为 `true`。
2. 运行 `python3 scripts/validate_pack.py <distillation-dir>`。
3. 对任何生成样稿运行 `python3 scripts/check_overlap.py --source <normalized-novel.txt> --generated <draft>`；`--source` 只接受 TXT/Markdown 规范文本。
4. 询问安装位置，只安装测试通过的 `skills/<skill-slug>/`。
5. 更新 `PIPELINE_STATE.json` 为 `complete`，汇报产物、测试状态、归因限制和安装位置。

## 质量红线

- 不得虚构引文、页码、章节、统计数据或情节事实。
- 不得把节选分析冒充整书结论。
- 不得生成逐章替代性复述、原作续写，或复用原作人物与世界观的新篇章。
- 不得在生成文本中复制原文长片段、独特比喻、标志性句式或连续三个辨识度高的情节节拍。
- 不得用作者名替代可观察的文风描述。
- 不得交付缺少反例、适用边界、证据定位或压力测试的 Skill。
- 不得把用户提供的小说原文提交、发布或安装到 Skill 目录。
