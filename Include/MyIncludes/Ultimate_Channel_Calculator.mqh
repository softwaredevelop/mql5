//+------------------------------------------------------------------+
//|                                 Ultimate_Channel_Calculator.mqh  |
//|      Calculation engine for John Ehlers' Ultimate Channel.       |
//|      VERSION 1.00: Optimized for incremental calculation.        |
//|                                        Copyright 2025, xxxxxxxx  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, xxxxxxxx"

#include <MyIncludes\Ehlers_Smoother_Calculator.mqh>

//+==================================================================+
//|             CLASS 1: CUltimateChannelCalculator                  |
//+==================================================================+
class CUltimateChannelCalculator
  {
protected:
   //--- Sub-Engines
   CEhlersSmootherCalculator *m_calc_center; // For Price
   CEhlersSmootherCalculator *m_calc_range;  // For True Range (STR)

   int               m_length;      // Period for Price Smoothing
   int               m_str_length;  // Period for True Range Smoothing
   double            m_multiplier;  // Channel Multiplier

   //--- Internal Buffers
   double            m_tr_buffer[]; // Raw True Range
   double            m_str_buffer[];// Smoothed True Range
   double            m_center_buffer[]; // Smoothed Price

   //--- Persistent Price Buffers for TR calculation
   double            m_high[];
   double            m_low[];
   double            m_close[];

   //--- Factory Method
   virtual void      CreateEngines(void);

   //--- Helper: Calculate True Range
   double            CalcTrueRange(int i);

public:
                     CUltimateChannelCalculator(void);
   virtual          ~CUltimateChannelCalculator(void);

   bool              Init(int length, int str_length, double multiplier);

   //--- Main Calculation
   void              Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
                               double &upper_buffer[], double &lower_buffer[], double &middle_buffer[]);

   //--- Virtual Prepare (to be overridden by HA)
   virtual bool      PrepareData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CUltimateChannelCalculator::CUltimateChannelCalculator(void)
  {
   m_calc_center = NULL;
   m_calc_range = NULL;
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CUltimateChannelCalculator::~CUltimateChannelCalculator(void)
  {
   if(CheckPointer(m_calc_center) != POINTER_INVALID)
      delete m_calc_center;
   if(CheckPointer(m_calc_range) != POINTER_INVALID)
      delete m_calc_range;
  }

//+------------------------------------------------------------------+
//| Factory Method (Standard)                                        |
//+------------------------------------------------------------------+
void CUltimateChannelCalculator::CreateEngines(void)
  {
   m_calc_center = new CEhlersSmootherCalculator();
   m_calc_range = new CEhlersSmootherCalculator();
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
bool CUltimateChannelCalculator::Init(int length, int str_length, double multiplier)
  {
   m_length = length;
   m_str_length = str_length;
   m_multiplier = multiplier;

   CreateEngines();

   if(CheckPointer(m_calc_center) == POINTER_INVALID || CheckPointer(m_calc_range) == POINTER_INVALID)
      return false;

// Init Center Calculator (Ultimate Smoother on Price)
   if(!m_calc_center.Init(m_length, ULTIMATESMOOTHER, SOURCE_PRICE))
      return false;

// Init Range Calculator (Ultimate Smoother on True Range)
// Note: We use SOURCE_PRICE mode for the sub-engine, but we will feed it TR values as "price"
   if(!m_calc_range.Init(m_str_length, ULTIMATESMOOTHER, SOURCE_PRICE))
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Main Calculation                                                 |
//+------------------------------------------------------------------+
void CUltimateChannelCalculator::Calculate(int rates_total, int prev_calculated, ENUM_APPLIED_PRICE price_type, const double &open[], const double &high[], const double &low[], const double &close[],
      double &upper_buffer[], double &lower_buffer[], double &middle_buffer[])
  {
   if(rates_total < MathMax(m_length, m_str_length))
      return;

   int start_index = (prev_calculated > 0) ? prev_calculated - 1 : 0;

// Resize Buffers
   if(ArraySize(m_tr_buffer) != rates_total)
     {
      ArrayResize(m_tr_buffer, rates_total);
      ArrayResize(m_str_buffer, rates_total);
      ArrayResize(m_center_buffer, rates_total);
      ArrayResize(m_high, rates_total);
      ArrayResize(m_low, rates_total);
      ArrayResize(m_close, rates_total);
     }

// Prepare Data (Standard or HA)
   if(!PrepareData(rates_total, start_index, open, high, low, close))
      return;

//--- 1. Calculate Centerline (Ultimate Smoother on Price)
// The sub-engine handles its own data preparation internally based on the raw arrays passed
   m_calc_center.Calculate(rates_total, prev_calculated, price_type, open, high, low, close, middle_buffer);

//--- 2. Calculate True Range
   int loop_start = MathMax(1, start_index);
   for(int i = loop_start; i < rates_total; i++)
     {
      m_tr_buffer[i] = CalcTrueRange(i);
     }

//--- 3. Smooth True Range (Ultimate Smoother on TR)
// We trick the sub-engine by passing m_tr_buffer as the "Close" price
// The other arrays (open, high, low) are dummy here because price_type will be PRICE_CLOSE
   m_calc_range.Calculate(rates_total, prev_calculated, PRICE_CLOSE, m_tr_buffer, m_tr_buffer, m_tr_buffer, m_tr_buffer, m_str_buffer);

//--- 4. Calculate Bands
   for(int i = loop_start; i < rates_total; i++)
     {
      if(middle_buffer[i] != EMPTY_VALUE && m_str_buffer[i] != EMPTY_VALUE)
        {
         upper_buffer[i] = middle_buffer[i] + m_multiplier * m_str_buffer[i];
         lower_buffer[i] = middle_buffer[i] - m_multiplier * m_str_buffer[i];
        }
     }
  }

//+------------------------------------------------------------------+
//| Helper: Calculate True Range                                     |
//+------------------------------------------------------------------+
double CUltimateChannelCalculator::CalcTrueRange(int i)
  {
   double th = MathMax(m_high[i], m_close[i-1]);
   double tl = MathMin(m_low[i], m_close[i-1]);
   return th - tl;
  }

//+------------------------------------------------------------------+
//| Prepare Data (Standard)                                          |
//+------------------------------------------------------------------+
bool CUltimateChannelCalculator::PrepareData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   for(int i = start_index; i < rates_total; i++)
     {
      m_high[i] = high[i];
      m_low[i] = low[i];
      m_close[i] = close[i];
     }
   return true;
  }

//+==================================================================+
//|             CLASS 2: CUltimateChannelCalculator_HA               |
//+==================================================================+
class CUltimateChannelCalculator_HA : public CUltimateChannelCalculator
  {
private:
   CHeikinAshi_Calculator m_ha_calculator;
   double            m_ha_open[], m_ha_high[], m_ha_low[], m_ha_close[];

protected:
   virtual void      CreateEngines(void) override;
   virtual bool      PrepareData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[]) override;
  };

//+------------------------------------------------------------------+
//| Factory Method (Heikin Ashi)                                     |
//+------------------------------------------------------------------+
void CUltimateChannelCalculator_HA::CreateEngines(void)
  {
   m_calc_center = new CEhlersSmootherCalculator_HA();
// Note: For TR smoothing, we use standard smoother because TR is already calculated from HA values
   m_calc_range = new CEhlersSmootherCalculator();
  }

//+------------------------------------------------------------------+
//| Prepare Data (Heikin Ashi)                                       |
//+------------------------------------------------------------------+
bool CUltimateChannelCalculator_HA::PrepareData(int rates_total, int start_index, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   if(ArraySize(m_ha_open) != rates_total)
     {
      ArrayResize(m_ha_open, rates_total);
      ArrayResize(m_ha_high, rates_total);
      ArrayResize(m_ha_low, rates_total);
      ArrayResize(m_ha_close, rates_total);
     }

   m_ha_calculator.Calculate(rates_total, start_index, open, high, low, close, m_ha_open, m_ha_high, m_ha_low, m_ha_close);

   for(int i = start_index; i < rates_total; i++)
     {
      m_high[i] = m_ha_high[i];
      m_low[i] = m_ha_low[i];
      m_close[i] = m_ha_close[i];
     }
   return true;
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
