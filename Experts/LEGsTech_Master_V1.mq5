//+------------------------------------------------------------------+
//|                                       LEGsTech_Master_V1.mq5   |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, LEGsTECH Team."
#property link        "https://www.legstech.com"
#property version     "1.60"
#property description "LEGsTECH Trading Bot Version 1.6 â€” Multi-Strategy MQL5 Expert Advisor"
#property description "SOLUTIONS FOR TOMORROW â€” Institutional Quantitative Execution Engine"

//+------------------------------------------------------------------+
//| Standard & Core Subsystem Header Includes                        |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

#include "..\Include\LEGsTech\Core\Defs.mqh"
#include "..\Include\LEGsTech\Core\Logger.mqh"
#include "..\Include\LEGsTech\Core\StateMachine.mqh"
#include "..\Include\LEGsTech\Core\BaseStrategy.mqh"
#include "..\Include\LEGsTech\Engine\SymbolHelper.mqh"
#include "..\Include\LEGsTech\Engine\RiskEngine.mqh"
#include "..\Include\LEGsTech\Engine\ExecutionEngine.mqh"
#include "..\Include\LEGsTech\Engine\PositionManager.mqh"
#include "..\Include\LEGsTech\UI\Theme.mqh"
#include "..\Include\LEGsTech\UI\Dashboard.mqh"
#include "..\Include\LEGsTech\Strategies\StrategySelector.mqh"

//+------------------------------------------------------------------+
//| 1. STRATEGY & PROFILE SELECTION INPUTS                           |
//+------------------------------------------------------------------+
input group "=== 1. STRATEGY & PROFILE SELECTION ==="
input ENUM_STRATEGY_TYPE   InpStrategyType         = STRATEGY_PORTFOLIO;      // Active Strategy (PORTFOLIO / RM / CL / DB)
input ENUM_TRADE_PROFILE   InpTradeProfile         = PROFILE_SCALP;           // Active Profile (SCALP / DAY_TRADE / SWING)
input ulong                InpMagicNumber          = 0;                       // EA Magic Number (0 = Auto Default Allocation)
input bool                 InpEnableRemmy          = true;                    // Portfolio: Enable Strategy REMMY (M15 Scalp)
input bool                 InpEnableCallisto       = true;                    // Portfolio: Enable Strategy CALLISTO (H1/M5 Swing)
input bool                 InpEnableDB             = false;                   // Portfolio: Enable Strategy DB (M30 Scalp)

//+------------------------------------------------------------------+
//| 1.1 SCALP PROFILE PARAMETERS                                     |
//+------------------------------------------------------------------+
input group "=== 1.1 SCALP PROFILE PARAMETERS ==="
input double               InpScalpRiskPercent     = 0.5;                     // Scalp Risk Per Trade (%)
input double               InpScalpSlPips          = 100.0;                   // Scalp Fixed Emergency SL (pips)
input double               InpScalpTpPips          = 100.0;                   // Scalp Take Profit (pips)
input double               InpScalpTrailTrigger    = 30.0;                    // Scalp Trailing Activation Profit (pips)
input double               InpScalpTrailDist       = 20.0;                    // Scalp Trailing Distance (pips)
input double               InpScalpTrailStep       = 5.0;                     // Scalp Trailing Step Update Buffer (pips)

//+------------------------------------------------------------------+
//| 1.2 DAY TRADE PROFILE PARAMETERS                                 |
//+------------------------------------------------------------------+
input group "=== 1.2 DAY TRADE PROFILE PARAMETERS ==="
input double               InpDayRiskPercent       = 1.0;                     // Day Trade Risk Per Trade (%)
input double               InpDayTpPips            = 100.0;                   // Day Trade Pos 1 TP (pips)
input double               InpDayBeTriggerPips     = 50.0;                    // Day Trade BE Trigger Profit (pips)
input double               InpDayBeLockPips        = 5.0;                     // Day Trade BE Lock Buffer (pips)
input double               InpDayTrailTriggerPips  = 70.0;                    // Day Trade Trailing Activation Profit (pips)
input double               InpDayTrailDistPips     = 30.0;                    // Day Trade Trailing Distance (pips)
input double               InpDayTrailStepPips     = 10.0;                    // Day Trade Trailing Step (pips)

//+------------------------------------------------------------------+
//| 1.3 SWING PROFILE PARAMETERS                                     |
//+------------------------------------------------------------------+
input group "=== 1.3 SWING PROFILE PARAMETERS ==="
input double               InpSwingRiskPercent     = 1.0;                     // Swing Risk Per Trade (%)
input double               InpSwingTpPips          = 400.0;                   // Swing Take Profit (pips)
input double               InpSwingTpThreshold     = 250.0;                   // Swing Target Classification Threshold (pips)
input double               InpSwingBeTrigger       = 100.0;                   // Swing Initial Lock Trigger (pips)
input double               InpSwingInitialLock     = 50.0;                    // Swing Initial Lock Buffer (pips)
input double               InpSwingTrailStep       = 50.0;                    // Swing Ratchet Step Interval (pips)
input double               InpSwingTrailDist       = 100.0;                   // Swing Trailing Distance Cushion (pips)

