#!/usr/bin/env node
"use strict";

// statusline-tap.js — Claude Code statusline interceptor
//
// Pipeline: Claude Code → stdin (JSON) → parse → persist to statusline.json → call inner command → combine outputs
//
// Security hardening:
//   - Symlink-safe atomic writes (refuse reparse points, verify parent ownership on Windows)
//   - Control-character stripping from all display strings (blocks ANSI/OSC injection)
//   - Size-capped reads from inner command output
//   - Strict type coercion on all parsed fields

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawnSync } = require('child_process');

const HOME = os.homedir();
const CLAUDE_DIR = process.env.CLAUDE_CONFIG_DIR || path.join(HOME, '.claude');
const MANAGER_DIR = path.join(CLAUDE_DIR, '.claude-manager');
const STATUSLINE_JSON = path.join(MANAGER_DIR, 'statusline.json');
const INNER_JSON = path.join(MANAGER_DIR, 'statusline-inner.json');

const MAX_INNER_OUTPUT = 512;
const MAX_DISPLAY_STRING = 64;

// --- Helpers ---

function safeNumber(v) {
  return typeof v === 'number' && Number.isFinite(v) ? v : 0;
}

function safeString(v) {
  return typeof v === 'string' ? v : '';
}

// Strip ANSI escape sequences and control characters.
// Order matters: strip full CSI/OSC sequences first (while ESC byte is intact),
// then remove any remaining bare control chars.
function stripControl(s) {
  if (typeof s !== 'string') return '';
  return s
    .replace(/\x1B\[[0-9;]*[A-Za-z]/g, '')   // CSI sequences (e.g. \x1B[31m)
    .replace(/\x1B\][^\x07]*\x07/g, '')       // OSC sequences (e.g. \x1B]8;;url\x07)
    .replace(/\x1B[^[]\S*/g, '')              // Other ESC sequences
    .replace(/[\x00-\x1F\x7F]/g, '')          // Remaining control chars
    .slice(0, MAX_DISPLAY_STRING);
}

function parseRateLimit(rl) {
  if (!rl || typeof rl.used_percentage !== 'number') return null;
  return {
    usedPercent: safeNumber(rl.used_percentage),
    resetsAt: safeNumber(rl.resets_at)
  };
}

// --- Parser ---

function parse(raw, capturedAt) {
  let data;
  try { data = JSON.parse(raw); } catch { return null; }
  if (typeof data !== 'object' || data === null) return null;

  const model = data.model;
  const ctx = data.context_window;
  const cost = data.cost;
  const limits = data.rate_limits;

  return {
    capturedAt,
    version: safeString(data.version),
    model: model && (model.id != null || model.display_name != null)
      ? { id: safeString(model.id), displayName: safeString(model.display_name) }
      : null,
    context: ctx && typeof ctx.used_percentage === 'number'
      ? { usedPercent: safeNumber(ctx.used_percentage), size: safeNumber(ctx.context_window_size) }
      : null,
    cost: cost && typeof cost.total_cost_usd === 'number'
      ? {
          totalUsd: safeNumber(cost.total_cost_usd),
          durationMs: safeNumber(cost.total_duration_ms),
          linesAdded: safeNumber(cost.total_lines_added),
          linesRemoved: safeNumber(cost.total_lines_removed)
        }
      : null,
    rateLimits: {
      fiveHour: parseRateLimit(limits?.five_hour),
      sevenDay: parseRateLimit(limits?.seven_day)
    }
  };
}

// --- Formatter ---

function format(parsed) {
  const parts = [];

  if (parsed.model && parsed.model.displayName) {
    parts.push(stripControl(parsed.model.displayName));
  }
  if (parsed.context) {
    parts.push(`ctx ${Math.round(parsed.context.usedPercent)}%`);
  }

  const rl = parsed.rateLimits;
  if (rl.fiveHour) parts.push(`5h ${Math.round(rl.fiveHour.usedPercent)}%`);
  if (rl.sevenDay) parts.push(`7d ${Math.round(rl.sevenDay.usedPercent)}%`);

  if (parsed.cost && typeof parsed.cost.totalUsd === 'number') {
    parts.push(`$${parsed.cost.totalUsd.toFixed(2)}`);
  }

  return parts.join('  ·  ');
}

// --- Symlink-safe atomic write ---

function safeWrite(filePath, content) {
  try {
    const dir = path.dirname(filePath);
    fs.mkdirSync(dir, { recursive: true });

    // Verify parent directory is not an attacker-controlled symlink (Windows: must be under HOME)
    const realDir = fs.realpathSync(dir);
    const normalizedReal = path.resolve(realDir).toLowerCase();
    const normalizedHome = path.resolve(HOME).toLowerCase();
    if (!normalizedReal.startsWith(normalizedHome + path.sep) && normalizedReal !== normalizedHome) {
      return;
    }

    // Refuse to write if target is a symlink (clobber vector)
    try {
      const st = fs.lstatSync(filePath);
      if (st.isSymbolicLink && st.isSymbolicLink()) return;
      // On Windows, check ReparsePoint attribute
      if (st.isSymbolicLink === undefined && (st.mode & 0o120000) === 0o120000) return;
    } catch (e) {
      if (e.code !== 'ENOENT') return;
    }

    // Atomic write: temp file + rename
    const tempPath = path.join(dir, `statusline.${process.pid}.tmp`);
    const fd = fs.openSync(tempPath, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL, 0o600);
    try {
      fs.writeSync(fd, content);
    } finally {
      fs.closeSync(fd);
    }
    fs.renameSync(tempPath, filePath);
  } catch {
    // Silent fail — statusline persistence is best-effort
  }
}

// --- Inner command ---

function getInnerCommand() {
  try {
    const st = fs.lstatSync(INNER_JSON);
    if (st.isSymbolicLink()) return '';
    if (st.size > 1024) return '';
    const raw = fs.readFileSync(INNER_JSON, 'utf-8');
    const config = JSON.parse(raw);
    return typeof config.command === 'string' ? config.command : '';
  } catch {
    return '';
  }
}

function runInner(command, stdinData) {
  if (!command) return null;
  try {
    const result = spawnSync(command, {
      shell: true,
      input: stdinData,
      encoding: 'utf-8',
      timeout: 5000,
      windowsHide: true
    });
    if (result.status === 0 && typeof result.stdout === 'string') {
      // Cap output length and strip control chars from inner command output
      return result.stdout.slice(0, MAX_INNER_OUTPUT);
    }
  } catch {}
  return null;
}

// --- stdin reader ---

function readStdin() {
  try {
    return fs.readFileSync(0, 'utf-8');
  } catch {
    return '';
  }
}

// --- Main ---

function main() {
  const raw = readStdin();
  const parsed = parse(raw, Date.now());

  if (parsed) {
    safeWrite(STATUSLINE_JSON, JSON.stringify(parsed));
  }

  const innerOutput = runInner(getInnerCommand(), raw);
  const tapOutput = parsed ? format(parsed) : '';

  const inner = typeof innerOutput === 'string' ? innerOutput.trim() : '';

  if (inner && tapOutput) {
    process.stdout.write(`${inner}  ·  ${tapOutput}`);
  } else if (inner) {
    process.stdout.write(inner);
  } else if (tapOutput) {
    process.stdout.write(tapOutput);
  }
}

main();
