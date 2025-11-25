# Market Facilitation Index (BW MFI) Professional

## 1. Summary (Introduction)

The Market Facilitation Index (MFI), developed by Bill Williams as part of his "Trading Chaos" methodology, is a unique indicator that measures the efficiency of price movement. It does not indicate trend direction but rather assesses the market's willingness to move the price for a given amount of volume.

The MFI is calculated by relating the price range of a bar to its volume. The core idea is to determine how effective each "tick" of volume was in creating price movement. The indicator's value is then analyzed in conjunction with the change in volume to classify the market into one of four distinct states, each represented by a different color on the histogram.

This provides a powerful, at-a-glance view of the underlying dynamics between price action and market participation.

## 2. Mathematical Foundations and Calculation Logic

The MFI's formula is remarkably simple, yet powerful.

### Calculation Steps (Algorithm)

1. **Calculate the MFI Value:** For each bar, the price range is divided by the volume.
    * $\text{MFI}_t = \frac{\text{High}_t - \text{Low}_t}{\text{Volume}_t}$
    * *(This value represents the price change per unit of volume).*

2. **Determine the Market State:** The indicator then compares the current bar's MFI and Volume to the previous bar's values to determine one of four possible states.

## 3. The Four States of the MFI

The power of the MFI comes from the interpretation of the relationship between the index and volume, visualized by four distinct colors.

| MFI vs Previous MFI | Volume vs Previous Volume | Color & Name | Interpretation |
| :--- | :--- | :--- | :--- |
| **Up** | **Up** | **Green (Green)** | The ideal state. Both volume and price movement are increasing, confirming the trend. This is a strong signal to enter or hold a position in the direction of the trend. |
| **Down** | **Down** | **Fade (Brown)** | The market is losing interest. Both volatility and volume are decreasing. This is a "boring" market, often seen during consolidation. It's a signal to be cautious or stay out. |
| **Up** | **Down** | **Fake (Blue)** | A potential trap. The price range is increasing, but on declining volume. This suggests the move lacks genuine participation and may be a "fakeout" or a stop-hunt. Be very cautious of moves on blue bars. |
| **Down** | **Up** | **Squat (Magenta)** | A signal of intense struggle. Volume is high, but the price range is small. This indicates a major battle between buyers and sellers. A "squat" bar often precedes a significant breakout, as one side eventually wins the fight. |

## 4. MQL5 Implementation Details

* **Modular Calculation Engine (`MarketFacilitationIndex_Calculator.mqh`):** All mathematical and logical operations are encapsulated in a dedicated include file.

* **Efficient 4-Buffer Drawing:** To achieve the four-color display in a stable and efficient manner, the indicator uses **four separate `DRAW_HISTOGRAM` plots and buffers**. The calculator determines the market state for each bar and places the MFI value into the corresponding buffer, leaving the other three empty. This is the most robust method for creating multi-color histograms in MQL5.

* **Platform-Aware Features:**
  * **Volume Type:** The user can select between `Tick Volume` and `Real Volume`. The indicator robustly checks for Real Volume availability.
  * **Heikin Ashi Integration:** The standard `_HA` derived class architecture is used to seamlessly support calculations on Heikin Ashi price data.

## 5. Parameters

* **Volume Type (`InpVolumeType`):** Allows the user to select the volume source for the calculation (`VOLUME_TICK` or `VOLUME_REAL`).
* **Candle Source (`InpCandleSource`):** Allows the user to select the candle type for the calculation (`Standard` or `Heikin Ashi`).

## 6. Usage and Interpretation

The MFI is not a standalone signal generator but an exceptional tool for **confirming the quality of price moves** and identifying potential turning points.

* **Trend Confirmation:** A series of **Green** bars during a trend confirms that the move is strong and supported by volume. This is a signal to hold or add to a position.
* **Exhaustion and Reversal Signals:**
  * A **Squat** bar (magenta) after a long trend is a major warning sign. It indicates that despite high volume, the price could not advance further. This signals a potential top or bottom is forming. Watch the next bar for confirmation of a reversal.
  * A **Fake** bar (blue) during a breakout attempt suggests the move lacks conviction and is likely to fail. Do not trust breakouts that occur on blue bars.
* **Consolidation:** A series of **Fade** bars (brown) indicates a quiet, consolidating market. This is a time to wait for a new signal (often a Green or Squat bar) before entering a trade.
