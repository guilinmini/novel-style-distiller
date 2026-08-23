# Zero-configuration dialogue example

After cloning and opening the repository, the user can stay in one conversation.

## 1. Supply the source

```text
蒸馏这本小说：/absolute/path/to/source-novel.txt
```

Expected behavior: register the source, complete the private audit, validate the source-isolated runtime pack, activate it, and report its neutral pack ID/version. Do not stop after creating directories.

## 2. Supply the original theme

```text
我要写一部长篇：在一座只在退潮时显露的钟楼中，年轻修表师必须在七次潮汐之内找出一封寄给未来自己的信为什么少了一页。
```

Expected behavior: create and activate a complete original project with locked style, built-in craft snapshot, Story Bible, outline, layered memory, and a project-specific writer Skill.

## 3. Write normally

```text
写第一章。
```

The chapter remains a draft. After review:

```text
接受，继续下一章。
```

Expected behavior: commit the first chapter to story canon, update every affected memory layer, rebuild the next context pack, and draft chapter two with the same locked style contract.
