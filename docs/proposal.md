# OCPP 项目申报书（仓库版）

**许可证：** MIT
**说明：** 本文件是提交版申报书的仓库副本，已去掉个人联系方式；提交以正式申报表为准。

## 基本信息

- 项目名称：OCPP 1.6J 充电协议栈（MoonBit 实现，六功能块协议语义）
- GitHub：https://github.com/cxh123-alt/OCPP　　**账号：** cxh123-alt
- 项目方向：MoonBit 充电协议库 / 桩与后台通信基础设施
- 是否移植：否，原创项目
- 符合性目标：OCPP 1.6J 28 条消息 + `docs/semantics.md` 的状态与调度语义
- 当前规模：4990 行（含测试），75 项测试，CI 含 check / test / wasm 构建

## 项目简介

用 MoonBit 实现充电桩与运营后台之间的 1.6J 协议栈：JSON-RPC 信封、28 条消息、桩侧与后台侧状态机、传输接缝，以及配置、预约、本地名单、充电曲线的状态语义。面向桩固件、运营平台、边缘网关与协议测试工具，提供可直接组合的库。

## 六功能块的语义与宿主职责

| 功能块 | 库内语义 | 宿主职责 |
|---|---|---|
| Core | 会话、交易号、计量、状态、配置存储与查询、清缓存、可用性/解锁/复位 | 真实鉴权、表计、配置生效、持久化 |
| Firmware Management | 编码诊断/固件消息，保存下载地址 | 生成诊断文件、下载、校验、刷写 |
| Local Auth List | Full 替换；Differential 增删；版本过期回 `VersionMismatch` | 名单持久化、真实鉴权 |
| Reservation | 占用/重复 → `Occupied`，`Unavailable`/`Faulted` 对应状态；`ReserveNow` 先清过期预约 | 周期调用 `release_expired`、插枪核对 |
| Remote Trigger | 编码触发并回执 | 执行实际动作 |
| Smart Charging | 按 purpose 组合曲线，覆盖 duration，处理有效期、时段与到期回落 | 应用到充电机、三相/功率、持久化 |

## 跨用途曲线组合

- `ChargePointMaxProfile`（连接器 0）是整桩上限；同一 purpose 内 `stackLevel` 高者优先；
- `TxProfile` 覆盖 `TxDefaultProfile`，两者各自取最高 `stackLevel`；
- 每段取 `min(整桩上限, 交易约束)`，只有一侧时取该侧；
- A/W 混用按桩电压换算（默认 230 V，可 `set_voltage`）；
- 时间段按 `validFrom`/`validTo`、`duration`、`startPeriod` 切分，高层到期回落。

## 整桩上限与交易曲线冲突

整桩上限 16 A、交易曲线 32 A，输出 composite 为 16 A：

```json
[2,"p1","SetChargingProfile",{"connectorId":0,"csChargingProfiles":{"chargingProfileId":1,"stackLevel":0,"chargingProfilePurpose":"ChargePointMaxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0}]}}}]
[2,"p2","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":2,"stackLevel":0,"chargingProfilePurpose":"TxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":32.0}]}}}]
[2,"p3","GetCompositeSchedule",{"connectorId":1,"duration":3600}]
[3,"p3",{"status":"Accepted","schedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0}]}}]
```

| 整桩上限 | 交易曲线 | composite |
|---|---|---|
| 16 A | 32 A | 16 A |
| 16 A | 10 A | 10 A |
| 16 A | 无 TxProfile、TxDefault 20 A | 16 A |
| 16 A | TxProfile 12 A、TxDefault 20 A | 12 A |

## 版本识别与下发命令

- 版本是连接属性：调用方从 WebSocket 子协议取得 `ocpp1.6`，作为 `ProtocolVersion` 传入；本库不实现 WebSocket；
- 不按报文形状判别：`Heartbeat` 为 `{}`、`Reset` 为 `{"type": ...}`，形状相同只能由连接绑定决定；
- 下发命令：`Central::command16(request)` 分配 `callId` 并编码 CALL；桩用同一绑定解码并回 CALLRESULT/CALLERROR；后台用 `Correlator` 配对，未知/重复/过期 id 不进入业务分发。

## 符合性与边界

- 目标为 1.6J 六功能块协议语义；库内不做实际功率/三相计算、持久化、真实鉴权、固件下载刷写、插枪核对与预约超时释放；
- 当前桩模型只建模连接器 1，多连接器桩需要宿主拆分；
- 1.6 Security 扩展不在目标内；2.0.1 旧代码归档在 `archive/ocpp-2.0.1`，`master` 不包含；
- native 目标需要系统 C 工具链，未在 CI 覆盖；WebSocket/TLS 由调用方实现。

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
