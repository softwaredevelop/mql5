# Positive/Negative Volume Index (PVI/NVI) Professional

## 1. Summary (Introduction)

The Positive Volume Index (PVI) and Negative Volume Index (NVI) are two separate, cumulative indicators that aim to distinguish between the trading activity of the "smart money" (informed, professional traders) and the "uninformed crowd."

The underlying theory posits that:

* **Negative Volume Index (NVI):** Tracks price changes on days with **lower volume** than the previous day. This is thought to represent the activity of the "smart money," who tend to build positions quietly during periods of low market excitement.
* **Positive Volume Index (PVI):** Tracks price changes on days with **higher volume** than the previous day. This is thought to represent the activity of the "uninformed crowd," who are more likely to react to news, hype, and strong price moves.

By observing these two lines, particularly in relation to their own long-term moving averages, traders can gain insight into the underlying strength or weakness of a trend.

## 2. Mathematical Foundations and Calculation Logic

Both indicators are cumulative, starting from a base value (e.g., 1000 or 0). For each bar, the volume is compared to the previous bar's volume to determine which index to update.

### Required Components

* **Price Data (P):** Typically the closing price.
* **Volume (V):** The volume for each bar.

### Calculation Steps (Algorithm)

1. **Initialize:** $\text{PVI}_0 = 1000$; $\text{NVI}_0 = 1000$.
2. **Iterate:** For each subsequent bar `t`:
    * Calculate the price change: $\text{Change}_t = P_t - P_{t-1}$
    * **If $V_t > V_{t-1}$ (Volume Increased):**
        * $\text{PVI}_t = \text{PVI}_{t-1} + \text{Change}_t$
        * $\text{NVI}_t = \text{NVI}_{t-1}$ (Unchanged)
    * **If $V_t < V_{t-1}$ (Volume Decreased):**
        * $\text{NVI}_t = \text{NVI}_{t-1} + \text{Change}_t$
        * $\text{PVI}_t = \text{PVI}_{t-1}$ (Unchanged)
    * **If $V_t = V_{t-1}$:** Both indices remain unchanged.

3. **Signal Lines:** A long-term moving average (typically a 255-period SMA) is calculated on both the PVI and NVI lines to serve as their respective trend benchmarks.

## 3. MQL5 Implementation Details

* **Modular Calculation Engine (`PVI_NVI_Calculator.mqh`):** All mathematical logic is encapsulated in a dedicated include file. The calculator uses a full recalculation loop to ensure the cumulative lines are always accurate.

* **Display Mode for Clarity:** Because the PVI and NVI lines can diverge significantly over time, compressing the vertical scale, the indicator includes a `Display Mode` input. This allows the user to focus on either the PVI or the NVI individually, which automatically adjusts the chart scale for optimal visibility.

* **Platform-Aware Features:** The indicator supports both `Tick Volume` and `Real Volume` and includes robust checks for Real Volume availability. It also fully supports `Heikin Ashi` price data.

## 4. Parameters

* **Display Mode (`InpDisplayMode`):** Allows the user to show only the PVI, only the NVI, or both. Default is `DISPLAY_NVI_ONLY` for focusing on the "smart money" signal.
* **Signal Period (`InpSignalPeriod`):** The period for the long-term moving average applied to both lines. The traditional value is `255`.
* **Signal MA Type (`InpSignalMAType`):** The type of moving average for the signal lines.
* **Volume Type (`InpVolumeType`):** The volume source for the calculation.
* **Candle Source (`InpCandleSource`):** The candle type for the price change calculation.

## 5. Usage and Interpretation

The most common and powerful signals come from the index lines crossing their own long-term moving averages (signal lines).

### NVI (Red Line) - The "Smart Money" Indicator

The NVI is often considered the more significant of the two indicators.

* **Primary Bullish Signal:** When the **NVI (red line) crosses ABOVE its signal line**, it suggests that the "smart money" is accumulating positions on quiet days. According to the original theory, there is a high probability (some analysts claim up to 95%) of a bull market as long as the NVI remains above its signal line.
* **Bearish Warning:** When the NVI crosses below its signal line, it indicates that the "smart money" is no longer supporting the price on quiet days, which can be a warning of a weakening trend.

### PVI (Blue Line) - The "Crowd" Indicator

The PVI tracks the more emotional, news-driven market participants.

* **Trend Confirmation:** When the **PVI (blue line) is rising and above its signal line**, it confirms that the crowd is participating in the trend, which is necessary for a healthy, sustained move.
* **Bearish Warning / Divergence:** A classic warning signal occurs when the price is making new highs, but the PVI is failing to make new highs or is trending down. This suggests that the crowd's enthusiasm is waning and the trend is losing its broad support. A cross of the PVI below its signal line is often seen as a confirmation of bearish pressure.

### Combined Strategy

* **High-Probability Longs:** Look for situations where the **NVI is above its signal line** (smart money is bullish) and the **PVI is also above its signal line** (the crowd is confirming the trend).
* **Potential Top / Major Reversal Warning:** A powerful bearish signal can occur when the **NVI crosses below its signal line** while the **PVI is still high or rising**. This divergence suggests that the smart money is exiting while the crowd is still buying, a classic topping pattern.
