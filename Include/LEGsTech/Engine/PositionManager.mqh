//+------------------------------------------------------------------+
//|                                              PositionManager.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//|                                              Version: V1.80      |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_ENGINE_POSITIONMANAGER_MQH
#define LEGSTECH_ENGINE_POSITIONMANAGER_MQH

#include <Object.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include "..\Core\Defs.mqh"
#include "SymbolHelper.mqh"
#include "ExecutionEngine.mqh"

//+------------------------------------------------------------------+
//| Ticket Modification Failure Cooldown Record                      |
//+------------------------------------------------------------------+
struct SModifyCooldown
{
   ulong    ticket;
   datetime lastFailedTime;
};

//+------------------------------------------------------------------+
//| Class CPositionManager                                           |
//| Manages multi-ticket pairs, BE moves on TP1, and runner exits    |
//| V1.8: Decoupled P1 Banker / P2 Runner & Manual Close Safeguards   |
//+------------------------------------------------------------------+
class CPositionManager : public CObject
{
private:
   string               m_symbol;
   ulong                m_magic_number;
   CExecutionEngine    *m_exec_engine;
   CSymbolHelper       *m_sym_helper;
   CPositionInfo        m_pos_info;
   
   STrackedPair         m_pairs[];
   int                  m_pair_count;
   bool                 m_is_initialized;

   SModifyCooldown      m_cooldowns[];
   int                  m_cooldown_count;

   // Offline Mock state map
   bool                 m_mock_mode;

   bool                 IsPositionOpen(ulong ticket);
   bool                 WasClosedWithProfit(ulong ticket);
   bool                 IsP1ClosedAtTP1(int pairIdx);
   bool                 IsTicketInCooldown(ulong ticket);
   void                 SetTicketCooldown(ulong ticket);
   void                 ClearTicketCooldown(ulong ticket);

public:
                        CPositionManager();
   virtual             ~CPositionManager();

   bool                 Init(const string symbol,
                             ulong magicNumber,
                             CExecutionEngine *execEngine,
                             CSymbolHelper *symHelper);

   // Overloaded Register methods for full backward and forward compatibility
   void                 RegisterPositions(ulong ticket1,
                                          ulong ticket2,
                                          ENUM_STRATEGY_TYPE strat,
                                          ENUM_ORDER_TYPE orderType,
                                          double entryPrice,
                                          double initialSL,
                                          double tp1Price);

   void                 RegisterPositions(ulong ticket1,
                                          ulong ticket2,
                                          ENUM_STRATEGY_TYPE strat);

   void                 UpdatePositionState(double beOffsetPips = 2.0, double beTriggerPips = 50.0);
   void                 ApplyActiveTrailing(const SStrategyConfig &config);
   bool                 CheckAndApplyBreakEven(ulong ticketRunner, double entryPrice, double beOffsetPips, ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY);
   bool                 CheckRunnerExit(ulong ticketRunner, bool oppositeSignal);
   int                  FindPairIndex(ulong ticket);
   
   int                  GetActiveTicketCount(ulong magicNumber = 0);
   double               GetFloatingPnL();
   int                  GetTrackedPairCount() const { return m_pair_count; }
   bool                 GetTrackedPair(int index, STrackedPair &outPair) const;
   void                 ClearClosedPairs();

