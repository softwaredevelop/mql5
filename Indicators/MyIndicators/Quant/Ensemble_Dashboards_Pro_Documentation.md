# Ensemble Dashboards Suite (v3.00)

## Institutional Multi-Asset Dual-Horizon Consensus Scanner & Single-Asset 9-Component Inspector HUD

**Enterprise Ultra Edition — High-Concurrency GUI Framework for MetaTrader 5*

---

## 1. Executive Summary & Dual-Perspective Architecture

The **Ensemble Dashboards Suite (v3.00)** provides the visualization, monitoring, and execution interface for the Ensemble Voting quantitative engine. Rather than relying on a single monolithic user interface, the suite implements a **Dual-Perspective Framework** that cleanly decouples macro multi-asset market scanning from single-asset microstructure component inspection:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        THE DUAL-PERSPECTIVE DASHBOARD SYSTEM                           │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  MODULE 1: Ensemble_Dashboard_Pro.mq5 (Macro Multi-Asset Scanner)                      │
│  • Simultaneously scans up to 15 assets across Tactical (M15) & Strategic (H1) horizons│
│  • Interactive 1-Click Symbol Switcher directly updates the active chart               │
│  • Macro Confluence Engine detects multi-timeframe alignment, conflicts, and pullbacks │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  MODULE 2: Ensemble_Component_Dashboard_Pro.mq5 (Single-Asset Inspector HUD)          │
│  • Deep-dives into the active chart's asset across all 9 individual voting engines    │
│  • Displays discrete vote badges (BULL, BEAR, NEUT), weights, and disabled states      │
│  • Real-time vote tallies, numerical consensus score, agreement %, and rating banner   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

Both dashboards operate as pure chart-window overlays (`indicator_chart_window`) with zero plot buffers, executing headless mathematical sweeps in nanoseconds while preserving 60+ FPS chart responsiveness.

---

## 2. Institutional GUI Engineering Standards

Traditional MetaTrader dashboard indicators built with transparent `OBJ_LABEL` text objects suffer from text overlapping, clipping, and misalignment across different screen resolutions and Windows DPI settings.

The Ensemble Dashboards eliminate these defects through our **Standardized Institutional GUI Conventions**:

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                          FLAT-BUTTON GRID ARCHITECTURE                                 │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. Zero Text-Overlap      • Every table cell is an independent OBJ_BUTTON with         │
│                            BORDER_FLAT geometry (x, y, width, height)                  │
│                          • Fixed cell bounding boxes make text drift physically        │
│                            impossible regardless of DPI scaling or font changes        │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 2. Headless Stack Engine • Multi-asset sweeps instantiate CEnsembleVotingCalculator   │
│                            strictly on the stack (calc.Init -> calc.Calculate)         │
│                          • Zero heap allocation on live ticks; complete cross-thread   │
│                            isolation between scanned instruments                       │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 3. DirectX Throttling    • UI rendering throttles to a maximum of 5 scans/sec (200 ms) │
│                          • Background fallback timer (OnTimer) ensures live updates    │
│                            even during zero-tick weekend or off-session market hours   │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 4. Deterministic Hygiene • ChartID-isolated namespaces:                                │
│                            ENS_DASH_[ChartID]_ and ENS_HUD_[ChartID]_                  │
│                          • Clean OnDeinit guarantees zero orphaned graphical objects   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Module 1: Ensemble Multi-Asset Scanner (`Ensemble_Dashboard_Pro.mq5`)

