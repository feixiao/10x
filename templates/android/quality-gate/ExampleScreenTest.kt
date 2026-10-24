package com.example.qualitygate

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import org.junit.Test

/**
 * 4 状态黄金 UI 快照测试范例。
 * AI 每次完成一个 Compose Screen，必须生成 Default、Loading、Error、DarkMode 四张截图。
 */
class ExampleScreenTest : BaseScreenshotTest() {

    @Composable
    private fun PreviewTheme(darkTheme: Boolean = false, content: @Composable () -> Unit) {
        MaterialTheme(
            colorScheme = if (darkTheme) darkColorScheme() else lightColorScheme(),
            content = content
        )
    }

    @Test
    fun renderDefaultState() {
        captureContent("ExampleScreen_Default") {
            PreviewTheme {
                // ExampleScreenContent(uiState = ExampleUiState.Content(...), onIntent = {})
            }
        }
    }

    @Test
    fun renderLoadingState() {
        captureContent("ExampleScreen_Loading") {
            PreviewTheme {
                // ExampleScreenContent(uiState = ExampleUiState.Loading, onIntent = {})
            }
        }
    }

    @Test
    fun renderErrorState() {
        captureContent("ExampleScreen_Error") {
            PreviewTheme {
                // ExampleScreenContent(uiState = ExampleUiState.Error("网络连接失败 (500)"), onIntent = {})
            }
        }
    }

    @Test
    fun renderDarkMode() {
        captureContent("ExampleScreen_DarkMode") {
            PreviewTheme(darkTheme = true) {
                // ExampleScreenContent(uiState = ExampleUiState.Content(...), onIntent = {})
            }
        }
    }
}
