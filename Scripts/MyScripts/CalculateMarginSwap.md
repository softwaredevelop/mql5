# Margin & Swap Calculator Script

## 1. Summary (Introduction)

The Margin & Swap Calculator is an MQL5 script designed as a quick-use utility tool for traders. When executed on a chart, it instantly calculates and displays the required margin and daily swap costs for a user-defined position size on the chart's specific financial instrument.

Unlike an indicator that runs continuously, this script performs a one-time calculation and presents its findings in a clear, formatted report in the "Experts" tab of the MetaTrader 5 terminal. Its primary purpose is to help traders with risk management and position sizing by providing essential cost information before a trade is placed, without cluttering the chart with visual objects.

## 2. Features and Calculated Data

The script provides a concise report covering two critical aspects of a potential trade:

- **Required Margin:**

  - It calculates the exact amount of account currency required to open the specified position size.
  - The calculation is performed separately for both a potential **BUY** order (using the Ask price) and a **SELL** order (using the Bid price).

- **Daily Swap Costs:**
  - It retrieves the broker's raw swap values for both long (BUY) and short (SELL) positions.
  - It calculates the final swap cost based on the specified lot size and the broker's defined calculation method (`SYMBOL_SWAP_MODE`).
  - To ensure clarity and prevent misinterpretation, the script displays the calculated swap value alongside a clear description of its unit (e.g., "In Points", "In EUR (Base Currency)").
  - It also identifies and displays the day of the week on which the triple (3-day) swap is charged.

## 3. MQL5 Implementation Details

The script is designed to be a simple, robust, and self-contained tool, adhering to our principles of clarity and stability.

- **Self-Contained Logic:** The script has no external dependencies on other indicators or libraries. All calculations are performed using built-in MQL5 functions (`OrderCalcMargin`, `SymbolInfo...`) within the `OnStart()` entry point.

- **Direct and Robust Calculation:**

  - **Margin:** The script uses the standard `OrderCalcMargin()` function, which is the most reliable way to determine margin requirements as it directly queries the broker's trade server for the exact value in the account's currency.
  - **Swap:** Instead of attempting complex and potentially unreliable currency conversions, the script was intentionally designed to present the raw, calculated swap cost and explicitly state its unit. This approach is more robust because it does not depend on the availability of specific currency pairs in the Market Watch.

- **Clear, Formatted Output:** The script uses `Print()` and `PrintFormat()` to generate a clean, well-structured report in the "Experts" tab. This avoids intrusive `Alert()` pop-up windows and keeps the chart clean, as no graphical objects are created.

- **Helper Functions for Readability:** To keep the main `OnStart()` function clean and improve code readability, the logic is supported by two small helper functions:

  1. `DayOfWeekToString()`: Converts the numeric day-of-the-week value for the triple swap into a human-readable string (e.g., "Wednesday").
  2. `SwapModeToString()`: Converts the `ENUM_SYMBOL_SWAP_MODE` integer into a descriptive string that clearly explains the unit of the calculated swap cost (e.g., "In Points", "In USD (Quote/Profit Currency)"). This is a key feature for ensuring the user correctly interprets the output.

- **Compatibility-Aware Design:** The `switch` block for handling different swap modes was refined through iterative testing to be compatible with various MetaTrader 5 terminal builds. It correctly handles different numeric values that brokers or terminal versions might assign to specific swap modes (e.g., `SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT`).

## 4. Usage

1. **Installation:**
   - Place `CalculateMarginSwap.mq5` into your `MQL5\Scripts` folder.
2. **Execution:**
   - Drag and drop the `CalculateMarginSwap` script from the Navigator window onto the chart of the desired symbol.
   - An input window will appear, allowing you to specify the position size in lots.
   - After clicking "OK", the script will execute its calculations.
3. **Review Output:**
   - Open the "Terminal" window (Ctrl+T).
   - Navigate to the "Experts" tab.
   - The script will print the full report and then terminate automatically.

## 5. Parameters

- **`InpLotSize`**
  - **Description:** The position size in lots for which the margin and swap costs will be calculated.
  - **Default Value:** `0.1`
