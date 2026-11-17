//+------------------------------------------------------------------+
//|                                            StrategyPortfolio.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_STRATEGIES_STRATEGYPORTFOLIO_MQH
#define LEGSTECH_STRATEGIES_STRATEGYPORTFOLIO_MQH

#include <Object.mqh>
#include "..\Core\Defs.mqh"
#include "..\Core\Logger.mqh"
#include "..\Core\BaseStrategy.mqh"
#include "..\Engine\SymbolHelper.mqh"
#include "..\Engine\RiskEngine.mqh"
#include "..\Engine\ExecutionEngine.mqh"
#include "..\Engine\PositionManager.mqh"
#include "StrategyRemmy.mqh"
#include "StrategyCallisto.mqh"
#include "StrategyDB.mqh"

//+------------------------------------------------------------------+
//| Class CStrategyPortfolio                                         |
//| Multi-Strategy Concurrent Execution (Scalp + Swing Fusion)       |
//+------------------------------------------------------------------+
class CStrategyPortfolio : public CBaseStrategy
{
private:
   CStrategyRemmy       *m_remmy;
   CStrategyCallisto    *m_callisto;
   CStrategyDB          *m_db;

   SStrategyConfig      m_config;
   SStrategyConfig      m_configRemmy;
   SStrategyConfig      m_configCallisto;
   SStrategyConfig      m_configDb;

   CSymbolHelper       *m_symHelper;
   CRiskEngine         *m_riskEngine;
   CExecutionEngine    *m_execEngine;
   CPositionManager    *m_posManager;

public:
                        CStrategyPortfolio();
   virtual             ~CStrategyPortfolio();

   bool                 InitWithEngines(const string symbol,
                                        const SStrategyConfig &globalConfig,
                                        CSymbolHelper *symHelper,
                                        CRiskEngine *riskEngine,
                                        CExecutionEngine *execEngine,
                                        CPositionManager *posMgr,
                                        CLogger *logger);

   virtual void         Deinit();
   virtual void         OnTickHandler();
   virtual void         OnBarHandler(ENUM_TIMEFRAMES tf);
   virtual void         EvaluateSetup();
   virtual void         ManageOpenPositions();
   virtual bool         ExecuteCurrentSignal();
   virtual string       GetStrategyName() { return "PORTFOLIO (MULTI-STRATEGY)"; }
   virtual string       GetStatusString();
   virtual ENUM_EA_STATE GetState();
   void                 SetConfig(const SStrategyConfig &cfg);
   bool                 IsDirectionAllowed(ENUM_SIGNAL_TYPE incomingSignalType, string strategyName);

   // Multi-Strategy Telemetry Accessors
   string               GetRemmyStatus()    { return (m_remmy != NULL) ? m_remmy.GetStatusString() : "RM: Disabled"; }
   string               GetCallistoStatus() { return (m_callisto != NULL) ? m_callisto.GetStatusString() : "CL: Disabled"; }
   string               GetDbStatus()       { return (m_db != NULL) ? m_db.GetStatusString() : "DB: Disabled"; }
};

