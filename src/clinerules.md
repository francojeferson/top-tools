# ClineRules Instructions

This document provides a categorized overview of all Cline rules defined in the
`src/clinerules/` directory. It serves as a quick reference for understanding
the scope and purpose of each rule.

## Categories

### Core Behaviors

Rules related to Cline's fundamental operational protocols and identity.

- [`AGENTS`](./clinerules/AGENTS.md): Behavioral guidelines to reduce common
  LLM coding mistakes. Covers core behavior, simplicity, surgical changes,
  goal-driven execution, baby steps methodology, reasoning rules, language
  rules, challenge mode, format constraints, banned output patterns, and
  tool failure recovery.
  `['core-behavior', 'coding-guidelines', 'simplicity', 'surgical-changes',
  'baby-steps', 'reasoning', 'language-rules']`

### Cognitive Framework

Rules governing internal cognitive state and attention management.

- [`WFGY`](./clinerules/WFGY.md): WFGY Core Flagship v2.0. Defines the
  similarity/tension metric (delta_s), zone classifications (safe, transit,
  risk, danger), memory triggers, coupler mechanics with hysteresis,
  progression guards, BBAM attention rebalancing, and lambda observation
  states (convergent, recursive, divergent, chaotic).
  `['cognitive-framework', 'attention-management', 'similarity-metric',
  'memory-system', 'state-machine']`

---

## Usage

These rules are loaded automatically when working in this workspace. They
complement the global `.clinerules/` configuration and apply to all tasks
within this project.

### Key Principles from AGENTS.md

- Think before coding. State assumptions explicitly.
- Simplicity first. Minimum code that solves the problem.
- Surgical changes. Touch only what you must.
- Goal-driven execution. Define success criteria and verify.
- Baby steps. One atomic change at a time, validated before proceeding.
- Read the full file before editing. Never change code you have not read.
- Tool failure recovery: stop and diagnose, never retry blindly.

### Key Parameters from WFGY.md

- Zones: safe (< 0.40), transit (0.40-0.60), risk (0.60-0.85), danger (> 0.85)
- Defaults: B_c=0.85, gamma=0.618, theta_c=0.75, zeta_min=0.10
- Coupler output: W_c = clip(B_s*P + Phi, -theta_c, +theta_c)
- BBPF bridge allowed only if delta_s decreases AND W_c < 0.5*theta_c

---

## File Structure

```
src/clinerules/
├── AGENTS.md    # Behavioral and coding guidelines
└── WFGY.md      # Cognitive framework and attention mechanics
```