//+------------------------------------------------------------------+
//| 1.4 UNIVERSAL BREAK-EVEN & TRAILING STOP CONTROLS                |
//+------------------------------------------------------------------+
input group "=== 1.4 UNIVERSAL BREAK-EVEN & TRAILING STOP ==="
input bool                 InpEnableTwinPositions  = true;                    // Enable Twin Positions (Banker 100p + Gated Runner)
input ENUM_TWIN_LOT_MODE   InpTwinLotMode          = TWIN_LOT_FULL_EACH;      // Twin Lot Mode (FULL_EACH: 0.01+0.01 / SPLIT_50_50)
input double               InpTwinTP1_Pips         = 100.0;                   // Pos 1 Fixed Take Profit (pips, default: 100.0)
input double               InpTwinBeTriggerPips    = 50.0;                    // Simultaneous BE Trigger Profit (pips, default: 50.0)
input double               InpTwinBeLockPips       = 5.0;                     // Simultaneous BE Profit Lock Buffer (pips, default: 5.0)
input double               InpTwinTrailDistPips    = 60.0;                    // Pos 2 Runner Trailing Cushion (pips, default: 60.0)
input double               InpTwinTrailStepPips    = 10.0;                    // Pos 2 Runner Trailing Step Buffer (pips, default: 10.0)
input bool                 InpUseBreakEven         = true;                    // Enable Automatic Break-Even (Default: True)
input double               InpBeTriggerPips        = 50.0;                    // Break-Even Trigger Profit (pips, default: 50.0)
input double               InpBeLockPips           = 5.0;                     // Break-Even Profit Lock Buffer (pips)
input bool                 InpUseTrailing          = true;                    // Enable Dynamic Trailing Stop (Default: True)
input double               InpTrailTriggerPips     = 70.0;                    // Trailing Stop Activation Profit (pips, default: 70.0)
input double               InpTrailDistPips        = 60.0;                    // Trailing Stop Distance (pips, default: 60.0)
input double               InpTrailStepPips        = 10.0;                    // Trailing Stop Step Update Buffer (pips, default: 10.0)
input bool                 InpTrailOnlyRunners     = true;                    // Trailing Targets Runners Only (TP1 locked at 100p)
input bool                 InpBlockRollover        = false;                   // Block Illiquid Rollover Window (17:00-21:00 UTC)

//+------------------------------------------------------------------+
//| 2. COMMON RISK & MONEY MANAGEMENT INPUTS                         |
//+------------------------------------------------------------------+
input group "=== 2. COMMON RISK & MONEY MANAGEMENT ==="
input ENUM_RISK_MODE       InpRiskMode             = RISK_MODE_FIXED_LOT;     // Risk Sizing Mode (Fixed Lot / % Equity)
input double               InpRiskPercent          = 1.0;                     // Risk Per Trade (%) (e.g. 1.0 = 1%)
input double               InpFixedLotSize         = 0.01;                    // Fixed Lot Size (if Fixed Mode active)
input double               InpMaxDailyDD           = 5.0;                     // Maximum Daily Drawdown Limit (%)
input int                  InpMaxSpreadPips        = 7;                       // Maximum Allowable Spread (pips)
input int                  InpSlippagePts          = 30;                      // Maximum Slippage Tolerance (points)
input int                  InpMaxPositions         = 2;                       // Max Concurrent Trades / Portfolio Cap (1, 2, or 3)
input bool                 InpEnableDoublePosition = false;                   // Enable Double Position (Pos 1 Fixed TP + Pos 2 Runner)
input bool                 InpUseSessionFilter     = true;                    // Restrict Trading to London & NY Sessions (07:00-20:00 UTC)
input int                  InpSessionStartHour     = 7;                       // Active Session Start Hour (UTC)
input int                  InpSessionEndHour       = 20;                      // Active Session End Hour (UTC)

//+------------------------------------------------------------------+
//| 3. RM STRATEGY PARAMETERS (V1.3 4-TF CASCADE)                    |
//+------------------------------------------------------------------+
input group "=== 3. RM STRATEGY PARAMETERS ==="
input bool                 InpRemmyUseD1Filter     = true;                    // RM: Use D1 Daily Bias Filter (Default: True)
input bool                 InpRemmyUseH4Filter     = true;                    // RM: Use H4 Candle Color Confirmation (Default: True)
input bool                 InpRemmyUseH1Filter     = true;                    // RM: Use H1 Forming Candle Alignment (Default: True)
input bool                 InpRemmyH1ClosedAlso    = false;                   // RM: Also Require Closed H1 Candle to Agree
input bool                 InpRemmySessionLock     = true;                    // RM: Lock Asian Session (07:00-20:00 GMT Only)
input int                  InpRemmyStartHourGmt    = 7;                       // RM: Active Window Start Hour (GMT, Default: 7)
input int                  InpRemmyEndHourGmt      = 20;                      // RM: Active Window End Hour (GMT, Default: 20)
input double               InpRemmyTpPips          = 100.0;                   // RM: Pos 1 Fixed Take Profit (pips)
input double               InpRemmySlBufferPips    = 5.0;                     // RM: SL Buffer Beyond Confirmed Fractal (pips)
input double               InpRemmyMinSlPips       = 20.0;                    // RM: Minimum SL Distance Floor (pips)
input double               InpRemmyMaxSlPips       = 200.0;                   // RM: Maximum Allowable SL Ceiling (pips)
input double               InpRemmyHalfLotSlPips   = 150.0;                   // RM: Half-Lot SL Threshold (pips)
input bool                 InpRemmyAutoBeOnTp1     = true;                    // RM: Auto Break-Even on Pos 2 when Pos 1 Hits TP
input double               InpRemmyBeLockPips      = 2.0;                     // RM: Break-Even Profit Lock Buffer (pips)
input bool                 InpRemmyRunner          = true;                    // RM: Enable 2-Position Setup (Pos 1 + Pos 2 Runner)
input int                  InpRemmyFractalMaxAge   = 3;                       // RM: Max Age of Confirmed Fractal (bars)
input int                  InpRemmyEmaPeriod       = 20;                      // RM: 15M Trend Filter EMA Period
input double               InpRemmyAtrMult         = 2.0;                     // RM: Overextension Threshold (x ATR)

