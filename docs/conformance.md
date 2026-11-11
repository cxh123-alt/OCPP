# 符合性范围与动作矩阵

本文说明仓库对 OCPP 各版本的符合性目标，以及哪些动作计入「Core 档位」、哪些属于扩展档位。

## 目标档位

- **1.6J Core：完整覆盖，作为本项目的符合性目标。**
- 1.6J 的 Remote Trigger 与 Firmware Management 动作单独实现，**不计入 Core**，在矩阵中列为扩展。
- 2.0.1：只覆盖充电会话主链路的子集，**不声称 2.0.1 符合性**，矩阵中单列。

## 1.6J Core 动作矩阵

Core 档位共 16 个动作，仓库全部实现，且都有往返测试。

| 动作 | 方向 | 请求 | 响应 | 状态 |
|---|---|---|---|---|
| Authorize | CP → CS | `idTag` | `idTagInfo.status` | 已实现 |
| BootNotification | CP → CS | 型号/厂商/序列号 | `status`、`currentTime`、`interval` | 已实现 |
| ChangeAvailability | CS → CP | `connectorId`、`type` | `status` | 已实现 |
| ChangeConfiguration | CS → CP | `key`、`value` | `status` | 已实现 |
| ClearCache | CS → CP | 空对象 | `status` | 已实现 |
| DataTransfer | 双向 | `vendorId`、可选 `messageId`/`data` | `status`、可选 `data` | 已实现 |
| GetConfiguration | CS → CP | 可选 `key` 列表 | `configurationKey`、`unknownKey` | 已实现 |
| Heartbeat | CP → CS | 空对象 | `currentTime` | 已实现 |
| MeterValues | CP → CS | `connectorId`、`transactionId`、`meterValue` | 空对象 | 已实现 |
| RemoteStartTransaction | CS → CP | `idTag`、可选 `connectorId` | `status` | 已实现 |
| RemoteStopTransaction | CS → CP | `transactionId` | `status` | 已实现 |
| Reset | CS → CP | `type` | `status` | 已实现 |
| StartTransaction | CP → CS | `connectorId`、`idTag`、`meterStart`、`timestamp` | `transactionId`、`idTagInfo` | 已实现 |
| StatusNotification | CP → CS | `connectorId`、`errorCode`、`status` | 空对象 | 已实现 |
| StopTransaction | CP → CS | `transactionId`、`meterStop`、`timestamp` | `idTagInfo` | 已实现 |
| UnlockConnector | CS → CP | `connectorId` | `status` | 已实现 |

## 扩展档位（不计入 Core）

| 动作 | 所属档位 | 状态 |
|---|---|---|
| RemoteTrigger | Remote Trigger | 已实现 |
| GetDiagnostics / DiagnosticsStatusNotification | Firmware Management | 已实现 |
| FirmwareStatusNotification | Firmware Management | 已实现 |

## 2.0.1 子集（非符合性声明）

| 动作 | 状态 |
|---|---|
| BootNotification / Heartbeat / Authorize | 已实现 |
| TransactionEvent（Started / Updated / Ended） | 已实现 |
| MeterValues / StatusNotification | 已实现 |
| RequestStartTransaction / RequestStopTransaction | 已实现 |
| GetVariables / SetVariables / Reset | 已实现 |

未实现：设备型号管理、证书管理、安全事件、Smart Charging 调度、预约等 2.0.1 功能块。

## 证书与安全

- 1.6J Core 档位本身不包含证书管理；本项目未实现 1.6 Security 扩展，因此在 Core 声明中不涉及证书。
- 2.0.1 的证书管理与安全事件不在子集内，本项目不声称 2.0.1 安全符合性。
- 传输层不实现 TLS 与证书校验；WebSocket 本身也不在库内，库只处理字符串。

## 验证方式

```bash
moon test --deny-warn
```

`v16/v16_test.mbt` 覆盖 Core 动作的字面字段名与往返，`transport/transport_test.mbt` 覆盖请求响应关联与超时。
