#!/usr/bin/env node
"use strict";

// session-start-tap.js — Claude Code SessionStart hook
//
// Tracks active sessions in active-sessions.json for cross-session awareness.
// Prunes stale entries (dead PIDs, entries older than 24h).
//
// Security hardening:
//   - Symlink-safe writes (refuse reparse points, verify parent under HOME)
//   - Size-capped reads
//   - Strict field validation

const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const CLAUDE_DIR = process.env.CLAUDE_CONFIG_DIR || path.join(HOME, '.claude');
const MANAGER_DIR = path.join(CLAUDE_DIR, '.claude-manager');
const SESSIONS_FILE = path.join(MANAGER_DIR, 'active-sessions.json');

const MAX_FILE_SIZE = 64 * 1024; // 64KB cap on sessions file
const MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24h

function safeString(v) {
  return typeof v === 'string' ? v.slice(0, 512) : '';
}

function readStdin() {
  return new Promise(resolve => {
    let buf = '';
    process.stdin.setEncoding('utf-8');
    process.stdin.on('data', chunk => { buf += chunk; });
    process.stdin.on('end', () => {
      if (!buf.trim()) { resolve(null); return; }
      try { resolve(JSON.parse(buf)); } catch { resolve(null); }
    });
    process.stdin.on('error', () => resolve(null));
  });
}

function isAlive(pid) {
  try { process.kill(pid, 0); return true; } catch { return false; }
}

function readSessions() {
  try {
    const st = fs.lstatSync(SESSIONS_FILE);
    if (st.isSymbolicLink()) return [];
    if (st.size > MAX_FILE_SIZE) return [];
    const raw = fs.readFileSync(SESSIONS_FILE, 'utf-8');
    const arr = JSON.parse(raw);
    if (!Array.isArray(arr)) return [];

    const now = Date.now();
    return arr.filter(entry => {
      if (!entry || typeof entry !== 'object') return false;
      if (typeof entry.sessionId !== 'string') return false;
      if (typeof entry.ppid !== 'number') return false;
      if (typeof entry.ts !== 'number') return false;
      if (now - entry.ts > MAX_AGE_MS) return false;
      return isAlive(entry.ppid);
    });
  } catch {
    return [];
  }
}

function safeWriteSessions(data) {
  try {
    fs.mkdirSync(MANAGER_DIR, { recursive: true });

    // Verify directory is under HOME (Windows ownership check)
    const realDir = fs.realpathSync(MANAGER_DIR);
    const normalizedReal = path.resolve(realDir).toLowerCase();
    const normalizedHome = path.resolve(HOME).toLowerCase();
    if (!normalizedReal.startsWith(normalizedHome + path.sep) && normalizedReal !== normalizedHome) {
      return;
    }

    // Refuse symlink target
    try {
      const st = fs.lstatSync(SESSIONS_FILE);
      if (st.isSymbolicLink()) return;
    } catch (e) {
      if (e.code !== 'ENOENT') return;
    }

    // Atomic write
    const tempPath = path.join(MANAGER_DIR, `active-sessions.${process.pid}.tmp`);
    const fd = fs.openSync(tempPath, fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL, 0o600);
    try {
      fs.writeSync(fd, JSON.stringify(data));
    } finally {
      fs.closeSync(fd);
    }
    fs.renameSync(tempPath, SESSIONS_FILE);
  } catch {
    // Silent fail
  }
}

async function main() {
  const input = await readStdin();
  if (!input) return;

  const sessionId = safeString(input.session_id);
  if (!sessionId) return;

  const sessions = readSessions().filter(s => s.sessionId !== sessionId);
  sessions.push({
    sessionId,
    ppid: process.ppid,
    cwd: safeString(input.cwd) || process.cwd(),
    transcriptPath: safeString(input.transcript_path),
    ts: Date.now()
  });

  safeWriteSessions(sessions);
}

main();