//+------------------------------------------------------------------+
//| 4. CL STRATEGY PARAMETERS                                        |
//+------------------------------------------------------------------+
input group "=== 4. CL STRATEGY PARAMETERS ==="
input bool                 InpCallistoSessionLock  = true;                    // CL: Lock Asian Session (07:00-20:00 GMT Only)
input int                  InpCallistoStartHourGmt = 7;                       // CL: Active Window Start Hour (GMT, Default: 7)
input int                  InpCallistoEndHourGmt   = 20;                      // CL: Active Window End Hour (GMT, Default: 20)
input ENUM_TIMEFRAMES      InpCallistoHtfTf        = PERIOD_H1;               // CL: High Timeframe for POI Scanner
input ENUM_TIMEFRAMES      InpCallistoLtfTf        = PERIOD_M5;               // CL: Low Timeframe for Confirmation
input ENUM_CONFIRMATION_MODE InpCallistoConfirmMode= CONFIRM_MODE_CHOCH;      // CL: Confirmation Mode (CHOCH/IFVG/ENGULFING)
input double               InpCallistoSlPips       = 100.0;                   // CL: Stop Loss (pips)
input double               InpCallistoTpPips       = 100.0;                   // CL: Take Profit (pips)
input int                  InpCallistoMaxDailyTrades = 10;                    // CL: Max Daily Trades Execution Limit
input bool                 InpCallistoUseM1Confirmation = true;               // CL: Require Completed M1 Directional Candle Close in Retest
input bool                 InpCallistoTargetOpposingPoi = true;               // CL: Pos 2 Targets Opposing H1 Institutional POI (or Trailing Runner)
input bool                 InpCallistoRunner       = false;                   // CL: Enable Double-Position Runner Mode
input double               InpCallistoStaleGuard   = 50.0;                    // CL: Stale Signal Guard (max pips past POI, 0=off)
input bool                 InpCallistoUseTrailing  = true;                    // CL: Enable Trailing Stop (60-Pip Cushion)
input double               InpCallistoTrailDist    = 60.0;                    // CL: Trailing Stop Distance Cushion (pips, default: 60.0)
input double               InpCallistoTrailTrigger = 70.0;                    // CL: Trailing Stop Activation Profit (pips, default: 70.0)
input double               InpCallistoTrailStep    = 10.0;                    // CL: Trailing Stop Step Update Buffer (pips, default: 10.0)
input bool                 InpCallistoUseBE        = true;                    // CL: Enable Break-Even (Default: True)
input double               InpCallistoBeTrigger    = 50.0;                    // CL: Break-Even Trigger Profit (pips, default: 50.0)
input double               InpCallistoBeLock       = 5.0;                     // CL: Break-Even Profit Lock Buffer (pips, default: 5.0)

//+------------------------------------------------------------------+
//| 5. DB STRATEGY PARAMETERS                                        |
//+------------------------------------------------------------------+
input group "=== 5. DB STRATEGY PARAMETERS ==="
input bool                 InpDbSessionLock        = true;                    // DB: Lock Asian Session (07:00-20:00 GMT Only)
input int                  InpDbStartHourGmt       = 7;                       // DB: Active Window Start Hour (GMT, Default: 7)
input int                  InpDbEndHourGmt         = 20;                      // DB: Active Window End Hour (GMT, Default: 20)
input bool                 InpDbAllSessions        = true;                    // DB: Trade All Sessions 24/7 (Ignore 8AM/8PM Lockout)
input int                  InpDbStartHour1         = 8;                       // DB: Morning Session Start (UTC Hour)
input int                  InpDbStartHour2         = 20;                      // DB: Evening Session Start (UTC Hour)
input int                  InpDbUtcOffset          = 2;                       // DB: Broker Server UTC Offset (Hours)
input double               InpDbSwingBuffer        = 15.0;                    // DB: 30M Swing SL Safety Buffer (pips)
input double               InpDbSlPips             = 100.0;                   // DB: Stop Loss (pips)
input double               InpDbTpPips             = 50.0;                    // DB: Take Profit (pips, strictly 50.0)
input int                  InpDbPullbackCount      = 1;                       // DB: M15 Pullback Candles to Reset Lock (Default: 1)

