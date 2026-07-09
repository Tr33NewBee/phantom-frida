# 🔧 Phantom-Frida 构建补丁说明

**最后更新**: 2026-07-09

## 📋 快速摘要

phantom-frida在编译frida源码时需要应用以下关键补丁。由于 `build/frida/` 目录被git忽略，这些改动需要在**每次重新下载源码后**手动应用。

### 文件清单
- ✅ `frida-build.patch` - 196行的git diff补丁文件
- ✅ `apply-patches.sh` - 自动应用补丁的脚本
- ✅ `PATCHES_NOTES.md` - 详细的改动说明文档

## 🚀 快速应用

### 方法1：自动应用（推荐）

```bash
# 进入项目根目录
cd /workspaces/phantom-frida

# 运行补丁应用脚本
bash apply-patches.sh
```

### 方法2：手动应用

```bash
# 进入frida源码目录
cd /workspaces/phantom-frida/build/frida

# 应用patch
git apply < /workspaces/phantom-frida/frida-build.patch
```

## 🔍 包含的补丁

### 核心编译修复 (2个)

| 文件 | 行号 | 问题 | 修复 |
|------|------|------|------|
| `subprojects/frida-core/compat/build.py` | 47 | glib_flavor参数不接受tr33newbee | 在choices中添加"tr33newbee" |
| `subprojects/frida-gum/gum/backend-posix/gumexceptor-posix.c` | 282-286 | 多行注释语法错误 | 为续行添加//前缀 |

### 配置文件更新

| 文件 | 范围 | 改动 |
|------|------|------|
| `.github/workflows/ci.yml` | 整个文件 | 39行改动：将工件名称从frida替换为tr33newbee |
| `meson.build` | 多处 | tr33newbee相关编译配置 |

## 📊 应用结果

应用补丁后的git状态：
```
 M .github/workflows/ci.yml
 M CONTRIBUTING.md
 M meson.build
 M subprojects/frida-core
 M subprojects/frida-gum
 ... 共22个insertions, 22个deletions
```

## ⚙️ 完整构建流程

```bash
# 1. 应用补丁
bash apply-patches.sh

# 2. 执行构建
export ARCH=android-arm64
export NDK_PATH=/workspaces/phantom-frida/build/android-ndk-r29
bash dev.sh

# 3. 在设备上禁用SELinux（运行时配置）
adb shell su -c 'setenforce 0'

# 4. 部署到设备
adb push output/tr33newbee-server /data/local/tmp/
```

## ⚠️ SELinux 运行时问题

如果看到以下错误：
```
libsepol.avtab_read: table is empty
Unable to load SELinux policy from the kernel: unsupported policy database format
```

**这不是编译问题**，而是设备SELinux配置问题。

**解决方案**：
```bash
# 禁用SELinux（用于测试/开发）
adb shell su -c 'setenforce 0'

# 或应用SELinux补丁（生产环境推荐）
adb push frida-sepolicy.sh /data/local/tmp/
adb shell su -c 'sh /data/local/tmp/frida-sepolicy.sh stealth'
```

## 📝 详细文档

完整的改动说明、手动应用步骤和故障排除指南，请查看 `PATCHES_NOTES.md`

## ✅ 验证补丁已应用

```bash
cd /workspaces/phantom-frida/build/frida
git status | grep "M "  # 应该显示修改的文件
```

## 🆘 故障排除

| 问题 | 解决方案 |
|------|---------|
| `找不到patch文件` | 确保在项目根目录运行脚本 |
| `patch apply失败` | 手动查看PATCHES_NOTES.md进行手动应用 |
| `构建还是失败` | 清除build目录重新下载：`rm -rf build/frida && bash dev.sh` |
| `运行时SELinux错误` | 运行 `adb shell su -c 'setenforce 0'` 禁用SELinux |

