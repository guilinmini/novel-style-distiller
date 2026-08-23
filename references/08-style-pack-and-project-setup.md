# 运行时风格包与原创项目初始化

本参考负责两件事：把已验证的来源分析编译成写作时可安全加载的风格包，以及用该风格包建立一部原创长篇。两步之间必须存在明确的隔离门。

## 一、编译 runtime-style-pack

### 输入条件

只有同时满足以下条件才编译正式风格包：

- 来源是完整小说，或交付状态明确允许当前范围；
- `STYLE_PROFILE.md` 与 `VOICE_PROFILE.md` 已形成；
- 核心结论有跨区段证据、反例和 holdout 结果；
- 可迁移技法已通过原创性与跨题材测试；
- `COPYRIGHT_REPORT.md` 不存在未解决的硬失败。

短样本可以生成 `EXPERIMENTAL` 包用于流程演示，但 manifest 必须标出范围和禁止发布，不得伪装为稳定包。

### 从画像到契约

使用 `templates/WRITING_STYLE_CONTRACT.md.template`，按以下顺序编译：

1. 把标签改写成可观察动作。例如把“克制”改写为情绪命名频率、叙述距离、动作承载比例和修饰强度。
2. 把规律分成 `must`、`usually`、`sometimes` 与 `avoid`，防止所有特征在每段同时出现。
3. 提取 always-on 常量：POV 契约、时态、叙述距离范围、叙述温度、信息权限和明显禁忌。
4. 为 action、dialogue、introspection、transition、climax 等场景建立模式，说明哪些参数升高、降低或暂停。
5. 为可调特征规定强度档位、适用条件、失效症状和修复动作。
6. 加入章节前检查与章节后漂移检查，使契约可执行而不只是说明文。
7. 删除所有来源身份、证据定位、引文、专名、独特比喻、原作事件顺序和人物关系映射。

不能安全中性化的特征只留在 `audit/`，不进入运行时包。

### 包内容与身份

使用 `templates/PACK_MANIFEST.md.template` 记录：

- 稳定的 pack ID；
- 语义版本，例如 `1.0.0`；
- 契约文件及可用时的内容哈希；
- 状态：`EXPERIMENTAL`、`VALIDATED` 或 `BLOCKED`；
- 兼容语言、类型边界和适用范围；
- runtime 文件白名单；
- 来源隔离与版权审查结果。

运行时包只允许包含：

```text
runtime-style-pack/
├── PACK_MANIFEST.md
├── WRITING_STYLE_CONTRACT.md
└── techniques/<skill-slug>/SKILL.md
```

`techniques/` 只放真正需要独立执行的中性技法。契约能完整表达时不要为了数量拆分 Skill。

### 隔离检查

在交付前检查整个 runtime 目录：

1. 不含作者名、书名、译者、角色名、地点、组织或其他来源专名；
2. 不含证据 locator、引文、页码、原始哈希或指向来源正文的链接；
3. 不含逐章梗概、原作因果链或可复原剧情的事件表；
4. 不含要求“像某作者”“精确模仿”或“无法区分”的触发描述；
5. 所有规则都能在完全无关的原创题材上解释和执行。

任一项失败，返回审计区修订，不能靠警告文字放行。

## 二、用主题初始化原创长篇

### 最小输入

需要：

- 用户主题或核心创意；
- 一个通过校验的 runtime pack；
- 项目名称或可生成的工作名。

题材、目标篇幅、受众、POV、语言、结局倾向等缺失时，先作保守假设并记录在 `NOVEL_PROJECT.md`。只有会根本改变用户意图的选择才暂停询问。

### 原创设计顺序

按以下顺序设计，避免从来源小说倒推换名版本：

1. 从用户主题提炼命题、情感承诺和核心矛盾；
2. 创建独立于来源的世界规则与限制；
3. 设计角色的欲望、恐惧、错误信念、资源和代价；
4. 确定不可逆的主线变化与结局方向；
5. 安排分幕或分卷压力曲线、关键选择与支线兑现窗口；
6. 最后把风格契约映射为呈现方式，不让风格包决定故事事实。

用 `templates/STORY_BIBLE.md.template` 和 `templates/MASTER_OUTLINE.md.template` 保存结果。大纲是可控计划，不是已经发生的 canon；只有已验收正文及其状态回写构成已发生事实。

### 锁定风格包

把 runtime pack 复制到项目 `style/`，并在 `NOVEL_PROJECT.md` 记录 pack ID、版本和可用时的内容哈希。项目创建后默认使用这份快照：

- 上游包更新不得静默覆盖项目副本；
- 升级必须显示旧版本、新版本、变化、预期影响和回归检查；
- 已有章节时，升级前至少抽检开端、近期章节和高强度场景；
- 一个项目一次只锁定一个主契约。确需混合时要生成并测试新的合成契约，而不是运行时轮流读取多个来源包。

### 建立持久状态

按模板创建：

- `NOVEL_PROJECT.md`：项目身份、创作目标、锁定风格与当前阶段；
- `bible/STORY_BIBLE.md`：稳定设定、人物、关系、知识权限和硬规则；
- `outline/MASTER_OUTLINE.md`：计划中的主线、分幕、角色弧和线程窗口；
- `outline/chapters/`：逐章蓝图；
- `state/CURRENT_STATE.md`：写下一章必需的紧凑事实；
- `state/PLOT_THREADS.md`：承诺、伏笔、悬念和待兑现线索；
- `state/TIMELINE.md`：已发生事件及其因果；
- `state/chapter-records/`：每章验收后的增量变更。

使用稳定 ID，例如 `char-lin`、`thread-missing-map`、`evt-0031`。同一实体不要在不同文件创建不同 ID。

### 生成项目专属 writer Skill

使用 `templates/PROJECT_WRITER.SKILL.md.template` 创建：

```text
.agents/skills/<project-slug>-writer/SKILL.md
```

替换所有占位符，并保证：

- frontmatter `name` 是合法、稳定、项目唯一的 slug；
- `description` 同时包含项目标题以及写章、续写、修订等触发信号；
- Skill 只读取项目 `style/`，不能回读 `distillations/.../audit/`；
- Skill 规定先加载风格契约、后加载故事状态；
- Skill 包含验收后回写规则；
- 所有相对项目路径能够从项目根定位。

### 安全合并 AGENTS.md

使用 `templates/AGENTS.project.md.template` 中的标记块：

```text
<!-- novel-style-distiller:start -->
...
<!-- novel-style-distiller:end -->
```

- 文件不存在时创建；
- 已有标记块时只替换块内内容；
- 没有标记块但存在其他内容时，在末尾追加；
- 永远不删除或改写标记块之外的指令；
- 如果现有指令与项目 writer Skill 冲突，报告冲突并等待用户决定，不擅自覆盖。

### 初始化完成检查

建书结束前确认：

1. 所有模板占位符均已替换；
2. 项目只引用其 `style/` 快照；
3. Bible、大纲和状态不存在明显矛盾；
4. 第一章蓝图能够从主题与主线推出；
5. 项目 writer Skill 的正例能触发，摘要/来源分析等诱饵不触发；
6. 项目目录不含来源小说或审计证据；
7. 向用户列出关键假设、当前阶段、下一步命令和需要确认的重大选择。
