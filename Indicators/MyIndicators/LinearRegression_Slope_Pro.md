# Linear Regression Slope Pro (Indicator)

## 1. Summary

**Linear Regression Slope Pro** is a "Smart Momentum" oscillator. It visualizes the **Velocity** (speed) of the price trend using Linear Regression, while simultaneously color-coding the bars based on the **Quality** (reliability) of that trend.

It answers two questions at once:

1. *"How fast is the price moving?"* (Height of the bar).
2. *"Is the move clean or choppy?"* (Color of the bar).

## 2. Methodology & Logic

The indicator combines two powerful statistical metrics:

### A. Normalized Slope (Velocity)

We calculate the slope of the Linear Regression line over $N$ periods. To make this value comparable across different assets (e.g. BTC vs EURUSD), we normalize it by volatility (ATR).

* **Formula:** `Slope_Value / ATR`.
* A value of **+0.5** means the price is rising at a rate of 0.5 ATR per bar.

### B. R-Squared (Quality Filter)

We use the Coefficient of Determination ($R^2$) to check if the slope is trustworthy.

* **Formula:** Standard $R^2$ calculation.
* **Logic:**
  * High $R^2$ (> 0.7) = The price points are tightly clustered around the regression line. **Valid Trend.**
  * Low $R^2$ (< 0.7) = The price points are scattered. **Noisy/Weak Trend.**

## 3. Visualization Check

The indicator uses a **Dual-State Coloring System**:

### Positive Slope (Rising Trend)

* 🟢 **Lime (Bright Green):** **Strong Bull.** Velocity is Up AND $R^2 > 0.7$. This is the "Green Light" for long entries. The trend is fast and stable.
* 🌲 **Sea Green (Dark Green):** **Weak Bull.** Velocity is Up BUT $R^2 < 0.7$. The price is rising, but it's choppy or unstable. Caution advised.

### Negative Slope (Falling Trend)

* 🔴 **Red (Bright Red):** **Strong Bear.** Velocity is Down AND $R^2 > 0.7$. This is the "Red Light" for short entries.
* 🟤 **Maroon (Dark Red):** **Weak Bear.** Velocity is Down BUT $R^2 < 0.7$. Falling but choppy.

## 4. Parameters

* `InpPeriod`: The lookback window for the Linear Regression (Default: `20`).
* `InpATRPeriod`: The window for volatility normalization (Default: `14`).
* `InpStrongR2`: The quality threshold. Trends with $R^2$ above this level get the "Bright" color (Default: `0.7`).

## 5. Strategic Usage

1. **Sniper Entry:** Look for the moment the histogram switches from Dark color to **Bright Color (Lime/Red)**. This signals a transition from "Chop" to "Clean Trend".
2. **Divergence:** If price makes a higher high, but the Slope Histogram makes a lower high (momentum loss), prepare for a reversal.
3. **Filter:** Avoid trading in the direction of the slope if the color is Dark (Sea Green/Maroon), as the risk of "whipsaw" is high. Wait for the Bright bars.
