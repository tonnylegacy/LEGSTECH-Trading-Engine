//+------------------------------------------------------------------+
//|                                             StrategyCallisto.mqh |
//|                                  Copyright 2026, LEGsTECH Team.  |
//|                                       SOLUTIONS FOR TOMORROW     |
//+------------------------------------------------------------------+
#ifndef LEGSTECH_STRATEGIES_STRATEGYCALLISTO_MQH
#define LEGSTECH_STRATEGIES_STRATEGYCALLISTO_MQH

#include "..\Core\Defs.mqh"
#include "..\Core\Logger.mqh"
#include "..\Core\StateMachine.mqh"
#include "..\Core\BaseStrategy.mqh"
#include "..\Engine\SymbolHelper.mqh"
#include "..\Engine\RiskEngine.mqh"
#include "..\Engine\ExecutionEngine.mqh"
#include "..\Engine\PositionManager.mqh"
#include "..\Indicators\FVGDetector.mqh"
#include "..\Indicators\StructureDetector.mqh"
#include "..\Indicators\SessionFilter.mqh"

//+------------------------------------------------------------------+
//| Struct for CALLISTO HTF POI and LTF Confirmation State           |
//+------------------------------------------------------------------+
struct SCallistoSetup
{
   bool                    isValid;             // True if active HTF POI established
   bool                    isBuy;               // True = Demand/Long POI, False = Supply/Short POI
   SFVGZone                htfPoiZone;          // Active HTF POI Zone
   bool                    isOrderBlock;        // True if POI is an Order Block
   bool                    isTapped;            // True if live price has tapped POI zone
   datetime                tapTime;             // Timestamp when tap occurred
   double                  tapPrice;            // Price level at time of tap

   // LTF Confirmation Data
   ENUM_CONFIRMATION_MODE  confirmMode;         // Selected confirmation mode
   double                  refSwingLevel;       // Reference LTF swing level
   datetime                refSwingTime;        // Time of reference swing level
   SFVGZone                ltfIfvgZone;         // LTF Inverted FVG zone
   bool                    isConfirmed;         // True if LTF confirmation condition met
   datetime                confirmTime;         // Timestamp of confirming LTF candle
   double                  confirmClosePrice;   // Close price of confirming candle

   void Reset()
   {
      isValid           = false;
      isBuy             = false;
      htfPoiZone.Reset();
      isOrderBlock      = false;
      isTapped          = false;
      tapTime           = 0;
      tapPrice          = 0.0;
      confirmMode       = CONFIRM_MODE_CHOCH;
      refSwingLevel     = 0.0;
      refSwingTime      = 0;
      ltfIfvgZone.Reset();
      isConfirmed       = false;
      confirmTime       = 0;
      confirmClosePrice = 0.0;
   }
};

//+------------------------------------------------------------------+
//| Class CStrategyCallisto                                          |
//| CALLISTO: H1 HTF POI Scanner & LTF Confirmation Architecture     |
//+------------------------------------------------------------------+
class CStrategyCallisto : public CBaseStrategy
{
private:
   // Collaborator Subsystems
   CSymbolHelper          *m_symbolHelper;
   CRiskEngine            *m_riskEngine;
   CExecutionEngine       *m_execEngine;
   CPositionManager       *m_posManager;
   CFVGDetector           *m_htfFvgDetector;
   CFVGDetector           *m_ltfFvgDetector;
   CStructureDetector     *m_structDetector;

   bool                    m_ownsEngines;
   bool                    m_ownsDetectors;

   // Strategy Configuration
   SStrategyConfig         m_config;

   // Active Setup State
   SCallistoSetup          m_setup;

   // Daily Trade Limit Tracking
   int                     m_tradesTodayCount;
   datetime                m_lastTradeDay;
   datetime                m_lastTradedPoiTime;
   double                  m_lastTradedPoiPrice;

   // Offline / Deterministic Testing Support
   bool                    m_mockMode;
   MqlRates                m_syntheticHtfRates[];
   int                     m_syntheticHtfCount;
   MqlRates                m_syntheticLtfRates[];
   int                     m_syntheticLtfCount;

