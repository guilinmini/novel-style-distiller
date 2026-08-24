---
name: novel-style-distiller
description: Distill a complete novel from a user-provided path into a source-isolated craft contract plus measurable reader-experience targets, calibrate an original Chinese serial project with sample chapters, and write or batch-write with durable canon memory. Use for 蒸馏小说、按主题开网文、校准文风、写下一章、批量写N章、续写或修订当前原创项目. Do not use for simple summaries, nonfiction, author role-play, source-novel continuation, passage imitation, or reproduction of source characters, worldbuilding, phrasing, or plot.
---

# Novel Style Distiller

把完整小说中可观察的写作机制和阅读体感蒸馏成与来源隔离的风格接口，再用该接口建立并持续创作一部全新的中文连载网文爽文。运行时接口由通用写作契约、阅读体感契约和可测风格目标共同组成；单章和批量写作还必须使用同一套爽点/钩子系统与持久记忆。

本 Skill 同时负责三个连续阶段：

```text
完整来源小说
  → A. 蒸馏与验证
  → 可移植 runtime-style-pack（技法+体感+量化目标）
  → B. 根据原创主题建书
  → 项目专属 writer Skill + 长篇状态文件
  → C. 单章或批量写作、验收与状态回写
```

## 克隆仓库后的零配置入口

当本 Skill 位于其原始仓库且根目录存在 `AGENTS.md` 与 `scripts/novelctl.sh` 时，先读取 [references/10-workspace-orchestration.md](references/10-workspace-orchestration.md)：

- 用户给出小说路径时，Agent 自动登记来源并完成模式 A，不要求用户安装 Skill 或创建目录；
- 用户随后给出主题时，Agent 自动完成模式 B、部署长篇记忆与项目 writer，并激活该项目；
- 后续自然语言写章请求直接进入模式 C；
- `.novel/` 只保存活动指针，真实创作记忆始终保存在原创项目文件中。

作为普通外部 Skill 安装时，仍可直接执行 A/B/C；不要假设宿主工作区存在仓库脚本。

## 选择工作模式

先根据用户目标选择且只执行当前所需模式：

| 模式 | 触发信号 | 主要结果 |
|---|---|---|
| A：蒸馏来源小说 | 蒸馏、分析整本小说、提炼文风/语气/写法 | `distillations/<source-slug>/audit/` 与 `runtime-style-pack/` |
| B：创建原创小说 | 给主题开书、按风格包建项目、初始化长篇 | `novel-projects/<project-slug>/` 与项目专属 writer Skill |
| C：写章、批量写或修订 | 写第 N 章、下一章、批量写 N 章、续写、重写本章 | 单章草稿或可恢复串行批次；逐章回写状态 |

如果用户一次要求多个阶段，按 A → B → C 顺序执行。已有有效产物时从相应阶段继续，不重复蒸馏。

## 全程不变的规则

1. **来源与运行时隔离**：证据、引文、书名、作者名和原作专名只留在 `audit/`；章节写作只能加载 `runtime-style-pack/` 和原创项目文件。
2. **风格契约必载**：模式 C 的每次写章、续写或修订，都先读取项目锁定的 `WRITING_STYLE_CONTRACT.md`。缺失、版本不符或无法定位时停止生成并报告问题。
3. **分层文件记忆是事实源**：不要依赖聊天记忆维护长篇连续性。Story Bible、实体状态、知识账本、关系账本、时间线、剧情线程、章节记录和压缩摘要各自承担不同记忆职责。
4. **受控回写**：单章模式先交付草稿，用户验收后才写入 canon。用户明确要求有界批量写作时，该请求可授权批次范围内逐章 `AUTO_COMMIT`，但每章仍必须独立审查、生成变更记录并完成原子回写。
5. **机制而非复刻**：提炼视角、距离、节奏、句法分布、信息控制、情绪呈现和对白机制；不迁移原作人物、世界、专名、独特措辞或情节骨架。
6. **作品级归因**：一部小说只支持对该作品、版本和所提供文本的判断，不能代表作者全部创作。译本的具体措辞、句法和节奏要记录译者归因。
7. **不发布来源正文**：不得把用户提供的小说、OCR 中间文件或可替代原作的密集摘录提交到 Git、安装目录或 runtime pack。
8. **体感不得在编译时消失**：审计层已验证的段落分布、注意力中心、POV声音、身体/物件关注、语域切换、标题承诺和说明上限，必须以来源隔离形式进入runtime；不能只留下可迁移到所有题材的通用技法。
9. **先校准再批量**：新项目默认先交付1章样稿，再用前3章验证稳定性。未通过`state/STYLE_CALIBRATION.md`前，不得把普通“写20章”解释为跳过风格确认；用户明确豁免时记录风险。

