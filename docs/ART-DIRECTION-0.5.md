# 0.5.0 原创美术素材与提示词

生成方式：Codex 内置 ImageGen；本轮未使用外部 API。母版 PNG 保留在项目 assets/ui 中，运行时仅作纹理缩放和九宫格布局。没有使用《炉石传说》或《杀戮尖塔》的游戏资产、标志或截图。

最终界面美术方向：暗青石板战场、旧铜按钮、暗色嵌槽；金色雕花集中在羊皮纸卡牌和生命 / 能量宝石，避免所有控件争夺视觉焦点。早期 button.png / panel.png 母版保留，实际界面改用 button-stone.png / panel-stone.png。角色为透明底全身图加轻微呼吸、整体摇摆与脚下召唤阵，不是骨骼动画或实时 3D 人物。

## assets/ui/button.png

Use case: stylized-concept. Asset type: production game UI texture, a single reusable blank fantasy button for Godot nine-slice. Primary request: Hearthstone-inspired tactile 2.5D / sculpted 3D fantasy interface craftsmanship, original design. One horizontally elongated rectangular button, exact FRONT ORTHOGRAPHIC view, approximately 3:1 ratio. The button fills the image edge to edge, NO outer margin. Thick beveled antique-gold cast metal frame with raised acanthus relief only at corners, warm highlights along top edge, dark contact shadows along lower bevel. Inner face is richly grained dark walnut wood with a subtle polished amber gradient and fine carved horizontal grooves. Inner flat quiet center occupies at least 75% of width and 55% of height so text can be overlaid. The frame occupies about 10% of image height; corners compact, nothing protrudes. Rich rendered material roughness, hand-painted AAA collectible card game look, warm gold, brown, copper. The center must NOT be a plain flat color. No text, no letters, no symbols, no numbers, no logos, no watermark, no perspective tilt, no multiple buttons. Output a single button texture.

## assets/ui/panel.png

Use case: stylized-concept. Asset type: production game UI nine-slice panel texture. One SQUARE blank fantasy panel, FRONT ORTHOGRAPHIC view, completely filling canvas edge to edge with no exterior empty margin. Hearthstone-inspired chunky hand-painted 3D materials, original medieval arcanist craftsmanship. Thick richly carved black walnut frame with cast gold acanthus corner ornaments, raised golden bevel trim, hammered bronze recessed liner, screws as tiny gemstones. Center is deep dark teal-black embossed leather with fine visible grain and subtle worn patches, subdued for highly readable overlaid text. Thick frame covers only outer 9% on each side; huge empty leather center. Golden corner filigree confined to corners for nine-slice scaling, straight edges continuous, no emblem in center, no text, no typography, no cards, no icons, no numbers, no UI mockup. Cast shadows integrated inside border, luminous upper-left edge, material depth and tactile polished tabletop fantasy game appearance.

## assets/ui/parchment.png

Use case: stylized-concept. Asset type: a single blank collectible fantasy card face base texture for a real Godot game. Portrait ratio 2:3. Front orthographic view, not angled. Card fills entire canvas, no outer margin. Hearthstone-inspired sculptural gold and carved walnut frame, original ornate fantasy craftsmanship. Thick rounded and bevelled gold frame with refined raised scrollwork corners, weathered bronze inner bevel. Entire inner face is light golden ivory SHEEPSKIN PARCHMENT, beautifully fibrous vellum grain, subtle mottling and softly worn edges. Center of parchment is light and plain enough for dark readable rules text and artwork that will be added programmatically. No printed text or decorations across the center, no illustration slot, no embedded picture, no text, no number, no symbol, no watermark, no central emblem. Outer border occupies 7% width. High-end stylized 3D rendered tactile depth, warm golden edge lighting.

## assets/ui/map.png

Use case: stylized-concept. Asset type: background texture for a playable vertical roguelike route map, original fantasy game art. Portrait ratio 3:4. A large antique parchment expedition chart lying perfectly flat and viewed directly from overhead, fills entire canvas without outside table or border. Warm ivory tan vellum with delicately singed and weathered edge, faint antique ink illustrations restricted to outer left and right 18%: bottom small woods and a ruined gate, middle craggy hills and pine trees, top distant sharp gothic castle at top edge. Central 64% width and almost entire height is CLEAR light parchment, very low contrast paper grain, for functional route nodes and paths that will be overlaid. Slay the Spire-inspired hand-inked adventure map feeling, premium painterly fantasy board game finish. NO routes, no lines across center, no nodes, no icons, no symbols, no text, no letters, no compass, no numbers, no watermark. Not a UI mockup, single seamless full background asset.

## assets/ui/orb.png

Use case: stylized-concept. Asset type: one isolated reusable fantasy game mana orb UI sprite, square image, transparent background. Primary request: Hearthstone-inspired 2.5D sculpted render, original design. Perfect circular polished sapphire-blue glass disk with glowing turquoise luminous depth, surrounded by a chunky antique-gold cast metal ring with elegant raised scrollwork and walnut-dark outer bevel. Viewed EXACTLY front-on orthographic, one circular object fills 94% of canvas, centered. Gem occupies inner 74% of diameter, dark richly saturated blue center intentionally quiet for a white energy numeral overlaid later. Top-left specular glint and warm golden bevel lighting, dimensional glass refraction visible mainly around outer edge. Subtle integrated shadow beneath ring. No embedded number, no symbol, no text, no logo, no pedestal, no extra objects. Actual transparent background, no checkerboard.

