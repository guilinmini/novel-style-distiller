# Contributing

感谢你改进 Novel Style Distiller。

## 提交范围

欢迎贡献：

- 更准确的小说叙事、文风和语气提取规则；
- 能揭示误触发、剧情矛盾、POV 越界或文本复制的测试；
- 确定性校验脚本及其最小依赖；
- 合成小说或明确可再分发的公版测试夹具；
- 中英文文档修正。

不要提交：

- 未经授权的小说全文、节选、电子书或 OCR 文件；
- 以作者姓名为唯一规则的模仿 Prompt；
- 不能回指证据位置的风格断言；
- 为了让测试通过而降低硬门槛的改动。

## 修改要求

1. 保持 `SKILL.md` 的 YAML frontmatter 只有 `name` 和 `description`。
2. 新增详细规则时优先放入 `references/`，保持入口简洁。
3. 新增 extractor 时定义职责边界、输出字段和自检项。
4. 新增 JSON 产物时同步更新 `schemas/`、模板和 `scripts/validate_pack.py`。
5. 运行：

   ```bash
   python3 -m pip install -r requirements.txt
   python3 scripts/validate_repo.py
   python3 -m unittest tests.test_scripts -v
   ```

6. 若修改生成或测试规则，使用至少三类叙事结构进行回归测试：第一人称/不可靠叙述、多人物限知、全知或非线性叙事。

## 测试材料

优先编写短小的合成小说夹具。若使用公版作品，记录版本和来源，并确保文件的再分发条件允许提交到仓库。测试失败样本也应去除原作专名和大段原文。
