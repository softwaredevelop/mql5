//+------------------------------------------------------------------+
//|                                           AccountInfoDisplay.mq5 |
//|                      Copyright 2025, xxxxxxxx                    |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property link      ""
#property description "Displays account information directly on the chart."
#property version   "2.02" // Final fix for boolean conversion

//--- Standard library includes
#include <Trade\AccountInfo.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>

//--- Custom include file for initialization data
#include <MyIncludes\AccountInfoDisplayInit.mqh>

//+------------------------------------------------------------------+
//| A simple structure to hold the formatted account data            |
//+------------------------------------------------------------------+
struct SAccountData
  {
   string            data[ROW_TOTAL_COUNT];
  };

//+------------------------------------------------------------------+
//| Account Info Display script class                                |
//+------------------------------------------------------------------+
class CAccountInfoDisplay
  {
protected:
   CAccountInfo      m_account;
   CChartObjectLabel m_labels[ROW_TOTAL_COUNT];
   CChartObjectLabel m_values[ROW_TOTAL_COUNT];

public:
                     CAccountInfoDisplay(void);
                    ~CAccountInfoDisplay(void);

   bool              Init(void);
   void              Processing(void);

protected:
   void              GetAccountData(SAccountData &account_data);
   void              UpdateChartLabels(const SAccountData &account_data);
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
//| Destructor (handles deinitialization)                            |
//+------------------------------------------------------------------+
CAccountInfoDisplay::~CAccountInfoDisplay(void)
  {
   for(int i = 0; i < ROW_TOTAL_COUNT; i++)
     {
      m_labels[i].Delete();
      m_values[i].Delete();
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| Initialization Method                                            |
//+------------------------------------------------------------------+
bool CAccountInfoDisplay::Init(void)
  {
   int   y_start = 10;
   int   y_step  = 16;
   color color_label;
   color color_value;
   color color_heading = clrDarkGray;
   int   font_size_data = 8;
   int   font_size_heading = 9;

   color_value = (color)(ChartGetInteger(0, CHART_COLOR_BACKGROUND) ^ 0xFFFFFF);
   color_label = (color)(color_value ^ 0x202020);

   if(ChartGetInteger(0, CHART_SHOW_OHLC))
      y_start += 16;

   int current_y = y_start;

   for(int i = 0; i < ROW_TOTAL_COUNT; i++)
     {
      bool is_heading = (StringFind(g_init_labels[i], "I. ") == 0 || StringFind(g_init_labels[i], "II. ") == 0 ||
                         StringFind(g_init_labels[i], "III. ") == 0 || StringFind(g_init_labels[i], "IV. ") == 0 ||
                         StringFind(g_init_labels[i], "V. ") == 0);

      m_labels[i].Create(0, "AccInfoLabel" + (string)i, 0, 20, current_y);
      m_labels[i].Description(g_init_labels[i]);
      m_labels[i].Color(is_heading ? color_heading : color_label);
      m_labels[i].FontSize(is_heading ? font_size_heading : font_size_data);
      m_labels[i].Selectable(false);

      m_values[i].Create(0, "AccInfoValue" + (string)i, 0, 140, current_y);
      m_values[i].Description("...");
      m_values[i].Color(color_value);
      m_values[i].FontSize(font_size_data);
      m_values[i].Selectable(false);

      current_y += y_step;
     }

   SAccountData data;
   GetAccountData(data);
   UpdateChartLabels(data);
   ChartRedraw();
   return(true);
  }

//+------------------------------------------------------------------+
//| Processing Method (called in a loop)                             |
//+------------------------------------------------------------------+
void CAccountInfoDisplay::Processing(void)
  {
   SAccountData data;
   GetAccountData(data);
   UpdateChartLabels(data);
   ChartRedraw();
   Sleep(1000);
  }

//+------------------------------------------------------------------+
//| Fills the data structure with current account info               |
//+------------------------------------------------------------------+
void CAccountInfoDisplay::GetAccountData(SAccountData &account_data)
  {
// This method is part of the CAccountInfoDisplay class, so it can see the m_account member.
// The enum values are global because of the #include.

// The CAccountInfo class does not have a Refresh() method.
// Data is refreshed automatically by the terminal.

   account_data.data[ROW_LOGIN] = (string)m_account.Login();
   account_data.data[ROW_NAME] = m_account.Name();
   account_data.data[ROW_SERVER] = m_account.Server();
   account_data.data[ROW_COMPANY] = m_account.Company();
   account_data.data[ROW_CURRENCY] = m_account.Currency();
   account_data.data[ROW_CURRENCY_DIGITS] = (string)m_account.InfoInteger(ACCOUNT_CURRENCY_DIGITS);
   account_data.data[ROW_BALANCE] = DoubleToString(m_account.Balance(), 2);
   account_data.data[ROW_CREDIT] = DoubleToString(m_account.Credit(), 2);
   account_data.data[ROW_PROFIT] = DoubleToString(m_account.Profit(), 2);
   account_data.data[ROW_EQUITY] = DoubleToString(m_account.Equity(), 2);
   account_data.data[ROW_MARGIN] = DoubleToString(m_account.Margin(), 2);
   account_data.data[ROW_MARGIN_FREE] = DoubleToString(m_account.FreeMargin(), 2);
   account_data.data[ROW_MARGIN_LEVEL] = DoubleToString(m_account.MarginLevel(), 2);
   account_data.data[ROW_MARGIN_CALL] = DoubleToString(m_account.MarginCall(), 2);
   account_data.data[ROW_MARGIN_STOPOUT] = DoubleToString(m_account.MarginStopOut(), 2);
   account_data.data[ROW_TRADE_MODE] = m_account.TradeModeDescription();
   account_data.data[ROW_LEVERAGE] = (string)m_account.Leverage();
   account_data.data[ROW_MARGIN_MODE] = m_account.MarginModeDescription();
   account_data.data[ROW_STOPOUT_MODE] = m_account.StopoutModeDescription();
   account_data.data[ROW_FIFO_CLOSE] = (string)m_account.InfoInteger(ACCOUNT_FIFO_CLOSE);
   account_data.data[ROW_HEDGE_ALLOWED] = (string)m_account.InfoInteger(ACCOUNT_HEDGE_ALLOWED);
   account_data.data[ROW_TRADE_ALLOWED] = m_account.TradeAllowed() ? "true" : "false";
   account_data.data[ROW_TRADE_EXPERT] = m_account.TradeExpert() ? "true" : "false";
  }

//+------------------------------------------------------------------+
//| Updates the chart labels from the data structure                 |
//+------------------------------------------------------------------+
void CAccountInfoDisplay::UpdateChartLabels(const SAccountData &account_data)
  {
   for(int i = 0; i < ROW_TOTAL_COUNT; i++)
     {
      if(m_values[i].Description() != account_data.data[i])
        {
         m_values[i].Description(account_data.data[i]);
        }
     }
  }

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart(void)
  {
   if(g_accountDisplay.Init())
     {
      while(!IsStopped())
        {
         g_accountDisplay.Processing();
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
