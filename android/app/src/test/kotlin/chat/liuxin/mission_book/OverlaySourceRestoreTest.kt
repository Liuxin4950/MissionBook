package chat.liuxin.mission_book

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 工作包 A 的纯逻辑回归：
 * - capture ticket 与发起来源绑定，ticket 不匹配时丢弃；
 * - 来源（圆形菜单 / 已有会话 / 主动提醒）在成功、取消、授权拒绝、投影失效、失败下都恢复来源；
 * - 截图恢复与主动通知分流，捕获中/待提醒互斥；
 * - 圆形动作顺序与菜单几何（含左右镜像）。
 *
 * 这里不碰 Android View、WindowManager 或 MediaProjection，真机窗口行为仍需设备验收。
 */
class OverlaySourceRestoreTest {
    private val allOutcomes = CaptureOutcome.values().toList()

    @Test
    fun `quick actions origin restores the circular menu for every outcome`() {
        for (outcome in allOutcomes) {
            assertEquals(
                "圆形菜单来源在 $outcome 时应恢复同一组圆形动作",
                OverlayRestorePlan.QuickActions,
                CaptureRestoreRules.plan(CaptureOrigin.QuickActions, outcome),
            )
        }
    }

    @Test
    fun `conversation origin keeps the original draft and only flags delivered on success`() {
        val origin = CaptureOrigin.Conversation("draft-42", "notice-7")
        assertEquals("draft-42", origin.draftKey)
        assertEquals("notice-7", origin.noticeId)
        for (outcome in allOutcomes) {
            val plan = CaptureRestoreRules.plan(origin, outcome) as OverlayRestorePlan.Conversation
            assertEquals("从会话发起的截图必须回到发起时的草稿", "draft-42", plan.draftKey)
            assertEquals(
                "只有成功交付才显示已交付图片",
                outcome == CaptureOutcome.Delivered,
                plan.deliveredImage,
            )
        }
    }

    @Test
    fun `notice origin restores the same notice surface even after cancellation`() {
        for (outcome in allOutcomes) {
            val plan = CaptureRestoreRules.plan(CaptureOrigin.Notice("notice-9"), outcome)
            assertEquals(OverlayRestorePlan.Notice("notice-9"), plan)
        }
    }

    @Test
    fun `unknown origin only restores the bubble and never guesses a panel`() {
        for (outcome in allOutcomes) {
            assertEquals(OverlayRestorePlan.Bubble, CaptureRestoreRules.plan(null, outcome))
        }
    }

    @Test
    fun `capture ticket binding rejects mismatched and missing tickets`() {
        val binding = CaptureTicketBinding("ticket-a", CaptureOrigin.QuickActions)
        assertTrue(binding.matches("ticket-a"))
        assertFalse("来自其它截图的迟到回调不能恢复当前来源", binding.matches("ticket-b"))
        assertFalse(binding.matches(null))
        assertFalse(binding.matches(""))
        // 会话来源的 ticket 同样只认精确身份。
        assertTrue(CaptureTicketBinding("ticket-b", CaptureOrigin.Conversation("draft-1")).matches("ticket-b"))
    }

    @Test
    fun `notice presentation is blocked while capturing or while a notice is pending`() {
        assertTrue(CaptureRestoreRules.noticeAllowed(takingCapture = false, noticePending = false, overlaysAllowed = true))
        assertFalse("截图进行中不能插入主动提醒", CaptureRestoreRules.noticeAllowed(true, false, true))
        assertFalse("同一提醒未处理完不能重复插入", CaptureRestoreRules.noticeAllowed(false, true, true))
        assertFalse("没有悬浮权限不能假装已显示", CaptureRestoreRules.noticeAllowed(false, false, false))
    }

    @Test
    fun `primary and more action order is fixed`() {
        assertEquals(
            listOf("文字", "语音", "截图", "更多"),
            AssistantOverlayQuickMenu.primaryActions.map { it.label },
        )
        assertEquals(
            listOf("会话", "感知", "关闭", "返回"),
            AssistantOverlayQuickMenu.moreActions.map { it.label },
        )
    }

    private fun boxOf(width: Int, height: Int) = OverlayPanelPlacement.Box(0, 0, width, height)
    private fun ballOf(left: Int, top: Int) = OverlayPanelPlacement.Box(left, top, left + 56, top + 56)

    @Test
    fun `menu opens inward with four non-overlapping buttons`() {
        val frame = boxOf(1000, 2000)
        val ball = ballOf(944, 600)
        val placement = AssistantOverlayQuickMenu.place(frame, ball) { it }
        requireNotNull(placement)
        assertEquals("主层始终四个动作", 4, placement.buttons.size)
        for (button in placement.buttons) {
            assertTrue(
                "动作必须完整落在可用区域内：$button",
                button.left >= frame.left && button.top >= frame.top &&
                    button.right <= frame.right && button.bottom <= frame.bottom,
            )
            assertTrue("动作要在主球内侧，不遮挡头像触控", button.right <= ball.left)
        }
        for (i in placement.buttons.indices) {
            for (j in i + 1 until placement.buttons.size) {
                val a = placement.buttons[i]
                val b = placement.buttons[j]
                val overlap = a.left < b.right && b.left < a.right && a.top < b.bottom && b.top < a.bottom
                assertFalse("动作之间不能重叠：$a / $b", overlap)
            }
        }
        assertTrue("动作按上到下排布", placement.buttons.first().top < placement.buttons.last().top)
    }

    @Test
    fun `menu mirrors exactly when the bubble is docked on the left`() {
        val frame = boxOf(1000, 2000)
        val right = requireNotNull(AssistantOverlayQuickMenu.place(frame, ballOf(944, 600)) { it })
        val left = requireNotNull(AssistantOverlayQuickMenu.place(frame, ballOf(0, 600)) { it })
        assertEquals(right.buttons.size, left.buttons.size)
        for (index in right.buttons.indices) {
            val mirrored = right.buttons[index]
            val actual = left.buttons[index]
            assertEquals("第 $index 个动作的纵向位置不随左右镜像改变", mirrored.top, actual.top)
            assertEquals(
                "左右镜像后的横向位置应关于屏幕中线对称",
                frame.width - mirrored.right,
                actual.left,
            )
            assertTrue("左侧球展开时动作在主球内侧", actual.left >= 56)
        }
    }

    @Test
    fun `menu placement refuses frames that cannot hold the arc`() {
        // 可用宽度连一个动作球加半径都放不下时，必须拒绝而不是画出残缺菜单。
        val narrow = boxOf(120, 400)
        assertNull(AssistantOverlayQuickMenu.place(narrow, ballOf(64, 160)) { it })
    }
}