//+------------------------------------------------------------------+
//| 6. GUI & ON-CHART DASHBOARD INPUTS                               |
//+------------------------------------------------------------------+
input group "=== 6. GUI & DASHBOARD ==="
input bool                 InpShowDashboard        = true;                    // Enable On-Chart GUI Dashboard Overlay
input int                  InpDashboardX           = 15;                      // Dashboard Left X Offset (pixels)
input int                  InpDashboardY           = 25;                      // Dashboard Top Y Offset (pixels)

//+------------------------------------------------------------------+
//| 7. LOGGING & TELEMETRY INPUTS                                    |
//+------------------------------------------------------------------+
input group "=== 7. LOGGING & TELEMETRY ==="
input ENUM_LOG_LEVEL       InpLogLevel             = LOG_LEVEL_INFO;          // Minimum Logging Severity Level
input bool                 InpLogToFile            = true;                    // Enable Rotating Daily Log File
input bool                 InpTestMode             = false;                   // Offline Deterministic Mock Mode

//+------------------------------------------------------------------+
//| Global EA Subsystem Singletons & State Variables                 |
//+------------------------------------------------------------------+
CLogger                    g_logger;
CSymbolHelper              g_symbolHelper;
CRiskEngine                g_riskEngine;
CExecutionEngine           g_execEngine;
CPositionManager           g_posManager;
CStrategySelector          g_strategySelector;
CDashboard                 g_dashboard;
SStrategyConfig            g_config;

ulong                      g_magicNumber           = 0;
bool                       g_isBacktest            = false;
datetime                   g_lastTimerUpdate       = 0;

//+------------------------------------------------------------------+
//| Helper: Calculate Closed Deals PnL & Performance Today           |
//+------------------------------------------------------------------+
double CalculateTodayPerformance(ulong magic, int &outTrades, int &outWinners)
{
   outTrades  = 0;
   outWinners = 0;
   double totalPnL = 0.0;
   
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   datetime todayStart = StructToTime(dt);
   
   if(HistorySelect(todayStart, TimeCurrent()))
   {
      int totalDeals = HistoryDealsTotal();
      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket > 0)
         {
            long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            if((magic == 0 || dealMagic == (long)magic) && 
               (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY))
            {
               double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + 
                               HistoryDealGetDouble(dealTicket, DEAL_SWAP) + 
                               HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
               totalPnL += profit;
               outTrades++;
               if(profit > 0) outWinners++;
            }
         }
      }
   }
   return totalPnL;
}

//+------------------------------------------------------------------+
//| Helper: Aggregate Live Telemetry for GUI Dashboard               |
//+------------------------------------------------------------------+
void UpdateDashboardTelemetry()
{
   SDashboardTelemetry telem;
   telem.Reset();

   telem.strategyName        = g_strategySelector.GetActiveStrategyName();
   switch(g_config.tradeProfile)
   {
      case PROFILE_SCALP:     telem.tradeProfileName = "âš¡ SCALP: +30p Trailing Lock"; break;
      case PROFILE_DAY_TRADE: telem.tradeProfileName = "ðŸ“Š DAY TRADE: 100p Fixed TP"; break;
      case PROFILE_SWING:     telem.tradeProfileName = "ðŸŒŠ SWING: 400p Runner"; break;
      default:                telem.tradeProfileName = "âš¡ SCALP MODE"; break;
   }
   telem.currentState        = g_strategySelector.GetState();
   telem.stateDesc           = StateToString(telem.currentState);
   telem.accountBalance      = AccountInfoDouble(ACCOUNT_BALANCE);
   telem.accountEquity       = AccountInfoDouble(ACCOUNT_EQUITY);
   
   int tradesToday = 0, winToday = 0;
   telem.dailyRealizedPnL    = CalculateTodayPerformance(g_magicNumber, tradesToday, winToday);
   telem.tradesToday         = tradesToday;
   telem.winningTradesToday  = winToday;
   telem.winRatePct          = (tradesToday > 0) ? (((double)winToday / (double)tradesToday) * 100.0) : 0.0;
   
   telem.dailyFloatingPnL    = g_posManager.GetFloatingPnL();
   telem.dailyDrawdownPct    = g_riskEngine.GetCurrentDailyDD();
   telem.maxDrawdownLimitPct = g_riskEngine.GetMaxDailyDD();
   telem.currentSpreadPips   = g_symbolHelper.GetSpreadPips();
   telem.maxSpreadLimitPips  = g_riskEngine.GetMaxSpreadPips();
   telem.openTicketsCount    = g_posManager.GetActiveTicketCount();
   
   // Scan live open positions dynamically for dashboard display
   int totalPos = PositionsTotal();
   int symPosIdx = 0;
   string curSym = _Symbol;
   StringToUpper(curSym);
   
   for(int i = 0; i < totalPos; i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      string pSym = PositionGetString(POSITION_SYMBOL);
      StringToUpper(pSym);
      if(pSym != curSym) continue;

      symPosIdx++;
      double pPnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(symPosIdx == 1)
      {
         telem.ticket1       = t;
         telem.ticket1PnL    = pPnL;
         telem.ticket1Status = (g_config.useTrailingStop) ? "Active (Trailing)" : "Active";
      }
      else if(symPosIdx == 2)
      {
         telem.ticket2       = t;
         telem.ticket2PnL    = pPnL;
         telem.ticket2Status = "Active Runner";
      }
   }
   
   telem.lastSignalInfo      = g_strategySelector.GetStatusString();
   if(g_config.strategyType == STRATEGY_PORTFOLIO)
   {
      CStrategyPortfolio *port = g_strategySelector.GetPortfolioStrategy();
      if(port != NULL)
      {
         telem.remmyStatus    = port.GetRemmyStatus();
         telem.callistoStatus = port.GetCallistoStatus();
         telem.dbStatus       = port.GetDbStatus();
      }
   }
   telem.isEmergencyHalted   = g_riskEngine.GetKillSwitch();

   telem.isBreakEvenEnabled  = g_config.useBreakEven;
   telem.beTriggerPips       = g_config.beTriggerPips;
   telem.beLockPips          = g_config.beLockPips;
   telem.isTrailingEnabled   = g_config.useTrailingStop;
   telem.trailTriggerPips    = g_config.trailTriggerPips;
   telem.trailDistPips       = g_config.trailDistPips;
   telem.tradeProfileName    = StringFormat("âš¡ TRAIL: +%.0fp Trigger / %.0fp Dist", g_config.trailTriggerPips, g_config.trailDistPips);

   g_dashboard.Update(telem);
}