The Multi-Asset Scanner provides real-time portfolio surveillance across up to 15 instruments simultaneously, comparing short-term execution flow against higher-timeframe trend structure.

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                              ENSEMBLE MULTI-ASSET SCANNER                              │
├──────────┬──────────────────────┬──────────────────────┬───────────┬───────────────────┤
│ Symbol   │ Tactical (M15)       │ Strategic (H1)       │ Agree %   │ Confluence        │
├──────────┼──────────────────────┼──────────────────────┼───────────┼───────────────────┤
│ DXY      │ +74 STR BUY          │ +99 STR BUY          │ 78%       │ STRONG BULL       │
│ EURUSD   │ -80 STR SELL         │ -100 STR SELL        │ 89%       │ STRONG BEAR       │
│ USDJPY   │ +49 BUY              │ -1 NEUTRAL           │ 67%       │ NEUTRAL           │
│ GBPUSD   │ -21 SELL             │ -100 STR SELL        │ 44%       │ STRONG BEAR       │
│ USDCHF   │ +99 STR BUY          │ +100 STR BUY         │ 100%      │ STRONG BULL       │
│ AUDUSD   │ +65 STR BUY          │ -22 SELL             │ 89%       │ CONFLICT          │
│ XAUUSD   │ -5 NEUTRAL           │ -100 STR SELL        │ 33%       │ PULLBACK (S)      │
│ US500    │ -60 STR SELL         │ +21 BUY              │ 78%       │ CONFLICT          │
└──────────┴──────────────────────┴──────────────────────┴───────────┴───────────────────┘
```

### 3.1. Column Structure & Interactive Functionality

1. **Symbol (Clickable Button):** Clicking any symbol cell executes `ChartSetSymbolPeriod(0, symbol, _Period)`. The active chart instantly switches to that asset without needing the Market Watch window.
2. **Tactical Slot (Default: M15):** Numerical consensus score ($-100 \dots +100$) + Rating text with color-coded background.
3. **Strategic Slot (Default: H1):** Macro timeframe consensus score + Rating badge.
4. **Agreement %:** Supermajority percentage of active capital aligned on the dominant side of the Tactical timeframe.
5. **Confluence Matrix:** Real-time multi-horizon alignment classification.

### 3.2. Macro Confluence State Machine

The Confluence engine classifies the interaction between the Tactical ($S_1$) and Strategic ($S_2$) scores using the configured threshold $T$ (`InpSignalThreshold`, default $20$):

| Confluence State | Background Color | Mathematical Logic | Operational Trading Bias |
| :--- | :---: | :--- | :--- |
| **`STRONG BULL`** | `clrMediumSeaGreen` | $S_1 \ge T \;\text{ and }\; S_2 \ge T$ | Both horizons Bullish; high-conviction Long momentum. |
| **`STRONG BEAR`** | `clrCrimson` | $S_1 \le -T \;\text{ and }\; S_2 \le -T$ | Both horizons Bearish; high-conviction Short momentum. |
| **`CONFLICT`** | `clrKhaki` | $(S_1 \ge T \text{ and } S_2 \le -T) \;\text{ or }\; (S_1 \le -T \text{ and } S_2 \ge T)$ | Timeframe conflict / market churn; **trading prohibited**. |
| **`PULLBACK (L)`** | `clrLightCyan` | $S_2 \ge T \;\text{ and }\; S_1 > -T$ | Macro Bullish, Tactical pulling back; watch for Long reload. |
| **`PULLBACK (S)`** | `clrMistyRose` | $S_2 \le -T \;\text{ and }\; S_1 < T$ | Macro Bearish, Tactical pulling back; watch for Short reload. |
| **`NEUTRAL`** | `clrWhite` | $-T < S_1 < T \;\text{ and }\; -T < S_2 < T$ | Both horizons trading within the neutral indecision zone. |

---

## 4. Module 2: Component Inspector HUD (`Ensemble_Component_Dashboard_Pro.mq5`)

The Component Inspector HUD renders an on-chart diagnostic grid dedicated strictly to the **active chart symbol**, exposing the internal voting mechanics of all 9 models in real time.

```text
┌──────────────────────────────────────────────────────────────────┐
│                   ENSEMBLE: DXY (M15)                            │
├────────────────────┬────────────┬─────────────┬──────────────────┤
│ Component          │ Family     │ Vote        │ Weight           │
├────────────────────┼────────────┼─────────────┼──────────────────┤
│ EMA Cross          │ Trend      │  ▲ BULL     │ 1.0              │
│ Price vs SMA       │ Trend      │  ▲ BULL     │ 1.0              │
│ RSI                │ Momentum   │  DISABLED   │ 1.0              │
│ MACD               │ Momentum   │  ▼ BEAR     │ 1.0              │
│ Stochastic %K      │ Momentum   │  ▼ BEAR     │ 1.0              │
│ Bollinger %B       │ Volatility │  — NEUT     │ 1.0              │
│ Donchian           │ Channel    │  ▼ BEAR     │ 1.0              │
│ OBV Trend          │ Volume     │  ▲ BULL     │ 1.0              │
│ MFI                │ Volume     │  ▲ BULL     │ 1.0              │
├────────────────────┴────────────┴─────────────┴──────────────────┤
│ ▲ Bull: 4 (Green)   |   ▼ Bear: 3 (Red)   |   — Neut: 1 (White)  │
├──────────────────────────────────────────────────────────────────┤
│ Consensus: +13.7    |   Agreement: 50%                           │
├──────────────────────────────────────────────────────────────────┤
│ RATING: NEUTRAL (Full-width colored status banner)               │
└──────────────────────────────────────────────────────────────────┘
```

### 4.1. Grid Layout & Vote Badges

* **Component Column (105 px):** Name of the mathematical model.

* **Family Column (75 px):** The quantitative pillar (Trend, Momentum, Volatility, Channel, Volume).
* **Vote Badge (70 px):** Color-coded solid button cells:
  * `▲ BULL` (`clrMediumSeaGreen` bg, white text): Positive directional bias.
  * `▼ BEAR` (`clrCrimson` bg, white text): Negative directional bias.
  * `— NEUT` (`clrWhite` bg, dark gray text): Reading inside neutral dead-zone ($50 \pm Z$).
  * `DISABLED` (`C'25,25,25'` bg, gray text): Model disabled in inputs; automatically excluded from active weight and vote tally.
* **Weight Column (45 px):** Individual component weight multiplier ($W_i$).

### 4.2. Diagnostic Summary Footers

* **Vote Tallies Row:** Displays active component count breakdown (`▲ Bull: X`, `▼ Bear: Y`, `— Neut: Z`).

* **Consensus & Agreement Row:** Displays smoothed consensus score ($-100.0 \dots +100.0$) and supermajority Agreement %.
* **Institutional Rating Banner:** Full-width color-coded badge highlighting the current regime (`STRONG BUY`, `BUY`, `NEUTRAL`, `SELL`, `STRONG SELL`).

---

## 5. Parameters Reference

### 5.1. Multi-Asset Scanner (`Ensemble_Dashboard_Pro.mq5`)

#### === Asset Selection Settings ===

* **`InpCustomSymbols`** (*default: `""`*): Comma-separated list of symbols (e.g., `"EURUSD,GBPUSD,USDJPY,BTCUSD"`). If left empty, scans Market Watch.

* **`InpMaxSymbols`** (*default: `12`*): Maximum number of asset rows to display.
* **`InpRefreshSeconds`** (*default: `3`*): Background timer fallback interval in seconds.

#### === Horizon Slots Configuration ===

* **`InpSlot1Label`** (*default: `"Tactical"`*): Display header label for Slot 1.

* **`InpSlot1TF`** (*default: `PERIOD_M15`*): Timeframe of calculation for Slot 1.
* **`InpSlot2Label`** (*default: `"Strategic"`*): Display header label for Slot 2.
* **`InpSlot2TF`** (*default: `PERIOD_H1`*): Timeframe of calculation for Slot 2.

#### === Universal Price & Threshold Settings ===

* **`InpSourcePrice`** (*default: `PRICE_CLOSE_STD`*): Global price source applied across all models.

* **`InpSignalThreshold`** (*default: `20`*): Minimum score required for directional ratings.

* **`InpStrongThreshold`** (*default: `60`*): Score required for supermajority ratings.
* **`InpConsensusSmoothing`** (*default: `3`*): Lookback length for consensus EMA filter.
* **`InpNeutralZone`** (*default: `5.0`*): Half-width buffer around the 50 midline of bounded components.

#### === Placement & Typography ===

* **`InpTableX`** (*default: `20`*): X offset in pixels from the left chart edge.

* **`InpTableY`** (*default: `35`*): Y offset in pixels from the top chart edge.

* **`InpFontSize`** (*default: `8`*): UI typography size.

---

### 5.2. Component Inspector HUD (`Ensemble_Component_Dashboard_Pro.mq5`)

#### === Timeframe & Analysis Horizon ===

* **`InpTimeframe`** (*default: `PERIOD_CURRENT`*): Timeframe to inspect. Set to `PERIOD_CURRENT` to track active chart timeframe, or choose any higher timeframe (`PERIOD_M15` through `PERIOD_MN1`).

#### === Placement & Typography ===

* **`InpDashboardCorner`** (*default: `CORNER_LEFT_UPPER`*): Anchor corner (`CORNER_LEFT_UPPER`, `CORNER_RIGHT_UPPER`, `CORNER_LEFT_LOWER`, `CORNER_RIGHT_LOWER`).

* **`InpTableX`** (*default: `20`*): X distance in pixels from the anchor corner.

* **`InpTableY`** (*default: `35`*): Y distance in pixels from the anchor corner.
* **`InpFontSize`** (*default: `8`*): Grid font size.
* **`InpRefreshSeconds`** (*default: `2`*): Background update timer.

#### === Individual Component Toggles & Weights ===

* Independent enable toggles and weight inputs for all 9 components (`InpMaCrossEnable`, `InpMaCrossWeight`, etc.) with individual lookback parameters.

---

## 6. Quantitative Trading & Portfolio Execution Playbooks

```text
┌────────────────────────────────────────────────────────────────────────┐
│                      ENSEMBLE PORTFOLIO PLAYBOOKS                      │
├────────────────────────────────────────────────────────────────────────┤
│ 1. Top-Down Confluence Alignment: Scan multi-asset grid -> Filter for  │
│                                   STRONG BULL / STRONG BEAR alignments.│
│ 2. The Tactical Pullback Setup:   Strategic is STRONG BULL, Tactical   │
│                                   pulls back into NEUTRAL or PULLBACK. │
│ 3. Microstructure Validation:     Click symbol -> Inspect 9-component  │
│                                   HUD to confirm Volume & Trend quorum.│
│ 4. Conflict & Chop Elimination:   Scanner displays CONFLICT -> Zero    │
│                                   trades permitted; capital preserved. │
└────────────────────────────────────────────────────────────────────────┘
```

### 6.1. Playbook 1: Top-Down Multi-Asset Confluence

* **Step 1 (Surveillance):** Monitor the `Ensemble_Dashboard_Pro` table across your 12-symbol watchlist.

* **Step 2 (Filtering):** Identify symbols displaying **`STRONG BULL`** (both Tactical M15 and Strategic H1 consensus $> +20$, with high Agreement $> 75\%$).

* **Step 3 (Chart Switch):** Click the symbol button (e.g. `USDCHF`). The active chart immediately updates to USDCHF.
* **Step 4 (Execution):** On the subwindow `Ensemble_Oscillator_Pro`, wait for the Consensus score to cross above its Signal Line. Execute Long order.

### 6.2. Playbook 2: Strategic Trend Pullback Reload

* **Market State:** A high-volume macro bull market experiencing a temporary corrective retrace.

* **Scanner Signal:** Confluence column flags **`PULLBACK (L)`**:
  * Strategic H1 consensus remains strongly positive ($> +60.0$).
  * Tactical M15 consensus has pulled back into negative or neutral territory ($[-20, +20]$).

* **Trade:** Do NOT short the market. Instead, prepare for a long continuation entry. Trigger the long order the moment the Tactical M15 consensus turns back green ($> +20.0$).

### 6.3. Playbook 3: Microstructure Component Dissection

* **Setup:** Before entering a high-stake swing trade, verify the quality of the consensus using `Ensemble_Component_Dashboard_Pro`:
  * **Ideal Bullish Quorum:** Both Trend components (`EMA Cross`, `Price vs SMA`) show `▲ BULL`, AND at least one Volume component (`OBV Trend` or `MFI`) shows `▲ BULL`.
  * **Low-Quality Warning:** If consensus is $+25.0$ solely because of overbought momentum oscillators, while both Volume components show `— NEUT` or `▼ BEAR`, the move lacks institutional capital backing. Avoid entering.

### 6.4. Playbook 4: Choppy Market Conflict Shield

* **Market State:** Market is directionless; higher timeframes are in conflict with lower timeframes.

* **Scanner Signal:** Confluence column displays **`CONFLICT`** (Khaki background):
  * Example: Tactical M15 is $+65$ (Short-term rally), but Strategic H1 is $-68$ (Macro downtrend).

* **Execution Rule:** **Zero trades permitted.** The conflict shield prevents discretionary traders from forcing trades into low-probability churn zones.
