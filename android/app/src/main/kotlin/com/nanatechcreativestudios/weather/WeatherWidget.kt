package com.nanatechcreativestudios.weather

import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.actionStartActivity
import kotlin.math.roundToInt

/// The home-screen widget: the GPS city's current weather.
///
/// Two sizes: 2x2 (compact) and 4x2 (full). Content is gated, not the
/// widget itself — free users see a locked upsell, Premium users see
/// live data, and a fresh install with no data yet asks the user to
/// open the app. Tapping the widget opens the app; a tap on the locked
/// widget opens it straight to the paywall.
class WeatherWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override val sizeMode = SizeMode.Responsive(
        setOf(
            DpSize(110.dp, 110.dp),
            DpSize(250.dp, 110.dp),
        ),
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { WidgetContent(context, currentState()) }
    }

    override suspend fun providePreview(context: Context, widgetCategory: Int) {
        provideContent {
            WidgetContent(
                context,
                HomeWidgetGlanceState(HomeWidgetPlugin.getData(context)),
                preview = true,
            )
        }
    }

    @Composable
    private fun WidgetContent(
        context: Context,
        state: HomeWidgetGlanceState,
        preview: Boolean = false,
    ) {
        val data = readData(state.preferences, preview)
        val isSmall = LocalSize.current.width < 180.dp
        val openApp = actionStartActivity<MainActivity>(
            context,
            Uri.parse(
                "weatherapp://widget?target=" +
                    if (data.state == "locked") "paywall" else "home",
            ),
        )

        Box(
            modifier = GlanceModifier.fillMaxSize()
                .background(Color(0xFF2B5FA8))
                .padding(12.dp)
                .clickable(onClick = openApp),
        ) {
            when (data.state) {
                "live" -> LiveContent(data, isSmall)
                "locked" -> LockedContent(isSmall)
                else -> NoDataContent(isSmall)
            }
        }
    }

    @Composable
    private fun LiveContent(data: WidgetData, isSmall: Boolean) {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.Vertical.Top,
        ) {
            Text(
                data.city,
                style = TextStyle(
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                ),
            )
            Text(
                data.temp,
                style = TextStyle(
                    fontSize = 34.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                ),
            )
            Text(
                "${data.condition} · ${data.feelsLike}",
                style = TextStyle(fontSize = 13.sp, color = Color.White),
            )
            if (!isSmall && data.dialogue.isNotEmpty()) {
                Text(
                    data.dialogue,
                    style = TextStyle(fontSize = 12.sp, color = Color.White),
                    maxLines = 2,
                )
            }
        }
    }

    @Composable
    private fun LockedContent(isSmall: Boolean) {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.Vertical.Center,
        ) {
            Text(
                "★ Premium",
                style = TextStyle(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                ),
            )
            if (!isSmall) {
                Text(
                    "Widgets are a Premium feature — tap to upgrade.",
                    style = TextStyle(fontSize = 12.sp, color = Color.White),
                    maxLines = 3,
                )
            }
        }
    }

    @Composable
    private fun NoDataContent(isSmall: Boolean) {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.Vertical.Center,
        ) {
            Text(
                "Weather App",
                style = TextStyle(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                ),
            )
            if (!isSmall) {
                Text(
                    "Open the app to load weather.",
                    style = TextStyle(fontSize = 12.sp, color = Color.White),
                )
            }
        }
    }

    private data class WidgetData(
        val state: String,
        val city: String,
        val temp: String,
        val feelsLike: String,
        val condition: String,
        val dialogue: String,
    )

    private fun readData(prefs: SharedPreferences, preview: Boolean): WidgetData {
        val state = prefs.getString("widget_state", "nodata") ?: "nodata"
        if (preview && state != "live" && state != "locked") {
            // The launcher gallery preview, before any real data exists.
            return WidgetData(
                state = "live",
                city = "Mesa, Arizona",
                temp = "72°",
                feelsLike = "Feels like 74°",
                condition = "Clear",
                dialogue = "Sunny and clear. Your sunglasses called — they want to go outside.",
            )
        }
        return WidgetData(
            state = state,
            city = prefs.getString("widget_city", "") ?: "",
            temp = "${prefs.getWidgetDouble("widget_temp", 0.0).roundToInt()}°",
            feelsLike =
                "Feels like ${prefs.getWidgetDouble("widget_feels_like", 0.0).roundToInt()}°",
            condition = prefs.getString("widget_condition", "") ?: "",
            dialogue = prefs.getString("widget_dialogue", "") ?: "",
        )
    }
}

/// home_widget stores doubles as raw long bits with a
/// "home_widget.double.<key>" flag, so read them back the same way.
private fun SharedPreferences.getWidgetDouble(key: String, default: Double): Double {
    return if (getBoolean("home_widget.double.$key", false)) {
        Double.longBitsToDouble(
            getLong(key, java.lang.Double.doubleToRawLongBits(default)),
        )
    } else {
        getFloat(key, default.toFloat()).toDouble()
    }
}

class WeatherWidgetReceiver : HomeWidgetGlanceWidgetReceiver<WeatherWidget>() {
    override val glanceAppWidget = WeatherWidget()
}
