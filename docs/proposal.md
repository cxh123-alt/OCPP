# 项目申报书（初稿）

## 项目名称

OCPP 1.6J / 2.0.1 充电桩协议栈（MoonBit 实现）

## 仓库

https://github.com/cxh123-alt/OCPP

## 一句话说明

用 MoonBit 实现充电桩与充电运营后台之间的 OCPP 协议：JSON-RPC 信封、两版报文、桩侧与后台侧状态机，并附可运行的演示。

## 现有基础

本仓库已具备：

- JSON-RPC 2.0 信封：CALL / CALLRESULT / CALLERROR，含 10 个标准错误码与逐类型 arity 校验
- 1.6J：BootNotification、Heartbeat、Authorize、StartTransaction、StopTransaction、MeterValues、StatusNotification、RemoteStartTransaction、RemoteStopTransaction、ChangeConfiguration、GetConfiguration、RemoteTrigger、Reset
- 2.0.1：BootNotification、Heartbeat、Authorize、TransactionEvent、MeterValues、StatusNotification、RequestStartTransaction、RequestStopTransaction、GetVariables、SetVariables、Reset
- 充电桩状态机：连接器状态、电表累计、交易号（1.6 整数 / 2.0.1 字符串）
- 后台：单端点同时服务两版协议，按报文形状判别版本
- 可运行 CLI：`demo`、`decode`、`soak`、`dump`，以及 README 中的 GIF 演示
- 49 个测试；GitHub Actions 跑 `moon check` 与 `moon test`

## 本期计划

1. 报文补齐：1.6 的 `GetDiagnostics`、`DiagnosticsStatusNotification`、`FirmwareStatusNotification`；2.0.1 的 `SetChargingProfile`、`GetCompositeSchedule`
2. 传输示例：提供 WebSocket 适配示例（子协议 `ocpp1.6` / `ocpp2.0.1`），把 `transport` 的 `Mailbox` 接到真实连接
3. 一致性：为动作表补双向 round-trip 测试与畸形报文用例
4. 文档：每个动作的字段表、错误码对照、接入步骤

## 技术路线

- 分层：`wire → schema → v16/v2 → station/central`，依赖单向，两侧状态机互不引用
- sans-IO：核心只产出/消费字符串，传输由调用方注入，便于测试与多目标编译
- 版本判别：后台按判别字段（`chargingStation` / `chargePointModel` 等）识别协议版本，混合车队共用一个端点
- 时钟注入：时间戳可复现，不读系统时间

## 预期功能

- 充电桩侧：完整核心档位（启动、鉴权、交易、计量、状态、配置）
- 后台侧：会话登记、鉴权裁决、交易与计量计数、命令下发
- 工具：报文解码、会话导出、脚本化演示

## 测试与文档

- `moon check --deny-warn`、`moon test --deny-warn`、`moon fmt --check` 本地全过
- 测试覆盖：信封合法性、两版字段名、完整交易流程、未知动作处理
- 文档：README（快速开始）、`docs/architecture.md`、`docs/protocol-coverage.md`、`docs/transport.md`

## 上游与合规

- 无第三方代码，依据 OCPP 1.6 / 2.0.1 公开规范自行实现
- 许可证：MIT
- 未使用任何闭源或未授权代码

## 里程碑

| 周 | 内容 |
|---|---|
| 第 1 周 | 报文补齐（1.6 诊断与固件状态） |
| 第 2 周 | 2.0.1 充电曲线相关动作 |
| 第 3 周 | WebSocket 适配示例 + 接入文档 |
| 第 4 周 | 一致性用例、文档收尾、发布 |
