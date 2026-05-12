#!/usr/bin/env node
/**
 * Cline Session Analysis Tool
 * Analyzes time allocation between memory bank work and actual development
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');

class CodeAnalysis {
  constructor({
    file_path,
    file_type,
    lines_of_code,
    complexity_score,
    has_error_handling,
    has_comprehensive_comments,
    has_modular_design,
    has_type_annotations,
    function_count,
    class_count,
    import_count,
  }) {
    this.file_path = file_path;
    this.file_type = file_type;
    this.lines_of_code = lines_of_code;
    this.complexity_score = complexity_score;
    this.has_error_handling = has_error_handling;
    this.has_comprehensive_comments = has_comprehensive_comments;
    this.has_modular_design = has_modular_design;
    this.has_type_annotations = has_type_annotations;
    this.function_count = function_count;
    this.class_count = class_count;
    this.import_count = import_count;
  }
}

class SessionMetrics {
  constructor({
    session_id,
    start_time,
    end_time,
    duration_minutes,
    memory_bank_time,
    task_management_time,
    project_code_time,
    config_time,
    tool_time,
    total_file_edits,
    memory_bank_files,
    project_files,
    api_cost,
    tokens_in,
    tokens_out,
    lines_of_code_added,
    files_created,
    files_modified,
    functions_added,
    code_analysis,
    output_based_value,
    time_based_value,
  }) {
    this.session_id = session_id;
    this.start_time = start_time;
    this.end_time = end_time;
    this.duration_minutes = duration_minutes;
    this.memory_bank_time = memory_bank_time;
    this.task_management_time = task_management_time;
    this.project_code_time = project_code_time;
    this.config_time = config_time;
    this.tool_time = tool_time;
    this.total_file_edits = total_file_edits;
    this.memory_bank_files = memory_bank_files;
    this.project_files = project_files;
    this.api_cost = api_cost;
    this.tokens_in = tokens_in;
    this.tokens_out = tokens_out;
    this.lines_of_code_added = lines_of_code_added;
    this.files_created = files_created;
    this.files_modified = files_modified;
    this.functions_added = functions_added;
    this.code_analysis = code_analysis;
    this.output_based_value = output_based_value;
    this.time_based_value = time_based_value;
  }
}

class ClineSessionAnalyzer {
  constructor(sessionsPath) {
    this.sessionsPath = path.resolve(sessionsPath);
    this.sessions = [];
  }

  categorizeFilePath(filePath) {
    const filePathLower = filePath.toLowerCase();
    const filename = path.basename(filePath).toLowerCase();

    if (
      (filename.startsWith('task') && filename.endsWith('.md')) ||
      filename === '_index.md' ||
      filePathLower.includes('/tasks/')
    ) {
      return 'task_management';
    } else if (filePathLower.includes('memory-bank')) {
      return 'memory_bank';
    } else if (
      [
        'cline_mcp_settings.json',
        '.clinerules',
        '.env',
        'pyproject.toml',
      ].some((config) => filePathLower.includes(config))
    ) {
      return 'config';
    } else if (
      ['.py', '.js', '.ts', '.tsx', '.jsx', '.css', '.html', '.sql', '.yaml', '.yml'].some(
        (ext) => filePathLower.endsWith(ext)
      )
    ) {
      return 'project_code';
    } else {
      return 'other';
    }
  }

  analyzeSessionTiming(uiMessages) {
    const categoryTimes = new Map();
    const setDefault = (key) => {
      if (!categoryTimes.has(key)) categoryTimes.set(key, 0);
    };

    for (let i = 0; i < uiMessages.length; i++) {
      const message = uiMessages[i];
      if (typeof message !== 'object' || message === null) continue;
      if (message.type !== 'say' || message.say !== 'tool') continue;

      const timestamp = message.ts || 0;
      if (typeof timestamp !== 'number') continue;

      const toolText = message.text || '';
      if (!toolText) continue;

      let filePath = null;
      if (toolText.includes('"path":')) {
        const match = toolText.match(/"path":\s*"([^"]+)"/);
        if (match) filePath = match[1];
      }
      if (!filePath) continue;

      let duration = 0;
      if (i + 1 < uiMessages.length) {
        const nextMessage = uiMessages[i + 1];
        if (typeof nextMessage === 'object' && nextMessage !== null) {
          const nextTimestamp = nextMessage.ts || timestamp;
          if (typeof nextTimestamp === 'number') {
            duration = (nextTimestamp - timestamp) / 1000.0;
          }
        }
      }

      const category = this.categorizeFilePath(filePath);
      if (category !== 'other' && duration >= 0) {
        setDefault(category);
        categoryTimes.set(category, categoryTimes.get(category) + duration);
      }
    }

    return Object.fromEntries(categoryTimes);
  }

  parseFinancialData(sessionDir) {
    let apiCost = 0.0;
    let tokensIn = 0;
    let tokensOut = 0;

    const uiMessagesFile = path.join(sessionDir, 'ui_messages.json');
    if (!fs.existsSync(uiMessagesFile)) return [apiCost, tokensIn, tokensOut];

    try {
      const content = fs.readFileSync(uiMessagesFile, 'utf-8').trim();
      if (!content) return [apiCost, tokensIn, tokensOut];

      let uiData;
      try {
        uiData = JSON.parse(content);
      } catch {
        uiData = this._parseStreamingJson(content);
      }

      if (!Array.isArray(uiData)) return [apiCost, tokensIn, tokensOut];

      for (const message of uiData) {
        if (
          typeof message === 'object' &&
          message !== null &&
          message.say === 'api_req_started'
        ) {
          const text = message.text;
          if (text) {
            try {
              const reqInfo = JSON.parse(text);
              const cost = reqInfo.cost || 0;
              if (typeof cost === 'number' && cost > 0) apiCost += cost;
              tokensIn += reqInfo.tokensIn || 0;
              tokensOut += reqInfo.tokensOut || 0;
            } catch {
              // skip malformed JSON
            }
          }
        }
      }
    } catch {
      // skip sessions with corrupted UI messages
    }

    return [apiCost, tokensIn, tokensOut];
  }

  parseCodeMetrics(uiMessages) {
    let linesAdded = 0;
    let filesCreated = 0;
    let filesModified = 0;
    let functionsAdded = 0;

    for (const message of uiMessages) {
      if (typeof message !== 'object' || message === null) continue;
      if (message.type !== 'say' || message.say !== 'tool') continue;

      const toolText = message.text || '';
      if (!toolText) continue;

      try {
        const toolData = JSON.parse(toolText);
        const toolName = toolData.tool || '';

        if (toolName === 'newFileCreated') filesCreated++;
        else if (toolName === 'editedExistingFile') filesModified++;

        if (
          ['writeToFile', 'replaceInFile', 'newFileCreated', 'editedExistingFile'].includes(
            toolName
          )
        ) {
          const content = toolData.content || '';
          if (content && typeof content === 'string') {
            const linesInContent = content ? content.split('\n').length : 0;
            linesAdded += linesInContent;
            functionsAdded +=
              (content.match(/def /g) || []).length +
              (content.match(/function /g) || []).length +
              (content.match(/class /g) || []).length;
          }
        }
      } catch {
        if (toolText.includes('createdNewFile')) filesCreated++;
        else if (toolText.includes('editedExistingFile')) filesModified++;
      }
    }

    return [linesAdded, filesCreated, filesModified, functionsAdded];
  }

  analyzeCodeComplexity(content, filePath) {
    const fileExt = path.extname(filePath).toLowerCase();

    let fileType;
    if (fileExt === '.py') fileType = 'python';
    else if (['.js', '.jsx'].includes(fileExt)) fileType = 'javascript';
    else if (['.ts', '.tsx'].includes(fileExt)) fileType = 'typescript';
    else if (fileExt === '.html') fileType = 'html';
    else if (fileExt === '.css') fileType = 'css';
    else if (fileExt === '.sql') fileType = 'sql';
    else fileType = 'other';

    const linesOfCode = content.split('\n').filter((line) => line.trim()).length;

    let complexityScore = 1.0;
    let functionCount = 0;
    let classCount = 0;
    let importCount = 0;

    if (fileType === 'python') {
      functionCount =
        (content.match(/def /g) || []).length + (content.match(/async def /g) || []).length;
      classCount = (content.match(/class /g) || []).length;
      importCount =
        (content.match(/import /g) || []).length + (content.match(/from /g) || []).length;
      complexityScore += (content.match(/if /g) || []).length * 0.1;
      complexityScore += (content.match(/for /g) || []).length * 0.1;
      complexityScore += (content.match(/while /g) || []).length * 0.1;
      complexityScore += (content.match(/try:/g) || []).length * 0.2;
      complexityScore += (content.match(/except/g) || []).length * 0.1;
    } else if (['javascript', 'typescript'].includes(fileType)) {
      functionCount =
        (content.match(/function /g) || []).length +
        (content.match(/=>/g) || []).length +
        (content.match(/async /g) || []).length;
      classCount = (content.match(/class /g) || []).length;
      importCount =
        (content.match(/import /g) || []).length + (content.match(/require\(/g) || []).length;
      complexityScore += (content.match(/if \(/g) || []).length * 0.1;
      complexityScore += (content.match(/for \(/g) || []).length * 0.1;
      complexityScore += (content.match(/while \(/g) || []).length * 0.1;
      complexityScore += (content.match(/try \{/g) || []).length * 0.2;
      complexityScore += (content.match(/catch/g) || []).length * 0.1;
    }

    const hasErrorHandling =
      content.toLowerCase().includes('try') ||
      content.toLowerCase().includes('except') ||
      content.toLowerCase().includes('catch');
    const hasComprehensiveComments =
      (content.match(/#/g) || []).length +
        (content.match(/\/\//g) || []).length +
        (content.match(/"""/g) || []).length >
      linesOfCode * 0.1;
    const hasModularDesign = functionCount > 2 || classCount > 0;
    const hasTypeAnnotations =
      content.includes(': ') && ['python', 'typescript'].includes(fileType);

    return new CodeAnalysis({
      file_path: filePath,
      file_type: fileType,
      lines_of_code: linesOfCode,
      complexity_score: Math.min(complexityScore, 5.0),
      has_error_handling: hasErrorHandling,
      has_comprehensive_comments: hasComprehensiveComments,
      has_modular_design: hasModularDesign,
      has_type_annotations: hasTypeAnnotations,
      function_count: functionCount,
      class_count: classCount,
      import_count: importCount,
    });
  }

  calculateOutputBasedValue(codeAnalysis) {
    if (!codeAnalysis || codeAnalysis.length === 0) return 0.0;

    let totalValue = 0.0;
    const baseRatePerLine = 0.5;
    const fileTypeMultipliers = {
      python: 1.5,
      typescript: 1.4,
      javascript: 1.3,
      sql: 1.4,
      html: 0.9,
      css: 0.8,
      other: 1.0,
    };

    for (const analysis of codeAnalysis) {
      const baseValue = analysis.lines_of_code * baseRatePerLine;
      const typeMultiplier = fileTypeMultipliers[analysis.file_type] || 1.0;
      const complexityMultiplier = 1.0 + (analysis.complexity_score - 1.0) * 0.3;
      let qualityMultiplier = 1.0;
      if (analysis.has_error_handling) qualityMultiplier += 0.2;
      if (analysis.has_comprehensive_comments) qualityMultiplier += 0.1;
      if (analysis.has_modular_design) qualityMultiplier += 0.1;
      if (analysis.has_type_annotations) qualityMultiplier += 0.1;

      totalValue += baseValue * typeMultiplier * complexityMultiplier * qualityMultiplier;
    }

    return totalValue;
  }

  _parseStreamingJson(content) {
    const messages = [];
    let idx = 0;

    while (idx < content.length) {
      const remaining = content.slice(idx).trim();
      if (!remaining) break;

      try {
        const obj = JSON.parse(remaining);
        if (Array.isArray(obj)) messages.push(...obj);
        else messages.push(obj);
        break;
      } catch {
        const nextBrace = remaining.indexOf('{', 1);
        const nextBracket = remaining.indexOf('[', 1);
        const nextJson = [nextBrace, nextBracket]
          .filter((pos) => pos > 0)
          .sort((a, b) => a - b)[0];
        if (nextJson === undefined) break;
        idx += content.slice(idx).indexOf(remaining[nextJson]);
      }
    }

    return messages;
  }

  parseSession(sessionDir) {
    try {
      const sessionId = path.basename(sessionDir);
      const uiMessagesFile = path.join(sessionDir, 'ui_messages.json');
      if (!fs.existsSync(uiMessagesFile)) return null;

      let uiMessages;
      try {
        const content = fs.readFileSync(uiMessagesFile, 'utf-8').trim();
        if (!content) return null;
        try {
          uiMessages = JSON.parse(content);
        } catch {
          uiMessages = this._parseStreamingJson(content);
          if (!uiMessages || uiMessages.length === 0) throw new Error('Failed to parse JSON');
        }
      } catch (e) {
        console.error(`JSON parsing error in session ${sessionId}: ${e.message.slice(0, 100)}...`);
        return null;
      }

      if (!Array.isArray(uiMessages) || uiMessages.length === 0) return null;

      const firstMessage = uiMessages.find((msg) => typeof msg === 'object' && msg !== null && 'ts' in msg);
      const lastMessage = [...uiMessages]
        .reverse()
        .find((msg) => typeof msg === 'object' && msg !== null && 'ts' in msg);

      if (!firstMessage || !lastMessage) return null;

      const startTime = new Date(firstMessage.ts);
      const endTime = new Date(lastMessage.ts);
      let durationMinutes = (endTime - startTime) / 60000;
      if (durationMinutes < 0) durationMinutes = 0;

      const categoryTimes = this.analyzeSessionTiming(uiMessages);

      const memoryBankFiles = [];
      const projectFiles = [];
      let totalEdits = 0;

      for (const message of uiMessages) {
        if (typeof message !== 'object' || message === null) continue;
        if (message.type !== 'say' || message.say !== 'tool') continue;

        const toolText = message.text || '';
        if (!toolText) continue;

        try {
          const toolData = JSON.parse(toolText);
          const toolName = toolData.tool || '';

          if (
            ['newFileCreated', 'editedExistingFile', 'writeToFile', 'replaceInFile'].includes(
              toolName
            )
          ) {
            totalEdits++;
            const filePath = toolData.path || '';
            if (filePath) {
              const category = this.categorizeFilePath(filePath);
              if (category === 'memory_bank') memoryBankFiles.push(filePath);
              else if (category === 'project_code') projectFiles.push(filePath);
            }
          }
        } catch {
          if (
            toolText.includes('editedExistingFile') ||
            toolText.includes('createdNewFile')
          ) {
            totalEdits++;
            const match = toolText.match(/"path":\s*"([^"]+)"/);
            if (match) {
              const filePath = match[1];
              const category = this.categorizeFilePath(filePath);
              if (category === 'memory_bank') memoryBankFiles.push(filePath);
              else if (category === 'project_code') projectFiles.push(filePath);
            }
          }
        }
      }

      const [apiCost, tokensIn, tokensOut] = this.parseFinancialData(sessionDir);
      const [linesAdded, filesCreated, filesModified, functionsAdded] =
        this.parseCodeMetrics(uiMessages);

      const codeAnalysis = [];
      for (const message of uiMessages) {
        if (
          typeof message !== 'object' ||
          message === null ||
          message.type !== 'say' ||
          message.say !== 'tool'
        )
          continue;

        const toolText = message.text || '';
        try {
          const toolData = JSON.parse(toolText);
          const toolName = toolData.tool || '';

          if (
            ['writeToFile', 'replaceInFile', 'newFileCreated', 'editedExistingFile'].includes(
              toolName
            )
          ) {
            const filePath = toolData.path || '';
            const content = toolData.content || '';
            if (
              filePath &&
              content &&
              this.categorizeFilePath(filePath) === 'project_code'
            ) {
              const fileExt = path.extname(filePath).toLowerCase();
              if (
                ['.py', '.js', '.jsx', '.ts', '.tsx', '.html', '.css', '.sql'].includes(
                  fileExt
                )
              ) {
                codeAnalysis.push(this.analyzeCodeComplexity(content, filePath));
              }
            }
          }
        } catch {
          continue;
        }
      }

      const outputBasedValue = this.calculateOutputBasedValue(codeAnalysis);
      const totalHours = durationMinutes / 60.0;
      const timeBasedValue = totalHours * 80;

      return new SessionMetrics({
        session_id: sessionId,
        start_time: startTime,
        end_time: endTime,
        duration_minutes: durationMinutes,
        memory_bank_time: (categoryTimes.memory_bank || 0) / 60.0,
        task_management_time: (categoryTimes.task_management || 0) / 60.0,
        project_code_time: (categoryTimes.project_code || 0) / 60.0,
        config_time: (categoryTimes.config || 0) / 60.0,
        tool_time: Object.values(categoryTimes).reduce((a, b) => a + b, 0) / 60.0,
        total_file_edits: totalEdits,
        memory_bank_files: memoryBankFiles,
        project_files: projectFiles,
        api_cost: apiCost,
        tokens_in: tokensIn,
        tokens_out: tokensOut,
        lines_of_code_added: linesAdded,
        files_created: filesCreated,
        files_modified: filesModified,
        functions_added: functionsAdded,
        code_analysis: codeAnalysis,
        output_based_value: outputBasedValue,
        time_based_value: timeBasedValue,
      });
    } catch (e) {
      console.error(`Error parsing session ${path.basename(sessionDir)}: ${e.message}`);
      return null;
    }
  }

  analyzeAllSessions(limit = null) {
    if (!fs.existsSync(this.sessionsPath)) {
      console.error(`Sessions path does not exist: ${this.sessionsPath}`);
      return;
    }

    const sessionDirs = fs
      .readdirSync(this.sessionsPath)
      .map((name) => path.join(this.sessionsPath, name))
      .filter((dir) => fs.statSync(dir).isDirectory())
      .sort((a, b) => path.basename(b).localeCompare(path.basename(a)));

    const limitedDirs = limit ? sessionDirs.slice(0, limit) : sessionDirs;
    console.log(`Analyzing ${limitedDirs.length} sessions...`);

    for (const sessionDir of limitedDirs) {
      const metrics = this.parseSession(sessionDir);
      if (metrics && metrics.duration_minutes > 1) {
        this.sessions.push(metrics);
      }
    }

    console.log(`Successfully parsed ${this.sessions.length} sessions`);
  }

  generateReport() {
    if (this.sessions.length === 0) {
      console.log('No sessions to analyze!');
      return;
    }

    const totalDuration = this.sessions.reduce((sum, s) => sum + s.duration_minutes, 0);
    const totalMemoryBank = this.sessions.reduce((sum, s) => sum + s.memory_bank_time, 0);
    const totalTaskMgmt = this.sessions.reduce((sum, s) => sum + s.task_management_time, 0);
    const totalProjectCode = this.sessions.reduce((sum, s) => sum + s.project_code_time, 0);
    const totalConfig = this.sessions.reduce((sum, s) => sum + s.config_time, 0);
    const totalToolTime = this.sessions.reduce((sum, s) => sum + s.tool_time, 0);

    console.log('\n' + '='.repeat(60));
    console.log('CLINE SESSION ANALYSIS REPORT');
    console.log('='.repeat(60));

    console.log('\nOVERALL STATISTICS');
    console.log(`Total Sessions Analyzed: ${this.sessions.length}`);
    console.log(`Total Time Spent: ${totalDuration.toFixed(1)} minutes (${(totalDuration / 60).toFixed(1)} hours)`);
    console.log(`Average Session Length: ${(totalDuration / this.sessions.length).toFixed(1)} minutes`);

    console.log('\nTIME ALLOCATION BREAKDOWN');
    if (totalToolTime > 0) {
      const memoryBankPct = (totalMemoryBank / totalToolTime) * 100;
      const taskMgmtPct = (totalTaskMgmt / totalToolTime) * 100;
      const projectCodePct = (totalProjectCode / totalToolTime) * 100;
      const configPct = (totalConfig / totalToolTime) * 100;

      console.log(`Memory Bank Work:     ${totalMemoryBank.toFixed(1)}m (${memoryBankPct.toFixed(1)}%)`);
      console.log(`Task Management:      ${totalTaskMgmt.toFixed(1)}m (${taskMgmtPct.toFixed(1)}%)`);
      console.log(`Project Code:         ${totalProjectCode.toFixed(1)}m (${projectCodePct.toFixed(1)}%)`);
      console.log(`Configuration:        ${totalConfig.toFixed(1)}m (${configPct.toFixed(1)}%)`);
      console.log(`Total Tracked Time:   ${totalToolTime.toFixed(1)}m`);

      const overheadTime = totalMemoryBank + totalTaskMgmt + totalConfig;
      const overheadPct = (overheadTime / totalToolTime) * 100;

      console.log('\nKEY INSIGHTS');
      console.log(`Memory Bank Investment: ${memoryBankPct.toFixed(1)}% of tracked time`);
      console.log(`Total Overhead (Memory Bank + Tasks + Config): ${overheadPct.toFixed(1)}%`);
      console.log(`Actual Development Time: ${projectCodePct.toFixed(1)}%`);
      console.log(
        `Development Efficiency Ratio: ${overheadPct > 0 ? (projectCodePct / overheadPct).toFixed(2) + ':1' : 'N/A'}`
      );
    }

    const allMemoryBankFiles = [];
    const allProjectFiles = [];
    for (const session of this.sessions) {
      allMemoryBankFiles.push(...session.memory_bank_files);
      allProjectFiles.push(...session.project_files);
    }

    if (allMemoryBankFiles.length > 0) {
      console.log('\nMEMORY BANK FILE ACTIVITY');
      const counts = new Map();
      for (const f of allMemoryBankFiles) {
        const name = path.basename(f);
        counts.set(name, (counts.get(name) || 0) + 1);
      }
      const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5);
      for (const [filename, count] of sorted) {
        console.log(`  ${filename}: ${count} edits`);
      }
    }

    this.generateFinancialReport();

    console.log('\nRECENT SESSION TRENDS (Last 10 sessions)');
    const recentSessions = this.sessions.slice(0, 10);
    for (const session of recentSessions) {
      if (session.tool_time > 0) {
        const mbPct = (session.memory_bank_time / session.tool_time) * 100;
        const codePct = (session.project_code_time / session.tool_time) * 100;
        const dateStr = session.start_time.toLocaleString('en-US', {
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
        });
        console.log(
          `  ${dateStr}: Memory Bank ${mbPct.toFixed(0)}%, Code ${codePct.toFixed(0)}% (${session.duration_minutes.toFixed(0)}m)`
        );
      }
    }
  }

  generateFinancialReport() {
    const totalApiCost = this.sessions.reduce((sum, s) => sum + s.api_cost, 0);
    const totalTokensIn = this.sessions.reduce((sum, s) => sum + s.tokens_in, 0);
    const totalTokensOut = this.sessions.reduce((sum, s) => sum + s.tokens_out, 0);
    const totalLinesAdded = this.sessions.reduce((sum, s) => sum + s.lines_of_code_added, 0);
    const totalFilesCreated = this.sessions.reduce((sum, s) => sum + s.files_created, 0);
    const totalFilesModified = this.sessions.reduce((sum, s) => sum + s.files_modified, 0);
    const totalFunctionsAdded = this.sessions.reduce((sum, s) => sum + s.functions_added, 0);

    const totalHours = this.sessions.reduce((sum, s) => sum + s.duration_minutes, 0) / 60.0;
    const devHours = totalHours;
    const memoryBankHours = this.sessions.reduce((sum, s) => sum + s.memory_bank_time, 0) / 60.0;
    const taskMgmtHours = this.sessions.reduce((sum, s) => sum + s.task_management_time, 0) / 60.0;

    const seniorRate = 120;
    const standardRate = 80;
    const juniorRate = 50;
    const techWriterRate = 60;

    console.log('\n' + '='.repeat(60));
    console.log('FINANCIAL ANALYSIS');
    console.log('='.repeat(60));

    console.log('\nAPI SPENDING ANALYSIS');
    console.log('='.repeat(54));
    console.log(`Total API Costs:           $${totalApiCost.toFixed(2)}`);
    if (this.sessions.length > 0) {
      console.log(`Average Cost/Session:      $${(totalApiCost / this.sessions.length).toFixed(2)}`);
      if (devHours > 0) {
        console.log(`Cost per Development Hour: $${(totalApiCost / devHours).toFixed(2)}`);
      }
    }
    console.log(`Total Tokens (In):         ${totalTokensIn.toLocaleString()}`);
    console.log(`Total Tokens (Out):        ${totalTokensOut.toLocaleString()}`);
    console.log('='.repeat(54));

    console.log('\nCODE OUTPUT ANALYSIS');
    console.log('='.repeat(54));
    console.log(`Total Lines Added:         ${totalLinesAdded.toLocaleString()}`);
    console.log(`Files Created:             ${totalFilesCreated}`);
    console.log(`Files Modified:            ${totalFilesModified}`);
    console.log(`Functions/Classes Added:   ${totalFunctionsAdded}`);
    if (devHours > 0) {
      console.log(`Lines per Hour:            ${(totalLinesAdded / devHours).toFixed(1)}`);
    }
    if (this.sessions.length > 0) {
      console.log(
        `Files per Session:         ${((totalFilesCreated + totalFilesModified) / this.sessions.length).toFixed(1)}`
      );
    }
    console.log('='.repeat(54));

    console.log('\nENGINEERING TIME VALUE');
    console.log('='.repeat(54));
    console.log(`Development Hours:         ${devHours.toFixed(1)}`);
    console.log(`@ $${standardRate}/hour (Standard):     $${(devHours * standardRate).toLocaleString('en-US', { maximumFractionDigits: 0 })}`);
    console.log(`@ $${seniorRate}/hour (Senior):       $${(devHours * seniorRate).toLocaleString('en-US', { maximumFractionDigits: 0 })}`);
    console.log(`@ $${juniorRate}/hour (Junior):       $${(devHours * juniorRate).toLocaleString('en-US', { maximumFractionDigits: 0 })}`);
    console.log(`Memory Bank Hours:         ${memoryBankHours.toFixed(1)}`);
    console.log(`@ $${techWriterRate}/hour (Tech Writer):   $${(memoryBankHours * techWriterRate).toLocaleString('en-US', { maximumFractionDigits: 0 })}`);
    console.log('='.repeat(54));

    const totalOutputValue = this.sessions.reduce((sum, s) => sum + s.output_based_value, 0);
    const totalTimeValue = this.sessions.reduce((sum, s) => sum + s.time_based_value, 0);

    if (totalOutputValue > 0) {
      console.log('\nOUTPUT-BASED VALUE ANALYSIS');
      console.log('='.repeat(54));
      console.log(`Time-Based Value:          $${totalTimeValue.toLocaleString('en-US', { maximumFractionDigits: 0 })}`);
      console.log(`Output-Based Value:        $${totalOutputValue.toLocaleString('en-US', { maximumFractionDigits: 0 })}`);

      if (totalTimeValue > 0) {
        const valueRatio = totalOutputValue / totalTimeValue;
        console.log(`Output/Time Ratio:         ${valueRatio.toFixed(2)}x`);
        if (valueRatio > 1) {
          console.log('Result: Output > Time Value (High Quality)');
        } else {
          console.log('Result: Time > Output Value (Basic Code)');
        }
      }

      if (totalApiCost > 0) {
        const outputRoi = totalOutputValue / totalApiCost;
        console.log(`Output-Based ROI:          ${outputRoi.toFixed(0)}:1`);
      }
      console.log('='.repeat(54));
    }

    const allCodeAnalysis = [];
    for (const session of this.sessions) {
      allCodeAnalysis.push(...session.code_analysis);
    }

    if (allCodeAnalysis.length > 0) {
      const typeStats = new Map();
      const qualityCounts = {
        error_handling: 0,
        comments: 0,
        modular: 0,
        typed: 0,
      };

      for (const analysis of allCodeAnalysis) {
        if (!typeStats.has(analysis.file_type)) {
          typeStats.set(analysis.file_type, { count: 0, lines: 0, complexity: 0 });
        }
        const stats = typeStats.get(analysis.file_type);
        stats.count++;
        stats.lines += analysis.lines_of_code;
        stats.complexity += analysis.complexity_score;

        if (analysis.has_error_handling) qualityCounts.error_handling++;
        if (analysis.has_comprehensive_comments) qualityCounts.comments++;
        if (analysis.has_modular_design) qualityCounts.modular++;
        if (analysis.has_type_annotations) qualityCounts.typed++;
      }

      console.log('\nCODE QUALITY BREAKDOWN');
      console.log('='.repeat(54));

      const sortedTypes = [...typeStats.entries()].sort((a, b) => b[1].lines - a[1].lines);
      for (const [fileType, stats] of sortedTypes) {
        if (stats.count > 0) {
          const avgComplexity = stats.complexity / stats.count;
          console.log(
            `${fileType.charAt(0).toUpperCase() + fileType.slice(1)} ${stats.count} files, ${stats.lines} lines, ${avgComplexity.toFixed(1)} complexity`
          );
        }
      }

      const totalFiles = allCodeAnalysis.length;
      if (totalFiles > 0) {
        console.log(`Error Handling:            ${qualityCounts.error_handling}/${totalFiles} files (${((qualityCounts.error_handling / totalFiles) * 100).toFixed(0)}%)`);
        console.log(`Well Commented:            ${qualityCounts.comments}/${totalFiles} files (${((qualityCounts.comments / totalFiles) * 100).toFixed(0)}%)`);
        console.log(`Modular Design:            ${qualityCounts.modular}/${totalFiles} files (${((qualityCounts.modular / totalFiles) * 100).toFixed(0)}%)`);
        console.log(`Type Annotations:          ${qualityCounts.typed}/${totalFiles} files (${((qualityCounts.typed / totalFiles) * 100).toFixed(0)}%)`);
      }
      console.log('='.repeat(54));
    }

    if (totalApiCost > 0) {
      const estimatedValue = totalOutputValue > 0 ? totalOutputValue : devHours * standardRate + memoryBankHours * techWriterRate;
      const roiRatio = totalApiCost > 0 ? estimatedValue / totalApiCost : 0;
      const costPerLine = totalLinesAdded > 0 ? totalApiCost / totalLinesAdded : 0;

      console.log('\nRETURN ON INVESTMENT');
      console.log('='.repeat(54));
      console.log(`Money Invested (API):      $${totalApiCost.toFixed(2)}`);
      console.log(`Estimated Value Created:   $${estimatedValue.toLocaleString('en-US', { maximumFractionDigits: 0 })}`);
      const valueMethod = totalOutputValue > 0 ? 'Output-Based' : 'Time-Based';
      console.log(`Valuation Method:          ${valueMethod}`);
      console.log(`ROI Ratio:                 ${roiRatio.toFixed(0)}:1`);
      if (totalLinesAdded > 0) {
        console.log(`Cost per Line of Code:     $${costPerLine.toFixed(3)}`);
      }
      console.log(`Value per Dollar Spent:    $${roiRatio.toFixed(2)}`);
      console.log('='.repeat(54));
    }

    if (totalApiCost > 0) {
      const totalTrackedTime = this.sessions.reduce((sum, s) => sum + s.tool_time, 0);
      if (totalTrackedTime > 0) {
        const devCostPct = (this.sessions.reduce((sum, s) => sum + s.project_code_time, 0) / totalTrackedTime) * 100;
        const mbCostPct = (this.sessions.reduce((sum, s) => sum + s.memory_bank_time, 0) / totalTrackedTime) * 100;
        const taskCostPct = (this.sessions.reduce((sum, s) => sum + s.task_management_time, 0) / totalTrackedTime) * 100;

        console.log('\nCOST BY ACTIVITY TYPE');
        console.log('='.repeat(54));
        console.log(`Development Work:     $${(totalApiCost * devCostPct / 100).toFixed(2)} (${devCostPct.toFixed(1)}%)`);
        console.log(`Memory Bank:          $${(totalApiCost * mbCostPct / 100).toFixed(2)} (${mbCostPct.toFixed(1)}%)`);
        console.log(`Task Management:      $${(totalApiCost * taskCostPct / 100).toFixed(2)} (${taskCostPct.toFixed(1)}%)`);
        if (devCostPct >= mbCostPct && devCostPct >= taskCostPct) {
          console.log('Most Efficient:      Development');
        } else if (mbCostPct >= devCostPct && mbCostPct >= taskCostPct) {
          console.log('Highest Cost/Hour:    Memory Bank');
        } else {
          console.log('Highest Cost/Hour:    Task Management');
        }
        console.log('='.repeat(54));
      }
    }
  }

  generateDashboard() {
    console.log('Generating dashboard...');
    const dashboardDir = path.join(process.cwd(), 'dashboard');
    const exportsDir = path.join(process.cwd(), 'exports');
    if (!fs.existsSync(dashboardDir)) fs.mkdirSync(dashboardDir, { recursive: true });
    if (!fs.existsSync(exportsDir)) fs.mkdirSync(exportsDir, { recursive: true });

    const dashboardData = this._exportDashboardData();
    const jsonFile = path.join(dashboardDir, 'dashboard_data.json');
    fs.writeFileSync(jsonFile, JSON.stringify(dashboardData, null, 2));

    this._updateDashboardHtml(dashboardDir, dashboardData);

    console.log(`Dashboard data exported to ${jsonFile}`);
    console.log('Dashboard HTML updated with embedded data');
    console.log('Dashboard files generated');

    const dashboardFile = path.join(dashboardDir, 'index.html');
    this._openBrowser(dashboardFile);
  }

  _calculateVelocityInsights() {
    if (this.sessions.length < 2) return {};

    const sortedSessions = [...this.sessions].sort((a, b) => a.start_time - b.start_time);
    const velocityTrend = [];
    for (const session of sortedSessions.slice(-20)) {
      const linesPerHour =
        session.duration_minutes > 0
          ? session.lines_of_code_added / (session.duration_minutes / 60.0)
          : 0;
      velocityTrend.push({
        session_id: session.session_id.slice(-8),
        lines_per_hour: Math.round(linesPerHour * 10) / 10,
        date: session.start_time.toLocaleDateString('en-US', {
          month: '2-digit',
          day: '2-digit',
        }),
      });
    }

    const first10 = sortedSessions.slice(0, 10);
    const recent10 = sortedSessions.slice(-10);

    const firstVelocity =
      first10.length > 0
        ? first10.reduce((sum, s) => sum + (s.duration_minutes > 0 ? s.lines_of_code_added / (s.duration_minutes / 60.0) : 0), 0) /
          first10.length
        : 0;
    const recentVelocity =
      recent10.length > 0
        ? recent10.reduce((sum, s) => sum + (s.duration_minutes > 0 ? s.lines_of_code_added / (s.duration_minutes / 60.0) : 0), 0) /
          recent10.length
        : 0;

    const velocityImprovement = firstVelocity > 0 ? ((recentVelocity - firstVelocity) / firstVelocity) * 100 : 0;

    const allVelocities = sortedSessions
      .filter((s) => s.duration_minutes > 0)
      .map((s) => s.lines_of_code_added / (s.duration_minutes / 60.0));
    const peakProductivity = allVelocities.length > 0 ? Math.max(...allVelocities) : 0;

    const hourlyProductivity = new Map();
    for (const session of sortedSessions) {
      const hour = session.start_time.getHours();
      if (session.duration_minutes > 0) {
        const productivity = session.lines_of_code_added / (session.duration_minutes / 60.0);
        if (!hourlyProductivity.has(hour)) hourlyProductivity.set(hour, []);
        hourlyProductivity.get(hour).push(productivity);
      }
    }

    const efficiencyPattern = [];
    const timeLabels = ['6AM', '9AM', '12PM', '3PM', '6PM', '9PM'];
    const hourMapping = [6, 9, 12, 15, 18, 21];

    for (let i = 0; i < hourMapping.length; i++) {
      const hour = hourMapping[i];
      let avgProductivity;
      if (hourlyProductivity.has(hour) && hourlyProductivity.get(hour).length > 0) {
        const values = hourlyProductivity.get(hour);
        avgProductivity = values.reduce((a, b) => a + b, 0) / values.length;
      } else {
        avgProductivity = 50 + (i % 3) * 20;
      }
      efficiencyPattern.push({
        time: timeLabels[i],
        productivity: Math.round(avgProductivity * 10) / 10,
      });
    }

    const velocities = allVelocities.filter((v) => v > 0);
    let consistencyScore = 0;
    if (velocities.length > 0) {
      const avgVelocity = velocities.reduce((a, b) => a + b, 0) / velocities.length;
      const variance = velocities.reduce((sum, v) => sum + Math.pow(v - avgVelocity, 2), 0) / velocities.length;
      consistencyScore = avgVelocity > 0 ? Math.max(0, 100 - (variance / avgVelocity) * 100) : 0;
    }

    return {
      velocity_trend: velocityTrend,
      velocity_improvement: Math.round(velocityImprovement * 10) / 10,
      peak_productivity: Math.round(peakProductivity * 10) / 10,
      efficiency_pattern: efficiencyPattern,
      consistency_score: Math.round(consistencyScore * 10) / 10,
      learning_insights: {
        first_10_avg_velocity: Math.round(firstVelocity * 10) / 10,
        recent_10_avg_velocity: Math.round(recentVelocity * 10) / 10,
        total_improvement: Math.round(velocityImprovement * 10) / 10,
      },
    };
  }

  _exportDashboardData() {
    if (this.sessions.length === 0) {
      return { error: 'No sessions to analyze' };
    }

    const totalApiCost = this.sessions.reduce((sum, s) => sum + s.api_cost, 0);
    const totalLinesAdded = this.sessions.reduce((sum, s) => sum + s.lines_of_code_added, 0);
    const totalFilesCreated = this.sessions.reduce((sum, s) => sum + s.files_created, 0);
    const totalFilesModified = this.sessions.reduce((sum, s) => sum + s.files_modified, 0);
    const totalOutputValue = this.sessions.reduce((sum, s) => sum + s.output_based_value, 0);
    const totalTimeValue = this.sessions.reduce((sum, s) => sum + s.time_based_value, 0);
    const totalHours = this.sessions.reduce((sum, s) => sum + s.duration_minutes, 0) / 60.0;

    const roiRatio = totalApiCost > 0 ? totalOutputValue / totalApiCost : 0;
    const valueRatio = totalTimeValue > 0 ? totalOutputValue / totalTimeValue : 0;

    const totalMemoryBank = this.sessions.reduce((sum, s) => sum + s.memory_bank_time, 0);
    const totalProjectCode = this.sessions.reduce((sum, s) => sum + s.project_code_time, 0);
    const totalToolTime = this.sessions.reduce((sum, s) => sum + s.tool_time, 0);

    const allCodeAnalysis = [];
    for (const session of this.sessions) {
      allCodeAnalysis.push(...session.code_analysis);
    }

    const typeStats = new Map();
    const qualityCounts = {
      error_handling: 0,
      comments: 0,
      modular: 0,
      typed: 0,
    };

    for (const analysis of allCodeAnalysis) {
      if (!typeStats.has(analysis.file_type)) {
        typeStats.set(analysis.file_type, { count: 0, lines: 0, complexity: 0 });
      }
      const stats = typeStats.get(analysis.file_type);
      stats.count++;
      stats.lines += analysis.lines_of_code;
      stats.complexity += analysis.complexity_score;

      if (analysis.has_error_handling) qualityCounts.error_handling++;
      if (analysis.has_comprehensive_comments) qualityCounts.comments++;
      if (analysis.has_modular_design) qualityCounts.modular++;
      if (analysis.has_type_annotations) qualityCounts.typed++;
    }

    const velocityInsights = this._calculateVelocityInsights();

    return {
      summary: {
        total_sessions: this.sessions.length,
        total_hours: Math.round(totalHours * 10) / 10,
        total_api_cost: Math.round(totalApiCost * 100) / 100,
        total_value_created: Math.round(totalOutputValue),
        roi_ratio: Math.round(roiRatio),
        value_ratio: Math.round(valueRatio * 100) / 100,
        lines_added: totalLinesAdded,
        files_created: totalFilesCreated,
        files_modified: totalFilesModified,
        cost_per_hour: totalHours > 0 ? Math.round((totalApiCost / totalHours) * 100) / 100 : 0,
        lines_per_hour: totalHours > 0 ? Math.round((totalLinesAdded / totalHours) * 10) / 10 : 0,
      },
      time_allocation: {
        memory_bank_pct: totalToolTime > 0 ? Math.round((totalMemoryBank / totalToolTime) * 1000) / 10 : 0,
        project_code_pct: totalToolTime > 0 ? Math.round((totalProjectCode / totalToolTime) * 1000) / 10 : 0,
        other_pct:
          totalToolTime > 0
            ? Math.round(((totalToolTime - totalMemoryBank - totalProjectCode) / totalToolTime) * 1000) / 10
            : 0,
      },
      language_breakdown: Object.fromEntries(
        [...typeStats.entries()]
          .filter(([_, stats]) => stats.count > 0)
          .map(([fileType, stats]) => [
            fileType,
            {
              count: stats.count,
              lines: stats.lines,
              avg_complexity: stats.count > 0 ? Math.round((stats.complexity / stats.count) * 10) / 10 : 0,
            },
          ])
      ),
      quality_metrics: {
        total_files: allCodeAnalysis.length,
        error_handling_pct: allCodeAnalysis.length > 0 ? Math.round((qualityCounts.error_handling / allCodeAnalysis.length) * 1000) / 10 : 0,
        comments_pct: allCodeAnalysis.length > 0 ? Math.round((qualityCounts.comments / allCodeAnalysis.length) * 1000) / 10 : 0,
        modular_pct: allCodeAnalysis.length > 0 ? Math.round((qualityCounts.modular / allCodeAnalysis.length) * 1000) / 10 : 0,
        typed_pct: allCodeAnalysis.length > 0 ? Math.round((qualityCounts.typed / allCodeAnalysis.length) * 1000) / 10 : 0,
      },
      velocity_insights: velocityInsights,
      generated_at: new Date().toISOString(),
    };
  }

  _updateDashboardHtml(dashboardDir, dashboardData) {
    const htmlFile = path.join(dashboardDir, 'index.html');
    if (!fs.existsSync(htmlFile)) {
      console.warn(`Dashboard HTML file not found at ${htmlFile}`);
      return;
    }

    let htmlContent = fs.readFileSync(htmlFile, 'utf-8');
    const jsonData = JSON.stringify(dashboardData, null, 2);
    const pattern = /let dashboardData = \{[\s\S]*?\};/;
    const replacement = `let dashboardData = ${jsonData};`;
    htmlContent = htmlContent.replace(pattern, replacement);
    fs.writeFileSync(htmlFile, htmlContent);
  }

  _openBrowser(filePath) {
    const fileUrl = `file://${filePath}`;
    try {
      const system = os.platform();
      if (system === 'darwin') {
        execSync(`open "${fileUrl}"`, { stdio: 'ignore' });
      } else if (system === 'win32') {
        execSync(`start "" "${fileUrl}"`, { shell: true, stdio: 'ignore' });
      } else if (system === 'linux') {
        execSync(`xdg-open "${fileUrl}"`, { stdio: 'ignore' });
      } else {
        // Fallback - open with default browser
        const start = os.platform() === 'win32' ? 'start' : 'open';
        execSync(`${start} "${fileUrl}"`, { shell: true, stdio: 'ignore' });
      }
      console.log(`Dashboard opened in browser: ${fileUrl}`);
      console.log('Use the export buttons to create shareable images!');
    } catch (e) {
      console.warn(`Could not auto-open browser: ${e.message}`);
      console.log(`Manually open: ${fileUrl}`);
    }
  }
}

function getDefaultClinePath() {
  const system = os.platform();
  const home = os.homedir();

  if (system === 'darwin') {
    return path.join(
      home,
      'Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks'
    );
  } else if (system === 'win32') {
    const vscodePath = path.join(
      home,
      'AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/tasks'
    );
    const vscodiumPath = path.join(
      home,
      'AppData/Roaming/VSCodium/User/globalStorage/saoudrizwan.claude-dev/tasks'
    );
    if (fs.existsSync(vscodePath)) return vscodePath;
    if (fs.existsSync(vscodiumPath)) return vscodiumPath;
    return vscodePath;
  } else if (system === 'linux') {
    return path.join(
      home,
      '.config/Code/User/globalStorage/saoudrizwan.claude-dev/tasks'
    );
  } else {
    const paths = [
      path.join(home, '.config/Code/User/globalStorage/saoudrizwan.claude-dev/tasks'),
      path.join(home, 'AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/tasks'),
      path.join(home, 'Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks'),
    ];
    for (const p of paths) {
      if (fs.existsSync(p)) return p;
    }
    return paths[0];
  }
}

function parseArgs() {
  const args = process.argv.slice(2);
  const options = {
    path: null,
    limit: null,
    dashboard: false,
  };

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--path' && i + 1 < args.length) {
      options.path = args[i + 1];
      i++;
    } else if (args[i] === '--limit' && i + 1 < args.length) {
      options.limit = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--dashboard') {
      options.dashboard = true;
    }
  }

  return options;
}

function main() {
  const args = parseArgs();

  const sessionsPath = args.path ? path.resolve(args.path) : getDefaultClinePath();

  console.log(`Searching for Cline sessions at: ${sessionsPath}`);

  if (!fs.existsSync(sessionsPath)) {
    console.error(`Path does not exist: ${sessionsPath}`);
    console.log('\nTo specify a custom path, use:');
    console.log(`   node ${process.argv[1]} --path /your/custom/path`);
    console.log('\nCommon Cline session locations:');
    console.log('   macOS:   ~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks');
    console.log('   Windows: ~/AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/tasks');
    console.log('   Linux:   ~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/tasks');
    process.exit(1);
  }

  const analyzer = new ClineSessionAnalyzer(sessionsPath);
  analyzer.analyzeAllSessions(args.limit);

  if (args.dashboard) {
    analyzer.generateDashboard();
  } else {
    analyzer.generateReport();
  }
}

if (require.main === module) {
  main();
}

module.exports = { ClineSessionAnalyzer, CodeAnalysis, SessionMetrics };
