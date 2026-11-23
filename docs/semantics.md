# 六功能块语义与宿主职责

OCPP 的 28 条消息只规定报文形状，不规定业务语义。本文说明每个功能块在库内的语义边界，以及必须由宿主（桩固件或运营平台）承担的部分。符合性目标是「1.6J 六功能块协议语义 + 本文列出的边界」。

## Core

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 启动与心跳 | 编码 BootNotification/Heartbeat，记录启动次数 | 设备序列号、固件版本、心跳间隔策略 |
| 鉴权 | 传输 idTag，解析 idTagInfo，缓存通过的 tag | 真正查黑白名单、下发授权结果 |
| 交易 | 维护 transactionId、meterStart/meterStop、状态迁移 | 计量表读数、交易持久化 |
| 状态通知 | 生成 StatusNotification，记录连接器状态 | 连接器硬件状态采集 |
| 配置 | 保存 ChangeConfiguration 写入，GetConfiguration 按 key 返回并报告 unknownKey，ClearCache 清鉴权缓存 | 配置项对硬件的实际生效 |
| 可用性 | ChangeAvailability 设置 Available/Unavailable，UnlockConnector 释放连接器，Reset 清交易与连接器状态 | 连接器硬件动作 |

## Firmware Management

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 诊断 | 编码 GetDiagnostics/DiagnosticsStatusNotification | 生成诊断文件、上传 |
| 固件 | 编码 UpdateFirmware/FirmwareStatusNotification，保存 location/retrieveDate | 下载、校验、刷写、回滚 |

## Local Auth List

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 名单同步 | Full 替换名单；Differential 按 idTag 增删；版本不大于当前时回 `VersionMismatch` | 名单持久化与鉴权决策 |
| 版本查询 | 返回当前 listVersion | — |

## Reservation

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 预约登记 | 同一连接器最多一条预约；连接器 `Charging`/`Preparing`/`Finishing` → `Occupied`，`Unavailable` → `Unavailable`，`Faulted` → `Faulted`；`ReserveNow` 先清理过期预约 | 周期调用 `release_expired`、插枪时核对 idTag |
| 取消 | 按 reservationId 删除；不存在时返回 `Rejected` | 通知用户、释放资源 |

**输入输出案例：连接器已占用**

```json
[2,"r1","ReserveNow",{"connectorId":1,"expiryDate":"2026-11-07T07:00:00Z","idTag":"TAG-9","reservationId":9}]
[3,"r1",{"status":"Occupied"}]
```

当前桩模型只建模一个连接器（`connectorId = 1`）；其他 `connectorId` 共用同一连接器状态，多连接器桩需要宿主在接入层拆分。

## Remote Trigger

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 触发 | 编码 RemoteTrigger，回执 Accepted | 执行实际动作（如上报 MeterValues） |

## Smart Charging

曲线按 `chargingProfilePurpose` 分工，库内组合规则是：

1. **ChargePointMaxProfile**（连接器 0）是整桩上限；同一 purpose 内取 `stackLevel` 最高者。
2. **TxProfile** 覆盖 **TxDefaultProfile**：有 TxProfile 时忽略 TxDefaultProfile；两者各自取最高 `stackLevel`。
3. 每个时间段取 **min(整桩上限, 交易约束)**；只有一侧存在时取该侧。
4. 时间段按 `validFrom`/`validTo`、`chargingSchedule.duration`、`chargingSchedulePeriod.startPeriod` 切分；高层到期后该段回落到仍有效的低层。

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 曲线存储 | 按连接器与 purpose 保存多条 ChargingProfile | 曲线持久化 |
| 跨用途组合 | 按上面 1–3 计算每段的有效限值；A/W 混用时按桩电压换算（默认 230 V，可配置） | 把限值应用到充电机、三相分配与功率控制；按现场电压调用 set_voltage |
| 有效期与时段 | 按上面第 4 条切段并处理到期回落 | — |
| 清理 | 按 id/connector/purpose/stackLevel 过滤删除；没有匹配项时回 `Unknown` | 重新计算实际输出 |

**输入输出案例：整桩上限与交易曲线冲突**

整桩上限 16 A，交易曲线 32 A：

```json
[2,"p1","SetChargingProfile",{"connectorId":0,"csChargingProfiles":{"chargingProfileId":1,"stackLevel":0,"chargingProfilePurpose":"ChargePointMaxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0}]}}}]
[3,"p1",{"status":"Accepted"}]
[2,"p2","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":2,"stackLevel":0,"chargingProfilePurpose":"TxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":32.0}]}}}]
[3,"p2",{"status":"Accepted"}]
[2,"p3","GetCompositeSchedule",{"connectorId":1,"duration":3600}]
[3,"p3",{"status":"Accepted","schedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0}]}}]
```

| 整桩上限 | 交易曲线 | composite | 依据 |
|---|---|---|---|
| 16 A | 32 A | 16 A | 取 min |
| 16 A | 10 A | 10 A | 取 min |
| 16 A | 无 TxProfile，TxDefault 20 A | 16 A | TxDefault 作为交易约束，取 min |
| 16 A | TxProfile 12 A，TxDefault 20 A | 12 A | TxProfile 覆盖 TxDefault，再取 min |

**输入输出案例：高层到期回落**

高层带 `validTo`，低层长期有效；`duration = 7200`：

| 时间段 | composite | 原因 |
|---|---|---|
| 05:00–06:00 | 10.0 A | 高层 stackLevel 1 有效 |
| 06:00–07:00 | 16.0 A | 高层过期，回落到低层 |

## 明确不在库内的部分

- 不在库内计算实际充电功率、三相分配、同层曲线合并与持久化；
- 不在库内做插枪核对与预约超时释放；
- 不在库内做名单持久化与真实鉴权；
- 不在库内做固件下载、校验与刷写。

这些由宿主实现；库只保证报文、状态与上述已声明的语义。
