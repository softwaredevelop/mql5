# Adaptive RSI Professional

## 1. Summary (Introduction)

The `RSI_Adaptive_Pro` is an advanced version of the Relative Strength Index that dynamically adjusts its own lookback period based on market volatility. This concept, also known as the Dynamic Momentum Index (a different concept from Wilder's DMI), aims to create a more responsive RSI in trending markets and a smoother RSI in ranging markets.

The core logic is to:

* **Shorten** the RSI period when volatility is high (strong trend), making the oscillator more sensitive to price changes.
* **Lengthen** the RSI period when volatility is low (sideways market), making the oscillator smoother and less prone to generating false signals.

This indicator provides a unique perspective on momentum, offering a different character compared to the classic, fixed-period RSI.

## 2. Mathematical Foundations and Calculation Logic

The indicator first calculates a volatility ratio and then uses it to determine the appropriate RSI period for each bar.

### Required Components

* **Pivotal Period (N):** The central or "normal" RSI period around which the adaptive period will fluctuate.
* **Volatility Periods (S, L):** A short (`S`) and long (`L`) period for measuring volatility.
* **Source Price (P)**.

### Calculation Steps (Algorithm)

1. **Calculate Volatility Ratio:** The indicator measures volatility by comparing the recent sum of price changes to its longer-term average.
    * $\text{Short-Term Volatility}_t = \sum_{i=0}^{S-1} \text{Abs}(P_{t-i} - P_{t-i-1})$
    * $\text{Long-Term Volatility}_t = \text{SMA}(\text{Short-Term Volatility}, L)_t$
    * $\text{Volatility Ratio}_t = \frac{\text{Short-Term Volatility}_t}{\text{Long-Term Volatility}_t}$

2. **Calculate the Adaptive RSI Period (NSP):** The Volatility Ratio is used to adjust the pivotal period.
    * $\text{NSP}_t = \text{Integer}[\frac{N}{\text{Volatility Ratio}_t}]$
    * The calculated period is then clamped within a reasonable range (e.g., between 2 and `N*2`) to prevent extreme values.

3. **Calculate the Simple RSI with the Adaptive Period:** For maximum stability with a constantly changing period, a **Simple RSI** is calculated on each bar using the dynamic `NSP`.
    * $\text{Sum Up}_t = \text{Sum of positive price changes over the last NSP}_t \text{ bars}$
    * $\text{Sum Down}_t = \text{Sum of absolute negative price changes over the last NSP}_t \text{ bars}$
    * $\text{Adaptive RSI}_t = 100 \times \frac{\text{Sum Up}_t}{\text{Sum Up}_t + \text{Sum Down}_t}$

## 3. MQL5 Implementation Details

* **Self-Contained Calculation Engine (`RSI_Adaptive_Calculator.mqh`):** The entire multi-stage calculation logic is encapsulated within a single, dedicated include file.

* **Stable RSI Calculation:** Due to the constantly changing lookback period, the calculator uses a non-recursive, "brute-force" Simple RSI calculation on each bar. This is computationally more intensive than Wilder's smoothed RSI but guarantees stability and prevents artifacts that could arise from a recursive formula with a variable period.

* **Object-Oriented Design (Inheritance):** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

## 4. Parameters

* **Pivotal Period (`InpPivotalPeriod`):** The central RSI period. The adaptive period will be shorter than this in high volatility and longer in low volatility. Default is `14`.
* **Volatility Short (`InpVolaShort`):** The short-term lookback period for measuring the "current" volatility. Default is `5`.
* **Volatility Long (`InpVolaLong`):** The long-term lookback period for calculating the average volatility. Default is `10`.
* **Applied Price (`InpSourcePrice`):** The source price for the calculation.

## 5. Usage and Interpretation

The Adaptive RSI offers a different "feel" compared to the classic RSI, which is crucial to understand.

* **Comparison to Classic RSI:**
  * **In High Volatility (Trending Markets):** The Adaptive RSI's period shortens. This makes it **more responsive and "spiky"** than a classic RSI. It will reach extreme overbought/oversold levels faster and more frequently, providing earlier signals of potential exhaustion.
  * **In Low Volatility (Ranging Markets):** The Adaptive RSI's period lengthens. This makes it **smoother and flatter**, often hovering closer to the 50 level. This helps to filter out the noise and false signals common in sideways markets.

* **Strategy:**
  * Use it to identify potential trend exhaustion. The sharp, deep moves into the >70 or <30 zones during a strong trend can provide earlier warnings than a classic RSI.
  * Use it as a range filter. When the Adaptive RSI becomes very flat and stays near the 50 level, it's a strong indication of a low-volatility, consolidating market, where breakout strategies might be prepared.

It is an excellent tool for traders who find the classic RSI too slow in fast markets but too noisy in slow markets.
