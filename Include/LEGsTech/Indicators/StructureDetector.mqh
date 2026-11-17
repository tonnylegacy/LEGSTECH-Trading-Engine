//+------------------------------------------------------------------+
//|                                            StructureDetector.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_INDICATORS_STRUCTUREDETECTOR_MQH
#define LEGSTECH_INDICATORS_STRUCTUREDETECTOR_MQH

#include <Object.mqh>
#include "..\Core\Defs.mqh"

//+------------------------------------------------------------------+
//| Class CStructureDetector                                         |
//| Market Structure Shifts, CHoCH Body Closes & Engulfing Patterns  |
//+------------------------------------------------------------------+
class CStructureDetector : public CObject
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

public:
                     CStructureDetector(void);
   virtual          ~CStructureDetector(void);
                     
   bool              Init(const string symbol, ENUM_TIMEFRAMES tf);
   
   // CHoCH / MSS Detection
   bool              DetectCHoCHFromRates(const MqlRates &rates[], int totalRates, double refSwingLevel, bool lookForBullish, SStructureResult &outResult);
   
   // Engulfing Pattern Detection
   ENUM_ENGULFING_TYPE DetectEngulfingFromRates(const MqlRates &rates[], int barIndex, double tolerancePoints = 2.0);
   
   // Pure Body Close Verification Helper
   bool              IsBodyCloseAbove(const MqlRates &rate, double level) const { return rate.close > level; }
   bool              IsBodyCloseBelow(const MqlRates &rate, double level) const { return rate.close < level; }
   
   // Order Block Detector Helper
   bool              FindOrderBlock(const MqlRates &rates[], int totalRates, int impulseIndex, bool isBullish, double &outObTop, double &outObBottom, datetime &outObTime);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStructureDetector::CStructureDetector(void)
{
   m_symbol    = "";
   m_timeframe = PERIOD_M5;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStructureDetector::~CStructureDetector(void)
{
}

//+------------------------------------------------------------------+
//| Initialize Structure Detector                                    |
//+------------------------------------------------------------------+
inline bool CStructureDetector::Init(const string symbol, ENUM_TIMEFRAMES tf)
{
   m_symbol    = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe = tf;
   return true;
}

//+------------------------------------------------------------------+
//| Detect CHoCH with strict candle body close confirmation          |
//+------------------------------------------------------------------+
inline bool CStructureDetector::DetectCHoCHFromRates(const MqlRates &rates[], int totalRates, double refSwingLevel, bool lookForBullish, SStructureResult &outResult)
{
   outResult.Reset();
   if(totalRates < 2 || refSwingLevel <= 0.0)
      return false;
      
   const MqlRates bar1 = rates[1];
   
   if(lookForBullish)
   {
      // Bullish CHoCH: Candle body closes strictly above reference swing high
      if(bar1.close > refSwingLevel && bar1.close > bar1.open)
      {
         outResult.eventType    = STRUCT_EVENT_CHOCH_BULLISH;
         outResult.eventTime    = bar1.time;
         outResult.barIndex     = 1;
         outResult.brokenPrice  = refSwingLevel;
         outResult.triggerClose = bar1.close;
         outResult.isBodyClose  = true;
         return true;
      }
      else if(bar1.high > refSwingLevel)
      {
         // Wick sweep only -> liquidity grab, NOT CHoCH
         outResult.eventType    = STRUCT_EVENT_SWEEP_BULLISH;
         outResult.eventTime    = bar1.time;
         outResult.barIndex     = 1;
         outResult.brokenPrice  = refSwingLevel;
         outResult.triggerClose = bar1.close;
         outResult.isBodyClose  = false;
         return false;
      }
   }
   else
   {
      // Bearish CHoCH: Candle body closes strictly below reference swing low
      if(bar1.close < refSwingLevel && bar1.close < bar1.open)
      {
         outResult.eventType    = STRUCT_EVENT_CHOCH_BEARISH;
         outResult.eventTime    = bar1.time;
         outResult.barIndex     = 1;
         outResult.brokenPrice  = refSwingLevel;
         outResult.triggerClose = bar1.close;
         outResult.isBodyClose  = true;
         return true;
      }
      else if(bar1.low < refSwingLevel)
      {
         // Wick sweep only -> liquidity grab, NOT CHoCH
         outResult.eventType    = STRUCT_EVENT_SWEEP_BEARISH;
         outResult.eventTime    = bar1.time;
         outResult.barIndex     = 1;
         outResult.brokenPrice  = refSwingLevel;
         outResult.triggerClose = bar1.close;
         outResult.isBodyClose  = false;
         return false;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Detect Directional Engulfing Pattern                             |
//+------------------------------------------------------------------+
inline ENUM_ENGULFING_TYPE CStructureDetector::DetectEngulfingFromRates(const MqlRates &rates[], int barIndex, double tolerancePoints)
{
   if(barIndex < 0 || (barIndex + 1) >= ArraySize(rates))
      return ENGULFING_NONE;
      
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   if(point <= 0.0) point = 0.00001;
   double tolDist = tolerancePoints * point;
   
   const MqlRates curr = rates[barIndex];     // Trigger candle (e.g. Bar 1)
   const MqlRates prev = rates[barIndex + 1]; // Previous candle (e.g. Bar 2)
   
   // 1. Bullish Engulfing:
   // Prev candle is bearish (close < open)
   // Curr candle is bullish (close > open)
   // Curr close strictly > Prev open
   // Curr open <= Prev close + tolerance
   // Curr body size >= Prev body size
   if(prev.close < prev.open && curr.close > curr.open)
   {
      if(curr.close > prev.open && curr.open <= (prev.close + tolDist))
      {
         double prevBody = prev.open - prev.close;
         double currBody = curr.close - curr.open;
         if(currBody >= prevBody)
         {
            return ENGULFING_BULLISH;
         }
      }
   }
   
   // 2. Bearish Engulfing:
   // Prev candle is bullish (close > open)
   // Curr candle is bearish (close < open)
   // Curr close strictly < Prev open
   // Curr open >= Prev close - tolerance
   // Curr body size >= Prev body size
   if(prev.close > prev.open && curr.close < curr.open)
   {
      if(curr.close < prev.open && curr.open >= (prev.close - tolDist))
      {
         double prevBody = prev.close - prev.open;
         double currBody = curr.open - curr.close;
         if(currBody >= prevBody)
         {
            return ENGULFING_BEARISH;
         }
      }
   }
   
   return ENGULFING_NONE;
}

//+------------------------------------------------------------------+
//| Find Order Block candle prior to displacement impulse            |
//+------------------------------------------------------------------+
inline bool CStructureDetector::FindOrderBlock(const MqlRates &rates[], int totalRates, int impulseIndex, bool isBullish, double &outObTop, double &outObBottom, datetime &outObTime)
{
   outObTop    = 0.0;
   outObBottom = 0.0;
   outObTime   = 0;
   
   if(impulseIndex < 0 || impulseIndex >= totalRates)
      return false;
      
   double currentPrice = rates[0].close;
   
   // Scan up to 120 historical bars for a structural displacement order block
   int maxScan = MathMin(totalRates - 2, impulseIndex + 120);
   for(int i = impulseIndex + 1; i < maxScan; i++)
   {
      if(isBullish)
      {
         // Bullish OB: down candle followed by strong bullish displacement
         if(rates[i].close < rates[i].open && rates[i-1].close > rates[i].high)
         {
            // Must be below or containing current price (valid demand support)
            if(currentPrice >= rates[i].low)
            {
               outObTop    = rates[i].high;
               outObBottom = rates[i].low;
               outObTime   = rates[i].time;
               return true;
            }
         }
      }
      else
      {
         // Bearish OB: up candle followed by strong bearish displacement
         if(rates[i].close > rates[i].open && rates[i-1].close < rates[i].low)
         {
            // Must be above or containing current price (valid supply resistance)
            if(currentPrice <= rates[i].high)
            {
               outObTop    = rates[i].high;
               outObBottom = rates[i].low;
               outObTime   = rates[i].time;
               return true;
            }
         }
      }
   }
   
   return false;
}

#endif // LEGSTECH_INDICATORS_STRUCTUREDETECTOR_MQH
