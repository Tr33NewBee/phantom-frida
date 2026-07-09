# Frida开发记录
通过自定义的frida来绕过大部分的检测,现在记录下使用时的潜在问题

## Failed to spawn: need Gadget to attach on jailed Android;
这个问题解决办法就是
```
/data/local/tmo/fs -l 0.0.0.0:12345
adb forward tcp:12345 tcp:12345
```
使用即可正常

## timeout
这个问题可能是因为`selinux`导致的,因为在`android 16 pixel 6`上注入时提示错误
```
libsepol.avtab_read: table is empty
Unable to load SELinux policy from the kernel: unsupported policy database format
```
这里虽然使用了frida-sepolicy.sh来处理,但是不是很好用,所以最直接、最不绕弯子的方式
```
adb shell su -c "setenforce 0"
```
再次执行注入即可正常.