//+------------------------------------------------------------------+
//| SetConfig: Propagate configuration updates to sub-strategies     |
//+------------------------------------------------------------------+
inline void CStrategyPortfolio::SetConfig(const SStrategyConfig &cfg)
{
   m_config = cfg;
   int maxTrades = (cfg.maxPositions > 0) ? cfg.maxPositions : 2;
   double riskPerStrategy = (cfg.riskMode != RISK_MODE_FIXED_LOT && maxTrades > 1) ? 
                            (cfg.riskPercent / (double)maxTrades) : cfg.riskPercent;

   // 1. Propagate Global Risk Controls to REMMY
   m_configRemmy.riskMode             = cfg.riskMode;
   m_configRemmy.fixedLotSize         = cfg.fixedLotSize;
   m_configRemmy.riskPercent          = riskPerStrategy;
   m_configRemmy.scalpRiskPercent     = riskPerStrategy;
   m_configRemmy.dayRiskPercent       = riskPerStrategy;
   m_configRemmy.swingRiskPercent     = riskPerStrategy;
   m_configRemmy.enableDoublePosition = cfg.enableDoublePosition;
   m_configRemmy.remmyRunnerEnabled   = cfg.enableDoublePosition;
   m_configRemmy.useBreakEven         = cfg.useBreakEven;
   m_configRemmy.beTriggerPips        = cfg.beTriggerPips;
   m_configRemmy.beLockPips           = cfg.beLockPips;
   m_configRemmy.useTrailingStop      = cfg.useTrailingStop;
   m_configRemmy.trailTriggerPips     = cfg.trailTriggerPips;
   m_configRemmy.trailDistPips        = cfg.trailDistPips;
   m_configRemmy.trailStepPips        = cfg.trailStepPips;
   m_configRemmy.maxPositions         = cfg.maxPositions;
   m_configRemmy.useSessionFilter     = cfg.useSessionFilter;
   m_configRemmy.sessionStartHour     = cfg.sessionStartHour;
   m_configRemmy.sessionEndHour       = cfg.sessionEndHour;
   m_configRemmy.remmyUseD1Filter      = cfg.remmyUseD1Filter;
   m_configRemmy.remmyUseSessionFilter = cfg.remmyUseSessionFilter;
   m_configRemmy.remmySessionStartGmt  = cfg.remmySessionStartGmt;
   m_configRemmy.remmySessionEndGmt    = cfg.remmySessionEndGmt;
   if(m_remmy != NULL) m_remmy.SetConfig(m_configRemmy);

   // 2. Propagate Global Risk Controls to CALLISTO
   m_configCallisto.riskMode             = cfg.riskMode;
   m_configCallisto.fixedLotSize         = cfg.fixedLotSize;
   m_configCallisto.riskPercent          = riskPerStrategy;
   m_configCallisto.scalpRiskPercent     = riskPerStrategy;
   m_configCallisto.dayRiskPercent       = riskPerStrategy;
   m_configCallisto.swingRiskPercent     = riskPerStrategy;
   m_configCallisto.enableDoublePosition = cfg.enableDoublePosition;
   m_configCallisto.callistoRunnerEnabled= cfg.enableDoublePosition;
   m_configCallisto.useBreakEven         = cfg.useBreakEven;
   m_configCallisto.beTriggerPips        = cfg.beTriggerPips;
   m_configCallisto.beLockPips           = cfg.beLockPips;
   m_configCallisto.useTrailingStop      = cfg.useTrailingStop;
   m_configCallisto.trailTriggerPips     = cfg.trailTriggerPips;
   m_configCallisto.trailDistPips        = cfg.trailDistPips;
   m_configCallisto.trailStepPips        = cfg.trailStepPips;
   m_configCallisto.maxPositions         = cfg.maxPositions;
   m_configCallisto.useSessionFilter     = cfg.useSessionFilter;
   m_configCallisto.sessionStartHour     = cfg.sessionStartHour;
   m_configCallisto.sessionEndHour       = cfg.sessionEndHour;
   m_configCallisto.callistoUseSessionFilter = cfg.callistoUseSessionFilter;
   m_configCallisto.callistoSessionStartGmt  = cfg.callistoSessionStartGmt;
   m_configCallisto.callistoSessionEndGmt    = cfg.callistoSessionEndGmt;
   m_configCallisto.callistoUseTrailing      = cfg.callistoUseTrailing;
   m_configCallisto.callistoTrailDistPips    = cfg.callistoTrailDistPips;
   m_configCallisto.callistoTrailTriggerPips = cfg.callistoTrailTriggerPips;
   m_configCallisto.callistoTrailStepPips    = cfg.callistoTrailStepPips;
   m_configCallisto.callistoUseBreakEven     = cfg.callistoUseBreakEven;
   m_configCallisto.callistoBeTriggerPips    = cfg.callistoBeTriggerPips;
   m_configCallisto.callistoBeLockPips       = cfg.callistoBeLockPips;
   m_configCallisto.callistoStaleGuardPips   = cfg.callistoStaleGuardPips;
   m_configCallisto.enableTwinPositions      = cfg.enableTwinPositions;
   m_configCallisto.twinLotMode              = cfg.twinLotMode;
   m_configCallisto.twinTP1_Pips             = cfg.twinTP1_Pips;
   m_configCallisto.twinBeTriggerPips        = cfg.twinBeTriggerPips;
   m_configCallisto.twinBeLockPips           = cfg.twinBeLockPips;
   m_configCallisto.twinTrailDistPips        = cfg.twinTrailDistPips;
   m_configCallisto.twinTrailStepPips        = cfg.twinTrailStepPips;
   m_configCallisto.callistoUseM1Confirmation= cfg.callistoUseM1Confirmation;
   m_configCallisto.callistoTargetOpposingPoi= cfg.callistoTargetOpposingPoi;
   if(m_callisto != NULL) m_callisto.SetConfig(m_configCallisto);

   // 3. Propagate Global Risk Controls to DB
   m_configDb.riskMode             = cfg.riskMode;
   m_configDb.fixedLotSize         = cfg.fixedLotSize;
   m_configDb.riskPercent          = riskPerStrategy;
   m_configDb.scalpRiskPercent     = riskPerStrategy;
   m_configDb.dayRiskPercent       = riskPerStrategy;
   m_configDb.swingRiskPercent     = riskPerStrategy;
   m_configDb.enableDoublePosition = cfg.enableDoublePosition;
   m_configDb.dbRunnerEnabled      = cfg.enableDoublePosition;
   m_configDb.dbTradeAllSessions   = cfg.dbTradeAllSessions;
   m_configDb.useBreakEven         = cfg.useBreakEven;
   m_configDb.beTriggerPips        = cfg.beTriggerPips;
   m_configDb.beLockPips           = cfg.beLockPips;
   m_configDb.useTrailingStop      = cfg.useTrailingStop;
   m_configDb.trailTriggerPips     = cfg.trailTriggerPips;
   m_configDb.trailDistPips        = cfg.trailDistPips;
   m_configDb.trailStepPips        = cfg.trailStepPips;
   m_configDb.maxPositions         = cfg.maxPositions;
   m_configDb.useSessionFilter     = cfg.useSessionFilter;
   m_configDb.sessionStartHour     = cfg.sessionStartHour;
   m_configDb.sessionEndHour       = cfg.sessionEndHour;
   m_configDb.dbUseSessionFilter       = cfg.dbUseSessionFilter;
   m_configDb.dbSessionStartGmt        = cfg.dbSessionStartGmt;
   m_configDb.dbSessionEndGmt          = cfg.dbSessionEndGmt;
   m_configDb.dbUtcOffset              = cfg.dbUtcOffset;
   m_configDb.dbSlPips                 = cfg.dbSlPips;
   m_configDb.dbTpPips                 = cfg.dbTpPips;
   m_configDb.dbSwingBufferPips        = cfg.dbSwingBufferPips;
   m_configDb.dbPullbackCandles        = cfg.dbPullbackCandles;
   m_configDb.dbStartHour1             = cfg.dbStartHour1;
   m_configDb.dbStartHour2             = cfg.dbStartHour2;
   if(m_db != NULL) m_db.SetConfig(m_configDb);
}

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStrategyPortfolio::CStrategyPortfolio()
{
   m_strategyType   = STRATEGY_PORTFOLIO;
   m_strategyName   = "PORTFOLIO_MULTI";
   m_remmy          = NULL;
   m_callisto       = NULL;
   m_db             = NULL;
   m_symHelper      = NULL;
   m_riskEngine     = NULL;
   m_execEngine     = NULL;
   m_posManager     = NULL;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStrategyPortfolio::~CStrategyPortfolio()
{
   Deinit();
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
void CStrategyPortfolio::Deinit()
{
   if(CheckPointer(m_remmy) == POINTER_DYNAMIC)    { delete m_remmy;    m_remmy = NULL; }
   if(CheckPointer(m_callisto) == POINTER_DYNAMIC) { delete m_callisto; m_callisto = NULL; }
   if(CheckPointer(m_db) == POINTER_DYNAMIC)       { delete m_db;       m_db = NULL; }
   m_isInitialized = false;
}

//+------------------------------------------------------------------+
//| Full Engine Initializer                                          |
//+------------------------------------------------------------------+
bool CStrategyPortfolio::InitWithEngines(const string symbol,
                                         const SStrategyConfig &globalConfig,
                                         CSymbolHelper *symHelper,
                                         CRiskEngine *riskEngine,
                                         CExecutionEngine *execEngine,
                                         CPositionManager *posMgr,
                                         CLogger *logger)
{
   Deinit();

   m_symbol      = symbol;
   m_timeframe   = PERIOD_M15;
   m_symHelper   = symHelper;
   m_riskEngine  = riskEngine;
   m_execEngine  = execEngine;
   m_posManager  = posMgr;
   m_logger      = logger;

   if(!globalConfig.enableRemmy && !globalConfig.enableCallisto && !globalConfig.enableDb)
   {
      if(logger) logger.Error("Portfolio: All sub-strategies are disabled! Enable at least one strategy.", "PORTFOLIO");
      return false;
   }

   // 1. Configure REMMY in SCALP Mode (Magic 101001)
   if(globalConfig.enableRemmy)
   {
      m_configRemmy                   = globalConfig;
      m_configRemmy.strategyType      = STRATEGY_REMMY;
      m_configRemmy.tradeProfile      = PROFILE_SCALP;
      m_configRemmy.magicNumber       = DEFAULT_MAGIC_REMMY;
      m_configRemmy.enableDoublePosition = globalConfig.enableDoublePosition;
      m_configRemmy.remmyRunnerEnabled= globalConfig.enableDoublePosition;
      m_configRemmy.riskMode          = globalConfig.riskMode;
      m_configRemmy.fixedLotSize      = globalConfig.fixedLotSize;
      m_configRemmy.riskPercent       = globalConfig.riskPercent;
      m_configRemmy.scalpRiskPercent  = globalConfig.riskPercent;
      m_configRemmy.dayRiskPercent    = globalConfig.riskPercent;
      m_configRemmy.swingRiskPercent  = globalConfig.riskPercent;

      m_remmy = new CStrategyRemmy();
      if(!m_remmy.InitWithEngines(symbol, PERIOD_M15, m_configRemmy, symHelper, riskEngine, execEngine, posMgr, logger))
      {
         if(logger) logger.Error("Portfolio: Failed to initialize REMMY sub-strategy!", "PORTFOLIO");
         return false;
      }
      if(logger) logger.Info("Portfolio: Strategy REMMY (M15 Scalp) initialized [ACTIVE]", "PORTFOLIO");
   }
   else
   {
      m_remmy = NULL;
      if(logger) logger.Info("Portfolio: Strategy REMMY disabled by configuration [OFFLINE]", "PORTFOLIO");
   }

   // 2. Configure CALLISTO in SWING Mode (Magic 101002)
   if(globalConfig.enableCallisto)
   {
      m_configCallisto                = globalConfig;
      m_configCallisto.strategyType   = STRATEGY_CALLISTO;
      m_configCallisto.tradeProfile   = PROFILE_SWING;
      m_configCallisto.magicNumber    = DEFAULT_MAGIC_CALLISTO;
      m_configCallisto.enableDoublePosition = globalConfig.enableDoublePosition;
      m_configCallisto.callistoRunnerEnabled= globalConfig.enableDoublePosition;
      m_configCallisto.callistoUseTrailing      = globalConfig.callistoUseTrailing;
      m_configCallisto.callistoTrailDistPips    = globalConfig.callistoTrailDistPips;
      m_configCallisto.callistoTrailTriggerPips = globalConfig.callistoTrailTriggerPips;
      m_configCallisto.callistoTrailStepPips    = globalConfig.callistoTrailStepPips;
      m_configCallisto.callistoUseBreakEven     = globalConfig.callistoUseBreakEven;
      m_configCallisto.callistoBeTriggerPips    = globalConfig.callistoBeTriggerPips;
      m_configCallisto.callistoBeLockPips       = globalConfig.callistoBeLockPips;
      m_configCallisto.callistoStaleGuardPips   = globalConfig.callistoStaleGuardPips;
      m_configCallisto.riskMode       = globalConfig.riskMode;
      m_configCallisto.fixedLotSize   = globalConfig.fixedLotSize;
      m_configCallisto.riskPercent    = globalConfig.riskPercent;
      m_configCallisto.scalpRiskPercent  = globalConfig.riskPercent;
      m_configCallisto.dayRiskPercent    = globalConfig.riskPercent;
      m_configCallisto.swingRiskPercent  = globalConfig.riskPercent;

      m_callisto = new CStrategyCallisto();
      if(!m_callisto.InitWithEngines(symbol, PERIOD_H1, m_configCallisto, symHelper, riskEngine, execEngine, posMgr, logger))
      {
         if(logger) logger.Error("Portfolio: Failed to initialize CALLISTO sub-strategy!", "PORTFOLIO");
         return false;
      }
      if(logger) logger.Info("Portfolio: Strategy CALLISTO (H1 Swing) initialized [ACTIVE]", "PORTFOLIO");
   }
   else
   {
      m_callisto = NULL;
      if(logger) logger.Info("Portfolio: Strategy CALLISTO disabled by configuration [OFFLINE]", "PORTFOLIO");
   }

   // 3. Configure DB in SCALP Mode (Magic 101003)
   if(globalConfig.enableDb)
   {
      m_configDb                      = globalConfig;
      m_configDb.strategyType         = STRATEGY_DB;
      m_configDb.tradeProfile         = PROFILE_SCALP;
      m_configDb.magicNumber          = DEFAULT_MAGIC_DB;
      m_configDb.enableDoublePosition = globalConfig.enableDoublePosition;
      m_configDb.dbRunnerEnabled      = globalConfig.enableDoublePosition;
      m_configDb.dbTradeAllSessions   = globalConfig.dbTradeAllSessions;
      m_configDb.riskMode             = globalConfig.riskMode;
      m_configDb.fixedLotSize         = globalConfig.fixedLotSize;
      m_configDb.riskPercent          = globalConfig.riskPercent;
      m_configDb.scalpRiskPercent     = globalConfig.riskPercent;
      m_configDb.dayRiskPercent       = globalConfig.riskPercent;
      m_configDb.swingRiskPercent     = globalConfig.riskPercent;

      m_db = new CStrategyDB();
      if(!m_db.InitWithEngines(symbol, PERIOD_M30, m_configDb, symHelper, riskEngine, execEngine, posMgr, logger))
      {
         if(logger) logger.Error("Portfolio: Failed to initialize DB sub-strategy!", "PORTFOLIO");
         return false;
      }
      if(logger) logger.Info("Portfolio: Strategy DB (M30 Scalp) initialized [ACTIVE]", "PORTFOLIO");
   }
   else
   {
      m_db = NULL;
      if(logger) logger.Info("Portfolio: Strategy DB disabled by configuration [OFFLINE]", "PORTFOLIO");
   }

   m_isInitialized = true;
   string activeList = "";
   if(m_remmy != NULL) activeList += "REMMY ";
   if(m_callisto != NULL) activeList += "CALLISTO ";
   if(m_db != NULL) activeList += "DB ";
   if(logger) logger.Info(StringFormat("Portfolio: Initialized successfully with active strategies: [ %s]", activeList), "PORTFOLIO");
   return true;
}

//+------------------------------------------------------------------+
//| OnTick Handler: Updates all active strategies                    |
//+------------------------------------------------------------------+
void CStrategyPortfolio::OnTickHandler()
{
   if(!m_isInitialized) return;

   if(m_remmy != NULL)    m_remmy.OnTickHandler();
   if(m_callisto != NULL) m_callisto.OnTickHandler();
   if(m_db != NULL)       m_db.OnTickHandler();
}

//+------------------------------------------------------------------+
//| OnBar Handler: Checks bar updates across all timeframes          |
//+------------------------------------------------------------------+
void CStrategyPortfolio::OnBarHandler(ENUM_TIMEFRAMES tf)
{
   if(!m_isInitialized) return;

   if(m_remmy != NULL)    m_remmy.OnBarHandler(tf);
   if(m_callisto != NULL) m_callisto.OnBarHandler(tf);
   if(m_db != NULL)       m_db.OnBarHandler(tf);
}

//+------------------------------------------------------------------+
//| Evaluate Setup                                                   |
//+------------------------------------------------------------------+
void CStrategyPortfolio::EvaluateSetup()
{
   if(!m_isInitialized) return;

   if(m_remmy != NULL)    m_remmy.EvaluateSetup();
   if(m_callisto != NULL) m_callisto.EvaluateSetup();
   if(m_db != NULL)       m_db.EvaluateSetup();
}

//+------------------------------------------------------------------+
//| Manage Open Positions across all active strategies               |
//+------------------------------------------------------------------+
void CStrategyPortfolio::ManageOpenPositions()
{
   if(!m_isInitialized) return;

   if(m_remmy != NULL)    m_remmy.ManageOpenPositions();
   if(m_callisto != NULL) m_callisto.ManageOpenPositions();
   if(m_db != NULL)       m_db.ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| Directional Mutex: Enforce Partner's Risk-Free Retracement Rule   |
//+------------------------------------------------------------------+
bool CStrategyPortfolio::IsDirectionAllowed(ENUM_SIGNAL_TYPE incomingSignalType, string strategyName)
{
   if(incomingSignalType != SIGNAL_BUY && incomingSignalType != SIGNAL_SELL)
      return true;

   int totalPos = PositionsTotal();
   if(totalPos == 0)
      return true;

   bool isIncomingBuy = (incomingSignalType == SIGNAL_BUY);
   double point = (m_symHelper != NULL) ? m_symHelper.GetPoint() : _Point;
   double pipVal = (point > 0.0) ? (point * 10.0) : 0.1;
   if(pipVal <= 0.0) pipVal = 0.1;

   string curSym = m_symbol;
   StringToUpper(curSym);

   for(int i = 0; i < totalPos; i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      string pSym = PositionGetString(POSITION_SYMBOL);
      StringToUpper(pSym);
      if(pSym != curSym) continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool isExistingBuy = (posType == POSITION_TYPE_BUY);

      // Same direction positions (BUY with BUY, SELL with SELL) are allowed
      if(isExistingBuy == isIncomingBuy)
         continue;

      // Existing position is in the OPPOSITE direction!
      // Enforce Partner's "Risk-Free Retracement Rule":
      // 1. Existing trade MUST have SL locked at or beyond Break-Even (Zero downside risk)
      // 2. Current price must be at least 100 pips away from the existing trade's open price
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double slPrice   = PositionGetDouble(POSITION_SL);
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);

      bool isRiskFree = false;
      if(isExistingBuy)
      {
         // For existing BUY: SL must be >= openPrice (protected in profit or BE)
         isRiskFree = (slPrice > 0.0 && slPrice >= (openPrice - 0.5 * pipVal));
      }
      else
      {
         // For existing SELL: SL must be <= openPrice (protected in profit or BE)
         isRiskFree = (slPrice > 0.0 && slPrice <= (openPrice + 0.5 * pipVal));
      }

      double pipDistance = MathAbs(curPrice - openPrice) / pipVal;

      if(!isRiskFree || pipDistance < 100.0)
      {
         if(m_logger != NULL)
         {
            m_logger.Warning(StringFormat("PORTFOLIO MUTEX: %s %s blocked! Opposite position #%I64u active (RiskFree: %s, Dist: %.1fp < 100p). Preventing wash trade.",
                                          strategyName, (incomingSignalType == SIGNAL_BUY ? "BUY" : "SELL"),
                                          t, isRiskFree ? "YES" : "NO", pipDistance), "PORTFOLIO");
         }
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| Execute Current Signal                                           |
//+------------------------------------------------------------------+
bool CStrategyPortfolio::ExecuteCurrentSignal()
{
   if(m_riskEngine != NULL)
   {
      string denyReason;
      if(!m_riskEngine.IsTradingAllowed(denyReason))
      {
         if(m_logger != NULL)
            m_logger.Warning(StringFormat("Portfolio execution BLOCKED by Global RiskEngine: %s", denyReason), "PORTFOLIO");
         return false;
      }
   }

   int maxAllowed = (m_config.maxPositions > 0) ? m_config.maxPositions : 2;
   int currentPositions = (m_riskEngine != NULL) ? m_riskEngine.CountSymbolPositions() : 0;

   // If max concurrent positions already filled, strategies wait in queue
   if(currentPositions >= maxAllowed)
   {
      return false;
   }

   bool anyExecuted = false;

   // 1. Try REMMY if ready and slots available
   if(currentPositions < maxAllowed && m_remmy != NULL && m_remmy.GetState() == EA_STATE_ENTRY_READY)
   {
      STradeSignal remmySig;
      if(m_remmy.GetTradeSignals(remmySig) && IsDirectionAllowed(remmySig.type, "RM"))
      {
         if(m_remmy.ExecuteCurrentSignal())
         {
            anyExecuted = true;
            currentPositions = (m_riskEngine != NULL) ? m_riskEngine.CountSymbolPositions() : currentPositions + 1;
         }
      }
   }

   // 2. Try CALLISTO if ready and slots available
   if(currentPositions < maxAllowed && m_callisto != NULL && m_callisto.GetState() == EA_STATE_ENTRY_READY)
   {
      STradeSignal callistoSig;
      if(m_callisto.GetTradeSignals(callistoSig) && IsDirectionAllowed(callistoSig.type, "CL"))
      {
         if(m_callisto.ExecuteCurrentSignal())
         {
            anyExecuted = true;
            currentPositions = (m_riskEngine != NULL) ? m_riskEngine.CountSymbolPositions() : currentPositions + 1;
         }
      }
   }

   // 3. Try DB if ready and slots available
   if(currentPositions < maxAllowed && m_db != NULL && m_db.GetState() == EA_STATE_ENTRY_READY)
   {
      STradeSignal dbSig;
      if(m_db.GetTradeSignals(dbSig) && IsDirectionAllowed(dbSig.type, "DB"))
      {
         if(m_db.ExecuteCurrentSignal())
         {
            anyExecuted = true;
            currentPositions = (m_riskEngine != NULL) ? m_riskEngine.CountSymbolPositions() : currentPositions + 1;
         }
      }
   }

   return anyExecuted;
}

//+------------------------------------------------------------------+
//| State Getter                                                     |
//+------------------------------------------------------------------+
ENUM_EA_STATE CStrategyPortfolio::GetState()
{
   int maxAllowed = (m_config.maxPositions > 0) ? m_config.maxPositions : 2;
   int currentPositions = (m_riskEngine != NULL) ? m_riskEngine.CountSymbolPositions() : 0;

   // If slots available and any strategy is ENTRY_READY, portfolio is ready to execute
   if(currentPositions < maxAllowed)
   {
      if(m_remmy != NULL && m_remmy.GetState() == EA_STATE_ENTRY_READY) return EA_STATE_ENTRY_READY;
      if(m_callisto != NULL && m_callisto.GetState() == EA_STATE_ENTRY_READY) return EA_STATE_ENTRY_READY;
      if(m_db != NULL && m_db.GetState() == EA_STATE_ENTRY_READY) return EA_STATE_ENTRY_READY;
   }

   if(m_remmy != NULL && m_remmy.GetState() == EA_STATE_MANAGING) return EA_STATE_MANAGING;
   if(m_callisto != NULL && m_callisto.GetState() == EA_STATE_MANAGING) return EA_STATE_MANAGING;
   if(m_db != NULL && m_db.GetState() == EA_STATE_MANAGING) return EA_STATE_MANAGING;

   if(m_remmy != NULL && m_remmy.GetState() == EA_STATE_ANALYSING) return EA_STATE_ANALYSING;
   if(m_callisto != NULL && m_callisto.GetState() == EA_STATE_ANALYSING) return EA_STATE_ANALYSING;
   if(m_db != NULL && m_db.GetState() == EA_STATE_ANALYSING) return EA_STATE_ANALYSING;

   return EA_STATE_IDLE;
}

//+------------------------------------------------------------------+
//| Status String                                                    |
//+------------------------------------------------------------------+
string CStrategyPortfolio::GetStatusString()
{
   string status = "PORTFOLIO: ";
   status += (m_remmy != NULL) ? StringFormat("[RM: %s] ", StateToString(m_remmy.GetState())) : "[RM: OFF] ";
   status += (m_callisto != NULL) ? StringFormat("[CL: %s] ", StateToString(m_callisto.GetState())) : "[CL: OFF] ";
   status += (m_db != NULL) ? StringFormat("[DB: %s]", StateToString(m_db.GetState())) : "[DB: OFF]";
   return status;
}

#endif // LEGSTECH_STRATEGIES_STRATEGYPORTFOLIO_MQH
