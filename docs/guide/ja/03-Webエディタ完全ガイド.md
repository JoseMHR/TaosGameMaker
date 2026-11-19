# 03 — Webエディタ完全ガイド

全タブの構成とエンドポイントは `editor/js/collections.js` の `TABS` で定義されています。

---

## 🗺️ ワールド・マップ関連

- **マップ (`map` → `MapEditor.js`)**：3Dオーバーワールドの描画エディタ (`data/world.json`)。地形のペイント、街、ダンジョン、宝箱、採取ポイントの配置。
- **都市ワークスペース (`cityWorkspace` → `CityWorkspace.js`)**：街ごとの施設（酒場、商店、民家）とNPCを一元的にレイアウト・管理。
- **エンティティ (`ids` → `IdsManager.js`)**：マップ上の全配置可能オブジェクト（7言語対応、*POI Wizard* 搭載）。
- **ダンジョン (`dungeons` → `DungeonEditor.js`)**：3Dグリッド型ダンジョン設計。ウォークスルーシミュレータ (*DungeonWalkthroughModal*) と自動生成 (*DungeonWizardModal*) を装備。
- **ダンジョンピース (`dungeonPieces` → `DungeonPiecesManager.js`)**：固定ロジックタイル 🔒、装飾タイル 🎨、データ駆動型スマートオブジェクト 🧩 (*Smart Objects*) の統合管理。

---

## 💬 キャラクター＆モンスター

- **NPC (`npcs` → `NpcEditor.js`)**：会話ツリー管理 (`data/npcs/<id>.json`)。ノードグラフエディタ (`NpcGraphEditor.js`)、リアルタイムノベルシミュレータ (`VnSimulatorModal.js`)、絵文字アバター対応。
- **敵 (`enemies` → `EnemiesManager.js`)**：ステータス、行動AI、弱点耐性、ドロップ品。
  > ⚔️ **Combat Sandbox (戦闘サンドボックス)**：Godotを起動することなく、ブラウザ内で直接モンスターと対戦テストを行える強力なシミュレータ。

---

## 🎒 アイテム・クラス・バランス

- **アイテム (`items` → `ItemsManager.js`)**：武器、防具、消耗品 (*Item Wizard* 内蔵)。
- **クラス (`professions` → `ProfessionsManager.js`)**：職業定義とレベルに応じたスキル習得ツリー。
- **スキル (`skills` → `SkillsManager.js`)**：プレイヤーの戦闘技・魔法カタログ。
- **環境設定 (`config` → `ConfigManager.js`)**：**ゲーム全体の数値バランス調整盤**（経験値曲線、ダメージ計算式、ATBテンポ、経済レート）。
