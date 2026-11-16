# Changelog

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
