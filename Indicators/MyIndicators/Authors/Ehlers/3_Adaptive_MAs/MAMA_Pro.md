# MAMA Professional (MESA Adaptive Moving Average)

## 1. Summary (Introduction)

The MAMA (MESA Adaptive Moving Average), developed by John Ehlers, is one of the most sophisticated adaptive moving averages available. Unlike other adaptive averages that adjust to volatility (like KAMA or VIDYA), MAMA adapts in a unique way: it adjusts its speed based on the **rate of change of the market's phase**, as measured by a Hilbert Transform Homodyne Discriminator.

This allows the MAMA to "tune in" to the market's current rhythm. It features a "fast attack, slow decay" mechanism, causing it to rapidly ratchet behind price changes and then hold its value, creating a distinctive step-like appearance.

This indicator plots two lines, forming a complete crossover system:

* **MAMA (MESA Adaptive Moving Average):** The faster, primary adaptive line (red).
* **FAMA (Following Adaptive Moving Average):** A slower, smoother version of the MAMA, which acts as a signal line (blue).

According to Ehlers, the crossover of these two lines creates a trading system that is **"virtually free of whipsaw trades,"** as a cross only occurs after a major, confirmed change in market direction.

## 2. Mathematical Foundations and Calculation Logic

The MAMA is a modified Exponential Moving Average where the smoothing factor (`alpha`) is dynamically calculated on every bar based on the measured rate of phase change of the market cycle.

### Calculation Steps (Algorithm)

The calculation is a complex, multi-stage digital signal processing pipeline:

1. **Cycle Measurement:** The indicator uses a series of filters (Band-Pass, Hilbert Transform, Homodyne Discriminator) to measure the dominant cycle period of the market in real-time. This process is similar to the one used in the Adaptive Laguerre Filter.
2. **Phase Calculation:** From the Hilbert Transform's components (InPhase and Quadrature), the algorithm calculates the current phase angle of the market cycle.
3. **Rate of Phase Change (`DeltaPhase`):** The core of the system. The indicator measures how quickly the phase angle is changing from one bar to the next. A fast-changing phase indicates a short, choppy market cycle, while a slow-changing phase indicates a longer, trending market.
4. **Adaptive Alpha Calculation:** The measured `DeltaPhase` is used to calculate a variable smoothing factor, `alpha`. This `alpha` is constrained between a user-defined `FastLimit` and `SlowLimit`.
    * A rapid phase change results in a small `alpha` (slower moving average).
    * A slow phase change or a "phase snapback" results in a large `alpha` (faster moving average), causing the "ratchet" effect.
5. **MAMA and FAMA Calculation:**
    * The MAMA is calculated as an EMA using the adaptive `alpha`.
    * The FAMA is calculated as an EMA of the MAMA, using `0.5 * alpha` as its smoothing factor, making it inherently slower.

## 3. MQL5 Implementation Details

* **Self-Contained Calculator (`MAMA_Calculator.mqh`):** The entire complex, multi-stage, and highly state-dependent calculation is encapsulated within a dedicated, reusable calculator class.
* **Heikin Ashi Integration:** An inherited `_HA` class allows the calculation to be performed seamlessly on smoothed Heikin Ashi data.
* **Stability via Full Recalculation:** The MAMA algorithm is one of the most state-dependent filters in technical analysis. To ensure absolute stability and prevent desynchronization errors, the indicator employs a **full recalculation** on every `OnCalculate` call. This is the only robust method for this type of DSP filter.

## 4. Parameters

* **Fast Limit (`InpFastLimit`):** The maximum possible value for the adaptive `alpha`. This controls how quickly the MAMA can "attack" or ratchet towards the price. Ehlers' recommended value is **0.5**.
* **Slow Limit (`InpSlowLimit`):** The minimum possible value for the adaptive `alpha`. This controls the MAMA's speed in smooth, trending markets. Ehlers' recommended value is **0.05**.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation. This unified dropdown menu allows you to select from all standard and Heikin Ashi price types.

## 5. Usage and Interpretation

The MAMA/FAMA system is a **complete, low-noise, trend-following crossover strategy**.

### **1. The Crossover Signal (Primary Strategy)**

The core trading signal is the crossover of the two lines. Due to the system's design, crossovers are infrequent and typically signal major, confirmed changes in trend.

* **Buy Signal:** The **red MAMA line crosses above the blue FAMA line**. This indicates the start of a new uptrend.
* **Sell Signal:** The **red MAMA line crosses below the blue FAMA line**. This indicates the start of a new downtrend.

### **2. Position Management**

* **Entry:** Enter a trade on the open of the candle following the crossover.
* **Stop Loss:** Place the initial stop-loss beyond the most recent significant **swing point**.
  * For a Buy signal, place the stop below the last clear swing low that formed before the crossover.
  * For a Sell signal, place the stop above the last clear swing high.
* **Exit:** The most straightforward exit strategy is to hold the position until an **opposite crossover signal** occurs. This is designed to capture the majority of a major trend.

### **3. Recommended Timeframes**

The MAMA system is designed to analyze clear market cycles and trends, making it most effective on mid- to long-term timeframes.

* **Ideal:** **H1, H4, and D1**. On these timeframes, the signals are very reliable and filter out most of the intraday noise.
* **Acceptable for Intraday:** **M15 and M30**. These can be effective, but it is highly recommended to filter signals in the direction of the higher-timeframe trend.
* **Not Recommended:** **M1 and M5**. These timeframes are typically too noisy for the cycle-measuring algorithm to function reliably, which can lead to more frequent and less reliable signals.
