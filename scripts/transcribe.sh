#!/bin/bash
set -euo pipefail

# === MKV → 文字起こし → 議事録スクリプト ===
# 使い方: ./transcribe.sh input.mkv

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PYTHON="/home/o9oem/venv-transcribe/bin/python3"

# --- 非対話シェル用: nvm default の PATH を補完 ---
NVM_DEFAULT=$(cat "$HOME/.nvm/alias/default" 2>/dev/null || echo "")
if [ -n "$NVM_DEFAULT" ]; then
    NVM_NODE_DIR=$(ls -d "$HOME/.nvm/versions/node/v${NVM_DEFAULT}"* 2>/dev/null | sort -V | tail -1)
    [ -n "$NVM_NODE_DIR" ] && export PATH="$NVM_NODE_DIR/bin:$PATH"
fi
export PATH="$HOME/.local/bin:$PATH"
source "$HOME/.config/env/secrets.env" 2>/dev/null
WHISPER_MODEL="turbo"

# --- 引数チェック ---
if [ $# -lt 1 ]; then
    echo "使い方: $0 <input.mkv>"
    exit 1
fi

INPUT_FILE="$1"
if [ ! -f "$INPUT_FILE" ]; then
    echo "エラー: ファイルが見つかりません: $INPUT_FILE"
    exit 1
fi

# --- 依存関係チェック ---
for cmd in ffmpeg gemini; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "エラー: $cmd がインストールされていません。"
        exit 1
    fi
done

if [ ! -x "$PYTHON" ]; then
    echo "エラー: Python venv が見つかりません: $PYTHON"
    echo "  python3 -m venv /home/o9oem/venv-transcribe && /home/o9oem/venv-transcribe/bin/pip install faster-whisper"
    exit 1
fi

"$PYTHON" -c "import faster_whisper" 2>/dev/null || {
    echo "エラー: faster-whisper がインストールされていません。"
    echo "  /home/o9oem/venv-transcribe/bin/pip install faster-whisper"
    exit 1
}

# --- パス設定 ---
INPUT_DIR="$(cd "$(dirname "$INPUT_FILE")" && pwd)"
INPUT_BASE="$(basename "$INPUT_FILE")"
INPUT_NAME="${INPUT_BASE%.*}"

AUDIO_TMP="${INPUT_DIR}/${INPUT_NAME}_tmp.wav"
TRANSCRIPT_FILE="${INPUT_DIR}/${INPUT_NAME}_transcript.txt"
MINUTES_FILE="${INPUT_DIR}/${INPUT_NAME}_minutes.md"

# --- Step 1: 音声抽出 ---
echo "=== Step 1/3: 音声抽出 (ffmpeg) ==="
ffmpeg -i "$INPUT_FILE" -vn -acodec pcm_s16le -ar 16000 -ac 1 -y "$AUDIO_TMP" 2>/dev/null
echo "  完了: $AUDIO_TMP"

# --- Step 2: 文字起こし (faster-whisper) ---
echo "=== Step 2/3: 文字起こし (faster-whisper, model=$WHISPER_MODEL) ==="
"$PYTHON" "$SCRIPT_DIR/transcribe.py" "$AUDIO_TMP" "$TRANSCRIPT_FILE" "$WHISPER_MODEL"
echo "  完了: $TRANSCRIPT_FILE"

# --- 一時ファイル削除 ---
rm -f "$AUDIO_TMP"

# --- Step 3: 議事録化 (Gemini CLI) ---
echo "=== Step 3/3: 議事録化 (Gemini CLI) ==="

# ファイル名から日時を推測 (例: "2026-03-18 14-00-52")
MEETING_DATE="不明"
if [[ "$INPUT_NAME" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})[[:space:]]+([0-9]{2})-([0-9]{2}) ]]; then
    MEETING_DATE="${BASH_REMATCH[1]}年${BASH_REMATCH[2]}月${BASH_REMATCH[3]}日 ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}"
fi

TRANSCRIPT_CONTENT=$(cat "$TRANSCRIPT_FILE")

PROMPT=$(cat <<'PROMPT_TEMPLATE'
# 指示

以下の情報と構造化ルールに基づき、提供されたミーティングの文字起こしテキストを分析・構造化し、その結果を用いて議事録を作成してください。
Markdownで出力してください。コードブロックで囲まず、そのままMarkdownとして出力してください。

## 入力情報

### 1. ミーティング情報

* **会議名/件名**: 文字起こし内容から推測してください
* **日時**: MEETING_DATE_PLACEHOLDER
* **場所**: オンライン
* **参加者リスト**: 文字起こし内容から推測してください。文字起こしテキスト中に人名（例: 「〇〇さん」「〇〇氏」）が登場した場合、それらを参加者として抽出してください。また、発言の文脈や口調の違いから話者を区別し、可能な限り具体的な名前を特定してください。特定できない場合は「話者A」「話者B」のように区別してください。
* **ミーティングの目的**: 文字起こし内容から推測してください
* **事前に配布された議題**: 文字起こし内容から推測してください

### 2. 参加者の特定に関する追加指示

文字起こしテキストを分析する際、以下の手順で参加者を特定してください：
1. テキスト中に登場する全ての人名を抽出する（「〇〇さん」「〇〇氏」「〇〇の方」等の表現から）
2. 名前が直接言及されていなくても、発言内容から役割（PM、開発、営業等）を推測する
3. 議事録の全ての箇所（決定事項、ToDo、共有事項等）で、可能な限り具体的な名前または役割名を使用する
4. 「[発言者不明]」は最終手段とし、文脈から推測可能な場合は推測した名前を使用する

### 3. 文字起こしテキスト

TRANSCRIPT_PLACEHOLDER

### 議事録の作成

以下の標準形式で、自然で分かりやすい文章の議事録を作成してください。

```
件名: （会議名/件名）
日時:
場所:
参加者: （敬称略、役職等あれば付記）
目的:
議題: （箇条書き）
---
決定事項: （箇条書きで具体的に）
ToDoリスト: （担当者、タスク内容、期限を明記した表形式または箇条書き）
合意事項: （箇条書きで具体的に）
共有事項・報告事項: （箇条書き、必要に応じて発言者名を付記）
提起された課題・懸念点: （箇条書き、必要に応じて提起者名を付記）
その他特筆事項:
次回予定:
```

* 文字起こしテキストから直接判断できない情報（会議名、日時、場所、目的、議題など）は、「ミーティング情報」を最優先で参照してください。情報がない場合は「不明」と記載してください。
* 文字起こしテキスト中の不明瞭な箇所（話者、内容）は、議事録にもその旨を注記してください (例: 「[内容不明瞭]」)。
* ToDoリストの担当者欄には、文字起こしから特定した具体的な人名を記載してください。特定できない場合のみ役割名（「開発担当」等）を使用してください。
* 構造化データの内容を忠実に反映しつつ、議事録として読みやすいように体裁を整えてください。
PROMPT_TEMPLATE
)

# プレースホルダを実際の値に置換
PROMPT="${PROMPT/MEETING_DATE_PLACEHOLDER/$MEETING_DATE}"
PROMPT="${PROMPT/TRANSCRIPT_PLACEHOLDER/$TRANSCRIPT_CONTENT}"

# Gemini CLI で議事録生成
echo "$PROMPT" | gemini -p "" > "$MINUTES_FILE"

echo "  完了: $MINUTES_FILE"
echo ""
echo "=== 全処理完了 ==="
echo "  文字起こし: $TRANSCRIPT_FILE"
echo "  議事録:     $MINUTES_FILE"
