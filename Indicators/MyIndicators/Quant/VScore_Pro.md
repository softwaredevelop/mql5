# V-Score Pro (Indicator)

## 1. Summary

**V-Score Pro** (Volume-Weighted Z-Score) is an institutional-grade quantitative indicator. While standard Z-Scores measure deviation from a simple time-based average (SMA), the V-Score measures the statistical deviation from the **Volume-Weighted Average Price (VWAP)**.

VWAP represents the "True Value"—the average price weighted by actual capital flow. Therefore, V-Score precisely identifies whether the current price is "Expensive" or "Cheap" relative to where the institutional money has been transacted, utilizing a **5-Zone Thermal Heatmap** for zero-latency visual processing.

## 2. Methodology & Logic

The indicator calculates how many Standard Deviations ($\sigma$) the price has stretched away from the VWAP.

### The Formula

$$V\text{-}Score = \frac{\text{Price} - \text{VWAP}}{\sigma_{(Price - VWAP)}}$$

* **Numerator:** The absolute distance between the current price and the VWAP.
* **Denominator:** The standard deviation of this distance over a rolling window ($N$).

### The Institutional Z-Score Levels

The indicator oscillates around **0.0** (Fair Value). Understanding the specific deviation levels is critical for interpreting market phases:

* **0.0 to $\pm$1.0 (The Noise Zone):**
  * *Meaning:* Algorithmic chop. No clear institutional directional flow.
  * *Visual:* Histogram is **Gray** (Neutral).
* **$\pm$1.5 (The Point of No Return):**
  * *Meaning:* The breakout threshold. Statistically, if the price breaches and holds the 1.5 level, the momentum is strong enough that it will likely reach the 2.0 extreme.
  * *Visual:* Marked by a dashed horizontal line. Histogram shifts to **Coral** (Bull Flow) or **LightSkyBlue** (Bear Flow).
* **$\pm$1.5 to $\pm$2.0 (The Flow / Momentum Zone):**
  * *Meaning:* Active institutional accumulation or distribution. This is the optimal zone to be in a trend-following position.
* **$\pm$2.0 to $\pm$2.5 (The Extreme Zone):**
  * *Meaning:* **WARNING.** The trend is statistically overextended. The elastic band is stretched tight.
  * *Action:* Do not open new trend-following positions here.
  * *Visual:* Histogram shifts to **OrangeRed** (Bull Extreme) or **DeepSkyBlue** (Bear Extreme). Marked by solid lines.
* **$\pm$2.5 to $\pm$3.0+ (The Statistical Wall):**
  * *Meaning:* **STOP.** 99% probability of mean reversion or momentum exhaustion.
  * *Action:* Mandatory profit-taking zone. The market is at a climax. Marked by the outermost solid lines.

## 3. MQL5 Implementation Details

* **Engine (`VScore_Calculator.mqh`):**
  * Strictly adheres to **O(1) incremental calculation**. It does not recalculate the history on every tick, ensuring zero performance drop even on 1-second charts.
  * Integrates the `CVWAPCalculator` engine to ensure the VWAP baseline matches standard institutional calculations.
* **Visuals (`VScore_Pro.mq5`):**
  * **5-Color Thermal Heatmap:** Groups complex statistical data into an easily readable format (Gray $\rightarrow$ Warming/Cooling $\rightarrow$ Hot/Freezing).
  * Explicitly draws the 1.5 (Dashed), 2.0 (Solid), and 2.5 (Solid) reference levels.

## 4. Parameters

* `InpPeriod`: The rolling window for standard deviation calculation (Default: `20`). A shorter period makes the indicator more sensitive and volatile.
* `InpVWAPReset`: The anchor for the VWAP calculation.
  * `PERIOD_SESSION` (Default): Resets daily. Used for Intraday trading.
  * `PERIOD_WEEK`: Resets weekly. Used for Swing trading.
  * `PERIOD_MONTH`: Resets monthly. Used for Position trading.

## 5. Strategic Usage

1. **The "Point of No Return" Breakout:**
    Wait for the V-Score to cross above **+1.5** (Coral) or below **-1.5** (LightSkyBlue) with strong price action. This confirms that the move out of the "Noise" zone is legitimate and has institutional backing.
2. **Mandatory Profit Taking (The Wall):**
    If you are in a Long position and the V-Score touches or exceeds **+2.5**, instantly scale out or close the position. Do not be greedy; statistical exhaustion is guaranteed.
3. **Absorption / Divergence (BULL_ABS / BEAR_ABS):**
    If the price makes a *New High*, but the V-Score fails to reach the Extreme Zone (> 2.0) and stays lower than it was at the previous price high, this is **Bull Absorption** (exhaustion of buyers). A sharp mean-reversion drop to the VWAP (0.0) is imminent.
4. **Squeeze Confluence:**
    If `Squeeze_Pro` indicates a Squeeze (Low Volatility) and the V-Score is near **0.0**, a massive, high-R/R move is loading, ready to launch directly from Fair Value.
