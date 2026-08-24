# 构造画像与 Skills

## 先画像，后原子化

先用全部验证项生成 `STYLE_PROFILE.md` 和 `VOICE_PROFILE.md`，检查各维度是否互相矛盾，再决定哪些机制值得成为独立 Skill。随后按 [13-style-affinity-calibration.md](13-style-affinity-calibration.md) 生成`STYLE_FINGERPRINT.json`，把句段分布、读者注意力、POV声音、标题承诺和说明上限变成可重算的作品级指纹。画像描述来源作品；Skill 承担明确任务；指纹负责防止体感在runtime编译时被稀释。

## 两种 Skill

### `source-profile`

用于分析、比较和诊断该小说/版本的写法，例如：

- 分析一段文字是否符合已验证的叙述距离；
- 解释该作品在冲突场景中怎样调节句长；
- 比较两个章节的叙述语气变化。

它可以提及作品来源，但不得把证据片段拼成替代性文本，也不负责生成“像作者”的新篇章。

### `transferable-technique`

用于原创写作，例如：

- 在全新故事里延迟揭示因果；
- 用动作和物体交互外化情绪；
- 在限知视角下控制信息泄露。

它的触发条件、执行步骤和示例不能依赖作者名、书名或原作专名。来源只保存在 `metadata.json` 的审计字段。

一个 Skill 只能选一种 kind。

## 原子 Skill 结构

根据 kind 使用对应模板：`templates/SKILL.source-profile.md.template` 或 `templates/SKILL.transferable-technique.md.template`。

1. 目标效果与可观察完成标准；
2. 何时调用、何时不调用和兄弟 Skill 区分；
3. 所需输入与缺失信息处理；
4. 机制说明；
5. 可执行步骤与判停点；
6. 强度旋钮；
7. 诊断、失败模式和修复；
8. 原创性边界。

frontmatter 只保留 `name` 和 `description`。`description` 必须同时写任务信号和排除条件。每个子 Skill 都随附一个最小 `evidence-index.json`，保存 locator、hash、证据关系和非替代性释义；来源画像必须用它核验结论，可迁移技法用它保留审计链。

## 风格配方

当多个机制经常共同出现时，可额外生成一个组合 Skill：

- 只组合 3–7 个已通过测试且相容的技法；
- 为每个技法给出独立强度参数；
- 说明组合顺序和冲突处理；
- 用可观察特征命名，如 `restrained-close-voice-recipe`；
- 不用作者姓名命名或承诺精确复制作者声音。

配方不能替代原子 Skill，也不能绕过各 Skill 的测试。

## Skill 关系

只使用有实际执行意义的关系：

- `depends-on`：A 需要 B 的结果；
- `pairs-with`：A 与 B 经常组合；
- `modulates`：A 调整 B 的强度或表现；
- `conflicts-with`：二者同时使用会破坏效果；
- `applies-after`：A 应在 B 之后执行。

关系确定后，回填相邻 Skill 区分并进行全包路由测试。

## 禁止的设计

- “写得更优美”“像作者一样写”等不可观测步骤；
- 把一整本书装进一个巨型 Skill；
- 在 Skill 中内嵌大段原文或密集引用；
- 把原作事件简单换名当作示例；
- 把分析画像与创作技法混成同一个触发器；
- 用作者姓名、书名或角色名提高生成 Skill 的触发率。

## 编译运行时风格契约

画像、指纹和原子 Skill 属于审计层，不能直接全部塞进长篇写作上下文。验证完成后，按 [08-style-pack-and-project-setup.md](08-style-pack-and-project-setup.md) 将通过项编译为 `runtime-style-pack/`：

1. 把来源描述改写为无来源身份的可执行参数；
2. 区分 always-on 常量、场景模式与偶发装饰；
3. 合并重复或冲突规则，给出优先级和强度旋钮；
4. 删除证据定位、引文、来源专名和情节映射；
5. 生成 `WRITING_STYLE_CONTRACT.md` 与 `PACK_MANIFEST.md`；
6. 从指纹编译来源隔离的`READER_EXPERIENCE_CONTRACT.md`与`STYLE_TARGETS.json`，保留主导注意力、人物声音坐标、标题承诺、说明上限和统计范围；
7. 只有确有独立路由价值的技法才复制进 `techniques/`。

三份运行时接口文件是原创小说每章必须加载的整体：写作合同回答“怎样写才清晰一致”，体感合同回答“读者主要在体验什么”，量化目标回答“页面分布是否已明显漂移”。来源画像和指纹仍留在`audit/`，只用于复核和重编译。
