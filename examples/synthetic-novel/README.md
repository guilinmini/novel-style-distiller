# Synthetic end-to-end example

本目录只包含可公开的合成文本与三阶段提示词：

1. `example-prompt.txt`：用短样本演示蒸馏，并强制标记为 `EXPERIMENTAL`；
2. `example-theme.txt`：用实验风格包创建完全原创的项目；
3. `example-chapter-request.txt`：验证草稿、接受、状态回写和下一章文风继承。

网文核心技法、批次中断恢复和 120 章状态回归由仓库级 `knowledge/`、`references/12-batch-writing.md` 与 `tests/longform-regression.sh` 覆盖，不使用来源作品换名作为测试材料。

`novel.txt` 太短，不能证明稳定的作品级风格。示例的目的只是验证路由、目录、模板、来源隔离和章节状态机，不用于发布生产风格包。

完整仓库模式的自然语言流程见 [`../zero-config-dialogue.md`](../zero-config-dialogue.md)。
