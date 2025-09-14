# LLM バッチ処理用スクリプト

LLM を使用するジョブを YAML と ERB で定義し、標準入力から与えられる処理対象データを処理し、標準出力に書き出すスクリプト群です。
LLM は OpenAI API 互換の API を使用します。

## 各ファイルの働き

ジョブ実行スクリプト: bin/job.rb path/to/job_definition.yml
入出力内容のサンプル: docs/example/input-output.jsonl
ジョブ定義のサンプル: docs/example/job.yml
