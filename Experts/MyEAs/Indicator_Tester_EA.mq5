//+------------------------------------------------------------------+
//|                                         Indicator_Tester_EA.mq5  |
//|                                          Copyright 2025, xxxxxxxx|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"
#property version   "1.03"
#property description "A universal EA to test and optimize indicator strategies."

#include <Trade\Trade.mqh>
#include <MyIncludes\Expert\Signal\Signal_Supertrend.mqh>

//--- Enum to select which indicator to test
enum ENUM_SIGNAL_TYPE
  {
   SIGNAL_SUPERTREND
  };

//--- EA Input Parameters ---
input group "Strategy Settings"
input ENUM_SIGNAL_TYPE InpSignalType = SIGNAL_SUPERTREND;
input ulong            InpMagicNumber = 12345;
input double           InpLotSize = 0.01;
input int              InpStopLossPips = 200;
input int              InpTakeProfitPips = 600;

input group "Supertrend Settings"
input int InpSupertrendPeriod = 10;
input double InpSupertrendMultiplier = 3.0;

//--- Global Objects ---
CTrade      g_trade;
CSignalBase *g_signal_module;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   switch(InpSignalType)
     {
      case SIGNAL_SUPERTREND:
        {
         CSignalSupertrend *st_module = new CSignalSupertrend();
         if(CheckPointer(st_module) == POINTER_INVALID)
            return(INIT_FAILED);
         if(!st_module.Init(_Symbol, _Period, InpSupertrendPeriod, InpSupertrendMultiplier))
           {
            delete st_module;
            return(INIT_FAILED);
           }
         g_signal_module = st_module;
         break;
        }
     }

   if(CheckPointer(g_signal_module) == POINTER_INVALID)
     {
      Print("Failed to initialize a signal module.");
      return(INIT_FAILED);
     }

   g_trade.SetExpertMagicNumber(InpMagicNumber);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(CheckPointer(g_signal_module) != POINTER_INVALID)
      delete g_signal_module;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- We only work on the open of a new bar for stability
   static datetime last_bar_time = 0;
   datetime time[1];
   if(CopyTime(_Symbol, _Period, 0, 1, time) <= 0)
      return;

   if(time[0] == last_bar_time)
      return;
   last_bar_time = time[0];

   if(CheckPointer(g_signal_module) == POINTER_INVALID)
      return;

//--- Get signals from the previous (closed) bar (shift=1) and the one before that (shift=2)
   int current_signal = g_signal_module.GetSignal(1);
   int previous_signal = g_signal_module.GetSignal(2);

//--- Check for a new BUY signal (transition from not-buy to buy)
   if(current_signal == 1 && previous_signal != 1)
     {
      //--- Close any open SELL positions with the same magic number
      if(PositionSelect(_Symbol))
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            g_trade.PositionClose(_Symbol);
        }

      //--- Open a new BUY position if no position for this EA exists
      if(!PositionSelect(_Symbol) || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
        {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = (InpStopLossPips > 0) ? price - InpStopLossPips * _Point : 0;
         double tp = (InpTakeProfitPips > 0) ? price + InpTakeProfitPips * _Point : 0;
         g_trade.Buy(InpLotSize, _Symbol, price, sl, tp, "Indicator Tester");
        }
     }

//--- Check for a new SELL signal (transition from not-sell to sell)
   if(current_signal == -1 && previous_signal != -1)
     {
      //--- Close any open BUY positions with the same magic number
      if(PositionSelect(_Symbol))
        {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            g_trade.PositionClose(_Symbol);
        }

      //--- Open a new SELL position if no position for this EA exists
      if(!PositionSelect(_Symbol) || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
        {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = (InpStopLossPips > 0) ? price + InpStopLossPips * _Point : 0;
         double tp = (InpTakeProfitPips > 0) ? price - InpTakeProfitPips * _Point : 0;
         g_trade.Sell(InpLotSize, _Symbol, price, sl, tp, "Indicator Tester");
        }
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
