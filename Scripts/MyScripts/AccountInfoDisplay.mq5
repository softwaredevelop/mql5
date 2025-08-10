//+------------------------------------------------------------------+
//|                                           AccountInfoDisplay.mq5 |
//|                             Copyright 2000-2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property description "Displays account information directly on the chart."
#property version   "1.10" // Version updated to reflect changes

//--- Standard library includes
#include <Trade\AccountInfo.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Custom include file for initialization data
// Make sure this file is in your MQL5/Include folder
#include "AccountInfoDisplayInit.mqh"

//+------------------------------------------------------------------+
//| Account Info Display script class                                |
//+------------------------------------------------------------------+
class CAccountInfoDisplay
  {
protected:
   CAccountInfo      m_account;
   //--- Chart objects
   // The size of the array is now determined by our enum
   CChartObjectLabel m_label[ROW_TOTAL_COUNT];
   CChartObjectLabel m_label_info[ROW_TOTAL_COUNT];

public:
                     CAccountInfoDisplay(void);
                    ~CAccountInfoDisplay(void);
   //---
   bool              Init(void);
   void              Deinit(void);
   void              Processing(void);

private:
   void              AccountInfoToChart(void);
  };
//--- Global instance of our class
CAccountInfoDisplay g_accountDisplay;
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CAccountInfoDisplay::CAccountInfoDisplay(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CAccountInfoDisplay::~CAccountInfoDisplay(void)
  {
  }
//+------------------------------------------------------------------+
//| Initialization Method                                            |
//+------------------------------------------------------------------+
bool CAccountInfoDisplay::Init(void)
  {
   int   sy=10;
   int   dy=16;
   color color_label;
   color color_info;
   color color_heading = clrDarkGray;
   int   font_size_data = 8;
   int   font_size_heading = 9;

//--- Dynamic color tuning
   color_info = (color)(ChartGetInteger(0, CHART_COLOR_BACKGROUND) ^ 0xFFFFFF);
   color_label = (color)(color_info ^ 0x202020);

//--- Adjust starting position if OHLC is shown
   if(ChartGetInteger(0, CHART_SHOW_OHLC))
      sy += 16;

   int current_y = sy;

//--- Create chart labels
   for(int i = 0; i < ROW_TOTAL_COUNT; i++)
     {
      // Check if the current label is a heading
      bool is_heading = (
                           StringFind(init_str[i], "I. ")  == 0 ||
                           StringFind(init_str[i], "II. ") == 0 ||
                           StringFind(init_str[i], "III. ") == 0 ||
                           StringFind(init_str[i], "IV. ") == 0 ||
                           StringFind(init_str[i], "V. ") == 0
                        );

      // Create the property label (e.g., "Balance")
      m_label[i].Create(0, "AccInfoLabel" + IntegerToString(i), 0, 20, current_y);
      m_label[i].Description(init_str[i]);
      m_label[i].Color(is_heading ? color_heading : color_label);
      m_label[i].FontSize(is_heading ? font_size_heading : font_size_data);
      m_label[i].Selectable(false);

      // Create the value label (e.g., "99588.30")
      m_label_info[i].Create(0, "AccInfoValue" + IntegerToString(i), 0, 140, current_y);
      m_label_info[i].Description(" ");
      m_label_info[i].Color(color_info);
      m_label_info[i].FontSize(font_size_data);
      m_label_info[i].Selectable(false);

      current_y += dy;
     }

// Initial data population
   AccountInfoToChart();
   ChartRedraw();
   return(true);
  }
//+------------------------------------------------------------------+
//| Deinitialization Method                                          |
//+------------------------------------------------------------------+
void CAccountInfoDisplay::Deinit(void)
  {
//--- MODIFICATION: Implemented Deinit to clean up chart objects
// This ensures that when the script is removed, it leaves no trace.
   for(int i = 0; i < ROW_TOTAL_COUNT; i++)
     {
      m_label[i].Delete();
      m_label_info[i].Delete();
     }
   ChartRedraw();
  }
//+------------------------------------------------------------------+
//| Processing Method (called in a loop)                             |
//+------------------------------------------------------------------+
void CAccountInfoDisplay::Processing(void)
  {
// Update the data on the chart
   AccountInfoToChart();
   ChartRedraw();

//--- MODIFICATION: Increased sleep time for better performance
// Updating every 50ms is excessive. 1 second is plenty for this info.
   Sleep(1000); // 1000 milliseconds = 1 second
  }
//+------------------------------------------------------------------+
//| Method to write account info to chart labels                     |
//+------------------------------------------------------------------+
void CAccountInfoDisplay::AccountInfoToChart(void)
  {
//--- MODIFICATION: Using the enum for indexing instead of "magic numbers"
// This makes the code readable and robust against reordering.

// --- I. Basic Account Information ---
   m_label_info[ROW_LOGIN].Description((string)m_account.Login());
   m_label_info[ROW_NAME].Description(m_account.Name());
   m_label_info[ROW_SERVER].Description(m_account.Server());
   m_label_info[ROW_COMPANY].Description(m_account.Company());
   m_label_info[ROW_CURRENCY].Description(m_account.Currency());
   m_label_info[ROW_CURRENCY_DIGITS].Description((string)m_account.InfoInteger(ACCOUNT_CURRENCY_DIGITS));

// --- II. Financial Status and Balances ---
   m_label_info[ROW_BALANCE].Description(DoubleToString(m_account.Balance(), 2));
   m_label_info[ROW_CREDIT].Description(DoubleToString(m_account.Credit(), 2));
   m_label_info[ROW_PROFIT].Description(DoubleToString(m_account.Profit(), 2));
   m_label_info[ROW_EQUITY].Description(DoubleToString(m_account.Equity(), 2));

// --- III. Margin and Risk Management ---
   m_label_info[ROW_MARGIN].Description(DoubleToString(m_account.Margin(), 2));
   m_label_info[ROW_MARGIN_FREE].Description(DoubleToString(m_account.FreeMargin(), 2));
   m_label_info[ROW_MARGIN_LEVEL].Description(DoubleToString(m_account.MarginLevel(), 2));
   m_label_info[ROW_MARGIN_CALL].Description(DoubleToString(m_account.MarginCall(), 2));
   m_label_info[ROW_MARGIN_STOPOUT].Description(DoubleToString(m_account.MarginStopOut(), 2));

// --- IV. Trading Modes and Rules ---
   m_label_info[ROW_TRADE_MODE].Description(m_account.TradeModeDescription());
   m_label_info[ROW_LEVERAGE].Description((string)m_account.Leverage());
   m_label_info[ROW_MARGIN_MODE].Description(m_account.MarginModeDescription());
   m_label_info[ROW_STOPOUT_MODE].Description(m_account.StopoutModeDescription());
   m_label_info[ROW_FIFO_CLOSE].Description((string)m_account.InfoInteger(ACCOUNT_FIFO_CLOSE));
   m_label_info[ROW_HEDGE_ALLOWED].Description((string)m_account.InfoInteger(ACCOUNT_HEDGE_ALLOWED));

// --- V. Trading Permissions ---
   m_label_info[ROW_TRADE_ALLOWED].Description((string)m_account.TradeAllowed());
   m_label_info[ROW_TRADE_EXPERT].Description((string)m_account.TradeExpert());
  }
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart(void)
  {
//--- Initialize our display object
   if(g_accountDisplay.Init())
     {
      //--- Loop until the script is stopped by the user
      while(!IsStopped())
        {
         g_accountDisplay.Processing();
        }
     }
//--- Deinitialize to clean up the chart
   g_accountDisplay.Deinit();
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
