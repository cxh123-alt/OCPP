# OCPP 项目申报书（仓库版）

**许可证：** MIT
**说明：** 本文件是提交版申报书的仓库副本，已去掉个人联系方式；提交以正式申报表为准。

## 基本信息

- 项目名称：OCPP 1.6J 充电协议栈（MoonBit 实现，六功能块完整协议语义）
- GitHub 仓库链接：https://github.com/cxh123-alt/OCPP
- GitHub 账号：cxh123-alt（项目账号，主要提交者）
- 项目方向：MoonBit 充电协议库 / 桩与后台通信基础设施
- 是否为移植项目：否，原创项目
- 符合性目标：OCPP 1.6J 六功能块完整协议语义（28 条消息 + `docs/semantics.md` 的状态与调度语义）；宿主只承担硬件执行、持久化与网络传输

## 项目简介

OCPP 用 MoonBit 实现充电桩与运营后台之间的 1.6J 协议栈：JSON-RPC 信封、28 条消息、桩侧与后台侧状态机、传输接缝，以及预约、本地名单、充电曲线的状态语义。项目面向桩固件、运营平台、边缘网关与协议测试工具，提供可直接组合的库。当前版本 4789 行（含测试），72 项测试通过，GitHub Actions 每次推送执行 check、test 与 wasm 构建，当前为绿。

## 六功能块的语义与宿主职责

28 条消息只规定报文形状，不规定完整业务行为。库内语义与宿主职责逐块写死：

| 功能块 | 库内语义 | 宿主职责 |
|---|---|---|
| Core | 会话状态、交易号、计量累计、状态通知、配置存储与查询、清缓存、可用性/解锁/复位 | 真实鉴权、计量表读数、配置对硬件生效、持久化 |
| Firmware Management | 编码诊断/固件消息，保存下载地址 | 生成诊断文件、下载、校验、刷写、回滚 |
| Local Auth List | 保存 listVersion 与名单，Full/Differential 合并 | 名单持久化、真实鉴权 |
| Reservation | 同一连接器最多一条预约（当前桩模型只有连接器 1）；非 Available 或已有预约返回 `Occupied`；未知 id 取消返回 `Rejected` | 插枪核对、超时释放 |
| Remote Trigger | 编码触发并回执 | 执行实际动作 |
| Smart Charging | 按连接器与 purpose 保存多条曲线；composite 覆盖请求 duration，按 ChargePointMaxProfile 整桩上限与 TxProfile/TxDefaultProfile 交易约束取 min，再按有效期/时段切分并处理到期回落 | 把限值应用到充电机、三相分配与功率控制 |

完整表格与边界见 `docs/semantics.md`。

## 语义案例

**连接器已占用时的预约**

```json
[2,"r1","ReserveNow",{"connectorId":1,"expiryDate":"2026-11-07T07:00:00Z","idTag":"TAG-9","reservationId":9}]
[3,"r1",{"status":"Occupied"}]
```

桩侧在连接器为 `Charging`/`Preparing`/`Finishing`，或该连接器已有预约时返回 `Occupied`，不写入预约表。

**多曲线约束**

```json
[2,"c1","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":1,"stackLevel":0,"chargingProfilePurpose":"TxDefaultProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0}]}}}]
[3,"c1",{"status":"Accepted"}]
[2,"c2","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":2,"stackLevel":1,"chargingProfilePurpose":"TxDefaultProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":10.0}]}}}]
[3,"c2",{"status":"Accepted"}]
[2,"c3","GetCompositeSchedule",{"connectorId":1,"duration":3600}]
[3,"c3",{"status":"Accepted","schedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":10.0}]}}]
```

同一连接器两条曲线，stackLevel 1 覆盖 stackLevel 0，composite 返回 10.0 A；`ClearChargingProfile` 删除后 composite 为空。

**跨用途组合规则**

- `ChargePointMaxProfile` 存在连接器 0，是整桩上限；同一 purpose 内 `stackLevel` 高者优先；
- `TxProfile` 覆盖 `TxDefaultProfile`，两者各自取最高 `stackLevel`；
- 每个时间段取 `min(整桩上限, 交易约束)`，只有一侧时取该侧；
- 库负责组合与有效期/时段切分，宿主负责把限值应用到充电机并持久化。

**整桩上限与交易曲线冲突**

整桩上限 16 A、交易曲线 32 A，输入：