   // Mock Controls
   void                 SetMockMode(bool enabled) { m_mock_mode = enabled; }
   void                 SetMockPairClosed(ulong ticket, bool closed);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPositionManager::CPositionManager()
{
   m_symbol         = "";
   m_magic_number   = 0;
   m_exec_engine    = NULL;
   m_sym_helper     = NULL;
   m_pair_count     = 0;
   m_cooldown_count = 0;
   m_is_initialized = false;
   m_mock_mode      = false;
   ArrayResize(m_pairs, 0);
   ArrayResize(m_cooldowns, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPositionManager::~CPositionManager()
{
   ArrayFree(m_pairs);
   ArrayFree(m_cooldowns);
}

//+------------------------------------------------------------------+
//| Initialize Position Manager                                      |
//+------------------------------------------------------------------+
inline bool CPositionManager::Init(const string symbol,
                                  ulong magicNumber,
                                  CExecutionEngine *execEngine,
                                  CSymbolHelper *symHelper)
{
   m_symbol         = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_magic_number   = magicNumber;
   m_exec_engine    = execEngine;
   m_sym_helper     = symHelper;
   m_pair_count     = 0;
   m_cooldown_count = 0;
   ArrayResize(m_pairs, 0);
   ArrayResize(m_cooldowns, 0);
   
   m_is_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Check if position ticket is currently active                     |
//+------------------------------------------------------------------+
inline bool CPositionManager::IsPositionOpen(ulong ticket)
{
   if(ticket == 0) return false;
   if(m_mock_mode)
   {
      for(int i = 0; i < m_pair_count; i++)
      {
         if(m_pairs[i].ticket1 == ticket) return !m_pairs[i].p1Closed;
         if(m_pairs[i].ticket2 == ticket) return !m_pairs[i].p2Closed;
      }
      return false;
   }
   return m_pos_info.SelectByTicket(ticket);
}

//+------------------------------------------------------------------+
//| Check if ticket closed with profit via deal history              |
//| V1.8: Strictly requires net or gross profit > 0 (prevents losses)|
//+------------------------------------------------------------------+
inline bool CPositionManager::WasClosedWithProfit(ulong ticket)
{
   if(ticket == 0) return false;
   if(m_mock_mode) return true;
   
   if(!HistorySelectByPosition(ticket))
   {
      datetime fromTime = TimeCurrent() - (86400 * 7); // Select past 7 days fallback
      HistorySelect(fromTime, TimeCurrent() + 60);
      if(!HistorySelectByPosition(ticket))
         return false;
   }
   
   int totalDeals = HistoryDealsTotal();
   if(totalDeals == 0) return false;
   
   double grossProfit = 0.0;
   double netProfit   = 0.0;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double swap   = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         double comm   = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         
         grossProfit += profit;
         netProfit   += (profit + swap + comm);
      }
   }
   
   // Strictly requires positive profit (must NOT be closed at a loss or flat 0)
   return (grossProfit > 0.0 || netProfit > 0.0);
}

//+------------------------------------------------------------------+
//| Verify if Position 1 closed by hitting verified TP1 with profit  |
//| V1.8: Triple-verification (DEAL_REASON_TP, exit price, pip dist) |
//+------------------------------------------------------------------+
inline bool CPositionManager::IsP1ClosedAtTP1(int pairIdx)
{
   if(pairIdx < 0 || pairIdx >= m_pair_count) return false;
   ulong ticket = m_pairs[pairIdx].ticket1;
   if(ticket == 0) return false;
   if(m_mock_mode) return true;
   
   if(!HistorySelectByPosition(ticket))
   {
      datetime fromTime = TimeCurrent() - (86400 * 7);
      HistorySelect(fromTime, TimeCurrent() + 60);
      if(!HistorySelectByPosition(ticket))
         return false;
   }
   
   int totalDeals = HistoryDealsTotal();
   if(totalDeals == 0) return false;
   
   double grossProfit = 0.0;
   double exitPrice = 0.0;
   ENUM_DEAL_REASON dealReason = DEAL_REASON_CLIENT;
   bool hasOutDeal = false;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_ENTRY entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         grossProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         
         if(entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT || entryType == DEAL_ENTRY_OUT_BY)
         {
            exitPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            dealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);
            hasOutDeal = true;
         }
      }
   }
   
   // Position 1 MUST have closed with strictly positive gross profit
   if(grossProfit <= 0.0) return false;
   
   // 1. Direct server deal reason flag for Take Profit
   if(dealReason == DEAL_REASON_TP) return true;
   
   // 2. Check exit price against registered TP1 target price (within 5-pip tolerance for slippage)
   double tp1 = m_pairs[pairIdx].tp1Price;
   if(tp1 > 0.0 && exitPrice > 0.0 && m_sym_helper != NULL)
   {
      double tolerance = m_sym_helper.PipToPrice(5.0);
      if(m_pairs[pairIdx].orderType == ORDER_TYPE_BUY)
      {
         if(exitPrice >= (tp1 - tolerance)) return true;
      }
      else if(m_pairs[pairIdx].orderType == ORDER_TYPE_SELL)
      {
         if(exitPrice <= (tp1 + tolerance)) return true;
      }
   }
   
   // 3. Fallback: Check profit distance in pips against standard TP1 threshold (>= 80 pips)
   if(exitPrice > 0.0 && m_pairs[pairIdx].entryPrice > 0.0 && m_sym_helper != NULL)
   {
      double dist = (m_pairs[pairIdx].orderType == ORDER_TYPE_BUY) ? 
                    (exitPrice - m_pairs[pairIdx].entryPrice) : 
                    (m_pairs[pairIdx].entryPrice - exitPrice);
      double pips = m_sym_helper.PriceToPip(dist);
      if(pips >= 80.0) return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if ticket is under failed modification cooldown            |
//+------------------------------------------------------------------+
inline bool CPositionManager::IsTicketInCooldown(ulong ticket)
{
   if(ticket == 0) return false;
   datetime now = TimeCurrent();
   for(int i = 0; i < m_cooldown_count; i++)
   {
      if(m_cooldowns[i].ticket == ticket)
      {
         if((now - m_cooldowns[i].lastFailedTime) < 5)
            return true; // Still within 5-second cooldown
         else
            return false; // Cooldown expired
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Set or refresh modification failure cooldown for a ticket        |
//+------------------------------------------------------------------+
inline void CPositionManager::SetTicketCooldown(ulong ticket)
{
   if(ticket == 0) return;
   datetime now = TimeCurrent();
   for(int i = 0; i < m_cooldown_count; i++)
   {
      if(m_cooldowns[i].ticket == ticket)
      {
         m_cooldowns[i].lastFailedTime = now;
         return;
      }
   }
   int newSize = m_cooldown_count + 1;
   ArrayResize(m_cooldowns, newSize);
   m_cooldowns[m_cooldown_count].ticket = ticket;
   m_cooldowns[m_cooldown_count].lastFailedTime = now;
   m_cooldown_count = newSize;
}

//+------------------------------------------------------------------+
//| Clear modification cooldown upon successful modification         |
//+------------------------------------------------------------------+
inline void CPositionManager::ClearTicketCooldown(ulong ticket)
{
   for(int i = 0; i < m_cooldown_count; i++)
   {
      if(m_cooldowns[i].ticket == ticket)
      {
         m_cooldowns[i] = m_cooldowns[m_cooldown_count - 1];
         m_cooldown_count--;
         ArrayResize(m_cooldowns, m_cooldown_count);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Register new execution pair (Full signature)                     |
//+------------------------------------------------------------------+
inline void CPositionManager::RegisterPositions(ulong ticket1,
                                                ulong ticket2,
                                                ENUM_STRATEGY_TYPE strat,
                                                ENUM_ORDER_TYPE orderType,
                                                double entryPrice,
                                                double initialSL,
                                                double tp1Price)
{
   m_pair_count++;
   ArrayResize(m_pairs, m_pair_count);
   
   m_pairs[m_pair_count - 1].ticket1        = ticket1;
   m_pairs[m_pair_count - 1].ticket2        = ticket2;
   m_pairs[m_pair_count - 1].strategy       = strat;
   m_pairs[m_pair_count - 1].orderType      = orderType;
   m_pairs[m_pair_count - 1].entryPrice     = entryPrice;
   m_pairs[m_pair_count - 1].initialSL      = initialSL;
   m_pairs[m_pair_count - 1].tp1Price       = tp1Price;
   m_pairs[m_pair_count - 1].p1BEApplied    = false;
   m_pairs[m_pair_count - 1].p1Closed       = (ticket1 == 0);
   m_pairs[m_pair_count - 1].p2BEApplied    = (ticket2 == 0);
   m_pairs[m_pair_count - 1].p2Closed       = (ticket2 == 0);
   m_pairs[m_pair_count - 1].trailingActive = false; // Strictly locked initially
   m_pairs[m_pair_count - 1].openTime       = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Register new execution pair (Compact signature)                  |
//+------------------------------------------------------------------+
inline void CPositionManager::RegisterPositions(ulong ticket1,
                                                ulong ticket2,
                                                ENUM_STRATEGY_TYPE strat)
{
   double entryPrice = 0.0;
   double initialSL  = 0.0;
   double tp1Price   = 0.0;
   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
   
   if(ticket1 > 0 && m_pos_info.SelectByTicket(ticket1))
   {
      entryPrice = m_pos_info.PriceOpen();
      initialSL  = m_pos_info.StopLoss();
      tp1Price   = m_pos_info.TakeProfit();
      orderType  = (m_pos_info.PositionType() == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   }
   else if(m_sym_helper != NULL)
   {
      entryPrice = m_sym_helper.GetBid();
   }
   
   RegisterPositions(ticket1, ticket2, strat, orderType, entryPrice, initialSL, tp1Price);
}

//+------------------------------------------------------------------+
//| Find pair index for a given ticket                               |
//+------------------------------------------------------------------+
inline int CPositionManager::FindPairIndex(ulong ticket)
{
   if(ticket == 0) return -1;
   for(int i = 0; i < m_pair_count; i++)
   {
      if(m_pairs[i].ticket1 == ticket || m_pairs[i].ticket2 == ticket)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Update position states and check Simultaneous Break-Even         |
//| V1.8: Strict decoupling of Banker/Runner & Manual Close Guard    |
//+------------------------------------------------------------------+
inline void CPositionManager::UpdatePositionState(double beOffsetPips, double beTriggerPips)
{
   if(!m_is_initialized || m_exec_engine == NULL || m_sym_helper == NULL) return;
   
   double ask = m_sym_helper.GetAsk();
   double bid = m_sym_helper.GetBid();
   if(ask <= 0.0 || bid <= 0.0)
   {
      m_sym_helper.Refresh();
      ask = m_sym_helper.GetAsk();
      bid = m_sym_helper.GetBid();
   }
   if(ask <= 0.0 || bid <= 0.0) return;
   
   for(int i = 0; i < m_pair_count; i++)
   {
      // 1. Check Position 1 (Banker) status
      if(!m_pairs[i].p1Closed && m_pairs[i].ticket1 > 0)
      {
         if(!IsPositionOpen(m_pairs[i].ticket1))
         {
            m_pairs[i].p1Closed = true;
            
            // V1.8: Strictly verify that Position 1 hit verified TP1 with profit before unlocking trailing
            bool p1Profit = WasClosedWithProfit(m_pairs[i].ticket1);
            bool p1HitTP  = p1Profit && IsP1ClosedAtTP1(i);
            
            if(p1HitTP)
            {
               m_pairs[i].trailingActive = true; // UNLOCK TRAILING FOR RUNNER!
               PrintFormat("[CPositionManager] Twin Position 1 #%I64u hit verified TP1 with profit. Unlocking Trailing Stop on Runner #%I64u!",
                           m_pairs[i].ticket1, m_pairs[i].ticket2);
            }
            else if(p1Profit)
            {
               m_pairs[i].trailingActive = false;
               PrintFormat("[CPositionManager] Twin Position 1 #%I64u closed with profit but did not hit verified TP1 (e.g. BE or manual). Runner Trailing remains locked.",
                           m_pairs[i].ticket1);
            }
            else
            {
               m_pairs[i].trailingActive = false;
               PrintFormat("[CPositionManager] Twin Position 1 #%I64u closed at a loss or flat (SL/Manual). Runner #%I64u keeps original SL and Trailing remains locked.",
                           m_pairs[i].ticket1, m_pairs[i].ticket2);
            }
         }
      }
      
      // 2. Check Position 2 (Runner) status
      if(!m_pairs[i].p2Closed && m_pairs[i].ticket2 > 0)
      {
         if(!IsPositionOpen(m_pairs[i].ticket2))
         {
            m_pairs[i].p2Closed = true;
         }
      }
      
      // 3. Simultaneous Break-Even Check:
      // When profit reaches beTriggerPips (default: 50.0 pips), BOTH Position 1 and Position 2 move SL to BE!
      if(m_pairs[i].entryPrice > 0.0 && (!m_pairs[i].p1BEApplied || !m_pairs[i].p2BEApplied))
      {
         double curPrice = (m_pairs[i].orderType == ORDER_TYPE_BUY) ? bid : ask;
         double profitDist = (m_pairs[i].orderType == ORDER_TYPE_BUY) ? (curPrice - m_pairs[i].entryPrice) : (m_pairs[i].entryPrice - curPrice);
         double profitPips = m_sym_helper.PriceToPip(profitDist);
         
         if(profitPips >= beTriggerPips)
         {
            // Apply BE to Position 1 (Banker)
            if(!m_pairs[i].p1BEApplied && !m_pairs[i].p1Closed && m_pairs[i].ticket1 > 0)
            {
               if(CheckAndApplyBreakEven(m_pairs[i].ticket1, m_pairs[i].entryPrice, beOffsetPips, m_pairs[i].orderType))
               {
                  m_pairs[i].p1BEApplied = true;
                  PrintFormat("[CPositionManager] Simultaneous BE applied to Position 1 #%I64u at +%.1fp profit.", m_pairs[i].ticket1, profitPips);
               }
            }
            
            // Apply BE to Position 2 (Runner)
            if(!m_pairs[i].p2BEApplied && !m_pairs[i].p2Closed && m_pairs[i].ticket2 > 0)
            {
               bool allowP2BE = true;
               // V1.8: If P1 was already closed, strictly require that P1 closed with profit!
               if(m_pairs[i].p1Closed && m_pairs[i].ticket1 > 0)
               {
                  if(!WasClosedWithProfit(m_pairs[i].ticket1))
                     allowP2BE = false; // P1 closed at loss -> Runner retains original SL!
               }
               
               if(allowP2BE)
               {
                  if(CheckAndApplyBreakEven(m_pairs[i].ticket2, m_pairs[i].entryPrice, beOffsetPips, m_pairs[i].orderType))
                  {
                     m_pairs[i].p2BEApplied = true;
                     PrintFormat("[CPositionManager] Simultaneous BE applied to Position 2 (Runner) #%I64u at +%.1fp profit.", m_pairs[i].ticket2, profitPips);
                  }
               }
            }
         }
      }
      
      // 4. Section 4: Runner Break-Even Guarantee (V1.8 Precision Elimination of Manual Close Assumption)
      // If Position 1 closed, NEVER force BE on Position 2 (Runner) unless:
      //   a) WasClosedWithProfit(m_pairs[i].ticket1) is strictly TRUE, AND
      //   b) Current price of P2 has independently reached profitPips >= beTriggerPips!
      // If Position 1 closed at a loss (e.g. manual panic close or early cut), Runner MUST KEEP ITS ORIGINAL STOP LOSS!
      if(m_pairs[i].p1Closed && !m_pairs[i].p2BEApplied && !m_pairs[i].p2Closed && m_pairs[i].ticket2 > 0)
      {
         if(WasClosedWithProfit(m_pairs[i].ticket1))
         {
            double curPrice = (m_pairs[i].orderType == ORDER_TYPE_BUY) ? bid : ask;
            double profitDist = (m_pairs[i].orderType == ORDER_TYPE_BUY) ? (curPrice - m_pairs[i].entryPrice) : (m_pairs[i].entryPrice - curPrice);
            double profitPips = m_sym_helper.PriceToPip(profitDist);
            
            if(profitPips >= beTriggerPips)
            {
               if(CheckAndApplyBreakEven(m_pairs[i].ticket2, m_pairs[i].entryPrice, beOffsetPips, m_pairs[i].orderType))
               {
                  m_pairs[i].p2BEApplied = true;
                  PrintFormat("[CPositionManager] Break-Even applied to Runner #%I64u after verified P1 profit exit (Current Runner Profit: +%.1fp >= %.1fp).",
                              m_pairs[i].ticket2, profitPips, beTriggerPips);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Universal Break-Even & Dynamic Trailing Stop               |
//| V1.8: Strict Trailing Gating (Pos 1 NEVER trails, Pos 2 strictly |
//| gated on verified P1 TP1 hit)                                    |
//+------------------------------------------------------------------+
inline void CPositionManager::ApplyActiveTrailing(const SStrategyConfig &config)
{
   if(!m_is_initialized || m_exec_engine == NULL || m_sym_helper == NULL) return;
   
   double ask = m_sym_helper.GetAsk();
   double bid = m_sym_helper.GetBid();
   if(ask <= 0.0 || bid <= 0.0)
   {
      m_sym_helper.Refresh();
      ask = m_sym_helper.GetAsk();
      bid = m_sym_helper.GetBid();
   }
   if(ask <= 0.0 || bid <= 0.0) return;
   
   string curSym = m_symbol;
   StringToUpper(curSym);
   
   // Scan all live market positions matching this symbol
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      
      if(IsTicketInCooldown(t)) continue; // Throttle failed modification retries
      
      if(!m_pos_info.SelectByTicket(t)) continue;
      
      string posSym = m_pos_info.Symbol();
      StringToUpper(posSym);
      if(posSym != curSym) continue;
      
      // Filter by magic number if specified, but allow all official LEGsTECH EA magic numbers
      if(m_magic_number > 0 && m_pos_info.Magic() != m_magic_number)
      {
         ulong pm = m_pos_info.Magic();
         if(pm != DEFAULT_MAGIC_REMMY && pm != DEFAULT_MAGIC_CALLISTO && pm != DEFAULT_MAGIC_DB)
            continue;
      }
      
      ENUM_POSITION_TYPE posType = m_pos_info.PositionType();
      double entry     = m_pos_info.PriceOpen();
      double currentSL = m_pos_info.StopLoss();
      double currentTP = m_pos_info.TakeProfit();
      
      double profitDist = (posType == POSITION_TYPE_BUY) ? (bid - entry) : (entry - ask);
      if(profitDist <= 0.0) continue; // Hard guard: strictly not in profit (in drawdown or flat)
      double profitPips = m_sym_helper.PriceToPip(profitDist);
      if(profitPips <= 0.0) continue;
      
      // Calculate target TP distance in pips
      double tpDistPips = 0.0;
      if(currentTP > 0.0)
      {
         double tpDist = (posType == POSITION_TYPE_BUY) ? (currentTP - entry) : (entry - currentTP);
         tpDistPips = m_sym_helper.PriceToPip(tpDist);
      }
      
      // -------------------------------------------------------------
      // TIER 0: TWIN-POSITION ARCHITECTURE (Pos 1 Banker + Pos 2 Runner)
      // -------------------------------------------------------------
      int pairIdx = FindPairIndex(t);
      if(pairIdx >= 0)
      {
         // Position 1: Banker Position (Fixed TP1, e.g. 100 pips)
         // Under twin positions, Pos 1 exits at fixed TP1 or BE, and NEVER trails!
         if(m_pairs[pairIdx].ticket1 == t)
         {
            if(m_pairs[pairIdx].ticket2 > 0)
            {
               continue; // Twin Banker NEVER trails!
            }
            // Single position mode (ticket2 == 0): falls through to standard trailing below!
         }
         
         // Position 2: Runner Position
         // Trailing is strictly GATED: ONLY unlocks AFTER Position 1 has closed with verified TP1 profit!
         if(m_pairs[pairIdx].ticket2 == t)
         {
            if(m_pairs[pairIdx].ticket1 > 0)
            {
               if(!m_pairs[pairIdx].trailingActive)
               {
                  // Position 1 has not hit verified TP1 yet (or closed at loss/BE).
                  // Runner does NOT trail prematurely!
                  continue;
               }
            }
            
            // Position 1 has hit verified TP1 and closed! Runner Trailing is now ACTIVE!
            double twinTrailDist = (config.twinTrailDistPips > 0.0) ? config.twinTrailDistPips : 60.0;
            double twinTrailStep = (config.twinTrailStepPips > 0.0) ? config.twinTrailStepPips : 10.0;
            double trailDist = m_sym_helper.PipToPrice(twinTrailDist);
            double stepDist  = m_sym_helper.PipToPrice(twinTrailStep);
            
            if(posType == POSITION_TYPE_BUY)
            {
               double proposedSL = bid - trailDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL > currentSL + stepDist || (currentSL == 0.0 && proposedSL > entry))
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               double proposedSL = ask + trailDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL < currentSL - stepDist || (currentSL == 0.0 && proposedSL < entry))
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
            continue; // Successfully handled under Twin-Position Runner Engine
         }
      }

      // -------------------------------------------------------------
      // SPECIALIZED CALLISTO MANAGEMENT (Single Position Fallback)
      // Trailing stop loss difference MUST ALWAYS be callistoTrailDistPips from CURRENT PRICE
      // -------------------------------------------------------------
      if(m_pos_info.Magic() == DEFAULT_MAGIC_CALLISTO)
      {
         // 1. Dedicated Callisto Break-Even: Lock at Entry + buffer pips
         if(config.callistoUseBreakEven && profitPips >= config.callistoBeTriggerPips)
         {
            double beLockDist = m_sym_helper.PipToPrice(config.callistoBeLockPips);
            if(posType == POSITION_TYPE_BUY)
            {
               double targetBE = entry + beLockDist;
               targetBE = m_sym_helper.NormalizePrice(targetBE);
               if(targetBE > currentSL || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, targetBE, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, targetBE))
                     {
                        currentSL = targetBE;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               double targetBE = entry - beLockDist;
               targetBE = m_sym_helper.NormalizePrice(targetBE);
               if(targetBE < currentSL || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, targetBE, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, targetBE))
                     {
                        currentSL = targetBE;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
         }

         // 2. Dedicated Callisto Dynamic Trailing Stop:
         if(config.callistoUseTrailing && profitPips >= config.callistoTrailTriggerPips)
         {
            double trailDist = m_sym_helper.PipToPrice(config.callistoTrailDistPips);
            double stepDist  = m_sym_helper.PipToPrice(config.callistoTrailStepPips);

            if(posType == POSITION_TYPE_BUY)
            {
               double proposedSL = bid - trailDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL > currentSL + stepDist || (currentSL == 0.0 && proposedSL > entry))
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               double proposedSL = ask + trailDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL < currentSL - stepDist || (currentSL == 0.0 && proposedSL < entry))
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
         }
         continue; // Fully handled under Callisto specialized trailing engine
      }

      // -------------------------------------------------------------
      // TIER 1: SWING / HIGH-TARGET POSITIONS (TP >= swingTpThresholdPips)
      // -------------------------------------------------------------
      if(tpDistPips >= config.swingTpThresholdPips)
      {
         if(profitPips >= config.swingBeTriggerPips)
         {
            double targetLockPips = config.swingInitialLockPips;
            
            if(profitPips >= (config.swingInitialLockPips + config.swingTrailDistPips))
            {
               double ratchetLevels = MathFloor((profitPips - config.swingTrailDistPips) / config.swingTrailStepPips);
               double dynamicLock = ratchetLevels * config.swingTrailStepPips;
               if(dynamicLock > targetLockPips)
                  targetLockPips = dynamicLock;
            }
            
            double targetLockDist = m_sym_helper.PipToPrice(targetLockPips);
            if(posType == POSITION_TYPE_BUY)
            {
               double proposedSL = entry + targetLockDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL > currentSL + m_sym_helper.PipToPrice(1.0) || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               double proposedSL = entry - targetLockDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL < currentSL - m_sym_helper.PipToPrice(1.0) || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
         }
         continue; // Handled under Swing Ratchet
      }
      
      // -------------------------------------------------------------
      // TIER 2: INTRADAY POSITIONS WITH FIXED TP (0 < TP < swingTpThresholdPips)
      // -------------------------------------------------------------
      if(tpDistPips > 0.0)
      {
         // A. Break-Even at configured intradayBeTriggerPips (default: 50.0 pips)
         double beTrigger = (config.intradayBeTriggerPips > 0.0) ? config.intradayBeTriggerPips : 50.0;
         double beLock    = (config.intradayBeLockPips > 0.0) ? config.intradayBeLockPips : 5.0;
         
         if(profitPips >= beTrigger)
         {
            double lockDist = m_sym_helper.PipToPrice(beLock);
            if(posType == POSITION_TYPE_BUY)
            {
               double proposedSL = entry + lockDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL > currentSL || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               double proposedSL = entry - lockDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL < currentSL || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
         }
         
         // B. Profit Protection Trailing at configured intradayTrailTriggerPips (default: 70.0 pips)
         double trailTrigger  = (config.intradayTrailTriggerPips > 0.0) ? config.intradayTrailTriggerPips : 70.0;
         double trailDistPips = (config.intradayTrailDistPips > 0.0) ? config.intradayTrailDistPips : 30.0;
         double trailStepPips = (config.intradayTrailStepPips > 0.0) ? config.intradayTrailStepPips : 10.0;
         
         if(profitPips >= trailTrigger)
         {
            double trailDist = m_sym_helper.PipToPrice(trailDistPips);
            double stepDist  = m_sym_helper.PipToPrice(trailStepPips);
            
            if(posType == POSITION_TYPE_BUY)
            {
               double proposedSL = bid - trailDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL > currentSL + stepDist || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               double proposedSL = ask + trailDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL < currentSL - stepDist || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
         }
         continue; // Handled under Intraday Adaptive
      }
      
      // -------------------------------------------------------------
      // TIER 3: OPEN RUNNER (TP == 0.0)
      // -------------------------------------------------------------
      // Universal Break-Even
      if(config.useBreakEven && config.beTriggerPips > 0.0)
      {
         double beLockDist = m_sym_helper.PipToPrice(config.beLockPips);
         
         if(posType == POSITION_TYPE_BUY)
         {
            if(profitPips >= config.beTriggerPips)
            {
               double targetBE = entry + beLockDist;
               targetBE = m_sym_helper.NormalizePrice(targetBE);
               if(currentSL < targetBE || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, targetBE, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, targetBE))
                     {
                        currentSL = targetBE;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            if(profitPips >= config.beTriggerPips)
            {
               double targetBE = entry - beLockDist;
               targetBE = m_sym_helper.NormalizePrice(targetBE);
               if(currentSL > targetBE || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, targetBE, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, targetBE))
                     {
                        currentSL = targetBE;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
         }
      }
      
      // Dynamic Trailing Stop for Open Runner
      if(config.useTrailingStop && config.trailTriggerPips > 0.0)
      {
         double trailDist = m_sym_helper.PipToPrice(config.trailDistPips);
         double stepDist  = m_sym_helper.PipToPrice(config.trailStepPips);
         
         if(posType == POSITION_TYPE_BUY)
         {
            if(profitPips >= config.trailTriggerPips)
            {
               double proposedSL = bid - trailDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL > currentSL + stepDist || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            if(profitPips >= config.trailTriggerPips)
            {
               double proposedSL = ask + trailDist;
               proposedSL = m_sym_helper.NormalizePrice(proposedSL);
               if(proposedSL < currentSL - stepDist || currentSL == 0.0)
               {
                  if(m_sym_helper.IsValidStopLoss(posType, proposedSL, currentSL))
                  {
                     if(m_exec_engine.ModifyPositionSL(t, proposedSL))
                     {
                        currentSL = proposedSL;
                        ClearTicketCooldown(t);
                     }
                     else SetTicketCooldown(t);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Apply Break-Even to individual runner ticket                     |
//| V1.8: Normalizes prices and infers direction safely from position|
//+------------------------------------------------------------------+
inline bool CPositionManager::CheckAndApplyBreakEven(ulong ticketRunner, double entryPrice, double beOffsetPips, ENUM_ORDER_TYPE orderType)
{
   if(ticketRunner == 0 || !IsPositionOpen(ticketRunner)) return false;
   if(m_exec_engine == NULL || m_sym_helper == NULL) return false;
   
   if(!m_pos_info.SelectByTicket(ticketRunner)) return false;
   double currentSL = m_pos_info.StopLoss();

   ENUM_POSITION_TYPE pType = m_pos_info.PositionType();
   if(entryPrice <= 0.0)
      entryPrice = m_pos_info.PriceOpen();

   double offsetPrice = m_sym_helper.PipToPrice(beOffsetPips);
   double targetSL = (pType == POSITION_TYPE_BUY) ? (entryPrice + offsetPrice) : (entryPrice - offsetPrice);
   targetSL = m_sym_helper.NormalizePrice(targetSL);

   // If current SL is already at or better than targetSL, Break-Even is already secured!
   if(currentSL > 0.0)
   {
      if(pType == POSITION_TYPE_BUY && currentSL >= targetSL) return true;
      if(pType == POSITION_TYPE_SELL && currentSL <= targetSL) return true;
   }

   if(!m_sym_helper.IsValidStopLoss(pType, targetSL, currentSL)) return false;
   
   return m_exec_engine.ModifyPositionSL(ticketRunner, targetSL);
}

//+------------------------------------------------------------------+
//| Check Runner exit condition on opposite signal                   |
//+------------------------------------------------------------------+
inline bool CPositionManager::CheckRunnerExit(ulong ticketRunner, bool oppositeSignal)
{
   if(ticketRunner == 0 || !IsPositionOpen(ticketRunner)) return false;
   if(!oppositeSignal) return false;
   if(m_exec_engine == NULL) return false;
   
   return m_exec_engine.ClosePosition(ticketRunner);
}

//+------------------------------------------------------------------+
//| Count active open positions for this symbol                      |
//+------------------------------------------------------------------+
inline int CPositionManager::GetActiveTicketCount(ulong magicNumber)
{
   if(m_mock_mode)
   {
      int count = 0;
      for(int i = 0; i < m_pair_count; i++)
      {
         if(m_pairs[i].ticket1 > 0 && !m_pairs[i].p1Closed) count++;
         if(m_pairs[i].ticket2 > 0 && !m_pairs[i].p2Closed) count++;
      }
      return count;
   }

   int count = 0;
   int total = PositionsTotal();
   string curSym = m_symbol;
   StringToUpper(curSym);
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         string posSym = PositionGetString(POSITION_SYMBOL);
         StringToUpper(posSym);
         if(posSym == curSym)
         {
            if(magicNumber > 0)
            {
               if((ulong)PositionGetInteger(POSITION_MAGIC) == magicNumber)
                  count++;
            }
            else if(m_magic_number > 0)
            {
               if((ulong)PositionGetInteger(POSITION_MAGIC) == m_magic_number)
                  count++;
            }
            else
            {
               count++;
            }
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Calculate aggregate floating PnL                                 |
//+------------------------------------------------------------------+
inline double CPositionManager::GetFloatingPnL()
{
   if(m_mock_mode) return 0.0;

   double totalPnL = 0.0;
   int total = PositionsTotal();
   string curSym = m_symbol;
   StringToUpper(curSym);
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         string posSym = PositionGetString(POSITION_SYMBOL);
         StringToUpper(posSym);
         if(posSym == curSym)
         {
            totalPnL += PositionGetDouble(POSITION_PROFIT);
            totalPnL += PositionGetDouble(POSITION_SWAP);
         }
      }
   }
   
   return totalPnL;
}

//+------------------------------------------------------------------+
//| Retrieve Tracked Pair by index                                   |
//+------------------------------------------------------------------+
inline bool CPositionManager::GetTrackedPair(int index, STrackedPair &outPair) const
{
   if(index < 0 || index >= m_pair_count) return false;
   outPair = m_pairs[index];
   return true;
}

//+------------------------------------------------------------------+
//| Clear inactive pairs from internal array                         |
//+------------------------------------------------------------------+
inline void CPositionManager::ClearClosedPairs()
{
   STrackedPair activePairs[];
   int activeCount = 0;
   
   for(int i = 0; i < m_pair_count; i++)
   {
      bool t1Active = (m_pairs[i].ticket1 > 0 && IsPositionOpen(m_pairs[i].ticket1));
      bool t2Active = (m_pairs[i].ticket2 > 0 && IsPositionOpen(m_pairs[i].ticket2));
      
      if(t1Active || t2Active)
      {
         activeCount++;
         ArrayResize(activePairs, activeCount);
         activePairs[activeCount - 1] = m_pairs[i];
      }
   }
   
   ArrayFree(m_pairs);
   m_pair_count = activeCount;
   ArrayResize(m_pairs, m_pair_count);
   for(int i = 0; i < m_pair_count; i++)
      m_pairs[i] = activePairs[i];
      
   ArrayFree(activePairs);
   
   // Purge cooldowns
   SModifyCooldown activeCDs[];
   int cdCount = 0;
   for(int c = 0; c < m_cooldown_count; c++)
   {
      if(IsPositionOpen(m_cooldowns[c].ticket))
      {
         cdCount++;
         ArrayResize(activeCDs, cdCount);
         activeCDs[cdCount - 1] = m_cooldowns[c];
      }
   }
   ArrayFree(m_cooldowns);
   m_cooldown_count = cdCount;
   ArrayResize(m_cooldowns, m_cooldown_count);
   for(int c = 0; c < m_cooldown_count; c++)
      m_cooldowns[c] = activeCDs[c];
   ArrayFree(activeCDs);
}

//+------------------------------------------------------------------+
//| Set Mock Pair status for testing                                 |
//+------------------------------------------------------------------+
inline void CPositionManager::SetMockPairClosed(ulong ticket, bool closed)
{
   for(int i = 0; i < m_pair_count; i++)
   {
      if(m_pairs[i].ticket1 == ticket) m_pairs[i].p1Closed = closed;
      if(m_pairs[i].ticket2 == ticket) m_pairs[i].p2Closed = closed;
   }
}

#endif // LEGSTECH_ENGINE_POSITIONMANAGER_MQH
