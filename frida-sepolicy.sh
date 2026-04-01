#!/system/bin/sh
# frida-selinux-patch.sh — 手动为 Frida 注入所需的 SELinux 规则
# 支持：Magisk / KernelSU / APatch
# 用法：adb shell su -c 'sh /data/local/tmp/frida-selinux-patch.sh'

SENTINEL="/data/adb/frida_se_patch"
AUTHOR="Tr33NewBee & Claude"
VERSION="1.0"
SEPOLICY_FILE_PRE="$1"

# ── 参数校验 ──────────────────────────────────────────────
if [ -z "$SEPOLICY_FILE_PRE" ]; then
    echo "[-] Error: SEPOLICY_FILE_PRE is required."
    echo "    Usage: sh $0 <prefix> [-f]"
    echo "    Example: sh $0 stealth"
    exit 1
fi
case "$SEPOLICY_FILE_PRE" in
    *[!a-z]*)
        echo "[-] Error: SEPOLICY_FILE_PRE must contain only lowercase letters [a-z]."
        echo "    Got: '$SEPOLICY_FILE_PRE'"
        exit 1
        ;;
esac

echo "========================="
echo "patch frida SELinux rules"
echo "author: $AUTHOR"
echo "version: $VERSION"
echo "========================="
# ── 检查是否已经 patch 过 ─────────────────────────────────
# ── 检查是否已经 patch 过（直接检测内核策略中的类型）─────
check_already_patched() {
    grep -qa "${SEPOLICY_FILE_PRE}_file"  /sys/fs/selinux/policy 2>/dev/null && \
    grep -qa "${SEPOLICY_FILE_PRE}_memfd" /sys/fs/selinux/policy 2>/dev/null
}

if check_already_patched; then
    echo "[*] Type '${SEPOLICY_FILE_PRE}_file' and '${SEPOLICY_FILE_PRE}_memfd' already exist in kernel policy."
    echo "[*] Frida SELinux rules are already applied — no action needed."
    echo "    Use '-f' to force re-patch: sh $0 $SEPOLICY_FILE_PRE -f"
    if [ "$2" != "-f" ]; then
        # 哨兵文件可能因重启被检测到需要补写
        touch "$SENTINEL" 2>/dev/null && chmod 644 "$SENTINEL" 2>/dev/null
        exit 0
    fi
    echo "[!] Force mode: re-applying all rules..."
fi

# ── 查找 magiskpolicy 可执行文件 ──────────────────────────
find_magiskpolicy() {
    # Magisk（标准 & 旧版路径）
    for p in \
        /data/adb/magisk/magiskpolicy \
        /sbin/magiskpolicy \
        /sbin/.magisk/bin/magiskpolicy; do
        [ -x "$p" ] && echo "$p" && return 0
    done

    # KernelSU（1.0+ 自带 magiskpolicy）
    for p in \
        /data/adb/ksu/bin/magiskpolicy \
        /data/adb/ksud; do
        [ -x "$p" ] && echo "$p" && return 0
    done

    # APatch
    [ -x /data/adb/ap/bin/magiskpolicy ] && \
        echo /data/adb/ap/bin/magiskpolicy && return 0

    # PATH 兜底
    command -v magiskpolicy 2>/dev/null && return 0

    return 1
}

MP_BIN=$(find_magiskpolicy)
if [ -z "$MP_BIN" ]; then
    echo "[-] magiskpolicy not found. Install Magisk / KernelSU / APatch first."
    exit 1
fi
echo "[+] magiskpolicy: $MP_BIN"

# KernelSU 的 ksud 用 'sepolicy' 子命令，其他都用 --live
if echo "$MP_BIN" | grep -q "ksud"; then
    MP() { "$MP_BIN" sepolicy --live "$1"; }
else
    MP() { "$MP_BIN" --live "$1"; }
fi

# ── 1. 添加 Frida 自定义类型 ──────────────────────────────
MP "type ${SEPOLICY_FILE_PRE}_file"
MP "type ${SEPOLICY_FILE_PRE}_memfd"
MP "typeattribute ${SEPOLICY_FILE_PRE}_file file_type"
MP "typeattribute ${SEPOLICY_FILE_PRE}_file mlstrustedobject"
MP "typeattribute ${SEPOLICY_FILE_PRE}_memfd file_type"
MP "typeattribute ${SEPOLICY_FILE_PRE}_memfd mlstrustedobject"

# ── 2. 通用 domain 规则 ───────────────────────────────────
MP "allow domain domain process execmem"
MP "allow domain ${SEPOLICY_FILE_PRE}_file dir search"
MP "allow domain ${SEPOLICY_FILE_PRE}_file file { open read getattr execute map }"
MP "allow domain ${SEPOLICY_FILE_PRE}_memfd file { open read write getattr execute map }"
MP "allow domain shell_data_file dir search"
MP "allow domain zygote_exec file execute"

# ── 3. $self 规则（frida-server 的 SELinux 类型）──────────
SELF_TYPE=$(cat /proc/self/attr/current 2>/dev/null | cut -d: -f3)
if [ -n "$SELF_TYPE" ]; then
    echo "[*] self type: $SELF_TYPE"
    MP "allow domain ${SELF_TYPE} process sigchld"
    MP "allow domain ${SELF_TYPE} fd use"
    MP "allow domain ${SELF_TYPE} unix_stream_socket { connectto read write getattr getopt }"
    MP "allow domain ${SELF_TYPE} tcp_socket { read write getattr getopt }"
else
    echo "[!] Could not determine self SELinux type, skipping \$self rules"
fi

# ── 4. zygote 规则 ────────────────────────────────────────
MP "allow zygote zygote capability sys_ptrace"

# ── 5. 可选规则（类型不存在时 magiskpolicy 自行报错忽略）──
# 用子 shell + 重定向静默错误，不影响主流程
MP "allow app_zygote zygote_exec file read"       2>/dev/null || true
MP "allow system_server apex_art_data_file file execute" 2>/dev/null || true

# ── 6. 写入哨兵文件 ───────────────────────────────────────
touch "$SENTINEL" && chmod 644 "$SENTINEL"
echo "[+] Done. Sentinel written: $SENTINEL"