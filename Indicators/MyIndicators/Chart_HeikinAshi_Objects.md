# Heikin Ashi Objects (High-Fidelity)

## 1. Summary (Introduction)

The `Chart_HeikinAshi_Objects` is a specialized version of the Heikin Ashi indicator designed for traders who demand **maximum visual clarity and sharpness**.

Standard MetaTrader 5 indicators use a rendering engine (Blend2D) that can sometimes blur the edges of candles, especially on high-resolution screens or with specific settings. This indicator bypasses the standard rendering engine by drawing each Heikin Ashi candle using precise **graphical objects** (`OBJ_TREND`).

The result is a crisp, pixel-perfect chart representation with fully customizable line widths, immune to the blurring effects of the platform's graphics smoothing.

## 2. Features and Logic

* **Object-Based Rendering:** Instead of using indicator buffers (`DRAW_CANDLES`), this tool draws each candle body and wick as a separate graphical object. This ensures sharp edges and distinct colors.
* **Customizable Widths:** You can independently set the pixel width for the candle **Body** and the **Wick**. This allows for better visibility on 4K monitors or specific zoom levels.
* **Performance Optimization:** Drawing thousands of objects can be resource-intensive. To maintain high performance, the indicator includes a `Max History` parameter, limiting the drawing to the most recent bars (e.g., the last 500).

## 3. Parameters

* **`InpMaxHistory`:** The number of recent bars to draw.
  * Default: `500`.
  * *Recommendation:* Keep this value reasonably low (300-1000) to ensure the chart remains responsive. Drawing objects for the entire history (e.g., 100,000 bars) is not recommended.
* **`InpBodyWidth`:** The width of the candle body in pixels.
  * Default: `3`.
  * Increase this value if you use high zoom levels or high-DPI screens.
* **`InpWickWidth`:** The width of the candle wick in pixels.
  * Default: `1`.

## 4. Usage

Use this indicator as a direct replacement for the standard `Chart_HeikinAshi` if you find the standard rendering too blurry or indistinct.

1. Attach the indicator to the chart.
2. Adjust the `Body Width` until the candles look substantial enough for your screen resolution.
3. Ensure `Max History` covers your active analysis window (e.g., 500 bars is usually enough for intraday trading).

*Note: Since this indicator uses objects, you can click on individual candles to see their properties, although they are set to non-selectable by default to avoid interfering with chart navigation.*
