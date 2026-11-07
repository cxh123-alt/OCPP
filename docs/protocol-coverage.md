# 动作覆盖

| 动作 | 方向 | 1.6J | 2.0.1 | 实现文件 |
|---|---|---|---|---|
| BootNotification | 桩 → 后台 | 是 | 是 | `v16/payloads.mbt`、`v2/payloads.mbt` |
| Heartbeat | 桩 → 后台 | 是 | 是 | 同上 |
| Authorize | 桩 → 后台 | 是 | 是 | 同上 |
| StartTransaction | 桩 → 后台 | 是 | — | `v16/payloads.mbt` |
| StopTransaction | 桩 → 后台 | 是 | — | `v16/payloads.mbt` |
| TransactionEvent | 桩 → 后台 | — | 是 | `v2/payloads.mbt` |
| MeterValues | 桩 → 后台 | 是 | 是 | 两者 |
| StatusNotification | 桩 → 后台 | 是 | 是 | 两者 |
| RemoteStartTransaction | 后台 → 桩 | 是 | — | `station/session.mbt` |
| RemoteStopTransaction | 后台 → 桩 | 是 | — | `station/session.mbt` |
| RequestStartTransaction | 后台 → 桩 | — | 是 | `station/session.mbt` |
| RequestStopTransaction | 后台 → 桩 | — | 是 | `station/session.mbt` |
| Reset | 后台 → 桩 | 是 | 是 | 两者 |
| ChangeConfiguration | 后台 → 桩 | 是 | — | v16 + station |
| GetConfiguration | 后台 → 桩 | 是 | — | v16 + station |
| RemoteTrigger | 后台 → 桩 | 是 | — | v16 + station |
| GetVariables | 后台 → 桩 | — | 是 | v2 + station |
| SetVariables | 后台 → 桩 | — | 是 | v2 + station |
| GetDiagnostics | 后台 → 桩 | 是 | — | v16 + station |
| DiagnosticsStatusNotification | 桩 → 后台 | 是 | — | v16 + central |
| FirmwareStatusNotification | 桩 → 后台 | 是 | — | v16 + central |

## 未实现

**1.6J**：ReserveNow / CancelReservation、UnlockConnector、ChangeAvailability、SendLocalList、DataTransfer，以及 Smart Charging 的全部动作。

**2.0.1**：Security 事件、CertificateSigned、SetChargingProfile、GetCompositeSchedule、UpdateFirmware、PublishFirmware、ReserveNow、UnlockConnector、DataTransfer、DisplayMessage。

## 已知简化

- 2.0.1 的 `TransactionEvent` 只编码必需字段，`meterValue` 为可选数组，`triggerReason` 用字符串。
- 2.0.1 的 `StatusNotification` 不区分 `connectorId` 为 0 的整桩状态语义。
- 1.6 的 `StopTransaction` 不带 `transactionData`。