//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_isBacktest = (bool)MQLInfoInteger(MQL_TESTER);

   // 1. Initialize Logger
   int logTarget = LOG_TARGET_CONSOLE;
   if(InpLogToFile && !g_isBacktest) logTarget |= LOG_TARGET_FILE;
   if(InpShowDashboard && !g_isBacktest) logTarget |= LOG_TARGET_DASHBOARD;
   g_logger.Init("LEGsTECH", InpLogLevel, logTarget);

   g_logger.Info("================================================================", "INIT");
   g_logger.Info("   LEGsTECH TRADING BOT VERSION 1.6 â€” INITIALIZING MASTER EA    ", "INIT");
   g_logger.Info("              SOLUTIONS FOR TOMORROW                            ", "INIT");
   g_logger.Info("================================================================", "INIT");

   // 2. Initialize Symbol Helper
   if(!g_symbolHelper.Init(_Symbol))
   {
      g_logger.Critical(StringFormat("Failed to initialize SymbolHelper on symbol %s", _Symbol), "INIT");
      return INIT_FAILED;
   }

   // 3. Resolve Magic Number
   if(InpMagicNumber > 0)
   {
      g_magicNumber = InpMagicNumber;
   }
   else
   {
      switch(InpStrategyType)
      {
         case STRATEGY_REMMY:
            g_magicNumber = DEFAULT_MAGIC_REMMY;
            break;
         case STRATEGY_CALLISTO:
            g_magicNumber = DEFAULT_MAGIC_CALLISTO;
            break;
         case STRATEGY_DB:
            g_magicNumber = DEFAULT_MAGIC_DB;
            break;
         case STRATEGY_PORTFOLIO:
            g_magicNumber = 0; // 0 = Track all portfolio sub-strategies concurrently
            break;
         default:
            g_magicNumber = DEFAULT_MAGIC_REMMY;
            break;
      }
   }

   // 4. Populate Unified Strategy Configuration
   g_config.SetDefaults();
   g_config.strategyType         = InpStrategyType;
   g_config.tradeProfile         = InpTradeProfile;
   g_config.isEnabled            = true;
   g_config.magicNumber          = g_magicNumber;
   g_config.riskMode             = InpRiskMode;
   g_config.fixedLotSize         = InpFixedLotSize;
   g_config.riskPercent          = InpRiskPercent;
   g_config.maxDailyLossPercent  = InpMaxDailyDD;
   g_config.maxDailyTrades       = InpCallistoMaxDailyTrades;
   g_config.maxSpreadPips        = InpMaxSpreadPips;
   g_config.slippagePoints       = InpSlippagePts;
   g_config.maxPositions         = InpMaxPositions;
   g_config.enableDoublePosition = InpEnableDoublePosition;
   g_config.useSessionFilter     = InpUseSessionFilter;
   g_config.sessionStartHour     = InpSessionStartHour;
   g_config.sessionEndHour       = InpSessionEndHour;
   g_config.enableRemmy          = InpEnableRemmy;
   g_config.enableCallisto       = InpEnableCallisto;
   g_config.enableDb             = InpEnableDB;

   // Universal Break-Even & Trailing Stop configurations
   g_config.useBreakEven         = InpUseBreakEven;
   g_config.beTriggerPips        = InpBeTriggerPips;
   g_config.beLockPips           = InpBeLockPips;
   g_config.useTrailingStop      = InpUseTrailing;
   g_config.trailTriggerPips     = InpTrailTriggerPips;
   g_config.trailDistPips        = InpTrailDistPips;
   g_config.trailStepPips        = InpTrailStepPips;
   g_config.trailOnlyRunners     = InpTrailOnlyRunners;
   g_config.blockRolloverWindow  = InpBlockRollover;

   // Twin-Position Institutional Engine Configuration
   g_config.enableTwinPositions  = InpEnableTwinPositions;
   g_config.twinLotMode          = InpTwinLotMode;
   g_config.twinTP1_Pips         = InpTwinTP1_Pips;
   g_config.twinBeTriggerPips    = InpTwinBeTriggerPips;
   g_config.twinBeLockPips       = InpTwinBeLockPips;
   g_config.twinTrailDistPips    = InpTwinTrailDistPips;
   g_config.twinTrailStepPips    = InpTwinTrailStepPips;

   // Trade Profile configurations
   g_config.scalpRiskPercent     = InpScalpRiskPercent;
   g_config.scalpSlPips          = InpScalpSlPips;
   g_config.scalpTpPips          = InpScalpTpPips;
   g_config.scalpTrailTriggerPips= InpScalpTrailTrigger;
   g_config.scalpTrailDistPips   = InpScalpTrailDist;
   g_config.scalpTrailStepPips   = InpScalpTrailStep;

   // In Portfolio mode, global risk settings override profile defaults
   if(InpStrategyType == STRATEGY_PORTFOLIO)
   {
      g_config.scalpRiskPercent  = InpRiskPercent;
      g_config.dayRiskPercent    = InpRiskPercent;
      g_config.swingRiskPercent  = InpRiskPercent;
   }
   else
   {
      g_config.dayRiskPercent    = InpDayRiskPercent;
      g_config.swingRiskPercent  = InpSwingRiskPercent;
   }
   g_config.dayTpPips            = InpDayTpPips;
   g_config.dayBeTriggerPips     = InpDayBeTriggerPips;
   g_config.dayBeLockPips        = InpDayBeLockPips;
   g_config.intradayBeTriggerPips    = InpDayBeTriggerPips;
   g_config.intradayBeLockPips       = InpDayBeLockPips;
   g_config.intradayTrailTriggerPips = InpDayTrailTriggerPips;
   g_config.intradayTrailDistPips    = InpDayTrailDistPips;
   g_config.intradayTrailStepPips    = InpDayTrailStepPips;

   g_config.swingTpPips          = InpSwingTpPips;
   g_config.swingTpThresholdPips = InpSwingTpThreshold;
   g_config.swingBeTriggerPips   = InpSwingBeTrigger;
   g_config.swingInitialLockPips = InpSwingInitialLock;
   g_config.swingTrailStepPips   = InpSwingTrailStep;
   g_config.swingTrailTriggerPips= InpSwingBeTrigger;
   g_config.swingTrailDistPips   = InpSwingTrailDist;

   // Strategy specific configurations
   g_config.remmyUseD1Filter         = InpRemmyUseD1Filter;
   g_config.remmyUseH4Filter         = InpRemmyUseH4Filter;
   g_config.remmyUseH1Filter         = InpRemmyUseH1Filter;
   g_config.remmyH1RequireClosedAlso = InpRemmyH1ClosedAlso;
   g_config.remmyUseSessionFilter    = InpRemmySessionLock;
   g_config.remmySessionStartGmt     = InpRemmyStartHourGmt;
   g_config.remmySessionEndGmt       = InpRemmyEndHourGmt;
   g_config.remmyFractalBars         = 5;
   g_config.remmyFractalMaxAge       = InpRemmyFractalMaxAge;
   g_config.remmyTpPips              = InpRemmyTpPips;
   g_config.remmySlBufferPips        = InpRemmySlBufferPips;
   g_config.remmyMinSlPips           = InpRemmyMinSlPips;
   g_config.remmyMaxSlPips           = InpRemmyMaxSlPips;
   g_config.remmyHalfLotSlPips       = InpRemmyHalfLotSlPips;
   g_config.remmyAutoBeOnTp1         = InpRemmyAutoBeOnTp1;
   g_config.remmyBeLockPips          = InpRemmyBeLockPips;
   g_config.remmyBeBufferPips        = InpRemmyBeLockPips;
   g_config.remmyRunnerEnabled       = InpRemmyRunner;
   g_config.remmyEmaPeriod           = InpRemmyEmaPeriod;
   g_config.remmyAtrMultiplier       = InpRemmyAtrMult;

   g_config.callistoUseSessionFilter = InpCallistoSessionLock;
   g_config.callistoSessionStartGmt  = InpCallistoStartHourGmt;
   g_config.callistoSessionEndGmt    = InpCallistoEndHourGmt;
   g_config.callistoHtfTf        = InpCallistoHtfTf;
   g_config.callistoLtfTf        = InpCallistoLtfTf;
   g_config.callistoConfirmMode  = InpCallistoConfirmMode;
   g_config.callistoUseM1Confirmation = InpCallistoUseM1Confirmation;
   g_config.callistoTargetOpposingPoi = InpCallistoTargetOpposingPoi;
   g_config.callistoSlPips       = InpCallistoSlPips;
   g_config.callistoTpPips       = InpCallistoTpPips;
   g_config.callistoRunnerEnabled= InpEnableDoublePosition && InpCallistoRunner;
   g_config.callistoStaleGuardPips= InpCallistoStaleGuard;
   g_config.callistoUseTrailing      = InpCallistoUseTrailing;
   g_config.callistoTrailDistPips    = InpCallistoTrailDist;
   g_config.callistoTrailTriggerPips = InpCallistoTrailTrigger;
   g_config.callistoTrailStepPips    = InpCallistoTrailStep;
   g_config.callistoUseBreakEven     = InpCallistoUseBE;
   g_config.callistoBeTriggerPips    = InpCallistoBeTrigger;
   g_config.callistoBeLockPips       = InpCallistoBeLock;

   g_config.dbUseSessionFilter   = InpDbSessionLock;
   g_config.dbSessionStartGmt    = InpDbStartHourGmt;
   g_config.dbSessionEndGmt      = InpDbEndHourGmt;
   g_config.dbTradeAllSessions   = InpDbAllSessions;
   g_config.dbRunnerEnabled      = InpEnableDoublePosition;
   g_config.dbStartHour1         = InpDbStartHour1;
   g_config.dbStartHour2         = InpDbStartHour2;
   g_config.dbUtcOffset          = InpDbUtcOffset;
   g_config.dbSwingBufferPips    = InpDbSwingBuffer;
   g_config.dbSlPips             = InpDbSlPips;
   g_config.dbTpPips             = InpDbTpPips;
   g_config.dbPullbackCandles    = InpDbPullbackCount;

   // 5. Initialize Risk Engine
   double riskVal = (InpRiskMode == RISK_MODE_FIXED_LOT) ? InpFixedLotSize : InpRiskPercent;
   if(!g_riskEngine.Init(_Symbol, riskVal, InpRiskMode, InpMaxDailyDD, InpMaxSpreadPips, InpMaxPositions, &g_symbolHelper))
   {
      g_logger.Critical("Failed to initialize RiskEngine!", "INIT");
      return INIT_FAILED;
   }
   g_riskEngine.SetTwinPositionConfig(InpEnableTwinPositions, InpTwinLotMode, 0.5);

   // 6. Initialize Execution Engine
   if(!g_execEngine.Init(_Symbol, g_magicNumber, InpSlippagePts, &g_symbolHelper))
   {
      g_logger.Critical("Failed to initialize ExecutionEngine!", "INIT");
      return INIT_FAILED;
   }

   // 7. Initialize Position Manager
   if(!g_posManager.Init(_Symbol, g_magicNumber, &g_execEngine, &g_symbolHelper))
   {
      g_logger.Critical("Failed to initialize PositionManager!", "INIT");
      return INIT_FAILED;
   }

   // 8. Initialize Strategy Selector
   if(!g_strategySelector.Init(_Symbol, InpStrategyType, g_config, &g_symbolHelper, &g_riskEngine, &g_execEngine, &g_posManager, &g_logger))
   {
      g_logger.Critical("Failed to initialize StrategySelector!", "INIT");
      return INIT_FAILED;
   }

   if(InpTestMode)
   {
      g_strategySelector.SetMockMode(true);
      g_logger.Warning("Offline Deterministic Test Mode ENABLED.", "INIT");
   }

   // 9. Initialize Dashboard Overlay
   bool showVisualGui = InpShowDashboard && !g_isBacktest;
   if(!g_dashboard.Init(ChartID(), InpDashboardX, InpDashboardY, 340, 510, 0, CORNER_LEFT_UPPER, showVisualGui))
   {
      g_logger.Warning("Dashboard initialized in headless/non-visual mode.", "INIT");
   }
   else if(showVisualGui)
   {
      g_dashboard.CreateUI();
   }

   // 10. Start 1-Second High Precision Timer
   EventSetTimer(1);

   // Perform initial telemetry update
   UpdateDashboardTelemetry();

   g_logger.Info(StringFormat("LEGsTECH EA Startup Complete. Active Strategy: %s | Magic: %I64u | Symbol: %s",
                              StrategyTypeToString(InpStrategyType), g_magicNumber, _Symbol), "INIT");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   g_strategySelector.Deinit();
   g_dashboard.Destroy();

   g_logger.Info(StringFormat("LEGsTECH EA Shutting Down. Reason code: %d", reason), "DEINIT");
   g_logger.Deinit();
}

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Guard 1: Emergency Kill Switch Halt
   if(g_riskEngine.GetKillSwitch())
   {
      return;
   }

   // Guard 2: Refresh Market Quotes
   g_symbolHelper.Refresh();

   // Guard 2.1: Continuous Live Position Management (Universal BE & Dynamic Trailing Stop)
   double beLock = (g_config.enableTwinPositions) ? g_config.twinBeLockPips : g_config.beLockPips;
   double beTrig = (g_config.enableTwinPositions) ? g_config.twinBeTriggerPips : g_config.beTriggerPips;
   g_posManager.UpdatePositionState(beLock, beTrig);
   g_posManager.ApplyActiveTrailing(g_config);

   // Guard 3: Daily Drawdown Circuit Breaker
   int closedTrades = 0, winTrades = 0;
   double realizedToday = CalculateTodayPerformance(g_magicNumber, closedTrades, winTrades);
   bool prevHalted = g_riskEngine.IsDDHalted();
   g_riskEngine.UpdateDailyDrawdown(AccountInfoDouble(ACCOUNT_EQUITY), realizedToday);
   bool currHalted = g_riskEngine.IsDDHalted();

   if(prevHalted && !currHalted)
   {
      g_logger.Info(StringFormat("Daily Drawdown Auto-Recovered! Trading resumed. Current DD: %.2f%%, Realized PnL: $%.2f",
                    g_riskEngine.GetCurrentDailyDD(), realizedToday), "TICK");
   }

   if(currHalted)
   {
      static datetime lastHaltWarn = 0;
      datetime now = TimeCurrent();
      if(now - lastHaltWarn >= 300) // Rate limit: Log at most once every 5 minutes
      {
         g_logger.Warning(StringFormat("Daily Drawdown limit active (Current DD: %.2f%%, Max: %.2f%%, Realized: $%.2f). Trading halted.", 
                          g_riskEngine.GetCurrentDailyDD(), g_riskEngine.GetMaxDailyDD(), realizedToday), "TICK");
         lastHaltWarn = now;
      }
      return;
   }

   // Dispatch Tick to Active Strategy
   g_strategySelector.OnTickHandler();

   // Check if Entry Signal Ready for Execution
   if(g_strategySelector.GetState() == EA_STATE_ENTRY_READY)
   {
      g_logger.Info("Entry signal ready â€” executing trade through ExecutionEngine...", "TICK");
      g_strategySelector.ExecuteCurrentSignal();
   }

   // Update telemetry during backtests or live ticks
   if(g_isBacktest)
   {
      UpdateDashboardTelemetry();
   }
}

