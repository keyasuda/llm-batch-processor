# RSpec テスト仕様

## テスト構成

### 1. ユニットテスト (`spec/job_processor_spec.rb`)
- JobProcessor クラスの基本機能をテスト
- モックを使用してLLM API呼び出しをシミュレート
- 設定検証、ERBテンプレート処理、エラーハンドリングをカバー

### 2. 統合テスト (`spec/integration_spec.rb`)
- qwen3-0.6b モデルを使用した実際のLLM統合テスト
- ローカルエンドポイント (http://localhost:8080) でのテスト
- 日本語・英語テキストの処理確認
- 画像処理は対象外（qwen3-0.6bが画像未対応のため）

### 3. スクリプトテスト (`spec/bin_job_spec.rb`)
- qwen3-0.6b を使用したコマンドライン実行の統合テスト
- JSONL入力/出力の確認（日本語テキスト）
- 複数行JSONL処理のテスト
- エラーハンドリングの検証

## テスト実行

```bash
# 全テスト実行
bundle exec rspec

# ユニットテストのみ
bundle exec rspec spec/job_processor_spec.rb

# 統合テストのみ（qwen3-0.6bが必要）
bundle exec rspec spec/integration_spec.rb

# 詳細出力
bundle exec rspec --format documentation
```

## テストの特徴

### qwen3-0.6b 統合テスト
- 実際のローカルLLMサーバーとの通信テスト
- サーバーが利用できない場合は自動的にスキップ
- 日本語と英語の両方でテスト実行

### 実際のLLM統合テスト
- 全てのテストで実際の qwen3-0.6b モデルを使用
- ローカルエンドポイント (http://localhost:8080) での実際のAPI通信
- ユニットテストのみモックを使用（JobProcessor内部ロジックのテスト用）

### エラーハンドリング
- 設定ファイルエラー
- JSONパースエラー  
- API接続エラー
- ファイル不存在エラー

## 注意事項

- 統合テストを実行するには qwen3-0.6b が http://localhost:8080 で動作している必要があります
- テストにはTemporary fileを使用し、実行後に自動クリーンアップされます
- WebMockによりHTTP通信は制御され、localhostのみ許可されています