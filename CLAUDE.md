# CLAUDE.md

このファイルは、このリポジトリでコードを扱う際にClaude Code (claude.ai/code) へのガイダンスを提供します。

## プロジェクト概要

SC1000は、USBスティックからサンプルとビートを読み込むオープンソースのポータブルデジタルスクラッチ楽器です。ファームウェア、Linux OS、ソフトウェア、PCBベースのハードウェアから構成される完全な組み込みシステムです。

## ビルドコマンド

### Dockerを使用したARMターゲット向けクロスコンパイル
```bash
# Docker環境をビルド（ARMクロスコンパイル用buildrootを含む）
docker build -t sc1000-buildroot .

# ARMターゲット向けxwaxソフトウェアをビルド
docker run -it --rm -v $(pwd):/work/SC1000 sc1000-buildroot /bin/bash -c "cd /work/SC1000/software && make CC=/work/buildroot-2018.08.4/output/host/usr/bin/arm-linux-gcc"

# クリーンして再ビルド
docker run -it --rm -v $(pwd):/work/SC1000 sc1000-buildroot /bin/bash -c "cd /work/SC1000/software && make clean && make CC=/work/buildroot-2018.08.4/output/host/usr/bin/arm-linux-gcc"

# アップデーターパッケージをビルド
docker run -it --rm -v $(pwd):/work/SC1000 sc1000-buildroot /bin/bash -c "cd /work/SC1000/updater && ./buildupdater.sh"

# 完全なワークフロー（ソフトウェア + アップデーター）
docker run -it --rm -v $(pwd):/work/SC1000 sc1000-buildroot /bin/bash -c "cd /work/SC1000/software && make CC=/work/buildroot-2018.08.4/output/host/usr/bin/arm-linux-gcc && cd /work/SC1000/updater && ./buildupdater.sh"
```

### ファームウェアビルド（MPLAB/XC8が必要）
```bash
cd firmware
make  # nbproject/Makefile-impl.mkシステムを使用
```

### OSイメージビルド
```bash
# Dockerを使用（自動化）
docker run -it --rm -v $(pwd):/work/SC1000 sc1000-buildroot build

# 手動buildroot（Dockerコンテナ内）
cd /work/buildroot-2018.08.4
cp /work/SC1000/os/buildroot/buildroot_config .config
make -j$(nproc)
```

## アーキテクチャ概要

### マルチプロセッサシステム設計
- **メインSoC**: Allwinner A13 ARM Cortex A8、カスタムLinux（buildrootベース）を実行
- **入力MCU**: PIC18LF14K22、物理入力を処理（メインSoCのI2Cスレーブ）
- **センサー**: AS5601磁気回転エンコーダー（ジョグホイール位置検出）

### ソフトウェアコンポーネント

#### コアアプリケーション（`software/`）
- **xwax**: 改良されたデジタルビニールシステム - メインオーディオエンジン
- **sc_input**: SC1000専用入力のハードウェア抽象化レイヤー
- **sc_playlist**: ビートとサンプルのファイル/フォルダ管理
- **sc_midimap**: MIDIマッピングと設定システム

#### 主要なデータフロー
1. PICファームウェアがADC/GPIOをサンプリング → I2Cステータスデータ
2. sc_inputがI2Cをポーリング → xwaxイベントに変換
3. xwaxオーディオエンジンが処理 → ALSA出力
4. 2デッキシステム: deck[0]（ビート） + deck[1]（サンプル）、ミックス出力

#### 設定システム
- 設定は`/media/sda/scsettings.txt`（USB）または`/var/scsettings.txt`（内部）から読み込み
- 設定ファイルによるMIDIとGPIO入力のランタイムリマッピング
- SC1000とSC500の両ハードウェアバリアントをサポート

### ハードウェア統合ポイント
- **オーディオ**: ALSA `hw:0,0`デバイスでデュアルデッキミキシング
- **USBストレージ**: `/dev/sda1`を`/media/sda/`に自動マウント
- **期待されるフォルダ構造**: `/media/sda/beats/`と`/media/sda/samples/`
- **I2C通信**: メインSoC ↔ PIC間でリアルタイム入力データ

### ビルドシステム詳細
- **ソフトウェア**: buildrootのARMクロスコンパイラーを使用する標準Makefile
- **ファームウェア**: Microchip XC8コンパイラーを使用するNetBeans/MPLABプロジェクト
- **OS**: カスタムオーバーレイ付きBuildroot 2018.08.4（`os/buildroot/sc1000overlay/`）
- **Docker**: 一貫性のあるビルドのための完全なクロスコンパイル環境

### 開発ワークフロー
1. ソフトウェア変更: `software/`で編集、Docker ARMクロスコンパイラーでビルド
2. ファームウェア変更: `firmware/main.c`を編集、MPLAB/makeでビルド
3. OS変更: `os/buildroot/buildroot_config`またはオーバーレイを修正、Dockerで再ビルド
4. ハードウェア: `hardware/`のPCB設計（メインPCBとエンクロージャ用ガーバー）

### 設定に関する注記
- 設定構造は`xwax.h`で`SC_SETTINGS`として定義
- デフォルト値は`xwax.c:94-113`の`loadSettings()`関数で設定
- MIDI/IOリマッピングにより、ランタイムハードウェア再設定が可能
- デュアルハードウェアサポート（SC1000/SC500）設定フラグ経由