# Account Info Display Script

## 1. Summary (Introduction)

The Account Info Display is an MQL5 script designed as a utility tool for traders. When executed on a chart, it displays a comprehensive, real-time overview of the current trading account's key statistics.

Unlike an indicator, which continuously recalculates based on price data, this script runs in a persistent loop, periodically refreshing and displaying account information directly on the chart using text label objects. Its primary purpose is to provide traders with at-a-glance access to crucial account metrics without needing to keep the "Terminal" window open.

## 2. Features and Displayed Data

The script organizes and displays account information in several logical categories:

- **I. Basic Info:**
  - Login, Name, Server, Company, and account Currency.
- **II. Financials:**
  - Real-time Balance, Credit, floating Profit/Loss, and Equity.
- **III. Margin:**
  - Current Margin used, Free Margin, Margin Level (%), and the broker-defined Margin Call and Stop Out levels.
- **IV. Rules:**
  - The account's trade mode (e.g., Real, Demo), Leverage, Margin Mode (e.g., Hedging), and other rules like FIFO.
- **V. Permissions:**
  - Confirms whether trading is allowed and if Expert Advisors (EAs) are permitted to trade on the account.

## 3. MQL5 Implementation Details

The script was refocused to follow a clean, object-oriented, and modular design, adhering to our established coding principles.

- **Object-Oriented Design:** The core logic is encapsulated within a `CAccountInfoDisplay` class. A single global instance of this class (`g_accountDisplay`) manages the script's entire lifecycle.

- **Separation of Concerns:** The logic is clearly divided into two distinct responsibilities:

  1. **Data Retrieval (`GetAccountData` method):** This method is solely responsible for querying the terminal for the latest account information using the standard `CAccountInfo` library class and formatting the data into a simple `SAccountData` structure.
  2. **Data Presentation (`UpdateChartLabels` method):** This method is responsible only for the visual aspect. It takes the `SAccountData` structure and updates the text of the `CChartObjectLabel` objects on the chart. It includes an optimization to only update a label if its text has actually changed, reducing unnecessary chart redraws.

- **Modular Configuration (`AccountInfoDisplayInit.mqh`):** The labels and their order are not hard-coded into the main script. They are defined in a separate include file, `MyIncludes\AccountInfoDisplayInit.mqh`. This file contains:

  - An `enum` (`ENUM_ACCOUNT_INFO_ROWS`) that provides clear, readable indices for each data row.
  - A `const string` array (`g_init_labels`) that holds the text for each label.
  - This approach makes it extremely easy to add, remove, or reorder the displayed information without touching the main script's logic.

- **Automatic Cleanup (RAII):** The script follows the **Resource Acquisition Is Initialization (RAII)** principle. The chart label objects are created in the `Init()` method, and their cleanup (deletion) is handled automatically by the `CAccountInfoDisplay` class's **destructor** (`~CAccountInfoDisplay`). This ensures that whenever the script is stopped or removed from the chart, all created objects are properly deleted, leaving the chart clean.

- **Persistent Loop:** The script's main logic resides in the `OnStart` function, which initializes the display object and then enters a `while(!IsStopped())` loop. Inside this loop, the `Processing()` method is called, which refreshes the data and sleeps for 1 second. This persistent execution is what allows the script to provide real-time updates, behaving much like an indicator.

## 4. Usage

1. **Installation:**
   - Place `AccountInfoDisplay.mq5` into your `MQL5\Scripts` folder.
   - Place `AccountInfoDisplayInit.mqh` into your `MQL5\Include\MyIncludes` folder.
2. **Execution:** Drag and drop the `AccountInfoDisplay` script from the Navigator window onto any chart.
3. **Termination:** To stop the script and remove the information from the chart, right-click on the chart and select "Remove Script". The script will automatically clean up all text objects it created.

## 5. Parameters

This script has no adjustable input parameters.
