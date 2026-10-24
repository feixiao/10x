package com.example.qualitygate

import androidx.compose.runtime.Composable
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.RoborazziRule
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * JVM 纯端渲染截图测试基类（免模拟器，单张渲染约 100~300ms）。
 * 统一渲染设备尺寸与像素密度，供所有 Feature 页面截图复用。
 */
@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w390dp-h844dp-xhdpi", application = android.app.Application::class)
abstract class BaseScreenshotTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @get:Rule
    val roborazziRule = RoborazziRule(
        options = RoborazziRule.Options(
            outputDirectoryPath = "screenshots"
        )
    )

    fun captureContent(filename: String, content: @Composable () -> Unit) {
        composeTestRule.setContent(content)
        composeTestRule.onRoot().captureRoboImage("screenshots/$filename.png")
    }
}
