# Velocity Pro (Indicator)

## 1. Summary

**Velocity Pro** is a dual-purpose kinematics indicator. It separates the "Directional Impulse" from the "Raw Activity" of the market. This distinction is crucial for identifying market states: Trend vs. Chop.

## 2. Concepts & Methodology

We distinguish between two physical concepts applied to price action:

### A. Velocity (The Vector)

* **Definition:** The rate of change of position with respect to a frame of reference (ATR). It has **Magnitude** and **Direction**.
* **Formula:** `(Close[i] - Close[i-N]) / (N * ATR)`.
* **Represents:** The net displacement. How far did the price actually get?
* **Visualization:** Colored Histogram.
  * **Green:** Fast pumping up.
  * **Red:** Fast dumping down.

### B. Speed (The Scalar)

* **Definition:** The magnitude of the rate of change of position. It has **Magnitude** only.
* **Formula:** `Mean(Abs(Close[k] - Close[k-1])) / ATR`.
* **Represents:** The total path length traveled. How much energy was spent?
* **Visualization:** Gold Line.

## 3. Interpretation (The Delta)

The relationship between the **Histogram (Velocity)** and the **Line (Speed)** tells the true story:

1. **Strong Trend (Efficiency):**
    * Velocity is High (Green/Red bars).
    * Speed is High (Gold line).
    * **Velocity ≈ Speed.** (The line rides the top of the bars).
    * *Meaning:* Every tick contributed to the move. High conviction.

2. **Choppy/Volatile (Inefficiency):**
    * Velocity is Low (Gray bars near 0).
    * Speed is High (Gold line soaring).
    * **Gap between Velocity and Speed.**
    * *Meaning:* The market is running around like crazy but getting nowhere. **Do NOT trade breakouts here.** Expect stop hunts.

## 4. Parameters

* `InpVelPeriod`: Lookback window (Default: 3 for M5 Trigger).
* `InpATRPeriod`: Normalization basis (Default: 14).
* `InpThreshold`: Level for "High Velocity" coloring (Default: 1.0).
* `InpShowSpeed`: Toggle the Scalar Speed line (Default: true).
