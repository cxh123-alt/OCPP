# OCPP 项目申报书（仓库版）

**许可证：** MIT
**说明：** 本文件是提交版申报书的仓库副本，已去掉个人联系方式；提交以正式申报表为准。

## 基本信息

- 项目名称：OCPP 1.6J Core 充电协议栈（MoonBit 实现，含 2.0.1 会话子集）
- GitHub 仓库链接：https://github.com/cxh123-alt/OCPP
- 项目方向：MoonBit 充电协议库 / 桩与后台通信基础设施
- 是否为移植项目：否，原创项目
- 符合性目标：OCPP 1.6J Core 档位 16/16；2.0.1 仅覆盖会话子集，不作符合性声明

## 项目简介

OCPP 用 MoonBit 实现充电桩与运营后台之间的协议栈：JSON-RPC 信封、1.6J 与 2.0.1 两版报文、桩侧与后台侧状态机、传输接缝。项目面向桩固件、运营平台、边缘网关与协议测试工具，提供可直接组合的库，而不是绑定某个平台的 demo。当前版本 4423 行（含测试），61 项测试通过，CI 每次推送执行 `moon check` 与 `moon test`。

## 核心功能范围

- 提供 JSON-RPC 的 CALL / CALLRESULT / CALLERROR 三种数组形态，按消息类型校验 arity，内置 10 个标准错误码；
- 提供注册、鉴权、连接器、交易状态枚举与线上字符串，秒级 UTC 时钟，带字段名的 JSON 读写；
- 提供 OCPP 1.6J Core 档位全部 16 个动作，每个动作都有请求、响应与往返测试；
- 提供 1.6J 扩展动作：RemoteTrigger、GetDiagnostics、DiagnosticsStatusNotification、FirmwareStatusNotification，单列为扩展档位，不计入 Core；
- 提供 2.0.1 会话子集 11 个动作：BootNotification、Heartbeat、Authorize、TransactionEvent、MeterValues、StatusNotification、RequestStartTransaction、RequestStopTransaction、GetVariables、SetVariables、Reset；
- 提供桩侧状态机：连接器状态、电表累计、交易号维护，可应答的下发命令就地应答，未支持动作返回标准 CALLERROR；
- 提供后台侧状态机：单端点服务两版协议，按报文形状判别版本，登记会话与交易计数；
- 提供传输接缝：方向信箱与 `Correlator`，保存未完成调用、按 `callId` 配对、清理超时；
- 提供 CLI：`demo` 打印两版各一轮完整充电，`decode` 解释单帧，`dump` 导出会话，`soak` 批量压测；
- 提供 61 个 MoonBit 测试与 GitHub Actions，覆盖字面字段名、双向往返、方向表与关联超时；
- 提供 `docs/conformance.md` 动作矩阵与 `docs/correlation.md` 关联/交易说明。

## 请求响应关联与交易推进

- `callId` 由发送方的连接持有者生成，同一条连接内唯一；`wire` 只负责编解码，不保存已发出的调用；
- `transport` 的 `Correlator` 保存未完成调用（`id`、动作、绝对截止时间），响应到达时按 `callId` 配对；未知、重复、过期 id 不进入业务分发；
- 超时由调用方注入时钟，`expired` 只返回过期 id 并清理；配对失败不伪造结果，业务侧返回标准 CALLERROR；
- 1.6J 交易由桩侧推进：`StartTransaction` 取得 `transactionId`，`MeterValues` 携带同一交易号，`StopTransaction` 结束，`StatusNotification` 更新连接器状态；后台侧分配交易号并按交易号归档；
- 2.0.1 交易由 `TransactionEvent` 三阶段推进：`Started` → `Updated` → `Ended`，`seqNo` 在同一交易内严格递增，后台按交易号与序号校验。

## 符合性与边界

- 1.6J Core 的 16 个动作全部实现，矩阵见 `docs/conformance.md`；扩展档位单独列出，不混入 Core 计数；
- 1.6J Core 本身不包含证书管理，证书与签名计量属于 1.6 Security 扩展，本版未实现，因此 Core 声明不涉及证书；
- 2.0.1 只覆盖会话主链路，不包含设备型号管理、证书管理、安全事件、Smart Charging，**不声称 2.0.1 符合性**；
- 传输层不实现 WebSocket 与 TLS，库只处理字符串；native 目标需要系统 C 编译器，当前环境未安装；
- 「复用」指同一套协议层可用于桩、后台、网关与测试工具，**不声称**中断的充电会话在重连后自动恢复；断线重连与离线续传由调用方在 `Correlator` 之上实现。

## 原创与参考说明

- 本项目为原创项目，不是移植项目，无原项目名称、来源链接与许可证需要声明；
- 报文与字段依据 OCPP 1.6J / 2.0.1 公开规范核对，代码为自写，不包含第三方代码；
- 本项目许可证：MIT；
- 与常见实现相比的设计取舍：
  - 1.6J 与 2.0.1 分别建模，不用一个结构体加版本标志位；
  - 版本判别放在后台侧，按报文形状判断，不依赖连接配置；
  - 核心为 sans-IO，只产出与消费字符串，时间由调用方注入；
  - 以动作矩阵和测试固定符合性范围，不在文档里使用「全协议」这类不可验证的表述。
