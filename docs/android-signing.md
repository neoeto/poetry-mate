# Android Release Keystore 配置说明

本文说明如何为 Poetry Mate 生成固定的 Android release keystore，并配置 GitHub Actions。

> **重要：** keystore 是 Android 应用更新身份的一部分。后续每个可分发的 APK/AAB 都必须使用同一个 keystore 签名。请勿把 `.jks`、密码或 `key.properties` 提交到 Git；keystore 丢失后将无法继续覆盖更新使用该签名的旧版本。

## 1. 生成 keystore

在仓库目录之外执行。以下命令适用于 macOS/Linux，并使用 JDK 自带的 `keytool`：

```bash
umask 077
mkdir -p "$HOME/private/poetry-mate-signing"
cd "$HOME/private/poetry-mate-signing"

keytool -genkeypair -v \
  -keystore poetry-mate-release.jks \
  -storetype JKS \
  -alias poetry-mate-release \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=Poetry Mate, O=Poetry Mate, C=CN"
```

命令会交互要求输入：

- keystore password，对应 `ANDROID_KEYSTORE_PASSWORD`
- key password，对应 `ANDROID_KEY_PASSWORD`

可以在提示输入 key password 时直接按回车，使用与 keystore 相同的密码。请将密码和 `.jks` 文件备份到密码管理器或其他安全位置。

检查 alias 和证书信息：

```bash
keytool -list -v \
  -keystore "$HOME/private/poetry-mate-signing/poetry-mate-release.jks" \
  -alias poetry-mate-release
```

## 2. 配置 GitHub Actions Secrets

打开 GitHub 仓库的：

**Settings → Secrets and variables → Actions → New repository secret**

创建以下四个 repository secrets：

| Secret | 值 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `poetry-mate-release.jks` 的 Base64 内容 |
| `ANDROID_KEYSTORE_PASSWORD` | 生成 keystore 时设置的 keystore password |
| `ANDROID_KEY_ALIAS` | `poetry-mate-release` |
| `ANDROID_KEY_PASSWORD` | 生成 key 时设置的 key password |

在 macOS 上将 keystore 转为一行 Base64 并复制到剪贴板：

```bash
base64 -i "$HOME/private/poetry-mate-signing/poetry-mate-release.jks" \
  | tr -d '\n' \
  | pbcopy
```

在 Linux 上可以使用：

```bash
base64 -w 0 "$HOME/private/poetry-mate-signing/poetry-mate-release.jks"
```

不要把 Base64 内容提交到仓库。Base64 只是编码，不是加密。

## 3. GitHub Actions 行为

`.github/workflows/build-app.yml` 会执行以下保护：

1. 四个 Android 签名 Secret 任意一个缺失时，构建直接失败。
2. 将 keystore 临时写入 `app/android/key.jks`，并生成 `key.properties`。
3. 使用 `keytool` 校验 keystore password 和 alias。
4. 构建 APK 后使用 `apksigner` 校验签名。

`app/android/app/build.gradle.kts` 在 CI 环境中通过
`POETRY_MATE_REQUIRE_RELEASE_SIGNING=true` 禁止回退到 debug 签名。

配置完成后，可通过以下方式触发构建：

- 推送 `v*` tag；或
- 在 **Actions → build-app → Run workflow** 手动运行。

## 4. 本地构建 release（可选）

本地如果需要使用同一个 keystore 构建 release，可以在 `app/android/` 下创建被 Git 忽略的 `key.properties`：

```properties
storeFile=/绝对路径/private/poetry-mate-signing/poetry-mate-release.jks
storePassword=你的 keystore password
keyAlias=poetry-mate-release
keyPassword=你的 key password
```

也可以将 keystore 放到 `app/android/key.jks`，此时写成：

```properties
storeFile=key.jks
storePassword=你的 keystore password
keyAlias=poetry-mate-release
keyPassword=你的 key password
```

不要将上述文件加入 Git。没有本地签名配置时，Gradle 仍允许生成 debug 签名的 release 包，但该包只适合临时测试，不应作为正式发布包。

## 5. 验证已发布 APK 的签名

下载新旧 APK 后，使用 Android SDK 的 `apksigner` 查看证书摘要：

```bash
$ANDROID_HOME/build-tools/<版本>/apksigner verify --print-certs old.apk
$ANDROID_HOME/build-tools/<版本>/apksigner verify --print-certs new.apk
```

两者的 signer certificate SHA-256 必须一致，才能进行覆盖更新。`versionCode` 递增本身不能解决签名不一致问题。

## 6. 旧版本无法更新时

如果手机上旧版本是由其他 keystore、某次 GitHub runner 的临时 debug keystore，或 Google Play 的应用签名密钥生成的：

- 能找回原 keystore：将原 keystore 配置到 GitHub Secrets，通常可以继续覆盖更新；
- 找不回原 keystore：Android 无法接受新的签名，只能卸载旧版本后安装首个固定签名版本；
- 如果应用来自 Google Play：应遵循 Play App Signing 的签名链，不能用任意本地 keystore 替代 Play 的应用签名密钥。

安装首个固定签名版本后，只要 keystore 不变，后续版本即可正常覆盖更新。
