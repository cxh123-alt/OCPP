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

## 版本由连接绑定

OCPP 在 WebSocket 握手的 `Sec-WebSocket-Protocol` 里协商版本（`ocpp1.6` / `ocpp2.0.1`）。库把这个结果作为 `ProtocolVersion` 参数传入，后台和桩各自保存，**不从报文里推断**。

原因是形状并不可靠：`Heartbeat` 两版都是 `{}`，`Reset` 都是 `{"type": ...}`，`DataTransfer` 的字段也几乎相同。只看形状会把同一份报文解成错误的版本。

```moonbit
central.handle(V16, text)    // 连接绑定 1.6J
central.handle(V201, text)   // 连接绑定的实验版本
```

后台向桩下发命令时用同一个绑定：

```moonbit
let call = central.command16(@v16.Reset({ kind: @schema.Soft }))
// 传输层写 call；桩用 V16 解码并回 CALLRESULT
```

2.0.1 的模型和代码保留在 `v2/`，但不在符合性目标内。


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
