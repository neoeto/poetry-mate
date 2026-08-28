# eszstd 原生库（Android jniLibs）

`es_compression` 仅在 iOS 上静态链接（`DynamicLibrary.process()`）；
Android 上由 `DynamicLibrary.open()` 按固定文件名加载：

- `libeszstd-android64.so`（arm64-v8a / x86_64）
- `libeszstd-android32.so`（armeabi-v7a）

本目录放置预编译产物，AGP 会自动打进 APK 的 `lib/<abi>/`。

## 来源与版本

- zstd 源码：https://github.com/facebook/zstd v1.5.4（与 es_compression 2.0.15 期望版本一致）
- NDK：r27 (27.0.12077973)，minSdk ≥ 21

## 重新构建

```bash
# 1) 下载源码
curl -fLO https://github.com/facebook/zstd/releases/download/v1.5.4/zstd-1.5.4.tar.gz
tar -xzf zstd-1.5.4.tar.gz && cd zstd-1.5.4/lib

# 2) 交叉编译（NDK r27，按 ABI 指定 clang wrapper）
NDK=~/Library/Android/sdk/ndk/27.0.12077973
TC=$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin
SRCS=$(ls common/*.c compress/*.c decompress/*.c dictBuilder/*.c)
INC="-I. -Icommon -Icompress -Idecompress -IdictBuilder -Ilegacy"
CFLAGS="-O2 -fPIC -shared -DZSTD_LEGACY_SUPPORT=0 -DZSTD_DISABLE_ASM"

"$TC/aarch64-linux-android21-clang"    $CFLAGS $INC -o libeszstd-android64.so $SRCS -llog
"$TC/armv7a-linux-androideabi21-clang" $CFLAGS $INC -o libeszstd-android32.so $SRCS -llog
"$TC/x86_64-linux-android21-clang"     $CFLAGS $INC -o libeszstd-android64.so $SRCS -llog

# 3) strip 并按 ABI 放入本目录
#    arm64-v8a/           <- libeszstd-android64.so
#    armeabi-v7a/         <- libeszstd-android32.so
#    x86_64/              <- libeszstd-android64.so
```

验证导出符号（应包含 `ZSTD_decompressStream` 等）：

```bash
$TC/llvm-nm -D arm64-v8a/libeszstd-android64.so | grep ' T ZSTD_' | head
```
