# DSH Keep Alive

给 **DSH Go**（Android 手机 App）用的 root 后台保活模块：通过 phantom、Doze、省电策略与 watchdog 维持 App 和 `libproot` 引擎存活，被清理后自动拉起。

> 包名：`io.github.ccch1mneyyy.dsh_app`  
> 适用：SukiSU / KernelSU / Magisk（模块格式通用），需要 root  
> 先说清楚：**没有任何模块能保证 App 绝对不被系统杀死**。强行停止、清理全部、LMK 内存回收都能杀；这个模块做的是“尽量保活 + 被清后尽快拉回来”。

## v1.3 新增：WebUI 管理界面

安装后，在 SukiSU / KernelSU / Magisk 的模块页点 **打开**，就能进入管理界面，不用再手敲命令。

界面里可以：

- 开关 **关闭 phantom 进程限制**
- 开关 **加入 Doze 白名单**
- 开关 **省电无限制**（AppOps + active bucket + 后台放行）
- 开关 **SwipeUpClean 保护**（系统没有公开白名单，靠“被清后自动拉起”）
- 开关 **自动检查**，并自定义 **30–3600 秒** 检查间隔
- 一键 **锁定**：Doze + 省电无限制 + phantom + 自动拉起
- **应用全部**、**立即检查**、**启动 DSH**、**打开系统应用设置**
- **显示高级设置**：关闭后只保留常用开关（简洁模式），再打开恢复完整设置
- 查看最近日志

> HyperOS 的“最近任务锁定”由桌面/系统管理，模块无法用命令替你点那个锁；这里做的是 AppOps + Doze + active bucket + 被清后自动拉起。想彻底防划卡，仍需在最近任务里手动上锁。

## 文件

```
dsh_keepalive/
├── module.prop
├── service.sh          # 开机 late_start：应用设置 + 启动 watchdog
├── control.sh          # WebUI 调用的控制脚本
├── config.conf         # 开关与间隔（WebUI 会改写）
├── uninstall.sh
└── webroot/
    ├── index.html
    ├── style.css
    └── app.js
```

配置在 `/data/adb/modules/dsh_keepalive/config.conf`：

```ini
PHANTOM=1
DOZE=1
BATTERY=1
SWIPE=1
AUTOCHECK=1
INTERVAL=300
SHOW_ADVANCED=1
```

## 安装

1. 下载 Release 里的 `dsh-keepalive-<version>.zip`
2. SukiSU / KernelSU / Magisk → 模块 → 从本地安装 → 选 zip
3. 重启手机
4. 打开模块页 → **打开** → 进入 WebUI

不想重启的话，装完手动跑一次：

```sh
su -c 'sh /data/adb/modules/dsh_keepalive/service.sh'
```

## 验证

```sh
su -c 'cat /data/adb/modules/dsh_keepalive/watchdog.pid'
su -c 'ps -A -o PID,PPID,ETIME,ARGS | grep -E "dsh_app|libproot"'
cat /sdcard/Download/DSH-Go/keepalive.log
```

正常时：watchdog 的 PPID 是 1；能同时看到 `dsh_app` 与 `libproot`；日志有 `service.sh start`、`watchdog started`。

WebUI 里点“立即检查”也会输出 `app=1 engine=1 watchdog=1`。

## 日志

`/sdcard/Download/DSH-Go/keepalive.log`

普通用户读不了就用：

```sh
su -c 'cat /sdcard/Download/DSH-Go/keepalive.log'
```

## 卸载

模块页直接卸载，或：

```sh
su -c 'rm -rf /data/adb/modules/dsh_keepalive'
```

卸载脚本会先杀掉 watchdog。

## 限制

- **挡不住**系统设置里的“强行停止”；被 force-stop 后 watchdog 可能拉不起来，需要手动打开一次
- 挡不住 ROM 禁止后台启动；需要同时在系统设置里给 DSH 开自启动/后台运行
- 你主动把 App 从最近任务划掉，watchdog 也会把它拉回来；不想要就关掉“自动检查”
- Android 没有公开的“SwipeUpClean 白名单”API；本模块用 AppOps + Doze + active bucket + 自动拉起做近似保护
- root 脚本有风险，先看代码再装；不同 ROM 行为可能不同

## 创作说明

本模块由 **DeepSeek 辅助创作**：需求、系统行为确认、脚本与 WebUI 初稿在 DeepSeek 协助下完成，作者 **bailongis** 负责实际测试、调整与发布。
