package com.nanatechcreativestudios.weather

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlin.math.roundToInt

/// The home-screen widget: the GPS city's current weather.
///
/// One layout for both sizes (2x2 compact and 4x2 full) — the content
/// is the same, the compact widget just shows it in less space. This is
/// deliberate: Glance's LocalSize.current cannot be read in this module,
/// because the Kotlin JVM backend cannot inline the inline getter
/// CompositionLocal.current (Compose runtime 1.7.8) here — it crashed
/// the build twice, inside WidgetContent and inside the provideContent
/// lambda alike. So there is no size branching at all. The same rule
/// applies to Glance's currentState(): build #10 crashed inlining it
/// inside the provideContent lambda ("couldn't find inline
/// method/androidx/glance/CompositionLocalsKt;currentState()"), so the
/// widget state is read outside the composable instead, from the same
/// SharedPreferences currentState() reads (see provideGlance). And the
/// tap action's Intent is built by hand rather than through
/// home_widget's inline reified actionStartActivity helper, so that no
/// inline call from another module is left anywhere in this file —
/// this toolchain has now failed to inline two of them. Content is
/// gated, not the widget itself — free users see a locked upsell,
/// Premium users see live data, and a fresh install with no data yet
/// asks the user to open the app. Tapping the widget opens the app; a
/// tap on the locked widget opens it straight to the paywall.
class WeatherWidget : GlanceAppWidget() {

    override val stateDefinition = HomeWidgetGlanceStateDefinition()

    override val sizeMode = SizeMode.Responsive(
        setOf(
            DpSize(110.dp, 110.dp),
            DpSize(250.dp, 110.dp),
        ),
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Read the widget state here, in the suspend function, and pass
        // it into the composable as a plain value — exactly how
        // providePreview already does it below. Glance's currentState()
        // is an inline @Composable function, and this toolchain cannot
        // inline it in this module (build #10). HomeWidgetPlugin.getData
        // reads the very same SharedPreferences the Glance state
        // definition reads, so the data is identical.
        val state = HomeWidgetGlanceState(HomeWidgetPlugin.getData(context))
        provideContent { WidgetContent(context, state) }
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
        // Build the launch Intent by hand instead of home_widget's
        // actionStartActivity<MainActivity>() helper: that helper is an
        // inline reified function, and this toolchain has now failed to
        // inline two cross-module inline calls (builds #8–#10). The
        // Intent below is exactly what the helper builds, and Glance's
        // own actionStartActivity(intent) is a plain function call.
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            data = Uri.parse(
                "weatherapp://widget?target=" +
                    if (data.state == "locked") "paywall" else "home",
            )
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        }
        val openApp = actionStartActivity(launchIntent)

        Box(
            modifier = GlanceModifier.fillMaxSize()
                .background(Color(0xFF2B5FA8))
                .padding(12.dp)
                .clickable(onClick = openApp),
        ) {
            when (data.state) {
                "live" -> LiveContent(data)
                "locked" -> LockedContent()
                else -> NoDataContent()
            }
        }
    }

    @Composable
    private fun LiveContent(data: WidgetData) {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.Vertical.Top,
        ) {
            Text(
                data.city,
                style = TextStyle(
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(Color.White),
                ),
                maxLines = 1,
            )
            Text(
                data.temp,
                style = TextStyle(
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(Color.White),
                ),
            )
            Text(
                "${data.condition} · ${data.feelsLike}",
                style = TextStyle(fontSize = 12.sp, color = ColorProvider(Color.White)),
                maxLines = 1,
            )
            if (data.dialogue.isNotEmpty()) {
                Text(
                    data.dialogue,
                    style = TextStyle(fontSize = 11.sp, color = ColorProvider(Color.White)),
                    maxLines = 1,
                )
            }
        }
    }

    @Composable
    private fun LockedContent() {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Text(
                "★ Premium",
                style = TextStyle(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(Color.White),
                ),
            )
            Text(
                "Widgets are a Premium feature — tap to upgrade.",
                style = TextStyle(fontSize = 12.sp, color = ColorProvider(Color.White)),
                maxLines = 3,
            )
        }
    }

    @Composable
    private fun NoDataContent() {
        Column(
            modifier = GlanceModifier.fillMaxSize(),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Text(
                "Weather App",
                style = TextStyle(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = ColorProvider(Color.White),
                ),
            )
            Text(
                "Open the app to load weather.",
                style = TextStyle(fontSize = 12.sp, color = ColorProvider(Color.White)),
            )
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
        Double.fromBits(
            getLong(key, java.lang.Double.doubleToRawLongBits(default)),
        )
    } else {
        getFloat(key, default.toFloat()).toDouble()
    }
}

class WeatherWidgetReceiver : HomeWidgetGlanceWidgetReceiver<WeatherWidget>() {
    override val glanceAppWidget = WeatherWidget()
}
