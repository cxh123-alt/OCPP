# 架构

## 分层

```
cli  →  sim  →  station ─┐
          └──→  central ─┼─→  v16  →  schema  →  wire
                          └──────────────────────┘
```

- `wire` 只认识三种 JSON 数组，不认识充电。
- `schema` 提供两侧共用的枚举、时钟和 JSON 读取。
- `v16` 是 1.6J 的报文结构与动作表。
- `station` 和 `central` 互不依赖，`sim` 是唯一同时看到两者的地方。
- 2.0.1 的旧代码归档在 `archive/ocpp-2.0.1` 分支，不在 master 上。

## 版本由连接绑定

OCPP 在 WebSocket 握手的 `Sec-WebSocket-Protocol` 里协商版本。库把结果作为 `ProtocolVersion` 参数传入，后台和桩各自保存，**不从报文里推断**。

原因是形状并不可靠：`Heartbeat` 是 `{}`，`Reset` 是 `{"type": ...}`，`DataTransfer` 的字段也几乎相同，只看形状会把同一份报文解成错误的版本。当前只交付 1.6J。

```moonbit
central.handle(V16, text)    // 连接绑定 1.6J
```

后台向桩下发命令时用同一个绑定：

```moonbit
let call = central.command16(@v16.Reset({ kind: @schema.Soft }))
// 传输层写 call；桩用 V16 解码并回 CALLRESULT
```

## 状态

充电桩侧只有四个状态：`Available → Preparing → Charging → Finishing → Available`。交易号是整数，保存在 `transaction_16`，由 `transaction_label()` 展示。

桩侧还保存三类 1.6J 扩展状态：本地授权名单（`local_list` 与 `local_list_version`）、预约（`reservations`）、下发的充电曲线（`charging_profile`）。预约只做登记与取消，不做占用裁决；曲线只保存与返回，不做调度计算。

后台侧按桩序列号登记 `StationRecord`，累计启动次数、鉴权次数、计量次数和交易次数。它不做持久化：这是协议库，存储是调用方的事。

## 时钟

所有时间来自 `ClockTime`，由调用方注入，`advance(seconds)` 只做秒级推进。这样 demo 和测试的时间戳完全可复现，不依赖机器时间。

## 错误

- 信封错误：`WireError`（arity、类型、未知消息类型、坏 JSON）。
- 报文错误：`SchemaError`（缺字段、类型错、未知枚举值），错误信息带字段名。
- 未知动作：桩侧 `NotSupported`，后台侧 `NotImplemented`，都走标准 CALLERROR。

## 已知缺口

- 无 WebSocket 传输；库只产出/消费报文文本。
- 1.6 的 `StopTransaction.transactionData` 未实现。
- 未实现安全扩展（证书、签名计量）。
