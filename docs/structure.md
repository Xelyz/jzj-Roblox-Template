# Template 结构

`init.lua` 按运行环境初始化服务端管理器或客户端界面。`Config` 将宿主游戏的 `GameConfig` 与默认配置合并。

- **信号。** `SignalManager` 在服务端按需创建 RemoteEvent 和 RemoteFunction。客户端等待复制并校验类型。同一运行环境内的事件使用 BindableEvent。
- **房间和比赛。** `RoomManager` 管理成员、房主、准备、开局和回房。房名由服务器根据房主创建时的 Roblox 显示名生成。开局由 `MatchService` 登记比赛，之后发出 `MatchStarted` 和 `GameInitRequest`。宿主开启 `game.abortOnPlayerLeave` 时，任意玩家掉线都会结束当前对局。默认仍使用最少玩家数判断是否中止。
- **聊天。** `ChatManager` 为每场比赛创建独立 TextChannel 并登记参赛玩家，服务器校验发送者和接收者属于同一场比赛。客户端在对局界面挂载 TextChannelWindow，并通过 TextChannel.SendAsync 提交消息。Roblox 负责消息过滤、显示和聊天权限。比赛移除时销毁频道。
- **排行榜。** 服务端模块提供读取排名和记录结果的接口，客户端通过远程函数读取并绘制排行榜。
- **界面。** `ClientUIUtils` 提供桌游风格主题（`UI.Colors`、`UI.Fonts`）和组件：纸面面板、带硬阴影的按钮、圆角标签、头像和顶部提示（`UI.showToast`）。各界面放在 `UI.createStage` 画布上，按 1280×720 设计尺寸等比缩放，长边扩展，覆盖整个屏幕（不留 Roblox 顶栏安全区），顶部元素需居中放置。`BackgroundManager` 绘制常驻桌面背景，主菜单、房间列表、房间和排行榜本身不再绘制底色。宿主对局界面可提供名为 `ChatSlot` 的 Frame 指定聊天框位置。
