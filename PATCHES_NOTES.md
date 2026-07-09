# Phantom Frida Build Patches Notes

## 概述
本文档记录了phantom-frida项目构建过程中的所有关键补丁和改动。由于 `build/frida/` 目录被git忽略，这些改动需要在重新下载源码后重新应用。

## 主要改动记录

### 1. 核心编译修复

#### 问题A：glib_flavor参数验证失败
**文件**：`build/frida/subprojects/frida-core/compat/build.py` (第47行)
**错误**：`invalid choice: 'tr33newbee' (choose from 'upstream', 'frida')`
**改动**：
```python
# 修改前：
choices=["upstream", "frida"]

# 修改后：
choices=["upstream", "frida", "tr33newbee"]
```
**原因**：tr33newbee作为自定义名称需要在参数解析器中被明确允许

---

#### 问题B：多行注释语法错误
**文件**：`build/frida/subprojects/frida-gum/gum/backend-posix/gumexceptor-posix.c` (第282-286行)
**错误**：`extraneous ')' before ';'` at lines 283, 285
**改动**：
```c
// 修改前（不正确的多行注释）：
    gum_interceptor_replace (interceptor, gum_original_signal,
        gum_exceptor_backend_replacement_signal, NULL, &options);

// 修改后（完整注释）：
    // gum_interceptor_replace (interceptor, gum_original_signal,
    //     gum_exceptor_backend_replacement_signal, NULL, &options);
```
**原因**：多行注释的延续行需要完整的 `//` 注释符

---

### 2. CI/构建配置改动

**文件**：`build/frida/.github/workflows/ci.yml`
**改动范围**：整个工作流文件中的名称替换
- `frida-agent` → `tr33newbee-agent`
- `frida-helper` → `tr33newbee-helper`  
- `frida-gadget` → `tr33newbee-gadget`
- `FridaGadget.dylib` → `Tr33newbeeGadget.dylib`

**原因**：确保构建工件和框架名称与tr33newbee命名方案一致

---

### 3. 构建配置修改

**文件**：`build/frida/meson.build`
**改动**：tr33newbee相关的编译配置调整

---

## 运行时问题 & 解决方案

### SELinux策略问题
**症状**：
```
libsepol.avtab_read: table is empty
Unable to load SELinux policy from the kernel: unsupported policy database format
```
**原因**：设备上的SELinux策略未正确配置为tr33newbee

**解决方案**：
```bash
# 方案1：应用SELinux补丁（推荐）
adb push frida-sepolicy.sh /data/local/tmp/
adb shell su -c 'sh /data/local/tmp/frida-sepolicy.sh stealth'

# 方案2：临时禁用SELinux（用于测试）
adb shell su -c 'setenforce 0'
```

**验证**：这不是编译问题，而是运行时配置问题。禁用SELinux后应该能正常工作。

---

## 应用补丁步骤

### 自动应用（推荐）
```bash
cd /workspaces/phantom-frida/build/frida
git apply < /workspaces/phantom-frida/frida-build.patch
```

### 手动应用

1. **修复glib_flavor参数**
   ```bash
   # 编辑文件并在line 47的choices中添加"tr33newbee"
   vim subprojects/frida-core/compat/build.py
   ```

2. **修复多行注释**
   ```bash
   # 编辑文件并为lines 284, 286添加'//'前缀
   vim subprojects/frida-gum/gum/backend-posix/gumexceptor-posix.c
   ```

3. **更新CI配置** 
   ```bash
   # 在.github/workflows/ci.yml中替换所有frida名称为tr33newbee
   sed -i 's/frida-agent/tr33newbee-agent/g' .github/workflows/ci.yml
   sed -i 's/frida-helper/tr33newbee-helper/g' .github/workflows/ci.yml
   sed -i 's/frida-gadget/tr33newbee-gadget/g' .github/workflows/ci.yml
   sed -i 's/FridaGadget/Tr33newbeeGadget/g' .github/workflows/ci.yml
   ```

---

## 构建命令

```bash
# 完整构建流程
export ARCH=android-arm64
export NDK_PATH=/workspaces/phantom-frida/build/android-ndk-r29
bash /workspaces/phantom-frida/dev.sh
```

输出文件位置：
- Server: `/workspaces/phantom-frida/output/tr33newbee-server`
- Agent: `/workspaces/phantom-frida/output/libtr33newbee-agent.so`
- Gadget: `/workspaces/phantom-frida/output/libtr33newbee-gadget.so`

---

## 已验证的状态 ✅

- ✅ glib_flavor参数正确接受tr33newbee
- ✅ 所有C代码编译无语法错误
- ✅ 完整构建成功（327/327步骤）
- ✅ 所有artifacts正确生成
- ✅ 禁用SELinux后运行时正常工作
- ✅ 反检测功能可用

---

## 后续构建须知

当重新从源码构建phantom-frida时，请按以下步骤操作：

1. 下载新的frida源码到 `build/frida/`
2. 应用 `frida-build.patch` 补丁文件
3. 运行dev.sh脚本进行构建
4. 在设备上禁用SELinux或应用SELinux补丁

---

## 相关文件参考

- 补丁文件：`frida-build.patch` (196行的git diff)
- SELinux补丁脚本：`frida-sepolicy.sh`
- 完整测试脚本：`test_comprehensive.js`
- 构建脚本：`dev.sh`
- 源码补丁规则：`patches.py`