## 模式 A：蒸馏完整小说

### A1. 登记输入

1. 在克隆仓库工作台中且尚未登记时，运行 `sh scripts/novelctl.sh register-source <path>`；然后读取用户实际提供的文本，不凭模型记忆补齐。
2. 确认它是小说，并登记书名、作者、版本、原文语言、当前文本语言、译者、完整度和用户的本地分析授权。
3. PDF/EPUB 先完整提取为 UTF-8 TXT/Markdown，检查章节顺序、缺页、乱码和 OCR 问题。
4. 只有节选或短样本时，可以生成带范围声明的探索报告，但不得发布为稳定风格包。
5. 已有 `audit/PIPELINE_STATE.json` 时核对来源 ID、哈希和阶段，从未完成处继续。

模式 A 的清单、画像、账本、候选、证据、测试和报告一律写入 `<output>/audit/`；只有通过隔离门的中性规则才能写入同级 `runtime-style-pack/`。

读取 [references/01-intake-and-segmentation.md](references/01-intake-and-segmentation.md) 完成来源登记、稳定定位、切分和 holdout。

### A2. 建立整书模型

读取 [references/02-whole-novel-model.md](references/02-whole-novel-model.md)，建立情节因果、人物弧光、叙述顺序、知识状态、伏笔兑现和场景账本。向用户简述整书理解；存在关键误读时先修正再继续。

### A3. 六路提取

读取 [references/03-parallel-extraction.md](references/03-parallel-extraction.md)，分别运行六种提取器：

1. [剧情架构](extractors/plot-architecture-extractor.md)
2. [人物弧光](extractors/character-arc-extractor.md)
3. [叙事与信息](extractors/narration-information-extractor.md)
4. [场景与节奏](extractors/scene-pacing-extractor.md)
5. [语言文风](extractors/prose-style-extractor.md)
6. [语气与对白](extractors/voice-tone-dialogue-extractor.md)

环境允许并行时可并行；否则进行六次独立扫描。先记录局部观察，再跨章节合并，避免由少数名场面概括全书。

### A4. 验证候选

读取 [references/04-evidence-validation.md](references/04-evidence-validation.md)。每条候选都必须具有可复核定位、跨区段覆盖、反例、适用条件、强度旋钮、失效边界和原创迁移测试。风格与声音候选冻结后再用 holdout 验证；失败项保留在 `rejected.jsonl`。

### A5. 形成审计画像、体感指纹与运行时风格包

读取 [references/05-build-skills.md](references/05-build-skills.md) 形成来源画像和原子技法，读取 [references/13-style-affinity-calibration.md](references/13-style-affinity-calibration.md) 生成可重算体感指纹，再按 [references/08-style-pack-and-project-setup.md](references/08-style-pack-and-project-setup.md) 编译运行时风格包。

默认产物：

```text
distillations/<source-slug>/
├── audit/
│   ├── SOURCE_MANIFEST.json
│   ├── PIPELINE_STATE.json
│   ├── CHUNK_MANIFEST.json
│   ├── NOVEL_OVERVIEW.md
│   ├── PLOT_MAP.md
│   ├── CHARACTER_ARCS.md
│   ├── STYLE_PROFILE.md
│   ├── VOICE_PROFILE.md
│   ├── STYLE_FINGERPRINT.json
│   ├── ledgers/
│   ├── verified.jsonl
│   ├── rejected.jsonl
│   ├── skills/
│   ├── INDEX.md
│   ├── CRAFT_REPORT.md
│   └── COPYRIGHT_REPORT.md
└── runtime-style-pack/
    ├── PACK_MANIFEST.md
    ├── WRITING_STYLE_CONTRACT.md
    ├── READER_EXPERIENCE_CONTRACT.md
    ├── STYLE_TARGETS.json
    └── techniques/<skill-slug>/SKILL.md
```

`audit/skills/` 可以保留带来源审计链的分析 Skill；`runtime-style-pack/` 只能包含原创写作必需的中性机制。两者不得互相软链接或隐式回读。

### A6. 测试与交付

读取 [references/06-evaluation.md](references/06-evaluation.md) 测试证据忠实度、路由、执行质量、跨题材迁移、单章体感、三章漂移、注意力中心和来源泄漏；再按 [references/07-delivery-and-copyright.md](references/07-delivery-and-copyright.md) 完成版权审计与交付。跨题材成功不能抵消体感回归失败。

只有通过硬门槛的内容可以进入 `runtime-style-pack/`。

在克隆仓库工作台中，正式包通过后运行 `sh scripts/novelctl.sh activate-pack <runtime-style-pack-path>`，使下一次主题请求能直接找到它。

