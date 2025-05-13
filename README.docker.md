# SC1000 Linuxイメージビルド用Docker環境

このDockerfileは、SC1000のLinuxイメージをビルドするための環境を提供します。buildroot 2018.08.4を使用して、ARM向けのLinuxイメージを構築します。

## 前提条件

- Docker がインストールされていること
- macOS（M1/M2/M3チップ対応）、Linux、またはWindows環境

## M1/M2/M3 Mac（Apple Silicon）での注意点

このDockerfileは、Apple Silicon（ARM64アーキテクチャ）上で動作するように設定されています。`--platform=linux/arm64`フラグを使用して、ARM64向けのUbuntuイメージを使用しています。

これにより、M1/M2/M3 Mac上でのパフォーマンスが向上し、Rosetta 2による変換が不要になります。

Intel Mac（x86_64アーキテクチャ）を使用している場合は、Dockerfileの最初の行を以下のように変更してください：

```
FROM ubuntu:20.04
```

## Dockerイメージのビルド

以下のコマンドを実行して、Dockerイメージをビルドします：

```bash
docker build -t sc1000-buildroot .
```

## Dockerコンテナの実行

### 対話モードでの実行

以下のコマンドを実行して、対話モードでDockerコンテナを起動します：

```bash
docker run -it --rm -v $(pwd):/work/SC1000 sc1000-buildroot
```

このコマンドは、現在のディレクトリ（SC1000プロジェクトのルートディレクトリ）を、コンテナ内の `/work/SC1000` にマウントします。

### 自動ビルドの実行

以下のコマンドを実行して、自動的にbuildroot環境の構築とLinuxイメージのビルドを行います：

```bash
docker run -it --rm -v $(pwd):/work/SC1000 sc1000-buildroot build
```

## 手動でのビルド手順

Dockerコンテナ内で以下の手順を実行することで、手動でビルドを行うこともできます：

```bash
cd /work/buildroot-2018.08.4
cp /work/SC1000/os/buildroot/buildroot_config .config
make -j$(nproc)
```

## ビルド結果

ビルドが成功すると、Linuxイメージが以下の場所に生成されます：

```
/work/buildroot-2018.08.4/output/images/
```

このディレクトリには、以下のようなファイルが含まれます：
- rootfsイメージ（ext2、squashfsなど）
- カーネルイメージ（zImage）
- デバイスツリーファイル（*.dtb）

## xwaxのビルド

SC1000用のxwaxをビルドするには、以下のコマンドを実行します：

```bash
docker run -it --rm \
  -v $(pwd):/work/SC1000 \
  sc1000-buildroot \
  /bin/bash -c "cd /work/SC1000/software && make CC=/work/buildroot-2018.08.4/output/host/usr/bin/arm-linux-gcc"
```

ビルドが成功すると、`/work/SC1000/software/xwax`にバイナリが生成されます。

### 対話モードでxwaxをビルドする場合

```bash
# コンテナを対話モードで起動
docker run -it --rm \
  -v $(pwd):/work/SC1000 \
  sc1000-buildroot

# コンテナ内で以下のコマンドを実行
cd /work/SC1000/software
make CC=/work/buildroot-2018.08.4/output/host/usr/bin/arm-linux-gcc
```

### クリーンビルドを行う場合

```bash
docker run -it --rm \
  -v $(pwd):/work/SC1000 \
  sc1000-buildroot \
  /bin/bash -c "cd /work/SC1000/software && make clean && make CC=/work/buildroot-2018.08.4/output/host/usr/bin/arm-linux-gcc"
```

### アップデーターの作成

ビルドしたxwaxをSC1000デバイスにアップデートするためのパッケージを作成するには：

```bash
docker run -it --rm \
  -v $(pwd):/work/SC1000 \
  sc1000-buildroot \
  /bin/bash -c "cd /work/SC1000/updater && ./buildupdater.sh"
```

### xwaxのビルドとアップデーターの作成を一度に行う場合

```bash
docker run -it --rm \
  -v $(pwd):/work/SC1000 \
  sc1000-buildroot \
  /bin/bash -c "cd /work/SC1000/software && make CC=/work/buildroot-2018.08.4/output/host/usr/bin/arm-linux-gcc && cd /work/SC1000/updater && ./buildupdater.sh"
```

## 注意事項

- buildrootのビルドには時間がかかる場合があります（システムのスペックによっては1時間以上）
- ビルドプロセス中に大量のディスク容量（約10GB）が必要になる場合があります
- Dockerコンテナを終了すると、コンテナ内のデータは失われますが、マウントしたディレクトリ（SC1000プロジェクト）のデータは保持されます

## トラブルシューティング

### ビルドエラーが発生する場合

1. メモリ不足の場合は、Dockerに割り当てるリソースを増やしてください
2. ビルド中にエラーが発生した場合は、エラーメッセージを確認し、必要なパッケージをインストールしてください
3. rootユーザーに関連するエラー（`you should not run configure as root`）が発生した場合は、環境変数 `FORCE_UNSAFE_CONFIGURE=1` が設定されていることを確認してください（このDockerfileでは既に設定済みです）
4. オーバーレイディレクトリに関するエラー（`rsync: change_dir "/work/buildroot-2018.08.4//sc1000overlay" failed: No such file or directory`）が発生した場合は、ビルドスクリプトがオーバーレイディレクトリのシンボリックリンクを正しく作成しているか確認してください（このDockerfileでは既に対応済みです）

### Dockerコンテナ内でのファイルの編集

Dockerコンテナ内でファイルを編集する必要がある場合は、以下のエディタが利用可能です：

- vi
- nano（インストールされていない場合は `apt-get update && apt-get install -y nano` でインストール）
