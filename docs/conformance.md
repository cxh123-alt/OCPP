# 符合性范围与动作矩阵

本项目的符合性目标是 **OCPP 1.6J 全量消息集**：Core、Firmware Management、Local Auth List Management、Reservation、Remote Trigger、Smart Charging 六个功能块，共 28 条请求/响应。

2.0.1 的代码保留在 `v2/` 作为实验，**不在符合性目标内**，也不参与验收。

## 1.6J 全量矩阵

### Core（16）

| 动作 | 方向 | 状态 |
|---|---|---|
| Authorize | CP → CS | 已实现 |
| BootNotification | CP → CS | 已实现 |
| ChangeAvailability | CS → CP | 已实现 |
| ChangeConfiguration | CS → CP | 已实现 |
| ClearCache | CS → CP | 已实现 |
| DataTransfer | 双向 | 已实现 |
| GetConfiguration | CS → CP | 已实现 |
| Heartbeat | CP → CS | 已实现 |
| MeterValues | CP → CS | 已实现 |
| RemoteStartTransaction | CS → CP | 已实现 |
| RemoteStopTransaction | CS → CP | 已实现 |
| Reset | CS → CP | 已实现 |
| StartTransaction | CP → CS | 已实现 |
| StatusNotification | CP → CS | 已实现 |
| StopTransaction | CP → CS | 已实现 |
| UnlockConnector | CS → CP | 已实现 |

### Firmware Management（4）

| 动作 | 方向 | 状态 |
|---|---|---|
| GetDiagnostics | CS → CP | 已实现 |
| DiagnosticsStatusNotification | CP → CS | 已实现 |
| FirmwareStatusNotification | CP → CS | 已实现 |
| UpdateFirmware | CS → CP | 已实现 |

### Local Auth List Management（2）

| 动作 | 方向 | 状态 |
|---|---|---|
| GetLocalListVersion | CS → CP | 已实现 |
| SendLocalList | CS → CP | 已实现 |

### Reservation（2）

| 动作 | 方向 | 状态 |
|---|---|---|
| ReserveNow | CS → CP | 已实现 |
| CancelReservation | CS → CP | 已实现 |

### Remote Trigger（1）

| 动作 | 方向 | 状态 |
|---|---|---|
| RemoteTrigger | CS → CP | 已实现 |

### Smart Charging（3）

| 动作 | 方向 | 状态 |
|---|---|---|
| SetChargingProfile | CS → CP | 已实现 |
| ClearChargingProfile | CS → CP | 已实现 |
| GetCompositeSchedule | CS → CP | 已实现 |

合计 16 + 4 + 2 + 2 + 1 + 3 = **28 / 28**。

## 版本识别

协议版本是**连接属性**，不是报文属性。OCPP 在 WebSocket 握手的 `Sec-WebSocket-Protocol` 里协商版本（`ocpp1.6` / `ocpp2.0.1`），库把协商结果作为参数传入：

```moonbit
central.handle(V16, text)    // 1.6J 连接
central.handle(V201, text)   // 2.0.1 连接（实验）
```

不使用报文形状做判别。`Heartbeat` 在两版里都是 `{}`，`Reset` 都是 `{"type": ...}`，形状相同的报文只能由连接绑定决定解码器。

## 下发命令流程（CS → CP）

1. 连接建立时绑定版本（例如 `V16`），双方各自保存；
2. 后台用 `Central::command16(request)` 构造 CALL：分配 `callId`，用该版本的 action 表编码；
3. 传输层把字符串写给桩；
4. 桩用同一绑定解码，`Session` 生成 `CALLRESULT` 或 `CALLERROR`，带回同一 `callId`；
5. 后台用 `Correlator` 按 `callId` 配对，超时或未知 id 不进入业务分发。

```moonbit
let call = central.command16(@v16.Reset({ kind: @schema.Soft }))
// transport.write(call)
```

## 证书与安全

- 1.6J 全量消息集不包含证书管理；1.6 Security 扩展（证书、签名计量）不在本目标内；
- 2.0.1 的证书管理与安全事件不属于实验代码范围；
- 传输层不实现 TLS 与证书校验，库只处理字符串。

## 验证

```bash
moon test --deny-warn
```

`v16/v16_test.mbt` 覆盖 28 条消息的字段与往返，`central/central_test.mbt` 覆盖版本绑定与下发命令，`transport/transport_test.mbt` 覆盖关联与超时。
