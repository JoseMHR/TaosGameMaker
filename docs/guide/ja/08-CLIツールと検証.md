# CLIツールとデータ検証

本プロジェクトには、ゲーム内データの整合性を維持し、参照切れやバグを事前に防止するための強力なコマンドラインツールが用意されています。

---

## 1. データ整合性バリデータ (`validate_data.py`)

[tools/validate_data.py](file:///d:/workspace/ods-proy-godot/tools/validate_data.py) は、`data/` ディレクトリ配下の全JSONファイルを網羅的に検査するスクリプトです。

### 1.1 実行方法
ターミナルまたはPowerShellで以下を実行します：

```bash
python tools/validate_data.py
```

### 1.2 検査項目
1. **JSON構文チェック**：文法エラー、不正なカンマ、閉じ括弧の欠損。
2. **多言語キーの網羅性**：7言語（`es`, `en`, `fr`, `it`, `de`, `zh`, `ja`）すべてが揃っているか、空文字列でないか。
3. **ID参照整合性（参照整合性）**：
   - POI内の `connected_to` が実在するPOI IDを指しているか。
   - POIダイアログの `conditions` や `on_select` で参照されるクエスト・アイテム・フラグが存在するか。
   - 戦闘エンカウントで指定された `enemy_id` が `data/enemies.json` に実在するか。
   - ドロップアイテム・ショップ販売アイテムのIDが `data/items.json` に存在するか。
4. **数値範囲チェック**：HP、攻撃力、確率、レベル要求値が正の値かつ妥当な範囲内か。

---

## 2. Webエディタ自動テスト (`check_editor.mjs`)

Node.js環境でWebエディタの全モジュールと構文を検証します：

```bash
node tools/check_editor.mjs
```

- 各タブ（ゾーン、POI、アイテム、敵、スキル、クエスト等）のJSスクリプトの依存関係が正しく解決されているか確認します。
- ブラウザを起動せずとも構文エラーや未定義参照をCI/CD上で検出できます。

---

## 3. コードマップ生成スクリプト (`gen_codemap.py`)

[tools/gen_codemap.py](file:///d:/workspace/ods-proy-godot/tools/gen_codemap.py) は、プロジェクト全体のスクリプト構成、クラス、シグナル、エクスポート変数を一覧化したドキュメントを自動生成します：

```bash
python tools/gen_codemap.py
```

- 出力先：`docs/CODEMAP.md`
- 新しいスクリプトを追加した際や、プロジェクト構造の全体像を把握したい時に便利です。

---

## 4. 自動化とCI連携のヒント

Gitリポジトリを利用している場合、コミット前フック（pre-commit）やGitHub Actionsなどのワークフローにバリデータを組み込むことで、不正なデータがマスターブランチに混入するのを防ぐことができます。

```yaml
# 例: .github/workflows/validate.yml
name: Validate Data
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - name: Run Validator
        run: python tools/validate_data.py
```

---

次章：[第9章：よくある質問とトラブルシューティング](09-よくある質問とトラブルシューティング.md)
