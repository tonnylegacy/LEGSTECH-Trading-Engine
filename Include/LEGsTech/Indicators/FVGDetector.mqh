//+------------------------------------------------------------------+
//|                                                  FVGDetector.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_INDICATORS_FVGDETECTOR_MQH
#define LEGSTECH_INDICATORS_FVGDETECTOR_MQH

#include <Object.mqh>
#include "..\Core\Defs.mqh"

//+------------------------------------------------------------------+
//| Class CFVGDetector                                               |
//| Fair Value Gap & Inverted FVG Polarity Engine                    |
//+------------------------------------------------------------------+
class CFVGDetector : public CObject
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   double            m_minGapPoints;
   ulong             m_nextFvgId;

   bool              DetectSingleFVG(const MqlRates &rates[], int i, int total, SFVGZone &outZone);

public:
                     CFVGDetector(void);
   virtual          ~CFVGDetector(void);
                     
   bool              Init(const string symbol, ENUM_TIMEFRAMES tf, double minGapPoints = 5.0);
   
   // Array-based Detection & State Tracking
   int               ScanFVGsFromRates(const MqlRates &rates[], int totalRates, SFVGZone &outZones[], int maxZones = 30);
   void              UpdateZoneStates(const MqlRates &rates[], int totalRates, SFVGZone &inOutZones[], int zoneCount);
   
   // Live Terminal Scanning
   int               ScanLiveFVGs(SFVGZone &outZones[], int maxZones = 30);

   // Live Price Intersections
   bool              CheckPriceTap(double currentPrice, const SFVGZone &zone);
   bool              CheckZoneRetestConfirmed(const MqlRates &rates[], int totalRates, const SFVGZone &zone, bool isBuy);
   
   // POI Discovery for CALLISTO
   bool              GetNearestActivePOI(double currentPrice, const SFVGZone &zones[], int zoneCount, bool lookForDemand, SFVGZone &outZone);
   
   // Utility
   double            GetConsequentEncroachment(double top, double bottom) const { return (top + bottom) / 2.0; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFVGDetector::CFVGDetector(void)
{
   m_symbol       = "";
   m_timeframe    = PERIOD_H1;
   m_minGapPoints = 5.0;
   m_nextFvgId    = 1;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFVGDetector::~CFVGDetector(void)
{
}

//+------------------------------------------------------------------+
//| Initialize FVG Detector                                          |
//+------------------------------------------------------------------+
inline bool CFVGDetector::Init(const string symbol, ENUM_TIMEFRAMES tf, double minGapPoints)
{
   m_symbol       = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe    = tf;
   m_minGapPoints = (minGapPoints >= 0.0) ? minGapPoints : 5.0;
   m_nextFvgId    = 1;
   return true;
}

//+------------------------------------------------------------------+
//| Detect Single 3-bar FVG at index i                               |
//+------------------------------------------------------------------+
inline bool CFVGDetector::DetectSingleFVG(const MqlRates &rates[], int i, int total, SFVGZone &outZone)
{
   outZone.Reset();
   if(i < 0 || (i + 2) >= total)
      return false;
      
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   if(point <= 0.0) point = 0.00001;
   double minGapDist = m_minGapPoints * point;
   
   // 3-Bar Triplet: rates[i] (newest), rates[i+1] (impulse), rates[i+2] (oldest)
   // Bullish FVG: Low[i] > High[i+2] + minGapDist
   if(rates[i].low > (rates[i + 2].high + minGapDist))
   {
      outZone.id            = m_nextFvgId++;
      outZone.type          = FVG_BULLISH;
      outZone.state         = FVG_STATE_FRESH;
      outZone.creationTime  = rates[i].time;
      outZone.barIndex      = i;
      outZone.topPrice      = rates[i].low;
      outZone.bottomPrice   = rates[i + 2].high;
      outZone.midPrice      = GetConsequentEncroachment(outZone.topPrice, outZone.bottomPrice);
      outZone.gapSizePoints = (outZone.topPrice - outZone.bottomPrice) / point;
      outZone.isMitigated   = false;
      outZone.isInverted    = false;
      outZone.tapCount      = 0;
      return true;
   }
   
   // Bearish FVG: High[i] < Low[i+2] - minGapDist
   if(rates[i].high < (rates[i + 2].low - minGapDist))
   {
      outZone.id            = m_nextFvgId++;
      outZone.type          = FVG_BEARISH;
      outZone.state         = FVG_STATE_FRESH;
      outZone.creationTime  = rates[i].time;
      outZone.barIndex      = i;
      outZone.topPrice      = rates[i + 2].low;
      outZone.bottomPrice   = rates[i].high;
      outZone.midPrice      = GetConsequentEncroachment(outZone.topPrice, outZone.bottomPrice);
      outZone.gapSizePoints = (outZone.topPrice - outZone.bottomPrice) / point;
      outZone.isMitigated   = false;
      outZone.isInverted    = false;
      outZone.tapCount      = 0;
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Scan FVGs from rates array                                       |
//+------------------------------------------------------------------+
inline int CFVGDetector::ScanFVGsFromRates(const MqlRates &rates[], int totalRates, SFVGZone &outZones[], int maxZones)
{
   int count = 0;
   ArrayResize(outZones, maxZones);
   
   for(int i = 1; i <= totalRates - 3 && count < maxZones; i++)
   {
      SFVGZone zone;
      if(DetectSingleFVG(rates, i, totalRates, zone))
      {
         outZones[count] = zone;
         count++;
      }
   }
   
   ArrayResize(outZones, count);
   
   // Update lifecycle states across historical candles
   UpdateZoneStates(rates, totalRates, outZones, count);
   
   return count;
}

//+------------------------------------------------------------------+
//| Update FVG lifecycle states & detect iFVG polarity inversions    |
//+------------------------------------------------------------------+
inline void CFVGDetector::UpdateZoneStates(const MqlRates &rates[], int totalRates, SFVGZone &inOutZones[], int zoneCount)
{
   for(int z = 0; z < zoneCount; z++)
   {
      int startBar = inOutZones[z].barIndex - 1;
      
      for(int k = startBar; k >= 1 && k < totalRates; k--)
      {
         if(inOutZones[z].type == FVG_BULLISH)
         {
            // Breach downward -> Inverted Bearish FVG
            if(rates[k].close < inOutZones[z].bottomPrice)
            {
               inOutZones[z].state         = FVG_STATE_INVERTED_ACTIVE;
               inOutZones[z].isInverted    = true;
               inOutZones[z].isMitigated   = false;
               inOutZones[z].type          = FVG_INVERTED_BEARISH;
               inOutZones[z].inversionTime = rates[k].time;
            }
            else if(rates[k].low <= inOutZones[z].topPrice)
            {
               inOutZones[z].tapCount++;
               if(rates[k].low <= inOutZones[z].midPrice)
               {
                  inOutZones[z].isMitigated = true;
                  inOutZones[z].state       = FVG_STATE_MITIGATED;
               }
               else
               {
                  inOutZones[z].state = FVG_STATE_PARTIALLY_TAPPED;
               }
            }
         }
         else if(inOutZones[z].type == FVG_BEARISH)
         {
            // Breach upward -> Inverted Bullish FVG
            if(rates[k].close > inOutZones[z].topPrice)
            {
               inOutZones[z].state         = FVG_STATE_INVERTED_ACTIVE;
               inOutZones[z].isInverted    = true;
               inOutZones[z].isMitigated   = false;
               inOutZones[z].type          = FVG_INVERTED_BULLISH;
               inOutZones[z].inversionTime = rates[k].time;
            }
            else if(rates[k].high >= inOutZones[z].bottomPrice)
            {
               inOutZones[z].tapCount++;
               if(rates[k].high >= inOutZones[z].midPrice)
               {
                  inOutZones[z].isMitigated = true;
                  inOutZones[z].state       = FVG_STATE_MITIGATED;
               }
               else
               {
                  inOutZones[z].state = FVG_STATE_PARTIALLY_TAPPED;
               }
            }
         }
         else if(inOutZones[z].type == FVG_INVERTED_BULLISH)
         {
            // Inverted bullish zone acts as support
            if(rates[k].close < inOutZones[z].bottomPrice)
            {
               inOutZones[z].state = FVG_STATE_INVALIDATED;
            }
            else if(rates[k].low <= inOutZones[z].topPrice)
            {
               inOutZones[z].tapCount++;
            }
         }
         else if(inOutZones[z].type == FVG_INVERTED_BEARISH)
         {
            // Inverted bearish zone acts as resistance
            if(rates[k].close > inOutZones[z].topPrice)
            {
               inOutZones[z].state = FVG_STATE_INVALIDATED;
            }
            else if(rates[k].high >= inOutZones[z].bottomPrice)
            {
               inOutZones[z].tapCount++;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Live scan wrapper                                                |
//+------------------------------------------------------------------+
inline int CFVGDetector::ScanLiveFVGs(SFVGZone &outZones[], int maxZones)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(m_symbol, m_timeframe, 0, 100, rates);
   if(copied < 5) return 0;
   
   return ScanFVGsFromRates(rates, copied, outZones, maxZones);
}

//+------------------------------------------------------------------+
//| Check if price tapped inside zone                                |
//+------------------------------------------------------------------+
inline bool CFVGDetector::CheckPriceTap(double currentPrice, const SFVGZone &zone)
{
   return (currentPrice >= zone.bottomPrice && currentPrice <= zone.topPrice);
}

//+------------------------------------------------------------------+
//| Check if zone retest confirmed on candle close                   |
//+------------------------------------------------------------------+
inline bool CFVGDetector::CheckZoneRetestConfirmed(const MqlRates &rates[], int totalRates, const SFVGZone &zone, bool isBuy)
{
   if(totalRates < 2) return false;
   
   if(isBuy)
   {
      // Buy Retest: Dips into zone (Low[1] <= TopPrice) and closes above BottomPrice with bullish body
      bool dipped = (rates[1].low <= zone.topPrice);
      bool closedAboveBottom = (rates[1].close > zone.bottomPrice);
      bool bullishBody = (rates[1].close >= rates[1].open);
      return (dipped && closedAboveBottom && bullishBody);
   }
   else
   {
      // Sell Retest: Rallies into zone (High[1] >= BottomPrice) and closes below TopPrice with bearish body
      bool rallied = (rates[1].high >= zone.bottomPrice);
      bool closedBelowTop = (rates[1].close < zone.topPrice);
      bool bearishBody = (rates[1].close <= rates[1].open);
      return (rallied && closedBelowTop && bearishBody);
   }
}

//+------------------------------------------------------------------+
//| Get Nearest Active POI for CALLISTO                              |
//+------------------------------------------------------------------+
inline bool CFVGDetector::GetNearestActivePOI(double currentPrice, const SFVGZone &zones[], int zoneCount, bool lookForDemand, SFVGZone &outZone)
{
   outZone.Reset();
   double minDistance = DBL_MAX;
   int bestIdx = -1;
   
   for(int i = 0; i < zoneCount; i++)
   {
      if(zones[i].state == FVG_STATE_INVALIDATED || zones[i].state == FVG_STATE_MITIGATED || zones[i].isMitigated)
         continue;
         
      if(lookForDemand)
      {
         // Look for Bullish FVG or Inverted Bullish FVG
         // STRICT INSTITUTIONAL RULE: Demand is support. If currentPrice has pierced below bottomPrice, it is blown!
         if(zones[i].type == FVG_BULLISH || zones[i].type == FVG_INVERTED_BULLISH)
         {
            if(currentPrice < zones[i].bottomPrice)
               continue; // Blown demand zone -> Ignore

            double dist = 0.0;
            if(currentPrice > zones[i].topPrice)
               dist = currentPrice - zones[i].topPrice; // Price above demand approaching it
            else
               dist = 0.0; // Price inside demand zone [bottomPrice, topPrice]

            if(dist < minDistance)
            {
               minDistance = dist;
               bestIdx = i;
            }
         }
      }
      else
      {
         // Look for Bearish FVG or Inverted Bearish FVG
         // STRICT INSTITUTIONAL RULE: Supply is resistance. If currentPrice has pierced above topPrice, it is blown!
         if(zones[i].type == FVG_BEARISH || zones[i].type == FVG_INVERTED_BEARISH)
         {
            if(currentPrice > zones[i].topPrice)
               continue; // Blown supply zone -> Ignore

            double dist = 0.0;
            if(currentPrice < zones[i].bottomPrice)
               dist = zones[i].bottomPrice - currentPrice; // Price below supply approaching it
            else
               dist = 0.0; // Price inside supply zone [bottomPrice, topPrice]

            if(dist < minDistance)
            {
               minDistance = dist;
               bestIdx = i;
            }
         }
      }
   }
   
   if(bestIdx >= 0)
   {
      outZone = zones[bestIdx];
      return true;
   }
   return false;
}

#endif // LEGSTECH_INDICATORS_FVGDETECTOR_MQH
