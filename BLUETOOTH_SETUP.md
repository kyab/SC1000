# Bluetooth設定の説明

## カーネル設定フラグメントとは

**カーネル設定フラグメント** (`linux_bt.config`) は、BuildrootがLinuxカーネルをビルドする際に、デフォルトの設定（`sunxi` defconfig）に**追加で適用**する設定ファイルです。

### 仕組み

1. Buildrootはデフォルトで `sunxi` defconfig を使用してカーネルをビルド
2. この設定にはBluetoothサポートが含まれていない
3. `linux_bt.config` をフラグメントとして指定すると、デフォルト設定に追加で適用される
4. 結果：`sunxi defconfig + linux_bt.config = Bluetooth対応カーネル`

### 設定ファイルの場所

- **ソース**: `/Users/koji/work/SC1000/os/buildroot/linux_bt.config`
- **ビルド時にコピー先**: `buildroot-2018.08.4/board/olimex/a13_olinuxino/linux_bt.config`
- **Buildroot設定での指定**: `BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES="board/olimex/a13_olinuxino/linux_bt.config"`

## USB Bluetoothドングル用の設定

SC1000は**USB Bluetoothドングル**を使用します（A13 SoMにはBluetoothハードウェアがありません）。

### 必要なカーネル設定

1. **`CONFIG_BT=y`**: Bluetoothサブシステムを有効化
2. **`CONFIG_BT_HCIBTUSB=y`**: USB Bluetoothドライバ（最重要）
3. **`CONFIG_BT_HCIBTUSB_BCM=y`**: Broadcom製チップサポート
4. **`CONFIG_BT_HCIBTUSB_RTL=y`**: Realtek製チップサポート
5. **`CONFIG_BT_HCIBTUSB_MTK=y`**: MediaTek製チップサポート
6. **`CONFIG_BT_HCIBTUSB_ATH3K=y`**: Atheros製チップサポート

### 不要な設定

- UART Bluetooth関連（`CONFIG_BT_HCIUART`など）は不要（A13 SoMにBluetoothハードウェアがないため）

## 起動スクリプト

1. **`S30dbus`**: D-Busシステムバス（Buildrootが自動生成）
2. **`S30bluetooth`**: bluetoothdデーモン（カスタムスクリプト）
3. **`S40bluealsa`**: BlueZ-ALSAデーモン（カスタムスクリプト）

## 動作確認

USB Bluetoothドングルを接続後、以下で確認：

```bash
# カーネルモジュールの確認
lsmod | grep bluetooth

# HCIデバイスの確認
ls -l /sys/class/bluetooth/

# bluetoothdの確認
pidof bluetoothd
```


