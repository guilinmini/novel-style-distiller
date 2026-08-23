---
name: novel-style-distiller
description: Distill a complete novel into evidence-backed plot, craft, prose-style, tone, dialogue, and narrative-voice skills for original fiction. Use when the user asks to 蒸馏小说、提炼小说写法、分析完整小说并制作 Skill/技能包. Do not use for simple summaries, excerpt-only analysis, nonfiction, author role-play, source-novel continuation, or passage reproduction.
---

# Novel Style Distiller

把一部完整小说中可观察的剧情组织、写作技法、语言风格、语气和叙述声音，蒸馏成可分析、可迁移、可测试的写作 Skills。目标是提炼机制，不是扮演作者或复刻原作。

## 开始前

1. 读取用户实际提供的完整小说；不得凭模型记忆补齐正文。
2. 确认书名、作者、版本、原文语言、当前文本语言和译者。
3. 确认输入是小说。散文、非虚构、剧本和方法论书不进入本流程。
4. 只有节选时，只生成带范围声明的探索报告，不生成最终 Skill pack。
5. 不把源小说复制进输出目录、安装目录或 Git 仓库。
6. 目标目录已有 `PIPELINE_STATE.json` 时，先核对来源与进度，再从未完成阶段继续。

读取 [references/01-intake-and-segmentation.md](references/01-intake-and-segmentation.md) 处理来源、版本、切分和 holdout。

## 不可变原则

- **作品级归因**：一部小说只能证明这部作品及当前版本呈现的特征，不能代表作者全部创作。
- **译本分离**：剧情设计可归于作品；具体措辞、句法和节奏应归于当前译本呈现，并记录译者。
- **证据优先**：结论必须回指正文定位；摘要和已有分析不能代替原文证据。
- **机制而非标签**：把“冷峻、诗意、克制”等标签拆成可观察标记、条件、效果和动作。
- **迁移而非复制**：迁移写作机制，不迁移人物、世界观、专名、独特表达或一一对应的情节节拍。
- **分析与生成分离**：来源画像负责分析；可迁移技法负责原创写作。一个子 Skill 只能承担一种职责。
- **保留失败信息**：保存反例、淘汰理由、边界和测试失败，不把不确定项伪装成结论。

## 建议输出