## 模式 B：从主题创建原创网文长篇

读取 [references/08-style-pack-and-project-setup.md](references/08-style-pack-and-project-setup.md) 与 [references/11-long-form-memory-system.md](references/11-long-form-memory-system.md)，然后：

在克隆仓库工作台中，确定项目 slug 后先运行 `sh scripts/novelctl.sh scaffold-project <project-slug> <runtime-pack-path>`；随后必须把所有模板占位符替换为真实内容，脚手架本身不是已配置项目。

1. 优先读取 `.novel/ACTIVE_PACK.md`；不存在时，若只有一个合格 runtime pack 则自动选择，多个合格包才让用户选择。不要自动混合多个来源包。
2. 校验 `PACK_MANIFEST.md`、风格契约、版本和来源隔离声明。
3. 根据用户主题提出最少必要假设，创建完全原创的 premise、人物、世界规则、核心冲突、结局方向与主线大纲；同时明确目标读者、核心爽感、主角引擎、成长维度、黄金三章承诺和第一个完整回报周期。
4. 将 runtime pack 复制到项目 `style/` 并锁定 pack ID、版本和可用时的内容哈希；确认`WRITING_STYLE_CONTRACT.md`、`READER_EXPERIENCE_CONTRACT.md`和`STYLE_TARGETS.json`均存在且一致。之后不要让上游包的变化静默改变本书。
5. 建立 Story Bible、总纲、章节蓝图、记忆索引、人物/实体状态、关系与知识账本、剧情线程、时间线、连续性账本、爽点/成长账本、连载节奏账本、风格校准状态、决策日志、章节记录、结构化变更、批次状态、阶段摘要和临时 context pack 目录。
6. 从模板生成 `.agents/skills/<project-slug>-writer/SKILL.md`。其描述必须明确项目名和写章触发词，使后续自然语言请求能路由到本项目。
7. 将仓库 `knowledge/` 复制为项目 `craft/` 快照；网文定位、爽点、钩子和自然文风为核心模块，其他技法按 `craft/INDEX.md` 的任务路由加载。
8. 仅在标记边界内创建或合并项目 `AGENTS.md` 指令；保留文件中所有无关内容。
9. 在工作台中运行 `activate-project` 与 `doctor`，再向用户展示建书摘要、关键假设、风格包版本和建议的第一章目标。除非用户要求，否则建书阶段不直接写完整第一章。

默认项目结构：

```text
novel-projects/<project-slug>/
├── NOVEL_PROJECT.md
├── AGENTS.md
├── style/
│   ├── PACK_MANIFEST.md
│   ├── WRITING_STYLE_CONTRACT.md
│   ├── READER_EXPERIENCE_CONTRACT.md
│   ├── STYLE_TARGETS.json
│   └── techniques/
├── craft/
│   └── INDEX.md + 按需加载的长篇技法模块
├── bible/STORY_BIBLE.md
├── outline/
│   ├── MASTER_OUTLINE.md
│   └── chapters/
├── state/
│   ├── MEMORY_INDEX.md
│   ├── CURRENT_STATE.md
│   ├── STYLE_CALIBRATION.md
│   ├── RELATIONSHIP_LEDGER.md
│   ├── KNOWLEDGE_LEDGER.md
│   ├── PLOT_THREADS.md
│   ├── TIMELINE.md
│   ├── CONTINUITY_LEDGER.md
│   ├── DECISION_LOG.md
│   ├── REWARD_LEDGER.md
│   ├── SERIAL_RHYTHM.md
│   ├── BATCH_INDEX.md
│   ├── ACTIVE_BATCH.md           # 有批次时
│   ├── characters/
│   ├── entities/
│   ├── chapter-records/          # .md + .changes.json
│   ├── summaries/
│   ├── context/
│   ├── revisions/
│   └── batches/
├── schemas/chapter-changes.schema.json
├── chapters/
└── .agents/skills/<project-slug>-writer/SKILL.md
```

## 模式 C：单章、批量续写或修订

读取 [references/09-chapter-writing-and-state.md](references/09-chapter-writing-and-state.md) 与 [references/11-long-form-memory-system.md](references/11-long-form-memory-system.md)。批量写时再读取 [references/12-batch-writing.md](references/12-batch-writing.md)。优先执行项目专属 writer Skill；它是本书的运行时入口。

### C1. 定位项目

在仓库工作台中先读取 `.novel/ACTIVE_PROJECT.md`；否则从当前目录向上查找 `NOVEL_PROJECT.md`，或使用用户提供的项目路径。确认项目 ID、当前状态、锁定风格包和目标章节。多个项目匹配且无法可靠判断时再询问用户。

