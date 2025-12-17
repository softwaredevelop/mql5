# Heikin Ashi Objects (High-Fidelity)

## 1. Summary (Introduction)

The `Chart_HeikinAshi_Objects` is a specialized version of the Heikin Ashi indicator designed for traders who demand **maximum visual clarity and sharpness**.

Standard MetaTrader 5 indicators use a rendering engine that can sometimes blur the edges of candles or lack specific customization options. This indicator bypasses the standard rendering engine by drawing each Heikin Ashi candle using precise **graphical objects** (`OBJ_TREND`).

The result is a crisp, pixel-perfect chart representation with fully customizable colors and line widths, immune to the blurring effects of the platform's graphics smoothing.

## 2. Features and Logic

* **Object-Based Rendering:** Instead of using indicator buffers (`DRAW_CANDLES`), this tool draws each candle body and wick as separate graphical objects.
* **Unified Trend Objects:** Both the candle body and the wick are drawn using `OBJ_TREND` with different widths. This technique ensures pixel-perfect width control regardless of the timeframe zoom.
* **Full Customization:** You can independently set the pixel width for the Body and Wick, choose custom colors for Bullish and Bearish candles, and decide whether to draw them in the background or foreground.
* **Performance Optimization:** Drawing thousands of objects can be resource-intensive. To maintain high performance, the indicator includes a `Max History` parameter, limiting the drawing to the most recent bars (e.g., the last 500).

## 3. Parameters

### Visual Settings

* **`InpMaxHistory`:** The number of recent bars to draw.
  * Default: `500`.
  * *Recommendation:* Keep this value reasonably low (300-1000) to ensure the chart remains responsive. Drawing objects for the entire history is not recommended.
* **`InpBodyWidth`:** The width of the candle body in pixels.
  * Default: `3`.
  * Increase this value if you use high zoom levels or high-DPI screens.
* **`InpWickWidth`:** The width of the candle wick in pixels.
  * Default: `1`.
* **`InpColorBull`:** The color for bullish (up) candles.
  * Default: `clrCornflowerBlue`.
* **`InpColorBear`:** The color for bearish (down) candles.
  * Default: `clrChocolate`.
* **`InpBack`:** Controls the Z-order of the candles.
  * `true`: Draws candles in the background (behind the Bid/Ask line and other indicators).
  * `false`: Draws candles in the foreground.

## 4. Usage

Use this indicator as a direct replacement for the standard `Chart_HeikinAshi` if you find the standard rendering too blurry or need specific color schemes not tied to the chart properties.

1. Attach the indicator to the chart.
2. Adjust the `Body Width` until the candles look substantial enough for your screen resolution.
3. Set your preferred Bull/Bear colors.
4. Ensure `Max History` covers your active analysis window.

*Note: The objects are created with `OBJPROP_SELECTABLE = false` to prevent accidental selection while analyzing the chart.*