## assets/key-art.png

本轮前段生成的主菜单原创主视觉：银发男性织律者位于画面右侧，深蓝和金色衣装，月夜哥特遗迹，流动的黄金/青色魔法丝线；左侧为低对比负空间供中文标题与按钮使用；无文字、标志或 UI。保留右人物、左菜单的构图。

## 开源图标

地图节点使用 Lucide 官方图标，原始来源 https://github.com/lucide-icons/lucide/tree/main/icons ，对应许可证见 assets/licenses/Lucide-LICENSE.txt。没有使用 emoji 代替地图图标。

## 说明

AI 生成素材在正式商业发行前仍应完成权属、平台披露及美术一致性审查；此记录不等于法律保证。

## assets/ui/weaver-figure.png

Use case: stylized-concept. Asset type: isolated full-body character sprite for a premium 2.5D fantasy card game. Reference image: the upper-left silver-haired male mage in the supplied 3x2 portrait atlas is the identity and costume reference; do not reproduce other characters or the atlas. Reimagine that SAME adult slender silver-haired male arcanist as one standing FULL BODY figure in a dynamic but balanced combat idle pose. Entire head, both boots and billowing cloak visible, no cropping. Deep navy long embroidered robe with exquisite gold celestial filigree, pale silver tousled hair, gloved hand conducting small cyan magical threads. Three-quarter facing RIGHT toward opponent. Hands anatomically correct, elegant single layered silhouette, cloak edge flowing slightly left. Fully modeled 3D render feeling with hand-painted high fantasy craftsmanship, facial quality matching reference; rich local material but readable broad values. Bright cool rim light, warm gold trim, grounded body, no frame, no card, no pedestal or circle, no scene, no UI, no numbers, no letters. TRUE transparent background. Portrait canvas about 2:3; sprite fills 90% of height, 80% of width. Single character only.

## assets/ui/grayblade-figure.png

Use case: stylized-concept. Asset type: isolated full-body enemy character sprite for a premium 2.5D fantasy card game. Reference image: upper-middle black-haired dark knight in the supplied 3x2 atlas is identity and costume reference; do not reproduce other characters or the atlas. Render the SAME adult handsome black-haired swordsman as one standing FULL BODY enemy figure in ready combat idle pose. Entire head and boots visible with a little transparent padding, no cropping. Dark gunmetal layered armor with weathered silver engraving, charcoal torn cloak, a broad sword held diagonally down toward LEFT; three-quarter facing LEFT toward player. Athletic realistic proportions, correct anatomy and hands, readable silhouette. Rich sculpted 3D high-fantasy render with hand-painted collectible-game surface treatment, cool steel speculars and subtle warm ember rim, fine face matching reference. No frame, no card, no pedestal, no ground circle, no scene, no UI, no numbers, no letters. TRUE transparent background. Portrait 2:3 canvas, figure and sword fill 90% height and 85% width. Single character only.

## assets/ui/health-gem.png

Use case: stylized-concept. Asset type: single square health-counter gemstone UI sprite for a fantasy card game, front orthographic view, true transparent background. One compact rounded square deep red RUBY gem, surrounded by a thick bevelled sculptural antique-gold frame with little dark walnut backing visible at corners. Hearthstone-inspired tactile 2.5D craftsmanship, original design. Crystal center occupies 72% of square, wine-red center quiet and dark for white numerals overlaid later, bright red glass facets near edges, specular upper-left glint and rich rough gold rim. No text or numbers or symbol on it, no card, no extra object, no background scene. Single square gem fills94%canvas with transparent margins, clean polished game asset.

## assets/ui/button-stone.png

Use case: stylized-concept. Asset type: ONE blank reusable nine-slice UI button texture for an existing fantasy card game. The reference is the actual stone battlefield; MATCH its dark weathered blue-green stone, aged bronze, candlelight and restrained material treatment. Single horizontal rectangular button front orthographic, 3:1 ratio, fills image to edges no outer margin. Sculpted 2.5D dark slate slab inset, visible fine stone grain and slight chisel wear. Narrow rounded bevel in OLD dark bronze, softly lit pale bronze top edge, small discreet rivets at four corners. Most of the face is quiet deep charcoal-teal slate, with smooth subtle variation and believable surface texture, suitable for ivory icon and text overlays. Dimmer subdued value than parchment playing cards, secondary UI should blend into the board. Rich realistic material depth but NOT shiny yellow gold, NOT walnut wood, NOT baroque acanthus corners, NOT bright orange center. No text, no symbols, no numbers, no logo, no watermark, no scene, exactly one production button texture.

## assets/ui/panel-stone.png

Use case: stylized-concept. Asset type: ONE square nine-slice empty equipment-slot panel texture for the supplied fantasy battlefield reference. Precisely match dark weathered blue-green stone board, aged bronze restraint, candlelit night tabletop. Orthographic overhead/front facing square fills entire image no exterior margin. Recessed slate/black leather socket with a thick dark beveled stone rim, narrow worn bronze inlay, tiny muted screws at corners, shallow engraved geometrical corner detailing, dark soft contact shadows showing recessed depth. The empty center occupies 85% of the surface, very fine stone and leather grain, extremely subdued. Premium 2.5D sculpted fantasy game surface, not a flat vector. No ornate gold scrolls, no bright gold, no flowers, no wood texture, no jewel, no emblem, no letters, no icon, no text, no UI mockup. One low-contrast textured equipment slot that visually belongs inside the stone tabletop.
