# 08 — CLI 工具与数据校验 (`tools/`)

所有实用工具均可直接在项目根目录运行：

---

## `validate_data.py` — 数据完整性交叉审计工具

```bash
python tools/validate_data.py
```

全量遍历 `data/` 下的所有 JSON 文件，防止运行时静默崩溃：
- 校验掉落表、宝箱与对话中提到的道具 ID 是否全部真实存在于 `data/items/`。
- 校验职业技能引用、怪物技能引用的有效性。
- 校验地牢机关按钮的联动目标 (`targets[].eid`) 是否落在同层地牢中。
- 校验 NPC 对话图中每个分支选项指向的下一个节点是否存在。

检测全部通过时返回状态码 `0`，发现异常时返回 `1`。编辑器内的【QA 面板】亦集成了相同逻辑。

---

## `gen_codemap.py` 与 `gen_editor_codemap.py`

```bash
python tools/gen_codemap.py          # 刷新 docs/CODEMAP.md 与 docs/SYMBOLS.tsv
python tools/gen_editor_codemap.py   # 刷新 editor/CODEMAP.md
```

在修改了引擎底层代码或编辑器组件结构后执行，以保持文档与源码定义同步。

---

## `check_editor.mjs` — 编辑器静态语法检查

```bash
node tools/check_editor.mjs
```

检查编辑器内所有 JS 文件的语法合规性，并验证全部相对路径模块引用的正确性。