### C2. 固定章节循环

每次都执行：

```text
PREPARE → PLAN → DRAFT → REVIEW → DELIVER → ACCEPT / COMMIT
```

- `PREPARE`：先读写作契约、阅读体感契约、量化目标和校准状态，再通过记忆索引选择当前状态、人物/实体、知识、关系、线程、时间线、爽点账本、连载节奏、上一章记录与变更快照；生成非 canon 的章节 context pack，并按 `craft/INDEX.md` 选择必要技法。
- `PLAN`：创建或收窄章节蓝图，明确本章变化、当下回报、压制/兑现债务、读者情绪运动、钩子与兑现窗口、主导/支撑注意力、标题承诺、POV声音坐标、场景转折、连续性风险和所用场景风格模式。
- `DRAFT`：保持 always-on 风格常量，并按 action、dialogue、introspection、transition、climax 等场景模式调节强度。
- `REVIEW`：检查事实连续性、人物知识边界、时间线、POV、风格漂移、体感目标、注意力中心、句段统计、本章回报、钩子债务、情绪对比、近期模式重复、可观察的 AI 腔症状、来源专名和可识别情节泄漏。
- `DELIVER`：单章模式交付草稿等待验收；批次模式把通过审查的章节作为当前事务的待提交结果，不跳过之后的逐章回写。
- `ACCEPT / COMMIT`：用户接受或批次授权生效后，保存正文、章节记录和 `.changes.json` 15 维事实快照/变更集，再按因果顺序原子化回写时间线、人物/实体、知识、关系、剧情线程、爽点/成长、连载节奏、连续性、当前状态和记忆索引。

用户收到草稿后直接要求“下一章”，视为对上一章的隐式验收，先提交上一章再准备下一章。用户要求修订当前或更早章节时，不推进章节号；若修订改变既有事实，先列出受影响文件并进行一致性回写。

新项目的第一章始终是校准样章。用户接受后更新`STYLE_CALIBRATION.md`；前三章完成时对照量化目标和体感合同做稳定性复盘。只有通过或用户明确豁免后，才解锁大于3章的自动批量。

这里的 `COMMIT` 只表示写入小说 canon 和项目状态，不表示执行 Git commit 或 push；版本控制操作必须由用户另行要求。

### C3. 批量写作

用户要求“批量写接下来 N 章”时：

1. 先读取`state/STYLE_CALIBRATION.md`；若未解锁且用户未明确豁免，先交付1章校准样稿，不直接创建大于3章的自动批次；
2. 校准通过后创建可恢复批次，明确数量、起点、自动提交/分组审阅模式和检查点间隔；
3. 先完成整个批次的功能级调度，只将未来 3–8 章展开为详细蓝图；
4. 严格串行执行“读取最新 canon → 写一章 → 审查 → 体感/统计回归 → 回写 → 批次 checkpoint”；
5. 不得并行起草有前后依赖的章节，不得累积多章后一次性回写状态；
6. 每个检查点比较钩子、爽点类型/强度、情绪波形、主导注意力、标题承诺、句段分布、章首章尾和人物声音，必要时只重排未提交章节；
7. 若中断，从 `BATCH_JOB.md` 的 `Next chapter` 恢复，不从聊天猜测进度；
8. 风格包错配、体感硬界越过、无法解决的 canon 矛盾、重试后仍未通过硬门、结构方向变更或回写不完整时立即暂停。

`AUTO_COMMIT` 不需要章间人工确认；`REVIEW_CHECKPOINTS` 在配置的分组边界暂停。两者都必须逐章通过质量门和持久化检查。

## 质量红线

- 不虚构来源引文、页码、章节、统计或情节事实。
- 不把节选结论冒充整书结论或正式 runtime pack。
- 不生成原作续写、番外、角色复用、世界观复用或换名复刻。
- 不把作者姓名、书名或来源专名写进运行时风格指令。
- 不把“冷峻、诗意、克制”等标签当作执行规则；必须展开成可观察行为。
- 不因追求文风而破坏人物目标、事实、POV、时间线或本章任务。
- 不在草稿未验收时提前修改 canon 状态。
- 不用同一套表面特征机械覆盖所有场景；风格稳定不等于节奏单一。
- 不把章尾悬念当作本章回报；每章既要有当下价值，也要产生未来压力。
- 不在批次中机械重复同一爽点、钩子、情绪曲线、章首、章尾或人物反应模式。
- 不把“跨题材可迁移”当成“阅读体感已保留”；runtime必须保留来源隔离的注意力、声音和分布目标。
- 不让大纲中的调查、制度或设定说明长期挤占体感合同规定的主导读者欲望。
