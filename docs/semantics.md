# 六功能块语义与宿主职责

OCPP 的 28 条消息只规定报文形状，不规定业务语义。本文说明每个功能块在库内的语义边界，以及必须由宿主（桩固件或运营平台）承担的部分。符合性目标是「1.6J 六功能块协议语义 + 本文列出的边界」。

## Core

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 启动与心跳 | 编码 BootNotification/Heartbeat，记录启动次数 | 设备序列号、固件版本、心跳间隔策略 |
| 鉴权 | 传输 idTag，解析 idTagInfo，缓存通过的 tag | 真正查黑白名单、下发授权结果 |
| 交易 | 维护 transactionId、meterStart/meterStop、状态迁移；RemoteStop 校验 transactionId 与当前交易；StopTransaction 携带 transactionData | 计量表读数、交易持久化 |
| 状态通知 | 生成 StatusNotification，记录连接器状态 | 连接器硬件状态采集 |
| 配置 | 保存 ChangeConfiguration 写入（只读键回 Rejected），GetConfiguration 按 key 返回并标记 readonly，ClearCache 清鉴权缓存 | 配置项对硬件的实际生效 |
| 可用性 | ChangeAvailability/UnlockConnector 校验 connectorId（0/1 有效，其他回 Rejected/NotSupported），Reset 清交易与连接器状态 | 连接器硬件动作 |
| 厂商透传 | 登记 vendorId 与 messageId；未登记 vendor 回 `UnknownVendorId`，未登记 message 回 `UnknownMessageId` | 执行具体厂商逻辑 |

## Firmware Management

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 诊断 | 编码 GetDiagnostics/DiagnosticsStatusNotification，维护诊断状态 | 生成诊断文件、上传 |
| 固件 | 保存 location/retrieveDate，维护固件状态并生成 FirmwareStatusNotification | 下载、校验、刷写、回滚 |

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
| 触发 | 编码 RemoteTrigger，记录 requestedMessage，回执 Accepted | 执行实际动作（如上报 MeterValues） |

## Smart Charging

曲线按 `chargingProfilePurpose` 分工：

1. **ChargePointMaxProfile**（连接器 0）是整桩上限；同一 purpose 内取 `stackLevel` 最高者。
2. **TxProfile** 覆盖 **TxDefaultProfile**：TxProfile 只在与当前 `transactionId` 一致（或未指定 transactionId）时参与；两者各自取最高 `stackLevel`。
3. 每个时间段先把限值统一换算成 **W**：A 值 × 电压 × `numberPhases`（缺省 3 相）；再取 **min(整桩上限, 交易约束)**，只有一侧时取该侧。
4. 输出保留所选曲线的 `chargingRateUnit` 与 `numberPhases`；`GetCompositeSchedule` 指定 `chargingRateUnit` 时按该单位输出；时间戳支持 `Z` 与 `±HH:MM` 偏移。
5. 时间段按 `validFrom`/`validTo`、`chargingSchedule.duration`、`chargingSchedulePeriod.startPeriod` 切分；高层到期后该段回落到仍有效的低层。
6. `chargingProfileKind = Recurring` 时按 `recurrencyKind`（Daily/Weekly）从 `startSchedule` 循环展开，`duration` 限制每个周期内的有效段。

| 语义 | 库负责 | 宿主负责 |
|---|---|---|
| 曲线存储 | 按连接器与 purpose 保存多条 ChargingProfile | 曲线持久化 |
| 跨用途组合 | 按上面 1–4 统一到 W 后取 min，输出单位/相数来自所选曲线 | 把限值应用到充电机；按现场电压调用 set_voltage |
| 有效期与时段 | 按第 5 条切段并处理到期回落 | — |
| 清理 | 按 id/connector/purpose/stackLevel 过滤删除；没有匹配项时回 `Unknown` | 重新计算实际输出 |

**输入输出案例：整桩上限与交易曲线冲突（相数参与换算）**

整桩上限 16 A 三相、交易曲线 32 A：

```json
[2,"p1","SetChargingProfile",{"connectorId":0,"csChargingProfiles":{"chargingProfileId":1,"stackLevel":0,"chargingProfilePurpose":"ChargePointMaxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0,"numberPhases":3}]}}}]
[3,"p1",{"status":"Accepted"}]
[2,"p2","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":2,"stackLevel":0,"chargingProfilePurpose":"TxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":32.0,"numberPhases":3}]}}}]
[3,"p2",{"status":"Accepted"}]
[2,"p3","GetCompositeSchedule",{"connectorId":1,"duration":3600}]
[3,"p3",{"status":"Accepted","schedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0,"numberPhases":3}]}}]
```

| 整桩上限（230 V/相） | 交易曲线 | composite | 依据 |
|---|---|---|---|
| 16 A × 3 相 = 11040 W | 32 A × 3 相 = 22080 W | 16 A × 3 相 | 取 min，整桩上限生效 |
| 16 A × 3 相 = 11040 W | 32 A × 1 相 = 7360 W | 32 A × 1 相 | 7360 W < 11040 W，交易曲线不超上限 |
| 16 A × 3 相 = 11040 W | 10 A × 3 相 = 6900 W | 10 A × 3 相 | 交易曲线更低 |
| 16 A × 3 相 | 无 TxProfile，TxDefault 20 A × 3 相 | 16 A × 3 相 | TxDefault 作为交易约束，取 min |

**输入输出案例：高层到期回落**

高层带 `validTo`，低层长期有效；`duration = 7200`：

| 时间段 | composite | 原因 |
|---|---|---|
| 05:00–06:00 | 10.0 A | 高层 stackLevel 1 有效 |
| 06:00–07:00 | 16.0 A | 高层过期，回落到低层 |

## 明确不在库内的部分

- 不在库内计算实际充电功率、三相硬件分配、同层曲线合并与持久化；
- 不在库内做插枪核对与预约超时释放；
- 不在库内做名单持久化与真实鉴权；
- 不在库内做固件下载、校验与刷写。

这些由宿主实现；库只保证报文、状态与上述已声明的语义。
