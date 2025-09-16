# LLM バッチ処理用スクリプト

LLM を使用するジョブを YAML と ERB で定義し、標準入力から与えられる処理対象データを処理し、標準出力に書き出すスクリプト群です。
LLM は OpenAI API 互換の API を使用します。

## 主な機能

- **ERB テンプレート**: ユーザープロンプトとシステムプロンプトを ERB で柔軟に定義
- **システムプロンプト対応**: 別ファイルでシステムプロンプトを設定可能
- **JSONL 処理**: 標準入力からの JSONL データを一行ずつ処理
- **OpenAI API 互換**: 各種 LLM バックエンドに対応
- **推論タグ除去**: LLM応答から `<think>...</think>` タグを自動除去
- **画像処理対応**: マルチモーダルモデルでの画像+テキスト処理
- **エラーハンドリング**: 堅牢なエラー処理とログ出力

## 各ファイルの働き

ジョブ実行スクリプト: `bin/job.rb path/to/job_definition.yml`
入出力内容のサンプル: `docs/example/input-output.jsonl`
ジョブ定義のサンプル: `docs/example/job.yml`
システムプロンプト付きサンプル: `docs/example/job_with_system.yml`

## セットアップ

```bash
# 依存関係のインストール
bundle install

# テスト実行
bundle exec rspec

# 使用例
bundle exec ruby bin/job.rb docs/example/job_with_system.yml < docs/example/input_sample.jsonl
```

## ジョブ定義ファイル

### 基本設定
```yaml
---
:id: ジョブの識別子
:erb_filepath: ユーザープロンプト定義ファイル(ERB)のパス
:backend_endpoint: バックエンドのエンドポイントURL(OAI互換API)
:model: 使用するモデル名
:output_label: 出力先ラベル
```

### システムプロンプト対応
```yaml
---
:id: summarization-job
:erb_filepath: user_prompt.erb
:system_erb_filepath: system_prompt.erb  # オプション
:backend_endpoint: http://localhost:8080
:model: qwen3-0.6b
:params:
  :temperature: 0.3
:use_images: false
:output_label: summary
```
