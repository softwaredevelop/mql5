//+------------------------------------------------------------------+
//|                                                 Signal_Base.mqh  |
//|         Abstract base class for all indicator signal modules.    |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CSignalBase
  {
public:
   //--- Pure virtual method that must be implemented by child classes
   virtual int       GetSignal(int shift) = 0; // 1 for Buy, -1 for Sell, 0 for Neutral

   //--- Virtual destructor
   virtual          ~CSignalBase() {};
  };
//+------------------------------------------------------------------+
