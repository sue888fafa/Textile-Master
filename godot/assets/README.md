# Godot 美术资源替换说明

当前项目没有强制依赖外部图片，`scripts/main.gd` 会绘制一套可运行的程序化占位美术。打开场景后，在 Inspector 的 **Art Slots** 分类中可以直接替换以下插槽：

- `background_texture`：全屏背景图。
- `score_panel_texture`、`level_panel_texture`、`pause_texture`：顶部 HUD 资源。
- `board_texture`：中央十字绣布面。
- `belt_texture`：传送带底图。建议使用透明背景、与闭环区域比例一致的纹理。
- `recycle_tray_texture`：中央五格待编制区的横向整体底图。
- `recycle_slot_texture`：待编制区 5 个独立台子的底图，会按比例缩放。
- `stitched_block_textures`：按颜色顺序放入 9 种已纺织的点位方块：珊瑚红、橙色、向日黄、橄榄绿、叶绿色、湖蓝色、深蓝色、紫色、粉色。缺失的槽位会使用程序化颜色和针脚回退。
- `unstitched_block_texture`：未纺织的点位方块。
- `machine_left_texture`、`machine_bottom_texture`、`machine_right_texture`：动态纺织机在左侧、水平段、右侧传送带上的方向资源，机器会根据当前位置自动选择。
- `link_tile_background_texture`：所有连连看格子共用的底图，会先铺满每个格子。
- `link_tile_textures`：连连看物品图标数组，按 9 个颜色组顺序设置透明背景图标，默认 36 个槽位，键为 `0-9`、`a-z`，样式数量增加时可继续添加槽位。`link_tile_style_counts` 分别控制 9 组启用的样式数量，默认 `[4,4,4,4,4,4,4,4,4]`。每个编制目标会随机选择所属颜色组中的一个样式并生成一对；同一样式才能配对，不再有干扰物品。未设置的槽位自动回退到程序绘制图标。

本次图集裁切资源位于 `assets/link_tiles/`，当前提供的透明 PNG 会按数组顺序装入图标槽位；默认场景保留 36 个槽位，缺少的槽位使用程序化回退。图标按 9 个颜色组管理，所有图标都可配对并触发纺织。正式关卡的棋盘尺寸和物品位置由关卡编辑器保存。
- `yarn_textures`：按颜色顺序放入 9 种线团：珊瑚红、橙色、向日黄、橄榄绿、叶绿色、湖蓝色、深蓝色、紫色、粉色。

当前机器朝向资源：左侧传送带使用 `machine_left.png`，水平段使用 `machine_bottom.png`，右侧传送带使用 `machine_right.png`。动态机器根据所在闭环路径段自动选择方向资源。

当前项目已预置的资源映射为：`yarn.png`（珊瑚红）、`yarn_sun.png`（向日黄）、`yarn_leaf.png`（叶绿色）、`yarn_lake.png`（湖蓝色）、`yarn_deep_blue.png`（深蓝色）。已纺织块使用 `stitched_block.png`（珊瑚红）、`yellow_stitched_reference.png`（向日黄）、`stitched_leaf.png`（叶绿色）、`stitched_lake.png`（湖蓝色）、`stitched_deep_blue.png`（深蓝色）。

## 参考图布局

脚本已经按参考图组织为顶部 HUD、中部闭环传送带、中央绣图区、动态纺织机和底部连连看棋盘。选中 `Main` 节点后，在 Inspector 的 `Layout - 390x844` 分类中编辑位置和尺寸，不需要改 GDScript：

