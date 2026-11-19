# 03 — Web 编辑器完整指南

所有编辑面板与数据集合的映射均在 `editor/js/collections.js` 的 `TABS` 常量中统一维护。

---

## 🗺️ 大世界与地图模块

- **世界地图 (`map` → `MapEditor.js`)**：3D 大地图网格绘制工具 (`data/world.json`)。支持绘制地块类型、放置城镇建筑、地牢入口、资源点与宝箱。
- **城镇工作台 (`cityWorkspace` → `CityWorkspace.js`)**：一站式城镇管理工作区。无需在多标签页间来回切换，即可集中配置城镇 POI、建筑群、常驻商店与关联 NPC。
- **兴趣点实体 (`ids` → `IdsManager.js`)**：管理大地图上的各类可放置实体与 POI，支持 7 国语言多语言字段，配备 **POI 创建向导** (*NpcPoiWizardModal*)。
- **地牢编辑器 (`dungeons` → `DungeonEditor.js`)**：多层 3D 网格地牢设计器，配备步进式漫游验证器 (*DungeonWalkthroughModal*) 与 **地牢生成向导** (*DungeonWizardModal*)。
- **地牢砖块库 (`dungeonPieces` → `DungeonPiecesManager.js`)**：整合管理核心固定逻辑砖块 🔒、装饰砖块 🎨 与纯数据驱动的智能对象 🧩 (*Smart Objects*)。

---

## 💬 角色与怪物模块

- **NPC 与对话树 (`npcs` → `NpcEditor.js`)**：保存在 `data/npcs/<id>.json` 中。包含可视化节点图编辑器 (`NpcGraphEditor.js`)、视觉小说模拟器 (`VnSimulatorModal.js`) 与 Emoji 头像解析支持。
- **怪物工坊 (`enemies` → `EnemiesManager.js`)**：怪物的属性面板、AI 行为类型、元素抗性与独立掉落表。
  > ⚔️ **Combat Sandbox (战斗沙盒)**：可在浏览器中与选中的怪物即时开战，自由调节玩家等级、装备与技能，无需启动 Godot 即可完成数值平衡。

---

## 🎒 道具、职业与平衡模块

- **道具管理 (`items` → `ItemsManager.js`)**：装备、消耗品与任务道具，内置 **道具向导** (*ItemWizardModal*)。
- **职业体系 (`professions` → `ProfessionsManager.js`)**：管理可玩职业及其随等级解锁的技能树。
- **技能库 (`skills` → `SkillsManager.js`)**：玩家战斗技能的全量参数。
- **全局配置 (`config` → `ConfigManager.js`)**：**全游戏数值平衡中枢**（经验成长曲线、伤害公式、ATB 战斗节奏、经济消耗）。
