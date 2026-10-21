# Android icon v4 — MB 书脊

用户选择：2026-10-21，第 04 版。参考：[确认的概念稿](concepts/2026-10-21/04-MB书脊.png)。

## 最终资源

- 概念稿由内置 image_gen 生成，完整创意提示词见概念目录。
- 内置 image_gen 尝试提取透明前景后，边缘仍有杂点；提取结果未用于应用。
- 正式图按确认稿整理为三条闭合矢量路径，保存于 `mission_book_icon_v4.svg`、`mission_book_logo_v4.svg`；单色 Android VectorDrawable 共享同一组路径。
- 统一填色：米白 `#F7F4EA`、森林绿 `#173F35`。108 dp 自适应前景围绕 (54,54) 居中；五档 PNG 由 SVG 经 Sharp 渲染导出，不从低分辨率图片放大。
- 自适应前景母版 1080×1080；彩色方形母版 1024×1024；旧 v3 两份母版存入 `archive/v3/`。本次导出临时脚本留在聊天工作区，未恢复已删除的仓库工具目录。

## 透明提取提示词（制作过程，未采用的中间结果）

Use case: background-extraction / precise-object-edit. The reference is the user-approved Mission Book concept 04 MB book-spine. Extract and faithfully reconstruct ONLY THE IVORY OPEN-BOOK SYMBOL INSIDE THE RIGHT-HAND GREEN APP TILE as a production Android adaptive icon foreground. Preserve its exact distinctive silhouette: two upright broad book pages, a narrow central transparent spine slit, the tiny angular notch in left page, and the two rounded B-like page lobes on the right separated by a broad curved transparent cut. Match the reference geometry rather than redesigning. Use one perfectly uniform warm ivory #F7F4EA solid fill, flat vector-like edges, clean antialiasing. Genuine transparent PNG background. A single centered symbol on a square canvas, symbol approximately 65 percent width, maintain original width-to-height ratio, generous transparent margins. Remove green tile entirely, remove all text, numbers, wordmarks, background, shadows, gradients, paper texture, highlights. No green pixels or outline, no enclosing tile, no checkmark, no extra symbols. This is the finalized minimal MB open book silhouette, not a new concept.
