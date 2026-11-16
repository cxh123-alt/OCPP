# 动作覆盖

本仓库交付 OCPP 1.6J 全量 28 条消息，逐条状态见 [conformance.md](conformance.md)。这里是按功能块的速查。

| 功能块 | 动作 | 方向 |
|---|---|---|
| Core | BootNotification、Heartbeat、Authorize、MeterValues、StatusNotification、StartTransaction、StopTransaction | 桩 → 后台 |
| Core | RemoteStartTransaction、RemoteStopTransaction、Reset、ChangeConfiguration、GetConfiguration、ChangeAvailability、ClearCache、UnlockConnector | 后台 → 桩 |
| Core | DataTransfer | 双向 |
| Firmware Management | DiagnosticsStatusNotification、FirmwareStatusNotification | 桩 → 后台 |
| Firmware Management | GetDiagnostics、UpdateFirmware | 后台 → 桩 |
| Local Auth List | GetLocalListVersion、SendLocalList | 后台 → 桩 |
| Reservation | ReserveNow、CancelReservation | 后台 → 桩 |
| Remote Trigger | RemoteTrigger | 后台 → 桩 |
| Smart Charging | SetChargingProfile、ClearChargingProfile、GetCompositeSchedule | 后台 → 桩 |

未列入的动作由桩侧回 `NotSupported`、后台侧回 `NotImplemented`，都是合法的 CALLERROR。

2.0.1 的旧覆盖表跟随代码一起移到了 `archive/ocpp-2.0.1` 分支。
