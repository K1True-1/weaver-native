# 0.5.0 本地试玩验证

日期：2026-09-20。环境：Windows、RTX 5070 Ti、NVIDIA 616.64、Godot 4.7.2、Compatibility / OpenGL 3.3。逻辑画布为 1600×1000。

## 自动回归

引擎 192、敌人牌组 949、卡牌运动 25、交互取消 16、地图 227、界面呈现 34、实体物件 71，共 1,514 项通过。VFX 检查另行通过：落地时序、敌人翻牌、动作恢复、中断清理、粒子上限、减少动效和音效生成。

物件检查验证了八种透明素材、真实轮廓点击、点击冷却、模态框遮挡、敌方行动保护、不改变游戏随机数和资源、当前耐久显示、实际攻击扣费、破坏奖励、六种不同音效波形。`tests/prop_capture.gd` 通过游戏视口投递鼠标移动、按下及释放事件，确认晶柱、炉火、水槽收到点击并触发反馈。

## 实际画面

- `artifacts/battle-props.png`：敌上我下、无姓名底框、当前血量、无框晶柱。
- `artifacts/prop-crystal-click.png`：晶柱点击反馈。
- `artifacts/prop-fire-water-click.png`：双物件鼠标点击后的火星、水波和局部微光。
- `artifacts/prop-rubble.png`：使用原摆件材质的破碎残片。
- `artifacts/battle-crowded.png`：双敌人布局验证；最终物件点击区域另外由呈现测试覆盖。
- `artifacts/title.png`、`map.png`、`map-progress.png`、`shop.png`：主菜单、分叉路线及商店。

## 独立 Windows 程序

文件：`dist/Weaver-Windows-0.5.0/Weaver.exe`。

大小：185,190,664 字节。SHA-256：`E31639C740AE244D047F6E189A6B1CD955E24F7CB6143FACEB3EB451FE15C550`。

使用官方 4.7.2 Windows release 导出模板；PCK 已内嵌，无需安装 Godot。模板来自官方归档，下载成员的 ZIP CRC 已校验。程序未签名。

`tools/check-release.cjs` 实际启动 EXE，在独立 QA 存档下验证：主菜单 → 规则练习 → 点击实体物件且游戏状态不变 → 出牌击碎晶柱获得 5 护甲 → 敌方完整回合 → 重新进入路线地图。退出码为 0。

日志 `artifacts/release-gpu.log` 输出 `BUILD_VERIFY_OK`，检查流程没有运行时错误。结束时地图帧率采样为 107 FPS；这只是本机的一次采样，不是最低帧率或跨设备性能保证。导出程序的实际截图在 `artifacts/release/`。

## 验收边界

这是可运行的本地试玩候选版，不是商业发行完成声明。未完成全路线长时间手工游玩、所有设备 / 窗口尺寸、无障碍完整审计、上线签名、平台资料、素材权属审核、商业音乐和最终数值平衡。

角色与物件为原创透明图层和 2.5D 动画，并非实时 3D 模型。八种战斗物件已独立重绘；四种非战斗服务物件、部分敌人及法术仍有旧图复用。旧 0.4 工程和旧存档没有被覆盖。本记录为发布前本地验收，上传结果以 GitHub v0.5.0 Release 为准。