//+------------------------------------------------------------------+
//| Timer Event Function (1-Second Interval)                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_isBacktest)
   {
      g_symbolHelper.Refresh();
      double beLock = (g_config.enableTwinPositions) ? g_config.twinBeLockPips : g_config.beLockPips;
      double beTrig = (g_config.enableTwinPositions) ? g_config.twinBeTriggerPips : g_config.beTriggerPips;
      g_posManager.UpdatePositionState(beLock, beTrig);
      g_posManager.ApplyActiveTrailing(g_config);
   }

   UpdateDashboardTelemetry();

   // Redraw chart visual objects if active
   if(InpShowDashboard && !g_isBacktest && g_dashboard.IsCreated())
   {
      g_dashboard.Redraw();
   }
}

//+------------------------------------------------------------------+
//| Chart Event Function (Dashboard Kill Switch & GUI Interaction)   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   bool killEngaged = false;
   bool toggleBE = false;
   bool toggleTrail = false;
   
   // Route chart event to Dashboard
   if(g_dashboard.OnChartEvent(id, lparam, dparam, sparam, killEngaged, toggleBE, toggleTrail))
   {
      if(killEngaged)
      {
         g_logger.Critical("EMERGENCY KILL SWITCH ACTIVATED VIA ON-CHART GUI! LIQUIDATING ALL MARKET POSITIONS IMMEDIATELY!", "KILL_SWITCH");
         
         // 1. Engage Risk Engine Kill Switch Flag
         g_riskEngine.SetKillSwitch(true);

         // 2. Liquidate all active strategy market exposure
         g_execEngine.CloseAllStrategyPositions(g_magicNumber);

         // 3. Force Strategy State to CLOSED & Reset internal signals
         g_strategySelector.SetState(EA_STATE_CLOSED);
         g_strategySelector.Reset();

         // 4. Update Dashboard UI to Emergency Halt banner
         g_dashboard.SetEmergencyHalt(true);
         UpdateDashboardTelemetry();
      }
      else if(toggleBE)
      {
         g_config.useBreakEven = !g_config.useBreakEven;
         g_strategySelector.SetConfig(g_config);
         g_logger.Info(StringFormat("Break-Even toggled via Dashboard: %s (Trigger: %.1fp, Lock: %.1fp)",
                       g_config.useBreakEven ? "ENABLED" : "DISABLED", g_config.beTriggerPips, g_config.beLockPips), "GUI");
         UpdateDashboardTelemetry();
      }
      else if(toggleTrail)
      {
         g_config.useTrailingStop = !g_config.useTrailingStop;
         g_strategySelector.SetConfig(g_config);
         g_logger.Info(StringFormat("Trailing Stop toggled via Dashboard: %s (Trigger: %.1fp, Trail: %.1fp)",
                       g_config.useTrailingStop ? "ENABLED" : "DISABLED", g_config.trailTriggerPips, g_config.trailDistPips), "GUI");
         UpdateDashboardTelemetry();
      }
   }
}

//+------------------------------------------------------------------+
//| Strategy Tester Custom Optimization Criterion                    |
//+------------------------------------------------------------------+
double OnTester()
{
   double netProfit   = TesterStatistics(STAT_PROFIT);
   double maxDD       = TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double trades      = TesterStatistics(STAT_TRADES);
   double profitTrades= TesterStatistics(STAT_PROFIT_TRADES);
   double winRate     = (trades > 0) ? ((profitTrades / trades) * 100.0) : 0.0;

   if(maxDD <= 0.0) maxDD = 1.0;
   
   // Optimization formula: (NetProfit / MaxDD%) * ln(max(Trades, 1))
   double score = (netProfit / maxDD) * MathLog(MathMax(trades, 1.0));

   PrintFormat("[TESTER] Optimization Score: %.4f | Net Profit: %.2f | Max DD: %.2f%% | Total Trades: %.0f | Win Rate: %.1f%%",
               score, netProfit, maxDD, trades, winRate);

   return score;
}

