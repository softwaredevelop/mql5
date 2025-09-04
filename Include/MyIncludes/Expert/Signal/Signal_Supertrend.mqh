//+------------------------------------------------------------------+
//|                                            Signal_Supertrend.mqh |
//|      Signal module for the Supertrend_HeikinAshi indicator.      |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Expert\Signal_Base.mqh> // Corrected path

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSignalSupertrend : public CSignalBase
  {
private:
   int               m_indicator_handle;

public:
                     CSignalSupertrend(void);
                    ~CSignalSupertrend(void) {};

   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, double multiplier);
   virtual int       GetSignal(int shift);
  };

//+------------------------------------------------------------------+
//| CSignalSupertrend: Constructor                                   |
//+------------------------------------------------------------------+
CSignalSupertrend::CSignalSupertrend(void) : m_indicator_handle(INVALID_HANDLE)
  {
  }

//+------------------------------------------------------------------+
//| CSignalSupertrend: Initialization                                |
//+------------------------------------------------------------------+
bool CSignalSupertrend::Init(string symbol, ENUM_TIMEFRAMES timeframe, int period, double multiplier)
  {
   m_indicator_handle = iCustom(symbol, timeframe, "MyIndicators\\Supertrend_HeikinAshi", period, multiplier);

   if(m_indicator_handle == INVALID_HANDLE)
     {
      Print("CSignalSupertrend Error: Failed to create indicator handle.");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| CSignalSupertrend: Get the signal from the indicator             |
//+------------------------------------------------------------------+
int CSignalSupertrend::GetSignal(int shift)
  {
   double color_buffer[1];

   if(CopyBuffer(m_indicator_handle, 1, shift, 1, color_buffer) <= 0)
      return 0;

   if(color_buffer[0] == 0)
      return 1;
   if(color_buffer[0] == 1)
      return -1;

   return 0;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
