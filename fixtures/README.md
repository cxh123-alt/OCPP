# 抓包样例

两份完整对话，由 `moon run cli -- dump` 直接导出，没有手工编辑：

| 文件 | 内容 |
|---|---|
| `session-1.6.tsv` | 1.6J：启动、鉴权、开始充电、三次计量、停止、状态 |
| `session-2.0.1.tsv` | 2.0.1：启动、鉴权、TransactionEvent 三阶段、三次计量、状态 |

每行三列：方向、动作、完整报文。可以直接解一帧：

```bash
moon run cli -- decode "$(cut -f3 fixtures/session-1.6.tsv | sed -n 4p)"
```

这些文件不参与自动测试（测试里内联断言，避免文件 IO 依赖），改协议实现时请一并更新。
