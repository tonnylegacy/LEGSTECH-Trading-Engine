//+------------------------------------------------------------------+
//|                                              FractalDetector.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_INDICATORS_FRACTALDETECTOR_MQH
#define LEGSTECH_INDICATORS_FRACTALDETECTOR_MQH

#include <Object.mqh>
#include "..\Core\Defs.mqh"

//+------------------------------------------------------------------+
//| Class CFractalDetector                                           |
//| Bill Williams 5-bar Fractal Scanner & Swing Tracker              |
//+------------------------------------------------------------------+
class CFractalDetector : public CObject
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_maxLookback;

   bool              IsUpperFractalAt(const MqlRates &rates[], int index, int total);
   bool              IsLowerFractalAt(const MqlRates &rates[], int index, int total);

public:
                     CFractalDetector(void);
   virtual          ~CFractalDetector(void);
                     
   bool              Init(const string symbol, ENUM_TIMEFRAMES tf, int maxLookback = 100);
   
   // Live Terminal Scanning
   bool              GetLatestUpperFractal(SFractalPoint &outPoint, int startShift = 2);
   bool              GetLatestLowerFractal(SFractalPoint &outPoint, int startShift = 2);
   int               ScanAllFractals(SFractalPoint &outFractals[], int maxCount = 20, int startShift = 2);
   
   // Offline / Deterministic Array Scanning (Test Harness Compatible)
   bool              GetLatestUpperFractalFromRates(const MqlRates &rates[], int totalRates, SFractalPoint &outPoint, int startShift = 2);
   bool              GetLatestLowerFractalFromRates(const MqlRates &rates[], int totalRates, SFractalPoint &outPoint, int startShift = 2);
   int               ScanAllFractalsFromRates(const MqlRates &rates[], int totalRates, SFractalPoint &outFractals[], int maxCount = 20, int startShift = 2);
   
   // Push and Swing Locators
   bool              FindPushHighBetween(const MqlRates &rates[], int startIdx, int endIdx, double &outHigh, int &outIdx);
   bool              FindPushLowBetween(const MqlRates &rates[], int startIdx, int endIdx, double &outLow, int &outIdx);
   
   // Strategy-Specific REMMY Scanner
   bool              EvaluateRemmySetup(const MqlRates &rates[], int totalRates, bool lookForBuy, SRemmyStructure &outSetup);
   bool              CheckFreshConfirmedFractal(const MqlRates &rates[], int totalRates, bool isBuy, SFractalPoint &outPoint, int maxAgeBars = 3);
   
   // Opposite Fractal Break Check (Runner Exit)
   bool              CheckOppositeFractalBreak(const MqlRates &rates[], int totalRates, bool isBuyPosition, double &outBrokenPrice);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFractalDetector::CFractalDetector(void)
{
   m_symbol      = "";
   m_timeframe   = PERIOD_M15;
   m_maxLookback = 100;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFractalDetector::~CFractalDetector(void)
{
}

//+------------------------------------------------------------------+
//| Initialize Fractal Detector                                      |
//+------------------------------------------------------------------+
inline bool CFractalDetector::Init(const string symbol, ENUM_TIMEFRAMES tf, int maxLookback)
{
   m_symbol      = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe   = tf;
   m_maxLookback = (maxLookback > 5) ? maxLookback : 100;
   return true;
}

//+------------------------------------------------------------------+
//| Check 5-bar Upper Fractal at specific index                      |
//+------------------------------------------------------------------+
inline bool CFractalDetector::IsUpperFractalAt(const MqlRates &rates[], int index, int total)
{
   if(index < 2 || (index + 2) >= total)
      return false;
      
   double h = rates[index].high;
   return (h > rates[index - 1].high &&
           h > rates[index - 2].high &&
           h > rates[index + 1].high &&
           h > rates[index + 2].high);
}

//+------------------------------------------------------------------+
//| Check 5-bar Lower Fractal at specific index                      |
//+------------------------------------------------------------------+
inline bool CFractalDetector::IsLowerFractalAt(const MqlRates &rates[], int index, int total)
{
   if(index < 2 || (index + 2) >= total)
      return false;
      
   double l = rates[index].low;
   return (l < rates[index - 1].low &&
           l < rates[index - 2].low &&
           l < rates[index + 1].low &&
           l < rates[index + 2].low);
}

//+------------------------------------------------------------------+
//| Live: Get Latest Upper Fractal                                   |
//+------------------------------------------------------------------+
inline bool CFractalDetector::GetLatestUpperFractal(SFractalPoint &outPoint, int startShift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(m_symbol, m_timeframe, 0, m_maxLookback, rates);
   if(copied < 5) return false;
   
   return GetLatestUpperFractalFromRates(rates, copied, outPoint, startShift);
}

//+------------------------------------------------------------------+
//| Live: Get Latest Lower Fractal                                   |
//+------------------------------------------------------------------+
inline bool CFractalDetector::GetLatestLowerFractal(SFractalPoint &outPoint, int startShift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(m_symbol, m_timeframe, 0, m_maxLookback, rates);
   if(copied < 5) return false;
   
   return GetLatestLowerFractalFromRates(rates, copied, outPoint, startShift);
}

//+------------------------------------------------------------------+
//| Live: Scan all Fractals                                          |
//+------------------------------------------------------------------+
inline int CFractalDetector::ScanAllFractals(SFractalPoint &outFractals[], int maxCount, int startShift)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(m_symbol, m_timeframe, 0, m_maxLookback, rates);
   if(copied < 5) return 0;
   
   return ScanAllFractalsFromRates(rates, copied, outFractals, maxCount, startShift);
}

