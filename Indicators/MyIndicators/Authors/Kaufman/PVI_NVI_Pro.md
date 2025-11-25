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

The most common and powerful signals come from the index lines crossing their own long-term moving averages (signal lines). The NVI is generally considered the more significant, leading indicator of the pair.

### NVI (Red Line) - The "Smart Money" Indicator

* **Primary Bullish Signal:** When the **NVI (red line) crosses ABOVE its signal line**, it suggests that the "smart money" is accumulating positions on quiet days. According to the original theory, there is a high probability of a bull market as long as the NVI remains above its signal line.
* **Bearish Warning:** When the NVI crosses below its signal line, it indicates that the "smart money" is no longer supporting the price on quiet days.

### PVI (Blue Line) - The "Crowd" Indicator

* **Trend Confirmation:** When the **PVI (blue line) is rising and above its signal line**, it confirms that the crowd is participating in the trend.
* **Bearish Warning / Divergence:** A classic warning signal occurs when the price is making new highs, but the PVI is failing to make new highs or is trending down. This suggests that the crowd's enthusiasm is waning.

### **Practical Strategies for Intraday Trading**

For intraday trading, the PVI/NVI is most effective when used in a **"top-down" approach**. This means using the indicator on a higher, "contextual" timeframe to determine the main trading bias, and then executing trades on a lower, "trading" timeframe.

#### Strategy 1: The NVI as a Master Trend Filter

This is the simplest and most robust way to use the indicator. The goal is to trade only in the direction favored by the "smart money."

1. **Setup:**
    * Open two charts of the same instrument.
    * On a **higher timeframe chart** (e.g., H1), apply the `PVI_NVI_Pro` indicator. Set the `Display Mode` to `DISPLAY_NVI_ONLY`. This is your "Compass Chart."
    * On your **lower, trading timeframe chart** (e.g., M5), apply your preferred entry indicators (e.g., Stochastics, MACD, Price Action patterns).

2. **Rules:**
    * If, on the H1 chart, the **NVI (red line) is ABOVE its signal line**, the primary bias is **BULLISH**. On your M5 chart, you should **only look for and take LONG (buy) signals**. Ignore all short signals.
    * If, on the H1 chart, the **NVI is BELOW its signal line**, the primary bias is **BEARISH**. On your M5 chart, you should **only look for and take SHORT (sell) signals**. Ignore all long signals.

#### Suggested Timeframe Combinations

| Trading Style | Trading Timeframe | PVI/NVI "Compass" Timeframe |
| :--- | :--- | :--- |
| Scalping | M1 | M15 or M30 |
| Fast Day Trading | M5 | H1 |
| Standard Day Trading | M15 | H4 |

#### Strategy 2: Advanced Divergence (Topping/Bottoming Signal)

This is a leading, but more advanced, signal for potential major reversals.

* **Potential Top (Bearish Divergence):** Look for a situation where the price makes a new high, the **PVI (crowd) also makes a new high**, but the **NVI (smart money) fails to make a new high** and forms a lower high. This indicates that professionals are no longer participating in the rally, which is being driven solely by the less-informed crowd—a classic sign of a top.
* **Potential Bottom (Bullish Divergence):** Look for a situation where the price makes a new low, but the **NVI forms a higher low**. This suggests that the "smart money" has stopped selling and is beginning to accumulate, even as the crowd continues to panic-sell.
