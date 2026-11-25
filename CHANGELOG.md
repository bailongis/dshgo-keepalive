# Changelog

## v1.4.4
- 修复 tawcroot 下把 watchdog 自身误判为引擎的问题：优先检查 3080 端口，再回退进程名。
- 修复 strategyMatch 在 backend=auto 时误报“策略不匹配”。
- service.sh 启动时清理所有旧 watchdog，不再只依赖可能过期的 pid 文件。
- 关闭“被清理后自动拉起”时，同时恢复 START_FOREGROUND 与 set-inactive。
- module.prop 作者改回 bailongis。
- 增加 `update.json` 与 `updateJson`，KernelSU 管理器可直接检查更新。
- 升级包不再覆盖 `config.conf`；`customize.sh` 会在安装时停掉旧 watchdog。

## v1.4

- WebUI 新增运行策略：自动 / PRoot / tawcroot
- 自动模式同时识别 `libproot.so` 与 `libtawcroot.so`
- watchdog 与 control.sh 共用策略配置，按所选后端判断引擎是否掉线
- WebUI 改为白色主题，去掉作者名与无关装饰，只保留功能
- `config.conf` 新增 `STRATEGY=auto`

## v1.3

- 新增 WebUI 管理界面（`webroot/`），模块页点“打开”即可操作
- 新增开关：phantom 限制、Doze 白名单、省电无限制、SwipeUpClean 保护、自动检查
- 自动检查间隔可自定义（30–3600 秒），watchdog 每次循环读取配置
- 新增“一键锁定”：Doze + 省电无限制 + phantom + 自动拉起
- 新增“显示高级设置”开关，简洁/完整两种界面
- 新增“立即检查”“启动 DSH”“系统应用设置”“查看日志”按钮
- 作者改为 bailongis
- 配置集中到 `config.conf`，WebUI 与 service.sh 共用

## v1.2

- watchdog 使用 setsid 脱离终端
- 启动 180 秒后检查 `libproot` 引擎，缺失则 force-stop 后重启 App
- 修复日志权限

## v1.1

- 首次加入 Doze 白名单、后台 appops、active bucket
- 加入基础 watchdog

## v1.0

- 初始版本