   // Internal processing helpers
   bool                    ScanHtfPOI(const MqlRates &htfRates[], int htfTotal, double currentPrice, SCallistoSetup &outSetup);
   bool                    CheckPOITap(double currentPrice, SCallistoSetup &inOutSetup);
   bool                    CheckLtfConfirmation(const MqlRates &ltfRates[], int ltfTotal, SCallistoSetup &inOutSetup);
   bool                    EvaluateChochConfirmation(const MqlRates &ltfRates[], int ltfTotal, SCallistoSetup &inOutSetup);
   bool                    EvaluateIfvgConfirmation(const MqlRates &ltfRates[], int ltfTotal, SCallistoSetup &inOutSetup);
   bool                    EvaluateEngulfingConfirmation(const MqlRates &ltfRates[], int ltfTotal, SCallistoSetup &inOutSetup);
   bool                    BuildSignal(const SCallistoSetup &setup, STradeSignal &outSignal);
   void                    CheckDailyTradeReset(datetime currentBarTime);
   void                    HandleManagingState();

public:
                           CStrategyCallisto();
   virtual                ~CStrategyCallisto();

   // IStrategy Contract Implementation
   virtual bool            Init(const string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_H1);
   virtual void            Deinit();
   virtual void            OnTickHandler();
   virtual void            OnBarHandler(ENUM_TIMEFRAMES tf);
   virtual void            EvaluateSetup();
   virtual bool            GetTradeSignals(STradeSignal &outSignal);
   virtual void            ManageOpenPositions();
   virtual void            Reset();
   virtual string          GetStatusString();

   // Advanced Dependency Injection Initializer
   bool                    InitWithEngines(const string symbol,
                                           ENUM_TIMEFRAMES htfTimeframe,
                                           const SStrategyConfig &config,
                                           CSymbolHelper *symHelper,
                                           CRiskEngine *riskEngine,
                                           CExecutionEngine *execEngine,
                                           CPositionManager *posMgr,
                                           CLogger *logger,
                                           CFVGDetector *htfFvgDet = NULL,
                                           CFVGDetector *ltfFvgDet = NULL,
                                           CStructureDetector *structDet = NULL);

   // Offline / Deterministic Testing Support
   void                    SetMockMode(bool enabled);
   bool                    IsMockMode() const { return m_mockMode; }
   void                    SetSyntheticHtfRates(const MqlRates &rates[], int count);
   void                    SetSyntheticLtfRates(const MqlRates &rates[], int count);
   bool                    EvaluateSetupFromRates(const MqlRates &htfRates[], int htfTotal, const MqlRates &ltfRates[], int ltfTotal, double currentPrice = 0.0);
   void                    ManageOpenPositionsFromRates(const MqlRates &rates[], int totalRates);

   // Execution Dispatcher
   bool                    ExecuteCurrentSignal();

   // Setters & Configuration Accessors
   void                    SetConfig(const SStrategyConfig &cfg)                { m_config = cfg; }
   void                    GetConfig(SStrategyConfig &outCfg) const             { outCfg = m_config; }
   void                    SetConfirmationMode(ENUM_CONFIRMATION_MODE mode)     { m_config.callistoConfirmMode = mode; }
   ENUM_CONFIRMATION_MODE  GetConfirmationMode() const                          { return m_config.callistoConfirmMode; }
   void                    SetHtfTimeframe(ENUM_TIMEFRAMES tf)                  { m_config.callistoHtfTf = tf; }
   ENUM_TIMEFRAMES         GetHtfTimeframe() const                              { return m_config.callistoHtfTf; }
   void                    SetLtfTimeframe(ENUM_TIMEFRAMES tf)                  { m_config.callistoLtfTf = tf; }
   ENUM_TIMEFRAMES         GetLtfTimeframe() const                              { return m_config.callistoLtfTf; }
   void                    SetMaxDailyTrades(int maxTrades)                     { m_config.maxDailyTrades = maxTrades; }
   int                     GetMaxDailyTrades() const                            { return m_config.maxDailyTrades; }
   int                     GetTradesTodayCount() const                          { return m_tradesTodayCount; }
   void                    SetTradesTodayCount(int count)                       { m_tradesTodayCount = count; }

   // State & Setup Queries
   bool                    GetActiveSetup(SCallistoSetup &outSetup) const       { outSetup = m_setup; return m_setup.isValid; }
   bool                    IsPOITapped() const                                  { return m_setup.isTapped; }
   bool                    IsLTFConfirmed() const                               { return m_setup.isConfirmed; }

