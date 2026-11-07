# 架构

## 分层

```
cli  →  sim  →  station ─┐
          └──→  central ─┼─→  v16 / v2  →  schema  →  wire
                          └────────────────────────────┘
```

- `wire` 只认识三种 JSON 数组，不认识充电。
- `schema` 提供两侧共用的枚举、时钟和 JSON 读取。
- `v16` / `v2` 是两套独立报文，因为 1.6 和 2.0.1 的字段名、嵌套方式和交易模型都不一样。
- `station` 和 `central` 互不依赖，`sim` 是唯一同时看到两者的地方。

## 为什么版本要按报文判别

OCPP 的 1.6J 和 2.0.1 共用 `BootNotification`、`Authorize`、`MeterValues` 这些动作名，但报文形状不同。现场后台通常一个端口接所有桩，没有握手阶段告诉你对面是哪版。

所以 `central` 在动作名之外看判别字段：

| 动作 | 1.6J | 2.0.1 |
|---|---|---|
| BootNotification | `chargePointModel` | `chargingStation` |
| Authorize | `idTag` 字符串 | `idToken` 对象 |
| MeterValues | `connectorId` | `evseId` |
| StatusNotification | `status` + `errorCode` | `connectorStatus` |

判别失败时按 1.6 处理并返回 CALLERROR，而不是猜。

## 状态

充电桩侧只有四个状态：`Available → Preparing → Charging → Finishing → Available`。交易号在 1.6 是整数，在 2.0.1 是字符串，所以 `ChargePoint` 分别保存 `transaction_16` 和 `transaction_2`，由 `transaction_label()` 统一展示。

后台侧按桩序列号登记 `StationRecord`，累计启动次数、鉴权次数、计量次数和交易次数。它不做持久化，也不需要：这是协议库，存储是调用方的事。

## 时钟

所有时间来自 `ClockTime`，由调用方注入，`advance(seconds)` 只做秒级推进。这样 demo 和测试的时间戳完全可复现，不依赖机器时间。

## 错误

- 信封错误：`WireError`（arity、类型、未知消息类型、坏 JSON）。
- 报文错误：`SchemaError`（缺字段、类型错、未知枚举值），错误信息带字段名。
- 未知动作：桩侧 `NotSupported`，后台侧 `NotImplemented`，都走标准 CALLERROR。

## 已知缺口

- 无 WebSocket 传输；库只产出/消费报文文本。
- 2.0.1 的 `TransactionEvent` 只实现 Started/Updated/Ended 的必需字段，`meterValue` 为可选数组。
- 1.6 的 `StopTransaction.transactionData` 未实现。
- 未实现安全扩展（证书、签名计量）。