在用户指定目录创建；未指定时使用 `distillations/<novel-slug>/`：

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
├── candidates/
├── ledgers/
│   ├── canon.jsonl
│   ├── scenes.jsonl
│   └── evidence.jsonl
├── verified.jsonl
├── rejected.jsonl
├── skills/<skill-slug>/
│   ├── SKILL.md
│   ├── metadata.json
│   ├── evidence-index.json
│   ├── test-prompts.json
│   ├── test-results.json
│   └── test-results.md
├── INDEX.md
├── CRAFT_REPORT.md
└── COPYRIGHT_REPORT.md
```

模板是推荐格式，不是要求宿主安装特定运行时。根据任务规模保留必要产物；最终子 Skill 必须自包含。

## 流程

### 0. 登记与切分

1. 使用 `templates/SOURCE_MANIFEST.json.template` 记录来源、版本、完整度、文本质量和本地分析确认。
2. PDF/EPUB 先完整提取为 UTF-8 TXT/Markdown；检查章节顺序、缺页、乱码和 OCR 问题。
3. 按卷、章、场景和段落建立稳定定位符，例如 `ch03.s07.p014`。
4. 按语义边界切成可处理的 chunk，并在 `CHUNK_MANIFEST.json` 记录顺序、范围和结构区段。
5. 从开端、中段和结尾分层预留约 20% 作为 holdout。文风与声音提取器在形成候选前不得读取这些正文。

### 1. 建立整书模型

读取 [references/02-whole-novel-model.md](references/02-whole-novel-model.md)，生成：

- `NOVEL_OVERVIEW.md`：类型承诺、核心冲突、叙述契约、结构分区和情绪曲线；
- `PLOT_MAP.md`：故事时间、叙述顺序、因果链、支线、伏笔与兑现；
- `CHARACTER_ARCS.md`：欲望、信念、关键选择、代价、知识状态和关系变化；
- `canon.jsonl` 与 `scenes.jsonl`：供后续核验的事实和场景账本。

向用户简要展示整书理解。若用户指出关键误读，先修正模型再继续。

### 2. 六路独立提取

读取 [references/03-parallel-extraction.md](references/03-parallel-extraction.md)。环境允许时并行运行；否则分别进行六次干净扫描，不共享彼此的候选判断：

1. [剧情架构](extractors/plot-architecture-extractor.md)
2. [人物弧光](extractors/character-arc-extractor.md)
3. [叙事与信息](extractors/narration-information-extractor.md)
4. [场景与节奏](extractors/scene-pacing-extractor.md)
5. [语言文风](extractors/prose-style-extractor.md)
6. [语气与对白](extractors/voice-tone-dialogue-extractor.md)

先逐 chunk 记录局部观察，再按类别合并。候选使用 `templates/candidate-record.json.template`，证据使用 `templates/evidence-record.json.template`。每个证据 ID 必须回指正文定位，而不是只指向整书摘要。

### 3. 验证与筛选

读取 [references/04-evidence-validation.md](references/04-evidence-validation.md)。每条候选必须通过：

1. 定位可复核；
2. 证据覆盖满足该类别要求；
3. 已主动搜索反例；
4. 能转成明确动作、强度旋钮和判停条件；
5. 换掉原作专名后仍可迁移；
6. 不依赖独特句子、人物关系或情节映射；
7. 作品、版本、译者和分析推断归因正确。

通过项写入 `verified.jsonl`，失败项写入 `rejected.jsonl` 并说明失败门。风格与声音候选冻结后再用 holdout 验证；不得从 holdout 发明新规律再冒充独立验证。

### 4. 构造画像与原子 Skills

读取 [references/05-build-skills.md](references/05-build-skills.md)，先生成：

- `STYLE_PROFILE.md`：词汇、句法、节奏、段落、意象、感官和描写配置；
- `VOICE_PROFILE.md`：叙述姿态、距离、温度、可靠性、幽默、反讽和对白机制。

再将验证通过的候选制作成原子 Skill。每个子 Skill 选择一种 `kind`：

- `source-profile`：分析、比较或诊断来源小说的写法；
- `transferable-technique`：把中性机制用于完全原创的小说任务。

分别使用对应的 `SKILL.*.md.template` 和测试模板。子 Skill 的 frontmatter 只保留 `name` 与 `description`；来源与证据放在 `metadata.json` 和 `evidence-index.json`。生成型 Skill 的名称、触发条件和示例不得依赖作者名、书名或原作专名。

### 5. 测试

读取 [references/06-evaluation.md](references/06-evaluation.md)：

1. 测试明确触发、隐式触发、不应触发和兄弟 Skill 混淆；
2. 检查剧情连续性、人物一致性、POV 和目标效果；
3. 对可迁移技法做跨题材测试和有/无 Skill 对照；
4. 检查是否泄露原作专名、独特表达或连续情节节拍；
5. 最好由看不到 oracle 的独立评测者执行；做不到时标记为 fallback；
6. 任何硬失败都不能被平均分抵消。

只有通过测试的子 Skill 才能进入交付目录。

### 6. 交付

读取 [references/07-delivery-and-copyright.md](references/07-delivery-and-copyright.md)：

1. 生成 `INDEX.md`、`CRAFT_REPORT.md` 和 `COPYRIGHT_REPORT.md`；
2. 人工核对来源哈希、证据定位、holdout、测试结果和归因限制；
3. 检查报告和子 Skill 未包含长引文、原作续写、原作专名或可识别的情节复刻；
4. 只安装通过审计的 `skills/<skill-slug>/`，不安装源小说、候选池或工作账本；
5. 更新 `PIPELINE_STATE.json`，向用户汇报产物、失败项、限制和安装位置。

## 质量红线

- 不虚构引文、页码、章节、统计或情节事实。
- 不把节选结论冒充整书或作者整体风格。
- 不生成原作续写、番外或换名复刻。
- 不复用原作人物、世界观、专名、独特比喻、标志性句式或台词。
- 不用作者姓名替代可观察的风格参数。
- 不交付缺少反例、适用边界、证据定位或测试记录的 Skill。
- 不把用户提供的小说原文提交或发布到 Git。
