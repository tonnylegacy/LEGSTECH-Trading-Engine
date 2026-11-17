# CLAUDE.md — LEGsTECH Quantitative Trading Engine (`MQL5`)

This file provides architectural context, build commands, and strict engineering invariants for **Claude Code** and autonomous coding agents working inside this repository.

## 1. Project Overview
- **System**: LEGsTECH Institutional Multi-Strategy MQL5 Expert Advisor (`LEGsTech_Master_V1.mq5`)
- **Primary Instrument**: `XAUUSD` (Gold)
- **Core Capabilities**:
  - Unified `STRATEGY_PORTFOLIO` orchestrating `STRATEGY_REMMY` (`PERIOD_M15`), `STRATEGY_CALLISTO` (`PERIOD_H1`/`PERIOD_M5`), and `STRATEGY_DB` (`PERIOD_M30`) from a single chart.
  - Atomic cross-chart execution mutex (`CRiskEngine::AcquireExecutionLock` / `ReleaseExecutionLock`) preventing concurrent `OrderSend` race conditions across chart threads.
  - Automated capital preservation (`CPositionManager`): Universal Break-Even (`+50 pips` trigger -> `Entry + 2 pips` lock), Dynamic Step Trailing Stop (`+30 pips` trigger, `20 pips` distance, `5 pips` step), and Daily Drawdown circuit breakers.
  - Interactive on-chart GUI (`CDashboard`) with live BE, Trailing, and Emergency Kill buttons.

## 2. Build & Verification Commands (Headless CLI)
Never rely on manual GUI clicks to compile MQL5. Always invoke `metaeditor64.exe` from the terminal and inspect the log for **`0 errors, 0 warnings`**:

```powershell
& "C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile:"Experts\LEGsTech_Master_V1.mq5" /inc:"." /log:"compile.log"
Get-Content compile.log
```

## 3. Strict Engineering & Risk Invariants
1. **Zero Compilation Warnings**: Every edit to `.mq5` or `.mqh` files must compile with `0 errors, 0 warnings`.
2. **Mandatory Execution Mutex**: Any new order dispatch path MUST acquire `m_riskEngine.AcquireExecutionLock(3)` before calling `CExecutionEngine` and MUST call `m_riskEngine.ReleaseExecutionLock()` on all exit paths.
3. **New-Bar Gating vs. Tick-Level Risk**:
   - Strategy signal evaluation (`EvaluateSetup`) runs strictly on closed-bar boundaries (`IsNewBar(m_timeframe)`).
   - Active position protection (`ManageOpenPositions` — Break-Even, Trailing Stop, Emergency Kill) runs tick-by-tick.
4. **Alpha Privacy in Public Mirror**: Never commit raw proprietary signal weights or production `.set` files into the public GitHub mirror. Keep entry weight formulas redacted inside `StrategyRemmy.mqh`, `StrategyCallisto.mqh`, and `StrategyDB.mqh` while preserving 100% compilable class contracts.
5. **Version Control Standard**: Never overwrite production baselines in-place without incrementing the version tag.
