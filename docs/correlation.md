# 请求响应关联与交易推进

本文说明两件容易在评审里被问到的职责：一次调用由谁配对响应，一段充电交易由谁推进状态。

## 请求与响应的关联

OCPP 的每条报文都是 JSON-RPC 的 CALL，带一个 `callId`；响应必须原样带回同一个 `callId`。库把这件事拆成三层：

| 层 | 负责 | 不负责 |
|---|---|---|
| `wire` | 编码/解码 `callId`，按数组长度校验 CALL / CALLRESULT / CALLERROR | 不保存已发出的调用 |
| `transport` | 方向信箱传递字符串；`Correlator` 保存未完成调用 | 不解析业务字段 |
| `station` / `central` | 收到请求后就地生成响应；收到响应时交给 `Correlator` 判定 | 不自己实现超时定时器 |

`Correlator` 的接口（`transport/pending.mbt`）：

```moonbit
let table = Correlator::new()
table.expect("17", "BootNotification", now, 30)   // 发出调用时登记
table.accept("17", now + 10)                       // 收到响应时配对，成功即删除
table.expired(now + 31)                            // 超时清理，返回过期的 callId
```

约定：

- `callId` 由发送方的连接持有者生成，同一条连接内唯一；
- 响应到达时用 `accept` 配对；未知 id、重复响应、已过期 id 一律不进入业务分发；
- 超时由调用方提供时钟，`expired` 只做判断和清理，不启动线程；
- 配对失败不会伪造结果，仍由业务侧返回标准 CALLERROR。

## 交易反馈的推进

### 1.6J

交易状态由桩侧推进，后台侧校验并分配交易号：

```
StartTransaction(connectorId, idTag, meterStart, timestamp)
  → CS 返回 transactionId
MeterValues(connectorId, transactionId, meterValue...)
  → 携带同一 transactionId，CS 按交易号归档
StopTransaction(transactionId, meterStop, timestamp)
  → CS 返回 idTagInfo，交易结束
StatusNotification(connectorId, status, errorCode)
  → 连接器状态回到 Available / Faulted
```

- 桩侧 `station` 保存 `transaction_id` 与电表累计，`begin_transaction` / `end_transaction` 是唯一入口；
- 后台侧 `central` 在 `StartTransaction` 时分配交易号并计数，在 `StopTransaction` 时按交易号归档；
- `MeterValues` 的 `transactionId` 来自桩侧保存的交易号，不从报文里猜。

### 2.0.1

`TransactionEvent` 用三阶段事件推进，`seqNo` 在同一交易内严格递增：

```
Started → Updated → ... → Ended
```

- 桩侧在 `begin_transaction` / `end_transaction` 时生成 Started / Ended，中间按采样周期发 Updated；
- 后台侧按 `transactionId` 与 `seqNo` 校验顺序，重复或倒退的 `seqNo` 不推进状态。

## 关于「复用」

仓库里的「复用」指**同一套协议层在不同场景复用**：同一个 `wire`、`v16`、`v2`、`station` 包可以用于桩固件、运营平台、边缘网关和测试工具。

**没有**声称「中断的充电会话在重连后自动恢复」。断线重连、离线队列、交易续传属于传输与业务层，当前不在库内；需要这些能力的调用方要在 `Correlator` 之上自行实现，文档不把它算作已实现能力。
