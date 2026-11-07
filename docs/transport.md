# 传输接法

库只产出和消费字符串，真正的 OCPP 连接是 WebSocket。两者之间只需要一对 `Mailbox`：

```moonbit
let to_charger = @transport.Mailbox::new()
let to_central = @transport.Mailbox::new()

// WebSocket 收到文本时，投递到对应方向的信箱
to_central.post(text_from_websocket)

// 处理循环：取出、交给状态机、把回包写回 WebSocket
while true {
  match to_central.take() {
    None => break
    Some(text) => {
      for reply in session.handle(text) {
        to_charger.post(reply)
      }
    }
  }
}
```

## 和真实 WebSocket 对接

1. 握手阶段协商子协议：1.6J 用 `ocpp1.6`，2.0.1 用 `ocpp2.0.1`。
2. 文本帧原样交给 `Mailbox::post`，二进制帧忽略。
3. `Mailbox::take` 的返回值直接 `send_text` 回去。
4. 断线重连后，OCPP 1.6 需要重新 `BootNotification`；2.0.1 还需要重放未确认的 `TransactionEvent`（本库只负责生成，重放策略由调用方决定）。

## 为什么不用 trait

`Channel` 这样的 trait 会把异步、生命周期、错误处理都带进来，而这一层真正需要的只是「先进先出」。`Mailbox` 小到可以复制进任何运行时，也便于测试里故意丢帧、乱序。

## 测试里的用法

`transport_test.mbt` 用两个信箱验证 FIFO 和 `relay`；`sim` 则直接调用两侧状态机，不经过信箱，因为它在同一个进程里同步执行。