- `score_rect`、`level_rect`、`pause_rect`：顶部三个 HUD 元素。
- `Main/UI/ScoreUI`、`Main/UI/LevelUI`、`Main/UI/PauseUI`：可在 2D 场景中直接拖动、缩放的金币、关卡和暂停 UI 节点。节点存在时优先使用节点位置和尺寸，旧 Rect2 仅作为回退。
- `tool_slot_background_texture`：三个道具栏共用的底图，会先绘制在每个道具栏的完整矩形中。
- `Main/UI/AddTimeUI`、`Main/UI/ShuffleUI`、`Main/UI/AutoClearUI`：底部增时、打乱、自动消除道具栏的场景节点，可直接拖动和缩放。对应图标资源通过 Main Inspector 的 `add_time_texture`、`shuffle_texture`、`auto_clear_texture` 替换，图标会叠加在公共道具栏底图上。
- `belt_panel_rect`：传送带外框。
- `board_layout_rect`：没有独立场景节点时的中央编制区域回退位置和尺寸。推荐在 2D 场景树中选中 `Main/StitchAreaUI`，直接拖动节点或调整 Control 的 Size/Scale；运行时会同步使用该节点的实际位置和大小。
- `belt_path_points`：传送带线团轨迹的归一化路径点，顺序为入口、底边、右侧、顶边、左侧、入口；更换传送带资源后可在 Inspector 中调整。
- `dynamic_machine_size`：动态纺织机的显示尺寸。
- `link_board_rect`：旧关卡底部连连看棋盘的位置和尺寸；新关卡由共享正方形网格自动计算。
- `materials_panel_rect`：连连看区域的整体布局范围。

素材尺寸改变时，优先调整对应 `Rect2` 的 `Size`。动态纺织机方向资源可以在 `Main` 的 `Art Slots` 中单独替换；线团纹理仍按照 `yarn_textures` 的顺序使用：珊瑚红、向日黄、叶绿色、湖蓝色、深蓝色。

当前版本已移除订单气泡、订单波次和动态纺织机数量限制。连连看配对成功后直接生成带颜色的线团产品；动态纺织机只寻找相同颜色的编制目标。

连连看物品使用共享游戏网格，默认是 10 列 × 25 行，图案消除后保留为空位，不会自动补充。物品之间的总间距默认约为格子边长的 2%。连连看不绘制整体底图、独立格子底色或边框，图标可以直接携带地图背景。建议资源使用 PNG/WebP，并保留透明通道；未填入的图标槽位会自动回退到 GDScript 绘制的占位样式。

可视化编辑器现在分为两个面板：布局编辑器使用共享网格编辑传送带和连连看物品；编制区域编辑器单独编辑传送带内部的编制图案和需求绑定。布局网格中的传送带区域不能放置连连看物品。编制图案保存后，运行时从对应关卡资源读取。

每个正式关卡单独保存为 `levels/level_###.tres`。`Main.level_files` 只记录关卡文件的游玩顺序；编辑器中的复制会创建新文件，上移/下移只调整顺序，移出不会删除原文件，可通过“从文件恢复”重新加入。首次从旧场景迁移时使用布局编辑器的“迁移内嵌关卡”按钮。

正式关卡通过布局编辑器在统一共享网格中手动编辑连连看点位位置；传送带矩形会占用对应格子，因此这些格子不会生成连连看物品。布局编辑器只保留一个小型通用点位图标，运行时会按编制区域颜色和目标数量自动生成并随机分配九种标准颜色物品。编制区域编辑器单独保存传送带内部的编制图案，并按每个编制点位自动计算两枚连连看物品。`link_cell_gap_ratio` 仍控制运行时图标间距。资源替换在 `Art Slots` 中完成。

布局点位数量必须严格等于编制目标数量的两倍。运行时每个编制目标从所属颜色组随机选择一个图标样式并生成一对；只有相同样式的两个图标可以配对，同色不同样式不能配对。

界面布局编辑不依赖美术资源：每关的 10×25 共享正方形网格、传送带位置和尺寸在编辑器中保存。传送带尺寸最小为 5×5，拖动会吸附到整数网格，且不能覆盖连连看物品。编制图案不占用共享布局格子，而是在独立编制编辑器中保存。运行时会由传送带矩形自动生成闭环轨迹，因此替换传送带图片后，起点、终点和机器方向也会随布局自动适配。
