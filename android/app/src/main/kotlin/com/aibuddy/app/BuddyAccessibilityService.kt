package com.aibuddy.app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/// On-device automation backbone: lets AI-Buddy read what is on screen and
/// operate ANY other app on the user's behalf (tap, type, scroll, navigate).
///
/// The service holds no logic of its own — MainActivity drives it through the
/// `com.aibuddy.app/accessibility` method channel, which forwards the LLM's
/// intent. The user must enable it once in system Accessibility settings; until
/// then [instance] stays null and every call reports "not enabled".
class BuddyAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: BuddyAccessibilityService? = null
            private set

        const val TAG = "BuddyA11y"
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.d(TAG, "Accessibility service connected")
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    // We drive the service on demand; passively observing every event would only
    // waste battery, so the callbacks stay empty.
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    // ── Screen reading ──────────────────────────────────────────────────────

    /// Flatten the active window into a list of interactable/labelled nodes so
    /// the LLM can "see" the screen as text and decide what to act on.
    fun readScreen(): List<Map<String, Any>> {
        val root = rootInActiveWindow ?: return emptyList()
        val out = mutableListOf<Map<String, Any>>()
        try {
            collect(root, out)
        } catch (e: Exception) {
            Log.e(TAG, "readScreen error: $e")
        } finally {
            root.recycle()
        }
        return out
    }

    private fun collect(node: AccessibilityNodeInfo?, out: MutableList<Map<String, Any>>) {
        if (node == null || out.size >= 400) return
        val text = node.text?.toString()?.trim().orEmpty()
        val desc = node.contentDescription?.toString()?.trim().orEmpty()
        val label = if (text.isNotEmpty()) text else desc

        if (label.isNotEmpty() && (node.isVisibleToUser)) {
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            out.add(
                mapOf(
                    "text" to label,
                    "clickable" to node.isClickable,
                    "editable" to node.isEditable,
                    "scrollable" to node.isScrollable,
                    "x" to bounds.centerX(),
                    "y" to bounds.centerY(),
                    "class" to (node.className?.toString() ?: ""),
                )
            )
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            collect(child, out)
            child?.recycle()
        }
    }

    /// Return the package of the app currently in the foreground (best effort).
    fun currentPackage(): String = rootInActiveWindow?.packageName?.toString() ?: ""

    // ── Actions ─────────────────────────────────────────────────────────────

    /// Click the first visible node whose text/description matches [query]
    /// (case-insensitive, exact → prefix → contains). Falls back to tapping the
    /// node's centre via a gesture when the node itself is not directly clickable.
    fun tapByText(query: String): Boolean {
        val root = rootInActiveWindow ?: return false
        try {
            val target = findByText(root, query) ?: return false
            // Walk up to the nearest clickable ancestor — labels are often inside
            // a clickable container rather than being clickable themselves.
            var node: AccessibilityNodeInfo? = target
            while (node != null && !node.isClickable) {
                node = node.parent
            }
            if (node != null && node.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return true
            }
            val bounds = Rect()
            target.getBoundsInScreen(bounds)
            return tapAt(bounds.centerX(), bounds.centerY())
        } catch (e: Exception) {
            Log.e(TAG, "tapByText error: $e")
            return false
        } finally {
            root.recycle()
        }
    }

    private fun findByText(root: AccessibilityNodeInfo, query: String): AccessibilityNodeInfo? {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return null

        // Exact matches provided by the framework are cheapest and most reliable.
        root.findAccessibilityNodeInfosByText(query)?.let { matches ->
            matches.firstOrNull { it.isVisibleToUser }?.let { return it }
        }

        // Fallback: manual walk scoring prefix > contains on text OR description.
        var best: AccessibilityNodeInfo? = null
        var bestScore = 0
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        var guard = 0
        while (stack.isNotEmpty() && guard < 2000) {
            guard++
            val node = stack.removeLast()
            val label = (node.text?.toString() ?: node.contentDescription?.toString() ?: "")
                .trim().lowercase()
            if (label.isNotEmpty() && node.isVisibleToUser) {
                val score = when {
                    label == q -> 100
                    label.startsWith(q) -> 80
                    label.contains(q) -> 60
                    else -> 0
                }
                if (score > bestScore) {
                    bestScore = score
                    best = node
                }
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { stack.addLast(it) }
            }
        }
        return best
    }

    /// Dispatch a short tap gesture at absolute screen coordinates.
    fun tapAt(x: Int, y: Int): Boolean {
        return try {
            val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 60))
                .build()
            dispatchGesture(gesture, null, null)
        } catch (e: Exception) {
            Log.e(TAG, "tapAt error: $e")
            false
        }
    }

    /// Type [text] into the currently focused editable field, or the first
    /// editable field found. Replaces existing content.
    fun inputText(text: String): Boolean {
        val root = rootInActiveWindow ?: return false
        try {
            val field = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
                ?: firstEditable(root)
                ?: return false
            val args = Bundle().apply {
                putCharSequence(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                    text
                )
            }
            return field.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        } catch (e: Exception) {
            Log.e(TAG, "inputText error: $e")
            return false
        } finally {
            root.recycle()
        }
    }

    private fun firstEditable(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        var guard = 0
        while (stack.isNotEmpty() && guard < 2000) {
            guard++
            val node = stack.removeLast()
            if (node.isEditable && node.isVisibleToUser) return node
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { stack.addLast(it) }
            }
        }
        return null
    }

    /// Scroll the first scrollable container forward/backward.
    fun scroll(forward: Boolean): Boolean {
        val root = rootInActiveWindow ?: return false
        try {
            val scrollable = findScrollable(root) ?: return false
            val action = if (forward) {
                AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
            } else {
                AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
            }
            return scrollable.performAction(action)
        } catch (e: Exception) {
            Log.e(TAG, "scroll error: $e")
            return false
        } finally {
            root.recycle()
        }
    }

    private fun findScrollable(root: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.addLast(root)
        var guard = 0
        while (stack.isNotEmpty() && guard < 2000) {
            guard++
            val node = stack.removeLast()
            if (node.isScrollable && node.isVisibleToUser) return node
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { stack.addLast(it) }
            }
        }
        return null
    }

    fun back(): Boolean = performGlobalAction(GLOBAL_ACTION_BACK)
    fun home(): Boolean = performGlobalAction(GLOBAL_ACTION_HOME)
    fun recents(): Boolean = performGlobalAction(GLOBAL_ACTION_RECENTS)
    fun notifications(): Boolean = performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
}