//+------------------------------------------------------------------+
//| Array: Get Latest Upper Fractal                                  |
//+------------------------------------------------------------------+
inline bool CFractalDetector::GetLatestUpperFractalFromRates(const MqlRates &rates[], int totalRates, SFractalPoint &outPoint, int startShift)
{
   outPoint.Reset();
   int limit = MathMin(totalRates - 3, m_maxLookback);
   
   for(int i = MathMax(2, startShift); i <= limit; i++)
   {
      if(IsUpperFractalAt(rates, i, totalRates))
      {
         outPoint.type        = FRACTAL_UPPER;
         outPoint.price       = rates[i].high;
         outPoint.time        = rates[i].time;
         outPoint.barIndex    = i;
         outPoint.isConfirmed = true;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Array: Get Latest Lower Fractal                                  |
//+------------------------------------------------------------------+
inline bool CFractalDetector::GetLatestLowerFractalFromRates(const MqlRates &rates[], int totalRates, SFractalPoint &outPoint, int startShift)
{
   outPoint.Reset();
   int limit = MathMin(totalRates - 3, m_maxLookback);
   
   for(int i = MathMax(2, startShift); i <= limit; i++)
   {
      if(IsLowerFractalAt(rates, i, totalRates))
      {
         outPoint.type        = FRACTAL_LOWER;
         outPoint.price       = rates[i].low;
         outPoint.time        = rates[i].time;
         outPoint.barIndex    = i;
         outPoint.isConfirmed = true;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Array: Scan all Fractals                                         |
//+------------------------------------------------------------------+
inline int CFractalDetector::ScanAllFractalsFromRates(const MqlRates &rates[], int totalRates, SFractalPoint &outFractals[], int maxCount, int startShift)
{
   int count = 0;
   ArrayResize(outFractals, maxCount);
   int limit = MathMin(totalRates - 3, m_maxLookback);
   
   for(int i = MathMax(2, startShift); i <= limit && count < maxCount; i++)
   {
      if(IsUpperFractalAt(rates, i, totalRates))
      {
         outFractals[count].type        = FRACTAL_UPPER;
         outFractals[count].price       = rates[i].high;
         outFractals[count].time        = rates[i].time;
         outFractals[count].barIndex    = i;
         outFractals[count].isConfirmed = true;
         count++;
      }
      else if(IsLowerFractalAt(rates, i, totalRates))
      {
         outFractals[count].type        = FRACTAL_LOWER;
         outFractals[count].price       = rates[i].low;
         outFractals[count].time        = rates[i].time;
         outFractals[count].barIndex    = i;
         outFractals[count].isConfirmed = true;
         count++;
      }
   }
   
   ArrayResize(outFractals, count);
   return count;
}

//+------------------------------------------------------------------+
//| Find Push High between two bar indices                           |
//+------------------------------------------------------------------+
inline bool CFractalDetector::FindPushHighBetween(const MqlRates &rates[], int startIdx, int endIdx, double &outHigh, int &outIdx)
{
   outHigh = -DBL_MAX;
   outIdx  = -1;
   
   int lowIdx  = MathMin(startIdx, endIdx);
   int highIdx = MathMax(startIdx, endIdx);
   
   if(lowIdx < 0 || highIdx >= ArraySize(rates))
      return false;
      
   for(int i = lowIdx; i <= highIdx; i++)
   {
      if(rates[i].high > outHigh)
      {
         outHigh = rates[i].high;
         outIdx  = i;
      }
   }
   return (outIdx >= 0);
}

//+------------------------------------------------------------------+
//| Find Push Low between two bar indices                            |
//+------------------------------------------------------------------+
inline bool CFractalDetector::FindPushLowBetween(const MqlRates &rates[], int startIdx, int endIdx, double &outLow, int &outIdx)
{
   outLow = DBL_MAX;
   outIdx = -1;
   
   int lowIdx  = MathMin(startIdx, endIdx);
   int highIdx = MathMax(startIdx, endIdx);
   
   if(lowIdx < 0 || highIdx >= ArraySize(rates))
      return false;
      
   for(int i = lowIdx; i <= highIdx; i++)
   {
      if(rates[i].low < outLow)
      {
         outLow = rates[i].low;
         outIdx = i;
      }
   }
   return (outIdx >= 0);
}

//+------------------------------------------------------------------+
//| Evaluate REMMY Setup (15M Swing & Push Break-and-Continuation)   |
//+------------------------------------------------------------------+
inline bool CFractalDetector::EvaluateRemmySetup(const MqlRates &rates[], int totalRates, bool lookForBuy, SRemmyStructure &outSetup)
{
   outSetup.Reset();
   if(totalRates < 10) return false;
   
   if(lookForBuy)
   {
      // 1. Locate newest confirmed lower fractal (Ref Fractal for SL)
      SFractalPoint refFractal;
      if(!GetLatestLowerFractalFromRates(rates, totalRates, refFractal, 2))
         return false;
         
      // 2. Locate prior swing low before ref fractal
      SFractalPoint priorSwing;
      if(!GetLatestLowerFractalFromRates(rates, totalRates, priorSwing, refFractal.barIndex + 2))
      {
         priorSwing = refFractal;
      }
      
      // 3. Locate push high between prior swing and ref fractal (or before breakout)
      double pushHigh = 0.0;
      int pushIdx = -1;
      int searchEnd = MathMax(refFractal.barIndex + 5, priorSwing.barIndex);
      if(!FindPushHighBetween(rates, 2, searchEnd, pushHigh, pushIdx))
         return false;
         
      // 4. Check if bar 1 closed strictly above push high
      bool isBreak = (rates[1].close > pushHigh);
      
      outSetup.isValid           = true;
      outSetup.isBuy             = true;
      outSetup.refFractal        = refFractal;
      outSetup.priorSwing        = priorSwing;
      outSetup.pushPrice         = pushHigh;
      outSetup.pushTime          = rates[pushIdx].time;
      outSetup.pushBarIndex      = pushIdx;
      outSetup.isBreakConfirmed  = isBreak;
      outSetup.triggerClosePrice = rates[1].close;
      outSetup.triggerTime       = rates[1].time;
      
      return isBreak;
   }
   else
   {
      // SELL Setup:
      // 1. Locate newest confirmed upper fractal (Ref Fractal for SL)
      SFractalPoint refFractal;
      if(!GetLatestUpperFractalFromRates(rates, totalRates, refFractal, 2))
         return false;
         
      // 2. Locate prior swing high before ref fractal
      SFractalPoint priorSwing;
      if(!GetLatestUpperFractalFromRates(rates, totalRates, priorSwing, refFractal.barIndex + 2))
      {
         priorSwing = refFractal;
      }
      
      // 3. Locate push low between prior swing and ref fractal
      double pushLow = 0.0;
      int pushIdx = -1;
      int searchEnd = MathMax(refFractal.barIndex + 5, priorSwing.barIndex);
      if(!FindPushLowBetween(rates, 2, searchEnd, pushLow, pushIdx))
         return false;
         
      // 4. Check if bar 1 closed strictly below push low
      bool isBreak = (rates[1].close < pushLow);
      
      outSetup.isValid           = true;
      outSetup.isBuy             = false;
      outSetup.refFractal        = refFractal;
      outSetup.priorSwing        = priorSwing;
      outSetup.pushPrice         = pushLow;
      outSetup.pushTime          = rates[pushIdx].time;
      outSetup.pushBarIndex      = pushIdx;
      outSetup.isBreakConfirmed  = isBreak;
      outSetup.triggerClosePrice = rates[1].close;
      outSetup.triggerTime       = rates[1].time;
      
      return isBreak;
   }
}

//+------------------------------------------------------------------+
//| Check Opposite Fractal Break (Runner Exit)                       |
//+------------------------------------------------------------------+
inline bool CFractalDetector::CheckOppositeFractalBreak(const MqlRates &rates[], int totalRates, bool isBuyPosition, double &outBrokenPrice)
{
   outBrokenPrice = 0.0;
   if(totalRates < 5) return false;
   
   if(isBuyPosition)
   {
      // BUY Runner: Exit on Lower Fractal break downward (Close[1] < FractalLow)
      SFractalPoint lowerFractal;
      if(GetLatestLowerFractalFromRates(rates, totalRates, lowerFractal, 2))
      {
         if(rates[1].close < lowerFractal.price)
         {
            outBrokenPrice = lowerFractal.price;
            return true;
         }
      }
   }
   else
   {
      // SELL Runner: Exit on Upper Fractal break upward (Close[1] > FractalHigh)
      SFractalPoint upperFractal;
      if(GetLatestUpperFractalFromRates(rates, totalRates, upperFractal, 2))
      {
         if(rates[1].close > upperFractal.price)
         {
            outBrokenPrice = upperFractal.price;
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for a freshly confirmed fractal swing point                |
//| For BUY: Lower Fractal (Swing Low)                               |
//| For SELL: Upper Fractal (Swing High)                             |
//+------------------------------------------------------------------+
inline bool CFractalDetector::CheckFreshConfirmedFractal(const MqlRates &rates[], int totalRates, bool isBuy, SFractalPoint &outPoint, int maxAgeBars)
{
   outPoint.Reset();
   if(totalRates < 7) return false;
   int checkLimit = MathMin(totalRates - 3, MathMax(3, maxAgeBars + 2));
   
   if(isBuy)
   {
      // Check for lower fractal at shift 3 (confirmed by bar 1 close) or shift 2 (confirmed 3-bar swing)
      for(int i = 2; i <= checkLimit; i++)
      {
         // Standard 5-bar lower fractal: rates[i].low lower than 2 bars left and 2 bars right
         if(IsLowerFractalAt(rates, i, totalRates))
         {
            outPoint.type        = FRACTAL_LOWER;
            outPoint.price       = rates[i].low;
            outPoint.time        = rates[i].time;
            outPoint.barIndex    = i;
            outPoint.isConfirmed = true;
            return true;
         }
         // 3-bar swing low fallback (bar i lower than bar i+1 and bar i-1)
         else if(i >= 2 && (i + 1) < totalRates && rates[i].low < rates[i + 1].low && rates[i].low < rates[i - 1].low)
         {
            outPoint.type        = FRACTAL_LOWER;
            outPoint.price       = rates[i].low;
            outPoint.time        = rates[i].time;
            outPoint.barIndex    = i;
            outPoint.isConfirmed = true;
            return true;
         }
      }
   }
   else
   {
      // Check for upper fractal at shift 3 or shift 2
      for(int i = 2; i <= checkLimit; i++)
      {
         if(IsUpperFractalAt(rates, i, totalRates))
         {
            outPoint.type        = FRACTAL_UPPER;
            outPoint.price       = rates[i].high;
            outPoint.time        = rates[i].time;
            outPoint.barIndex    = i;
            outPoint.isConfirmed = true;
            return true;
         }
         else if(i >= 2 && (i + 1) < totalRates && rates[i].high > rates[i + 1].high && rates[i].high > rates[i - 1].high)
         {
            outPoint.type        = FRACTAL_UPPER;
            outPoint.price       = rates[i].high;
            outPoint.time        = rates[i].time;
            outPoint.barIndex    = i;
            outPoint.isConfirmed = true;
            return true;
         }
      }
   }
   return false;
}

#endif // LEGSTECH_INDICATORS_FRACTALDETECTOR_MQH
