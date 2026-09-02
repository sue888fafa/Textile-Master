# Godot 美术资源替换说明

当前项目没有强制依赖外部图片，`scripts/main.gd` 会绘制一套可运行的程序化占位美术。打开场景后，在 Inspector 的 **Art Slots** 分类中可以直接替换以下插槽：

- `background_texture`：全屏背景图。
- `score_panel_texture`、`level_panel_texture`、`pause_texture`：顶部 HUD 资源。
- `order_bubble_texture`：传送带起点订单气泡背景；未提供时使用程序绘制的气泡。
- `board_texture`：中央十字绣布面。
- `belt_texture`：传送带底图。建议使用透明背景、与闭环区域比例一致的纹理。
- `recycle_tray_texture`：中央五格待编制区的横向整体底图。
- `recycle_slot_texture`：待编制区 5 个独立台子的底图，会按比例缩放。
- `stitched_block_textures`：按颜色顺序放入 5 种已纺织的点位方块：珊瑚红、向日黄、叶绿色、湖蓝色、深蓝色。
- `unstitched_block_texture`：未纺织的点位方块。
- `machine_left_texture`、`machine_bottom_texture`、`machine_right_texture`：动态纺织机在左侧、水平段、右侧传送带上的方向资源，机器会根据当前位置自动选择。
- `yarn_textures`：按颜色顺序放入 5 种线团：珊瑚红、向日黄、叶绿色、湖蓝色、深蓝色。

当前机器朝向资源：左侧传送带使用 `machine_left.png`，水平段使用 `machine_bottom.png`，右侧传送带使用 `machine_right.png`。动态机器根据所在闭环路径段自动选择方向资源。

当前项目已预置的资源映射为：`yarn.png`（珊瑚红）、`yarn_sun.png`（向日黄）、`yarn_leaf.png`（叶绿色）、`yarn_lake.png`（湖蓝色）、`yarn_deep_blue.png`（深蓝色）。已纺织块使用 `stitched_block.png`（珊瑚红）、`yellow_stitched_reference.png`（向日黄）、`stitched_leaf.png`（叶绿色）、`stitched_lake.png`（湖蓝色）、`stitched_deep_blue.png`（深蓝色）。

## 参考图布局

脚本已经按参考图组织为顶部 HUD、中部闭环传送带、中央绣图区、动态纺织机、底部中央五格待编制区和三合材料列。选中 `Main` 节点后，在 Inspector 的 `Layout - 390x844` 分类中编辑位置和尺寸，不需要改 GDScript：

- `score_rect`、`level_rect`、`pause_rect`：顶部三个 HUD 元素。
- `belt_panel_rect`、`board_layout_rect`：传送带外框和中央绣图区。
- `belt_path_points`：传送带线团轨迹的归一化路径点，顺序为入口、底边、右侧、顶边、左侧、入口；更换传送带资源后可在 Inspector 中调整。
- `dynamic_machine_size`：动态纺织机的显示尺寸。
- `machine_counter_offset`、`machine_counter_size`：传送带起点运行数量提示的位置和尺寸。
- `recycle_tray_rect`：底部中央五格待编制区。
- `materials_panel_rect`、`recycle_tray_rect`：底部三合材料区和中央五格待编制区。
- `recycle_slot_size`：待编制区 5 个独立台子的显示尺寸。
- `material_lane_1_rect` 到 `material_lane_4_rect`：四条可点击材料列；五种颜色会随机混排其中。

素材尺寸改变时，优先调整对应 `Rect2` 的 `Size`。动态纺织机方向资源可以在 `Main` 的 `Art Slots` 中单独替换；线团纹理仍按照 `yarn_textures` 的顺序使用：珊瑚红、向日黄、叶绿色、湖蓝色、深蓝色。

订单气泡固定显示在传送带起点附近，只在当前波次有剩余订单时显示；数量会随着三合动态纺织机生成即时递减。可在 `Layout - 390x844` 中调整 `order_bubble_size` 和 `order_bubble_gap`。

材料列每列仍有 10 枚线团，画面中只显示前 3 枚完整毛线球和第 4 枚半球；取走顶部线团后，隐藏在下方的材料会继续上移显示。

待编制区的 5 个槽位仅用于显示当前选中的线团，不可点击取回。材料列顶部线团进入后，三个同色线团会自动合成为一个传送带线团；待编制区的第 6 个线团会使本局失败。

材料区不再绘制程序生成的外层底板和列背景，只保留材料标题、数量、点击区域与毛线球。建议资源使用 PNG/WebP，并保留透明通道。未填入的待编制区插槽会自动回退到 GDScript 绘制的占位样式，因此替换资源时可以逐项预览，不需要一次准备完整素材包。
