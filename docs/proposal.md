# OCPP 项目申报书（仓库版）

**项目定位：** 纯 MoonBit 的 OCPP 1.6J / 2.0.1 充电桩协议栈
**GitHub：** https://github.com/cxh123-alt/OCPP　　**开源协议：** MIT
**说明：** 本文件是提交版申报书的仓库副本，已去掉个人联系方式；提交时以正式申报表为准。

## 1. 生态定位：一块可复用的充电协议底座

充电桩与运营后台之间的每一句话都由 OCPP 规定：一条 WebSocket 上跑 JSON-RPC 2.0，报文用位置数组承载，1.6J 与 2.0.1 两个版本的字段名、嵌套方式和交易模型都不相同。它不是某个厂商的私有协议，而是这个行业事实上的通用语言——桩要接入任何一家平台，平台要接入任何一批桩，都得先实现它。

在 MoonBit 生态里，这块底座今天是缺的：`moon search ocpp` 全库 0 命中，官方与社区都没有实现。开发者要拿到它，只有两条路：绑定 Node.js 或 JVM 上的现成库（引入运行时依赖，放弃 MoonBit 零依赖、可编译到 wasm 的组合性，也锁死了桩端固件与 Web 端部署）；或者自己从头写一遍。OCPP 补的正是这层纯 MoonBit 底座——交付的是**一个可直接以源码依赖引入的库**，不是某个运营平台；`cli` 下的 demo 只是这套 API 的可执行验收示例。当前版本尚未发布到 mooncakes，接入方式为仓库源码或路径依赖。

协议库的价值不在「支持了多少条报文」，而在「每条报文是否字节正确、两版是否分得清、错误是否可被捕获」。OCPP 选择先做深：把充电桩上线到完成一次充电的主链路做扎实，每一层都能用真实报文钉死，再谈扩展。

## 2. 交付范围：以协议库为主体，demo 仅为验收示例

v0.1 交付的主体是一套单向分层的库，8 个包，覆盖 OCPP 核心档位：

- **信封** `wire`：CALL / CALLRESULT / CALLERROR 三种数组形态，按消息类型校验 arity，拒绝非对象载荷，内置 10 个标准错误码；
- **共用层** `schema`：状态枚举与线上字符串、秒级 UTC 时钟、带字段名的 JSON 读写；
- **1.6J 报文** `v16`：16 个动作，含启动、鉴权、交易、计量、状态、配置、`RemoteTrigger`、诊断与固件状态；
- **2.0.1 报文** `v2`：11 个动作，含 `TransactionEvent` 三阶段、`GetVariables` / `SetVariables`；
- **桩侧** `station`：连接器状态、电表累计、交易号维护，可应答的下发命令就地应答，未支持动作返回标准 CALLERROR；
- **后台侧** `central`：单端点同时服务两版协议，按报文形状判别版本，登记会话并计数；
- **传输接缝** `transport`：方向信箱与 relay；
- **工具链** `cli`：`demo` / `decode` / `dump` / `soak`。

配套 53 项测试。本版不实现 WebSocket 传输本身、不做 Smart Charging 全量、不做证书与签名计量。

## 3. 应用场景

- 充电桩固件：可编译为 wasm-gc，无运行时依赖；native 目标需要系统 C 编译器；
- 运营平台：混合车队共用一个端点，不按连接配置版本；
- 边缘网关：`transport` 信箱留出协议转换与离线缓存的接缝；
- 协议测试与分析：`decode` / `dump` 可作抓包解释器；
- 教学与协议学习：两版报文对照实现。

## 4. 实现路径

两版分别建模，而不是一个结构体加版本标志位：1.6 的 `idTag` 是字符串，2.0.1 的 `idToken` 是对象；1.6 的交易是两条消息，2.0.1 是一串带 `seqNo` 的 `TransactionEvent`。

版本判别放在后台侧，按报文形状：`chargingStation` 对 `chargePointModel`，`idToken` 对 `idTag`，`connectorStatus` 对 `status`。判别字段缺失时按 1.6 处理，字段不合法时由读取层返回带字段名的 `SchemaError`。

核心是 sans-IO：只产出和消费字符串，不持有 socket，不读系统时间；时间由 `ClockTime` 注入。可验证性靠字面报文断言、双向 round-trip、方向表校验，外加 `sim` 跑完整会话。

## 5. 当前基础与验收

截至 2026 年 11 月 7 日：MoonBit 源码 4081 行（含测试），53 项测试通过，`moon check --deny-warn` 在本机工具链上干净，`moon build --target wasm` 通过，`moon run cli -- demo` 正常，18 次真实提交。native 目标需要系统 C 编译器，当前环境未安装，未作验证。GitHub Actions 在每次推送执行 `moon check` 与 `moon test`，当前为绿。

验收覆盖：信封 arity 与类型、两版字段名与嵌套、注册/鉴权/交易/计量/状态流程、配置读写、诊断与固件状态、未知动作 CALLERROR、方向表、时间戳、`meterValue` 嵌套、配置项 `readonly` 与 `unknownKey`。

**赛事依据：** MoonBit 2026 十一月黑客松｜[比赛章程](https://bxup9uklfcb.feishu.cn/wiki/KNrVwEVFziPHiGkQtwhc6w3gndd)
