FROM --platform=linux/arm64 ubuntu:20.04

# タイムゾーンの設定（インタラクティブなプロンプトを避けるため）
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tokyo
ENV FORCE_UNSAFE_CONFIGURE=1

# 必要なパッケージをインストール
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    cpio \
    unzip \
    rsync \
    bc \
    python \
    python3 \
    file \
    libncurses5-dev \
    libssl-dev \
    libelf-dev \
    bison \
    flex \
    patch \
    gawk \
    cmake \
    make \
    gcc \
    g++ \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを作成
WORKDIR /work

# buildrootをダウンロード
RUN wget https://buildroot.org/downloads/buildroot-2018.08.4.tar.gz \
    && tar -xzf buildroot-2018.08.4.tar.gz \
    && rm buildroot-2018.08.4.tar.gz

# SC1000のソースコードをコピー（ビルド時に必要なファイルのみ）
COPY os/buildroot/buildroot_config /work/SC1000/os/buildroot/buildroot_config
COPY os/buildroot/sc1000overlay /work/SC1000/os/buildroot/sc1000overlay

# ビルドスクリプトを作成
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# buildrootの設定\n\
cd /work/buildroot-2018.08.4\n\
cp /work/SC1000/os/buildroot/buildroot_config .config\n\
\n\
# オーバーレイディレクトリのシンボリックリンクを作成\n\
if [ ! -e /work/buildroot-2018.08.4/sc1000overlay ]; then\n\
  ln -sf /work/SC1000/os/buildroot/sc1000overlay /work/buildroot-2018.08.4/sc1000overlay\n\
fi\n\
\n\
# buildrootをビルド\n\
echo "Building buildroot (this may take a while)..."\n\
make -j$(nproc)\n\
\n\
echo "Build completed successfully!"\n\
echo "The Linux image is located at: /work/buildroot-2018.08.4/output/images/"\n\
' > /work/build.sh && chmod +x /work/build.sh

# ビルドスクリプトを実行してbuildrootをビルド
RUN /work/build.sh

# ビルド結果を保存するディレクトリを作成
VOLUME ["/work/buildroot-2018.08.4/output"]

# エントリポイントスクリプトを作成
RUN echo '#!/bin/bash\n\
\n\
if [ "$1" = "build" ]; then\n\
    exec /work/build.sh\n\
else\n\
    exec "$@"\n\
fi\n\
' > /work/entrypoint.sh && chmod +x /work/entrypoint.sh

ENTRYPOINT ["/work/entrypoint.sh"]
CMD ["/bin/bash"]
