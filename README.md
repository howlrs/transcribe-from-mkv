# transcribe-from-mkv

MKV/MP4 などの動画ファイルから音声を文字起こしし、AI で議事録を自動生成するスクリプトです。

## 処理フロー

```
input.mkv → [ffmpeg] → audio.wav → [faster-whisper] → transcript.txt → [Gemini CLI] → minutes.md
```

| ステップ | ツール | 説明 |
|----------|--------|------|
| 1. 音声抽出 | ffmpeg | 動画から音声を WAV (16kHz, mono) に変換 |
| 2. 文字起こし | faster-whisper | Whisper turbo モデルで日本語音声認識 |
| 3. 議事録生成 | Gemini CLI | 文字起こしテキストから構造化された議事録を生成 |

## 出力例

### 文字起こし (`*_transcript.txt`)

```
[00:00:00 - 00:00:06] 見えてますでしょうか
[00:00:06 - 00:00:08] 見えてます
[00:00:08 - 00:00:13] まずはサーバーの負荷状況のご報告からになります
```

### 議事録 (`*_minutes.md`)

```markdown
件名: サーバー運用状況に関する定例ミーティング
日時: 2026年3月18日 16:01
場所: オンライン
参加者: 田中（進行）、佐藤、鈴木、山田、高橋
目的: サーバー負荷状況の報告、進捗確認
...
```

## 必要環境

- **OS**: WSL2 (Ubuntu) — Windows から WSL2 経由で実行
- **CPU**: x86_64 (AMD / Intel)
- **Python**: 3.10 以上
- **ffmpeg**: 音声抽出に使用
- **Gemini CLI**: 議事録生成に使用（要認証）

## セットアップ

### 1. システム依存関係のインストール

```bash
sudo apt install ffmpeg
```

### 2. Python パッケージのインストール

```bash
pip install -r requirements.txt
```

### 3. Gemini CLI のインストールと認証

```bash
npm install -g @anthropic-ai/gemini-cli
gemini  # 初回起動で認証
```

詳細: [Gemini CLI ドキュメント](https://github.com/anthropics/gemini-cli)

### 4. スクリプトに実行権限を付与

```bash
chmod +x transcribe.sh
```

## 使い方

### WSL2 / Linux から直接実行

```bash
./transcribe.sh "2026-03-18 16-01-55.mkv"
```

### Windows からドラッグ＆ドロップで実行

1. `transcribe.bat` を動画ファイルと同じフォルダに配置
2. MKV ファイルを `transcribe.bat` にドラッグ＆ドロップ
3. WSL2 上で自動的に処理が開始されます

> **注意**: `transcribe.bat` 内の WSL ディストリビューション名（`wsl -d dev`）は、お使いの環境に合わせて変更してください。ディストリビューション名は `wsl -l -v` で確認できます。

### 出力ファイル

入力ファイルと同じディレクトリに生成されます：

| ファイル | 内容 |
|----------|------|
| `{ファイル名}_transcript.txt` | タイムスタンプ付き文字起こし |
| `{ファイル名}_minutes.md` | 構造化された議事録 (Markdown) |

## 設定・カスタマイズ

### Whisper モデルの変更

`transcribe.sh` の `WHISPER_MODEL` を変更：

| モデル | 精度 | 速度 (1時間音声) | 備考 |
|--------|------|------------------|------|
| `tiny` | 低 | ~2分 | テスト用 |
| `base` | 中 | ~4分 | 軽量 |
| `small` | 中高 | ~10分 | バランス型 |
| `turbo` | **高** | **~6分** | **デフォルト（推奨）** |
| `large-v3` | 最高 | ~40分 | 最高精度が必要な場合 |

### CPU スレッド数の調整

環境変数 `WHISPER_THREADS` で制御できます（デフォルト: 4）：

```bash
WHISPER_THREADS=8 ./transcribe.sh input.mkv
```

> スレッド数を増やしすぎると逆に遅くなる場合があります。4〜8 が推奨です。

### Gemini モデルの変更

`transcribe.sh` の `GEMINI_MODEL` を変更：

```bash
GEMINI_MODEL="gemini-3.1-flash-lite-preview"  # デフォルト
```

### 議事録テンプレートの変更

`transcribe.sh` 内の `PROMPT_TEMPLATE` セクションを編集することで、議事録のフォーマットや指示を自由にカスタマイズできます。

## 性能目安

AMD Ryzen 9 9950X (4スレッド, int8量子化) での実測値：

| 音声長 | 文字起こし時間 | 倍速 |
|--------|---------------|------|
| 1分 | ~12秒 | 5x |
| 10分 | ~60秒 | 10x |
| 1時間 | ~6分 | 10x |

※ 初回実行時はモデルダウンロード (~1.5GB) が発生します。

## 技術詳細

- **文字起こしエンジン**: [faster-whisper](https://github.com/SYSTRAN/faster-whisper) (CTranslate2 ベース)
- **量子化**: int8 (メモリ効率・速度向上)
- **VAD フィルター**: Silero VAD を使用し、無音区間のハルシネーション（誤認識）を抑制
- **議事録生成**: Gemini CLI 経由で Gemini API を呼び出し、構造化された Markdown 議事録を生成
- **日時自動推測**: ファイル名が `YYYY-MM-DD HH-MM-SS` 形式の場合、議事録の日時に自動反映

## ライセンス

MIT