```json
[2,"p1","SetChargingProfile",{"connectorId":0,"csChargingProfiles":{"chargingProfileId":1,"stackLevel":0,"chargingProfilePurpose":"ChargePointMaxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0}]}}}]
[3,"p1",{"status":"Accepted"}]
[2,"p2","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":2,"stackLevel":0,"chargingProfilePurpose":"TxProfile","chargingProfileKind":"Absolute","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":32.0}]}}}]
[3,"p2",{"status":"Accepted"}]
[2,"p3","GetCompositeSchedule",{"connectorId":1,"duration":3600}]
[3,"p3",{"status":"Accepted","schedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":16.0}]}}]
```

| 整桩上限 | 交易曲线 | composite |
|---|---|---|
| 16 A | 32 A | 16 A |
| 16 A | 10 A | 10 A |
| 16 A | 无 TxProfile、TxDefault 20 A | 16 A |
| 16 A | TxProfile 12 A、TxDefault 20 A | 12 A |


**高层到期回落**

高层曲线带 `validFrom`/`validTo`，低层曲线长期有效：

| 时间段 | composite | 原因 |
|---|---|---|
| 05:00–06:00 | limit 10.0 A | 高层 stackLevel 1 在有效期内 |
| 06:00–07:00 | limit 16.0 A | 高层已过 validTo，回落到低层 stackLevel 0 |

`GetCompositeSchedule` 请求 `duration = 7200`，返回两个 period：`startPeriod = 0` 的 10.0 A 与 `startPeriod = 3600` 的 16.0 A。

```json
[2,"e2","SetChargingProfile",{"connectorId":1,"csChargingProfiles":{"chargingProfileId":3,"stackLevel":1,"chargingProfilePurpose":"TxDefaultProfile","chargingProfileKind":"Absolute","validFrom":"2026-11-07T04:00:00Z","validTo":"2026-11-07T06:00:00Z","chargingSchedule":{"chargingRateUnit":"A","chargingSchedulePeriod":[{"startPeriod":0,"limit":10.0}]}}}]
[3,"e2",{"status":"Accepted"}]
```

## 版本识别与下发命令流程

- **版本是连接属性，不是报文属性。** 调用方在 WebSocket 握手的 `Sec-WebSocket-Protocol` 里取得 `ocpp1.6`，把结果作为 `ProtocolVersion` 传入；本库不实现 WebSocket，后台与桩各自保存绑定；
- 不依赖报文形状：`Heartbeat` 是 `{}`，`Reset` 是 `{"type": ...}`，形状相同的报文只能由连接绑定决定；
- **下发命令（CS → CP）**：`Central::command16(request)` 分配 `callId`，用 1.6J action 表编码 CALL；传输层写给桩；桩用同一绑定解码并回 CALLRESULT/CALLERROR；后台用 `Correlator` 配对，未知、重复、过期 id 不进入业务分发。

## 符合性与边界

- 目标为 1.6J 六功能块完整协议语义（含曲线有效期与时段回落）；库内不计算实际功率/三相，不做持久化与真实鉴权，不做插枪核对与预约超时释放，不做固件下载与刷写；
- 1.6J 消息集不含证书管理；1.6 Security 扩展不在目标内；
- 2.0.1 旧代码归档在 `archive/ocpp-2.0.1` 分支，`master` 不包含，不参与验收；
- 传输层不实现 WebSocket 与 TLS；native 目标需要系统 C 工具链，未在 CI 覆盖；
- 「复用」指协议层可用于桩、后台、网关与测试工具，不声称断线续传。

## 材料索引

| 申报内容 | 代码与文档 | 对应测试 |
|---|---|---|
| 28 条消息 | `v16/actions.mbt`、`v16/payloads.mbt` | `v16/v16_test.mbt` |
| 六功能块语义与宿主职责 | `docs/semantics.md` | — |
| 预约占用、多曲线组合 | `station/state.mbt` | `station/station_test.mbt` |
| 版本绑定与下发命令 | `central/server.mbt` | `central/central_test.mbt` |
| 关联与超时 | `transport/pending.mbt` | `transport/transport_test.mbt` |
| 动作矩阵 | `docs/conformance.md` | 同上 |

## 原创与参考说明

- 本项目为原创项目，不是移植项目，无原项目名称、来源链接与许可证需要声明；
- 报文与字段依据 OCPP 1.6J 公开规范核对，代码为自写，不包含第三方代码；
- 本项目许可证：MIT；
- 设计取舍：版本由连接绑定而非报文形状推断；核心 sans-IO；协议语义范围以 `docs/semantics.md` 为准，宿主边界逐块列明。