   // Subsystem Accessors
   CFVGDetector*           GetHtfFvgDetector()                                  { return m_htfFvgDetector; }
   CFVGDetector*           GetLtfFvgDetector()                                  { return m_ltfFvgDetector; }
   CStructureDetector*     GetStructureDetector()                               { return m_structDetector; }
   CPositionManager*       GetPositionManager()                                 { return m_posManager; }
   CRiskEngine*            GetRiskEngine()                                      { return m_riskEngine; }
   CExecutionEngine*       GetExecutionEngine()                                 { return m_execEngine; }
   CSymbolHelper*          GetSymbolHelper()                                    { return m_symbolHelper; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CStrategyCallisto::CStrategyCallisto()
{
   m_symbol              = "";
   m_timeframe           = PERIOD_H1;
   m_magicNumber         = DEFAULT_MAGIC_CALLISTO;
   m_strategyType        = STRATEGY_CALLISTO;
   m_strategyName        = "CL";
   m_isInitialized       = false;
   m_ownsEngines         = false;
   m_ownsDetectors       = false;
   m_mockMode            = false;
   m_tradesTodayCount    = 0;
   m_lastTradeDay        = 0;
   m_lastTradedPoiTime   = 0;
   m_lastTradedPoiPrice  = 0.0;
   m_syntheticHtfCount   = 0;
   m_syntheticLtfCount   = 0;

   m_symbolHelper        = NULL;
   m_riskEngine          = NULL;
   m_execEngine          = NULL;
   m_posManager          = NULL;
   m_htfFvgDetector      = NULL;
   m_ltfFvgDetector      = NULL;
   m_structDetector      = NULL;

   m_config.SetDefaults();
   m_config.strategyType = STRATEGY_CALLISTO;
   m_config.magicNumber  = DEFAULT_MAGIC_CALLISTO;
   m_setup.Reset();

   ArrayResize(m_syntheticHtfRates, 0);
   ArrayResize(m_syntheticLtfRates, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CStrategyCallisto::~CStrategyCallisto()
{
   Deinit();
   if(m_ownsEngines)
   {
      if(CheckPointer(m_symbolHelper) == POINTER_DYNAMIC)    { delete m_symbolHelper;    m_symbolHelper = NULL; }
      if(CheckPointer(m_riskEngine) == POINTER_DYNAMIC)      { delete m_riskEngine;      m_riskEngine = NULL; }
      if(CheckPointer(m_execEngine) == POINTER_DYNAMIC)      { delete m_execEngine;      m_execEngine = NULL; }
      if(CheckPointer(m_posManager) == POINTER_DYNAMIC)      { delete m_posManager;      m_posManager = NULL; }
   }
   if(m_ownsDetectors)
   {
      if(CheckPointer(m_htfFvgDetector) == POINTER_DYNAMIC)  { delete m_htfFvgDetector;  m_htfFvgDetector = NULL; }
      if(CheckPointer(m_ltfFvgDetector) == POINTER_DYNAMIC)  { delete m_ltfFvgDetector;  m_ltfFvgDetector = NULL; }
      if(CheckPointer(m_structDetector) == POINTER_DYNAMIC)  { delete m_structDetector;  m_structDetector = NULL; }
   }
   ArrayFree(m_syntheticHtfRates);
   ArrayFree(m_syntheticLtfRates);
}

//+------------------------------------------------------------------+
//| Standard Initialization                                          |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::Init(const string symbol, ENUM_TIMEFRAMES timeframe)
{
   m_symbol    = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe = timeframe;
   m_config.callistoHtfTf = timeframe;

   if(!CBaseStrategy::Init(m_symbol, m_timeframe))
      return false;

   if(m_symbolHelper == NULL)
   {
      m_symbolHelper = new CSymbolHelper();
      m_symbolHelper.Init(m_symbol);
      m_ownsEngines = true;
   }

   if(m_execEngine == NULL)
   {
      m_execEngine = new CExecutionEngine();
      m_execEngine.Init(m_symbol, m_magicNumber, m_config.slippagePoints, m_symbolHelper);
   }

   if(m_riskEngine == NULL)
   {
      m_riskEngine = new CRiskEngine();
      m_riskEngine.Init(m_symbol, m_config.riskPercent, m_config.riskMode,
                        m_config.maxDailyLossPercent, (double)m_config.maxSpreadPips,
                        m_config.maxDailyTrades, m_symbolHelper);
   }

   if(m_posManager == NULL)
   {
      m_posManager = new CPositionManager();
      m_posManager.Init(m_symbol, m_magicNumber, m_execEngine, m_symbolHelper);
   }

   if(m_htfFvgDetector == NULL)
   {
      m_htfFvgDetector = new CFVGDetector();
      m_htfFvgDetector.Init(m_symbol, m_config.callistoHtfTf);
      m_ownsDetectors = true;
   }

   if(m_ltfFvgDetector == NULL)
   {
      m_ltfFvgDetector = new CFVGDetector();
      m_ltfFvgDetector.Init(m_symbol, m_config.callistoLtfTf);
      m_ownsDetectors = true;
   }

   if(m_structDetector == NULL)
   {
      m_structDetector = new CStructureDetector();
      m_structDetector.Init(m_symbol, m_config.callistoLtfTf);
      m_ownsDetectors = true;
   }

   m_isInitialized = true;
   LogState(StringFormat("CALLISTO Strategy initialized on %s HTF: %s LTF: %s (Magic: %I64u)",
            m_symbol, EnumToString(m_config.callistoHtfTf), EnumToString(m_config.callistoLtfTf), m_magicNumber));
   return true;
}

//+------------------------------------------------------------------+
//| Advanced Dependency Injection Initializer                        |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::InitWithEngines(const string symbol,
                                              ENUM_TIMEFRAMES htfTimeframe,
                                              const SStrategyConfig &config,
                                              CSymbolHelper *symHelper,
                                              CRiskEngine *riskEngine,
                                              CExecutionEngine *execEngine,
                                              CPositionManager *posMgr,
                                              CLogger *logger,
                                              CFVGDetector *htfFvgDet,
                                              CFVGDetector *ltfFvgDet,
                                              CStructureDetector *structDet)
{
   m_symbol        = (symbol == "" || symbol == NULL) ? _Symbol : symbol;
   m_timeframe     = htfTimeframe;
   m_config        = config;
   m_config.callistoHtfTf = htfTimeframe;
   m_magicNumber   = config.magicNumber;
   m_symbolHelper  = symHelper;
   m_riskEngine    = riskEngine;
   m_execEngine    = execEngine;
   m_posManager    = posMgr;
   m_logger        = logger;
   m_ownsEngines   = false;

   if(htfFvgDet != NULL) { m_htfFvgDetector = htfFvgDet; }
   else
   {
      m_htfFvgDetector = new CFVGDetector();
      m_htfFvgDetector.Init(m_symbol, m_config.callistoHtfTf);
      m_ownsDetectors = true;
   }

   if(ltfFvgDet != NULL) { m_ltfFvgDetector = ltfFvgDet; }
   else
   {
      m_ltfFvgDetector = new CFVGDetector();
      m_ltfFvgDetector.Init(m_symbol, m_config.callistoLtfTf);
      m_ownsDetectors = true;
   }

   if(structDet != NULL) { m_structDetector = structDet; }
   else
   {
      m_structDetector = new CStructureDetector();
      m_structDetector.Init(m_symbol, m_config.callistoLtfTf);
      m_ownsDetectors = true;
   }

   if(m_stateMachine != NULL)
   {
      m_stateMachine.Init(m_logger, m_strategyName, EA_STATE_IDLE);
   }

   m_isInitialized = true;
   LogState(StringFormat("CALLISTO Strategy initialized via DI on %s HTF: %s LTF: %s (Magic: %I64u)",
            m_symbol, EnumToString(m_config.callistoHtfTf), EnumToString(m_config.callistoLtfTf), m_magicNumber));
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::Deinit()
{
   CBaseStrategy::Deinit();
   m_setup.Reset();
   m_lastSignal.Clear();
}

//+------------------------------------------------------------------+
//| Set Mock Mode for Offline Deterministic Testing                  |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::SetMockMode(bool enabled)
{
   m_mockMode = enabled;
   if(m_execEngine != NULL) m_execEngine.SetMockExecutionMode(enabled);
   if(m_posManager != NULL) m_posManager.SetMockMode(enabled);
}

//+------------------------------------------------------------------+
//| Set Synthetic HTF Rates for Deterministic Test Evaluation        |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::SetSyntheticHtfRates(const MqlRates &rates[], int count)
{
   m_syntheticHtfCount = count;
   ArrayResize(m_syntheticHtfRates, count);
   for(int i = 0; i < count; i++)
      m_syntheticHtfRates[i] = rates[i];
}

//+------------------------------------------------------------------+
//| Set Synthetic LTF Rates for Deterministic Test Evaluation        |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::SetSyntheticLtfRates(const MqlRates &rates[], int count)
{
   m_syntheticLtfCount = count;
   ArrayResize(m_syntheticLtfRates, count);
   for(int i = 0; i < count; i++)
      m_syntheticLtfRates[i] = rates[i];
}

//+------------------------------------------------------------------+
//| Check and Reset Daily Trade Limit at Midnight                    |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::CheckDailyTradeReset(datetime currentBarTime)
{
   if(currentBarTime <= 0) return;

   MqlDateTime dtCurrent, dtLast;
   TimeToStruct(currentBarTime, dtCurrent);
   TimeToStruct(m_lastTradeDay, dtLast);

   if(m_lastTradeDay == 0 || dtCurrent.day != dtLast.day || dtCurrent.mon != dtLast.mon || dtCurrent.year != dtLast.year)
   {
      m_tradesTodayCount = 0;
      m_lastTradeDay = currentBarTime;
   }
}

//+------------------------------------------------------------------+
//| OnTick Event Handler                                             |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::OnTickHandler()
{
   if(!m_isInitialized)
      return;

   if(IsNewBar(m_config.callistoLtfTf))
   {
      OnBarHandler(m_config.callistoLtfTf);
   }

   ENUM_EA_STATE state = GetState();
   if(state == EA_STATE_MANAGING)
   {
      ManageOpenPositions();
   }
}

//+------------------------------------------------------------------+
//| OnBar Event Handler (PERIOD_H1 / LTF Guard)                      |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::OnBarHandler(ENUM_TIMEFRAMES tf)
{
   if(!m_isInitialized)
      return;

   if(tf != m_config.callistoLtfTf && tf != m_config.callistoHtfTf && tf != m_timeframe)
      return;

   datetime barTime = (m_symbolHelper != NULL) ? m_symbolHelper.GetTickTime() : TimeCurrent();
   CheckDailyTradeReset(barTime);

   ENUM_EA_STATE state = GetState();
   if(state == EA_STATE_IDLE || state == EA_STATE_ANALYSING ||
      state == EA_STATE_SETUP_FOUND || state == EA_STATE_WAITING_FOR_CONFIRMATION_OR_TAP)
   {
      EvaluateSetup();

      if(GetState() == EA_STATE_ENTRY_READY)
      {
         ExecuteCurrentSignal();
      }
   }
   else if(state == EA_STATE_MANAGING)
   {
      ManageOpenPositions();
   }
}

//+------------------------------------------------------------------+
//| Evaluate Market Setup from Live Chart Data                       |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::EvaluateSetup()
{
   if(!m_isInitialized || m_htfFvgDetector == NULL || m_ltfFvgDetector == NULL || m_structDetector == NULL)
      return;

   if(m_config.callistoUseSessionFilter)
   {
      if(!CSessionFilter::IsInsideGmtTradingWindow(m_config.callistoSessionStartGmt, m_config.callistoSessionEndGmt))
         return;
   }

   if(m_mockMode && m_syntheticHtfCount >= 5 && m_syntheticLtfCount >= 5)
   {
      EvaluateSetupFromRates(m_syntheticHtfRates, m_syntheticHtfCount,
                             m_syntheticLtfRates, m_syntheticLtfCount);
      return;
   }

   MqlRates htfRates[];
   ArraySetAsSeries(htfRates, true);
   int copiedHtf = CopyRates(m_symbol, m_config.callistoHtfTf, 0, 150, htfRates);
   if(copiedHtf < 5) return;

   MqlRates ltfRates[];
   ArraySetAsSeries(ltfRates, true);
   int copiedLtf = CopyRates(m_symbol, m_config.callistoLtfTf, 0, 100, ltfRates);
   if(copiedLtf < 5) return;

   double currentPrice = (m_symbolHelper != NULL) ? m_symbolHelper.GetBid() : ltfRates[0].close;
   EvaluateSetupFromRates(htfRates, copiedHtf, ltfRates, copiedLtf, currentPrice);
}

//+------------------------------------------------------------------+
//| Evaluate Setup from Rates Arrays (Public Baseline Placeholder)   |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::EvaluateSetupFromRates(const MqlRates &htfRates[], int htfTotal,
                                                     const MqlRates &ltfRates[], int ltfTotal,
                                                     double currentPrice)
{
   if(htfTotal < 5 || ltfTotal < 5)
      return false;

   ENUM_EA_STATE currentState = GetState();
   if(currentState == EA_STATE_EXECUTED || currentState == EA_STATE_MANAGING)
      return false;

   if(currentPrice <= 0.0)
      currentPrice = ltfRates[0].close;

   CheckDailyTradeReset(ltfRates[0].time);

   if(m_tradesTodayCount >= m_config.maxDailyTrades)
   {
      m_setup.Reset();
      m_lastSignal.Clear();
      return false;
   }

   if(currentState == EA_STATE_IDLE && m_stateMachine != NULL)
      m_stateMachine.TransitionTo(EA_STATE_ANALYSING, "Scanning HTF POIs (Baseline)");

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   // Public baseline placeholder: scans structurally without emitting live proprietary signals.
   if(!ScanHtfPOI(htfRates, htfTotal, currentPrice, m_setup))
   {
      m_setup.Reset();
      m_lastSignal.Clear();
      return false;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Scan HTF Rates for Active POIs (Redacted Alpha Stub)             |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::ScanHtfPOI(const MqlRates &htfRates[], int htfTotal, double currentPrice, SCallistoSetup &outSetup)
{
   outSetup.Reset();
   if(htfTotal < 5 || m_htfFvgDetector == NULL || currentPrice <= 0.0)
      return false;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   return (htfRates[0].time > 0 && false);
}

//+------------------------------------------------------------------+
//| Check POI Tap (Redacted Alpha Stub)                              |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::CheckPOITap(double currentPrice, SCallistoSetup &inOutSetup)
{
   if(!inOutSetup.isValid || currentPrice <= 0.0)
      return false;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   return false;
}

//+------------------------------------------------------------------+
//| Dispatch LTF Confirmation Mode                                   |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::CheckLtfConfirmation(const MqlRates &ltfRates[], int ltfTotal, SCallistoSetup &inOutSetup)
{
   if(!inOutSetup.isTapped || ltfTotal < 3)
      return false;

   switch(inOutSetup.confirmMode)
   {
      case CONFIRM_MODE_CHOCH:     return EvaluateChochConfirmation(ltfRates, ltfTotal, inOutSetup);
      case CONFIRM_MODE_IFVG:      return EvaluateIfvgConfirmation(ltfRates, ltfTotal, inOutSetup);
      case CONFIRM_MODE_ENGULFING: return EvaluateEngulfingConfirmation(ltfRates, ltfTotal, inOutSetup);
      default:                     return EvaluateChochConfirmation(ltfRates, ltfTotal, inOutSetup);
   }
}

//+------------------------------------------------------------------+
//| Mode 1: LTF CHoCH Confirmation (Redacted Alpha Stub)             |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::EvaluateChochConfirmation(const MqlRates &ltfRates[], int ltfTotal, SCallistoSetup &inOutSetup)
{
   if(m_structDetector == NULL || ltfTotal < 3 || !inOutSetup.isValid)
      return false;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   return (ltfRates[0].time > 0 && false);
}

//+------------------------------------------------------------------+
//| Mode 2: LTF iFVG Confirmation (Redacted Alpha Stub)              |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::EvaluateIfvgConfirmation(const MqlRates &ltfRates[], int ltfTotal, SCallistoSetup &inOutSetup)
{
   if(m_ltfFvgDetector == NULL || ltfTotal < 3 || !inOutSetup.isValid)
      return false;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   return (ltfRates[0].time > 0 && false);
}

//+------------------------------------------------------------------+
//| Mode 3: LTF Engulfing Confirmation (Redacted Alpha Stub)         |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::EvaluateEngulfingConfirmation(const MqlRates &ltfRates[], int ltfTotal, SCallistoSetup &inOutSetup)
{
   if(m_structDetector == NULL || ltfTotal < 3 || !inOutSetup.isValid)
      return false;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   return (ltfRates[0].time > 0 && false);
}

//+------------------------------------------------------------------+
//| Build Valid STradeSignal (Public Baseline Placeholder)           |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::BuildSignal(const SCallistoSetup &setup, STradeSignal &outSignal)
{
   outSignal.Clear();
   if(!setup.isValid || !setup.isTapped || !setup.isConfirmed || m_symbolHelper == NULL)
      return false;

   // [PROPRIETARY ALPHA REDACTED IN PUBLIC MIRROR — Live Signal Weights & Regime Filters Maintained in Private Production Vault]
   double slDist = m_symbolHelper.PipToPrice(m_config.callistoSlPips);
   double tpDist = m_symbolHelper.PipToPrice(m_config.callistoTpPips);
   outSignal.type             = setup.isBuy ? SIGNAL_BUY : SIGNAL_SELL;
   outSignal.strategy         = STRATEGY_CALLISTO;
   outSignal.symbol           = m_symbol;
   outSignal.timestamp        = TimeCurrent();
   outSignal.entryPrice       = setup.isBuy ? m_symbolHelper.GetAsk() : m_symbolHelper.GetBid();
   outSignal.stopLossPrice    = setup.isBuy ? (outSignal.entryPrice - slDist) : (outSignal.entryPrice + slDist);
   outSignal.takeProfit1Price = setup.isBuy ? (outSignal.entryPrice + tpDist) : (outSignal.entryPrice - tpDist);
   outSignal.takeProfit2Price = 0.0;
   outSignal.isDualPosition   = m_config.enableTwinPositions || (m_config.enableDoublePosition && m_config.callistoRunnerEnabled);
   outSignal.riskAmountOrPct  = (m_config.riskMode == RISK_MODE_FIXED_LOT) ? m_config.fixedLotSize : m_config.riskPercent;
   outSignal.magicNumber      = m_magicNumber;
   outSignal.setupDescription = "CL Public Baseline Placeholder";

   return ValidateSignal(outSignal);
}

//+------------------------------------------------------------------+
//| Execute Validated Signal through Execution Engine                |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::ExecuteCurrentSignal()
{
   if(GetState() != EA_STATE_ENTRY_READY || !m_lastSignal.IsValid())
   {
      LogState("ExecuteCurrentSignal: State is not ENTRY_READY or signal invalid.");
      return false;
   }

   if(m_riskEngine == NULL || m_execEngine == NULL || m_posManager == NULL || m_symbolHelper == NULL)
   {
      LogState("ExecuteCurrentSignal: Required engine collaborators are NULL.");
      return false;
   }

   // 1. Check Daily Trade Execution Limit
   if(m_tradesTodayCount >= m_config.maxDailyTrades)
   {
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Daily Trade Limit Reached");
      m_lastSignal.Clear();
      return false;
   }

   // 2. Safety Filters & Trading Permission Verification
   string denyReason;
   if(!m_riskEngine.IsTradingAllowed(denyReason))
   {
      LogState(StringFormat("Execution BLOCKED by RiskEngine: %s", denyReason));
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "RiskEngine Guard Trip");
      m_lastSignal.Clear();
      return false;
   }

   // 3. Dynamic Risk & Lot Sizing Calculation
   double lot1 = 0.0, lot2 = 0.0;
   if(!m_riskEngine.CalculateLotSize(m_lastSignal.entryPrice, m_lastSignal.stopLossPrice, lot1, lot2, m_lastSignal.isDualPosition, m_lastSignal.riskAmountOrPct))
   {
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Lot Size Calc Failure");
      m_lastSignal.Clear();
      return false;
   }

   ENUM_ORDER_TYPE orderType = (m_lastSignal.type == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   // 4. Margin Pre-Check
   if(!m_riskEngine.CheckMargin(orderType, lot1 + lot2, denyReason))
   {
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Insufficient Margin");
      m_lastSignal.Clear();
      return false;
   }

   // 4.1 Cross-chart execution mutex lock
   if(!m_riskEngine.AcquireExecutionLock(3))
   {
      LogState("Execution BLOCKED: Another chart instance is executing orders on this symbol. Waiting for lock release...");
      return false;
   }

   // 5. Dispatch Order(s)
   m_execEngine.SetMagicNumber(m_magicNumber);
   ulong ticket1 = 0, ticket2 = 0;
   bool executed = false;

   if(m_lastSignal.isDualPosition && lot2 > 0.0)
   {
      executed = m_execEngine.ExecuteDualPositionOrder(orderType, lot1, lot2,
                                                       m_lastSignal.stopLossPrice,
                                                       m_lastSignal.takeProfit1Price,
                                                       m_lastSignal.takeProfit2Price,
                                                       "CL", ticket1, ticket2);
   }
   else
   {
      executed = m_execEngine.ExecuteMarketOrder(orderType, lot1,
                                                 m_lastSignal.stopLossPrice,
                                                 m_lastSignal.takeProfit1Price,
                                                 "CL", ticket1);
   }

   m_riskEngine.ReleaseExecutionLock();

   if(!executed || ticket1 == 0)
   {
      m_stateMachine.TransitionTo(EA_STATE_IDLE, "Execution Engine Failure");
      m_lastSignal.Clear();
      return false;
   }

   m_tradesTodayCount++;
   m_lastTradedPoiTime  = TimeCurrent();
   m_lastTradedPoiPrice = m_setup.htfPoiZone.midPrice;

   m_posManager.RegisterPositions(ticket1, ticket2, STRATEGY_CALLISTO, orderType,
                                  m_lastSignal.entryPrice, m_lastSignal.stopLossPrice,
                                  m_lastSignal.takeProfit1Price);

   m_positionInfo.ticket1            = ticket1;
   m_positionInfo.ticket2            = ticket2;
   m_positionInfo.strategy           = STRATEGY_CALLISTO;
   m_positionInfo.symbol             = m_symbol;
   m_positionInfo.positionType       = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   m_positionInfo.openPrice1         = m_lastSignal.entryPrice;
   m_positionInfo.openPrice2         = m_lastSignal.entryPrice;
   m_positionInfo.initialLot1        = lot1;
   m_positionInfo.initialLot2        = lot2;
   m_positionInfo.currentSL1         = m_lastSignal.stopLossPrice;
   m_positionInfo.currentSL2         = m_lastSignal.stopLossPrice;
   m_positionInfo.currentTP1         = m_lastSignal.takeProfit1Price;
   m_positionInfo.currentTP2         = 0.0;
   m_positionInfo.openTime           = TimeCurrent();
   m_positionInfo.isPosition1Closed  = false;
   m_positionInfo.isPosition2Closed  = (ticket2 == 0);
   m_positionInfo.isBreakEvenApplied = false;
   m_positionInfo.comment            = "CL";

   m_stateMachine.TransitionTo(EA_STATE_EXECUTED, "Orders Filled");
   m_stateMachine.TransitionTo(EA_STATE_MANAGING, "Managing Active Positions");
   return true;
}

//+------------------------------------------------------------------+
//| Manage Open Positions (Live Tick Mode)                           |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::ManageOpenPositions()
{
   if(!m_isInitialized || m_posManager == NULL)
      return;

   m_posManager.ApplyActiveTrailing(m_config);
   m_posManager.UpdatePositionState(m_config.remmyBeBufferPips);

   if(m_posManager.GetActiveTicketCount() == 0)
   {
      m_positionInfo.isPosition1Closed = true;
      m_positionInfo.isPosition2Closed = true;

      if(GetState() == EA_STATE_MANAGING)
      {
         m_stateMachine.TransitionTo(EA_STATE_CLOSED, "All Positions Terminated");
         m_stateMachine.TransitionTo(EA_STATE_IDLE, "Ready for Next Cycle");
      }
      m_setup.Reset();
      m_lastSignal.Clear();
   }
}

//+------------------------------------------------------------------+
//| Manage Open Positions from Synthetic Rates (Offline Mode)        |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::ManageOpenPositionsFromRates(const MqlRates &rates[], int totalRates)
{
   if(!m_isInitialized || m_posManager == NULL || totalRates < 5)
      return;

   m_posManager.UpdatePositionState(m_config.remmyBeBufferPips);

   if(m_posManager.GetActiveTicketCount() == 0)
   {
      m_positionInfo.isPosition1Closed = true;
      m_positionInfo.isPosition2Closed = true;

      if(GetState() == EA_STATE_MANAGING)
      {
         m_stateMachine.TransitionTo(EA_STATE_CLOSED, "All Positions Terminated");
         m_stateMachine.TransitionTo(EA_STATE_IDLE, "Ready for Next Cycle");
      }
      m_setup.Reset();
      m_lastSignal.Clear();
   }
}

//+------------------------------------------------------------------+
//| Retrieve Active Trade Signals                                    |
//+------------------------------------------------------------------+
inline bool CStrategyCallisto::GetTradeSignals(STradeSignal &outSignal)
{
   return CBaseStrategy::GetTradeSignals(outSignal);
}

//+------------------------------------------------------------------+
//| Reset Strategy Internal State                                    |
//+------------------------------------------------------------------+
inline void CStrategyCallisto::Reset()
{
   CBaseStrategy::Reset();
   m_setup.Reset();
   m_syntheticHtfCount = 0;
   m_syntheticLtfCount = 0;
   ArrayResize(m_syntheticHtfRates, 0);
   ArrayResize(m_syntheticLtfRates, 0);
}

//+------------------------------------------------------------------+
//| Generate Strategy Telemetry Status String                        |
//+------------------------------------------------------------------+
inline string CStrategyCallisto::GetStatusString()
{
   return StringFormat("CL | State: %s | TF: H1/M5 | DailyTrades: %d/%d | ActiveTickets: %d",
                       (m_stateMachine != NULL) ? m_stateMachine.GetCurrentStateName() : "N/A",
                       m_tradesTodayCount, m_config.maxDailyTrades,
                       (m_posManager != NULL) ? m_posManager.GetActiveTicketCount() : 0);
}

#endif // LEGSTECH_STRATEGIES_STRATEGYCALLISTO_MQH
