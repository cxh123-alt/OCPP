# 六功能块语义与宿主职责

OCPP 的 28 条消息只规定报文形状，不规定业务语义。本文说明每个功能块在库内的语义边界，以及必须由宿主（桩固件或运营平台）承担的部分。符合性目标是「1.6J 28 条消息 + 本文列出的语义」，不是「完整协议行为」。

## Core

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 启动与心跳 | 编码 BootNotification/Heartbeat，记录启动次数 | 设备序列号、固件版本、心跳间隔策略 |
| 鉴权 | 传输 idTag，解析 idTagInfo | 真正查黑白名单、下发授权结果 |
| 交易 | 维护 transactionId、meterStart/meterStop、状态迁移 | 计量表读数、交易持久化 |
| 状态通知 | 生成 StatusNotification，记录连接器状态 | 连接器硬件状态采集 |
| 配置 | ChangeConfiguration/GetConfiguration 的读写与回执 | 配置项实际生效 |

## Firmware Management

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 诊断 | 编码 GetDiagnostics/DiagnosticsStatusNotification | 生成诊断文件、上传 |
| 固件 | 编码 UpdateFirmware/FirmwareStatusNotification，保存下载地址 | 下载、校验、刷写、回滚 |

## Local Auth List

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 名单同步 | 保存 listVersion、Full/Differential 合并、回执 | 名单持久化与鉴权决策 |
| 版本查询 | 返回当前 listVersion | — |

## Reservation

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 预约登记 | 每个连接器最多一条预约；连接器非 Available 或已有预约时返回 `Occupied` | 到点释放、插枪时核对 idTag |
| 取消 | 按 reservationId 删除；不存在时返回 `Rejected` | 通知用户、释放资源 |

**输入输出案例：连接器已占用**

```json
[2,"r1","ReserveNow",{"connectorId":1,"expiryDate":"2026-11-07T07:00:00Z","idTag":"TAG-9","reservationId":9}]
[3,"r1",{"status":"Occupied"}]
```

桩侧逻辑：连接器处于 `Charging`/`Preparing`/`Finishing`，或该连接器已有预约 → `Occupied`，不写入预约表。

当前桩模型只建模一个连接器（`connectorId = 1`）；其他 `connectorId` 共用同一连接器状态，多连接器桩需要宿主在接入层拆分。

## Remote Trigger

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 触发 | 编码 RemoteTrigger，回执 Accepted | 执行实际动作（如上报 MeterValues） |

## Smart Charging

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 曲线存储 | 按连接器保存多条 ChargingProfile | 曲线持久化 |
| 曲线组合 | 同一连接器只考虑 `validFrom`/`validTo` 覆盖当前时刻的曲线，取其中 **stackLevel 最高** 者；高层到期后自动回落到仍有效的低层 | 把限值应用到充电机、处理时段插值与三相 |
| 清理 | 按 id/connector/purpose/stackLevel 过滤删除 | 重新计算实际输出 |

**输入输出案例：多曲线约束**

```json
[2,"c1","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":1,"stackLevel":0,"chargingProfilePurpose":"TxDefaultProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0}]}}}]
[3,"c1",{"status":"Accepted"}]
[2,"c2","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":2,"stackLevel":1,"chargingProfilePurpose":"TxDefaultProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":10.0}]}}}]
[3,"c2",{"status":"Accepted"}]
[2,"c3","GetCompositeSchedule",{"connectorId":1,"duration":3600}]
[3,"c3",{"status":"Accepted","schedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":10.0}]}}]
```

桩侧逻辑：两条曲线同一连接器，stackLevel 1 覆盖 stackLevel 0，composite 返回 10.0 A。`ClearChargingProfile` 可按 `connectorId` 或 `chargingProfileId` 删除，删除后 composite 为空。

**输入输出案例：高层到期回落**

高层曲线带 `validTo`，低层曲线长期有效：

```json
[2,"e1","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":1,"stackLevel":0,"chargingProfilePurpose":"TxDefaultProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0}]}}}]
[3,"e1",{"status":"Accepted"}]
[2,"e2","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":3,"stackLevel":1,"chargingProfilePurpose":"TxDefaultProfile","chargingProfileKind":"Absolute","validFrom":"2026-11-07T04:00:00Z","validTo":"2026-11-07T06:00:00Z","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":10.0}]}}}]
[3,"e2",{"status":"Accepted"}]
```

| 当前时刻 | composite | 原因 |
|---|---|---|
| 05:00 | limit 10.0 A | 高层 stackLevel 1 在有效期内 |
| 07:00 | limit 16.0 A | 高层已过 `validTo`，回落到低层 stackLevel 0 |

## 明确不在库内的部分

- 不在库内计算实际充电功率、三相分配、时段插值与同层曲线合并；
- 不在库内做预约占用裁决（插枪时核对、超时释放）；
- 不在库内做名单持久化与真实鉴权；
- 不在库内做固件下载、校验与刷写。

这些由宿主实现；库只保证报文、状态与上述已声明的语义。
