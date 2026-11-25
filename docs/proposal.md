# OCPP 项目申报书（仓库版）

**许可证：** MIT
**说明：** 本文件是提交版申报书的仓库副本，已去掉个人联系方式；提交以正式申报表为准。

## 基本信息

- 项目名称：OCPP 1.6J 充电协议栈（MoonBit 实现，六功能块协议语义）
- GitHub：https://github.com/cxh123-alt/OCPP　　**账号：** cxh123-alt
- 项目方向：MoonBit 充电协议库 / 桩与后台通信基础设施
- 是否移植：否，原创项目
- 当前规模：5706 行（含测试），90 项测试，CI 含 check / test / wasm 构建

## 项目简介

用 MoonBit 实现充电桩与运营后台之间的 1.6J 协议栈：JSON-RPC 信封、28 条消息、桩侧与后台侧状态机、传输接缝，以及配置、预约、本地名单、充电曲线的状态语义。面向桩固件、运营平台、边缘网关与协议测试工具，提供可直接组合的库。

## 六功能块的语义与宿主职责

| 功能块 | 库内语义 | 宿主职责 |
|---|---|---|
| Core | 会话、交易号与 RemoteStop 校验、transactionData、计量、状态、配置存储与 readonly、清缓存、连接器校验、可用性/解锁/复位、vendor/message 登记 | 真实鉴权、表计、配置生效、持久化 |
| Firmware Management | 保存下载地址、retries/retryInterval、诊断时间窗，维护状态并生成状态帧 | 生成诊断文件、下载、校验、刷写 |
| Local Auth List | Full 替换；Differential 增删；版本过期回 `VersionMismatch` | 名单持久化、真实鉴权 |
| Reservation | 占用/重复 → `Occupied`，`Unavailable`/`Faulted` 对应状态；`ReserveNow` 先清过期预约 | 周期调用 `release_expired`、插枪核对 |
| Remote Trigger | 编码触发、记录 requestedMessage 并回执 | 执行实际动作 |
| Smart Charging | 按 purpose 组合、相数参与换算、覆盖 duration、处理有效期/时段/到期回落 | 应用到充电机、持久化 |

## 跨用途曲线组合（相数参与）

- `ChargePointMaxProfile`（连接器 0）是整桩上限；同一 purpose 内 `stackLevel` 高者优先；
- `TxProfile` 覆盖 `TxDefaultProfile`，但只匹配其 `transactionId`（或未指定）；两者各自取最高 `stackLevel`；
- 每个时间段先把限值统一换算成 **W**：A × 电压 × `numberPhases`（缺省 3 相），再取 `min`；
- 输出保留所选曲线的单位与相数；请求指定 `chargingRateUnit` 时按该单位输出；时间戳支持 `Z` 与 `±HH:MM`；电压默认 230 V，可 `set_voltage`；
- 时间段按 `validFrom`/`validTo`、`duration`、`startPeriod` 切分，高层到期回落；Recurring 曲线按 Daily/Weekly 展开；`minChargingRate` 作为下限钳制且不超过整桩上限。

## 整桩上限与交易曲线冲突

整桩上限 16 A 三相、交易曲线 32 A 三相，输出 composite 为 16 A 三相：

```json
[2,"p1","SetChargingProfile",{"connectorId":0,"csChargingProfiles":{"chargingProfileId":1,"stackLevel":0,"chargingProfilePurpose":"ChargePointMaxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0,"numberPhases":3}]}}}]
[2,"p2","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":2,"stackLevel":0,"chargingProfilePurpose":"TxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":32.0,"numberPhases":3}]}}}]
[2,"p3","GetCompositeSchedule",{"connectorId":1,"duration":3600}]
[3,"p3",{"status":"Accepted","schedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0,"numberPhases":3}]}}]
```

| 整桩上限 | 交易曲线 | composite |
|---|---|---|
| 16 A × 3 相（11040 W） | 32 A × 3 相（22080 W） | 16 A × 3 相 |
| 16 A × 3 相（11040 W） | 32 A × 1 相（7360 W） | 32 A × 1 相 |
| 16 A × 3 相（11040 W） | 10 A × 3 相（6900 W） | 10 A × 3 相 |
| 16 A × 3 相 | 无 TxProfile、TxDefault 20 A × 3 相 | 16 A × 3 相 |

## 版本识别与下发命令

- 版本是连接属性：调用方从 WebSocket 子协议取得 `ocpp1.6`，作为 `ProtocolVersion` 传入；本库不实现 WebSocket；
- 不按报文形状判别：`Heartbeat` 为 `{}`、`Reset` 为 `{"type": ...}`，形状相同只能由连接绑定决定；
- 下发命令：`Central::command16(request)` 分配 `callId` 并编码 CALL；桩用同一绑定解码并回 CALLRESULT/CALLERROR；后台用 `Correlator` 配对。

## 最终符合性范围

- **在范围内**：OCPP 1.6J 28 条消息 + 本文声明的状态与调度语义（含 purpose 组合、相数换算、有效期/时段、到期回落、预约占用、本地名单增删、固件/诊断状态、厂商白名单、trigger 记录）；
- **不在范围内**：1.6 Security 扩展、2.0.1（归档在 `archive/ocpp-2.0.1`）、多连接器桩、实际功率/三相硬件分配、持久化、真实鉴权、固件下载刷写、WebSocket/TLS。

## 材料索引

| 内容 | 代码与文档 | 测试 |
|---|---|---|
| 28 条消息 | `v16/actions.mbt`、`v16/payloads.mbt` | `v16/v16_test.mbt` |
| 六功能块语义与案例 | `docs/semantics.md` | — |
| 预约/名单/曲线状态 | `station/state.mbt`、`station/session.mbt` | `station/station_test.mbt` |
| 版本绑定与命令 | `central/server.mbt` | `central/central_test.mbt` |
| 关联与超时 | `transport/pending.mbt` | `transport/transport_test.mbt` |

## 原创与参考说明

- 原创项目，非移植，无第三方代码；许可证 MIT；
- 报文依据 OCPP 1.6J 公开规范核对，代码自写；
- 版本由连接绑定；核心 sans-IO；语义范围以 `docs/semantics.md` 为准。
