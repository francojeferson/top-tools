#!/usr/bin/env python3
"""
Cline Session Analysis Tool
Analyzes time allocation between memory bank work and actual development
"""

import json
import os
import sys
import argparse
from pathlib import Path
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from dataclasses import dataclass
from typing import List, Dict, Any, Optional
import re
import platform
import ast
import keyword


@dataclass
class CodeAnalysis:
    """Analysis of code complexity and quality"""

    file_path: str
    file_type: str
    lines_of_code: int
    complexity_score: float
    has_error_handling: bool
    has_comprehensive_comments: bool
    has_modular_design: bool
    has_type_annotations: bool
    function_count: int
    class_count: int
    import_count: int


@dataclass
class ValueCalculation:
    """Value calculation breakdown for code output"""

    base_value: float
    file_type_multiplier: float
    complexity_multiplier: float
    quality_multiplier: float
    final_value: float


@dataclass
class SessionMetrics:
    """Metrics for a single Cline session"""

    session_id: str
    start_time: datetime
    end_time: Optional[datetime]
    duration_minutes: float
    memory_bank_time: float
    task_management_time: float
    project_code_time: float
    config_time: float
    tool_time: float
    total_file_edits: int
    memory_bank_files: List[str]
    project_files: List[str]
    # Financial metrics
    api_cost: float
    tokens_in: int
    tokens_out: int
    lines_of_code_added: int
    files_created: int
    files_modified: int
    functions_added: int
    # Enhanced value analysis
    code_analysis: List[CodeAnalysis]
    output_based_value: float
    time_based_value: float


class ClineSessionAnalyzer:
    def __init__(self, sessions_path: str):
        self.sessions_path = Path(sessions_path)
        self.sessions: List[SessionMetrics] = []

    def categorize_file_path(self, file_path: str) -> str:
        """Categorize a file path into memory bank, task management, config, or project code"""
        file_path_lower = file_path.lower()
        filename = Path(file_path).name.lower()

        # Task management: TASK files, _index.md, or files in tasks/ directories
        if (
            (filename.startswith("task") and filename.endswith(".md"))
            or filename == "_index.md"
            or "/tasks/" in file_path_lower
        ):
            return "task_management"
        elif "memory-bank" in file_path_lower:
            return "memory_bank"
        elif any(
            config in file_path_lower
            for config in [
                "cline_mcp_settings.json",
                ".clinerules",
                ".env",
                "pyproject.toml",
            ]
        ):
            return "config"
        elif any(
            ext in file_path_lower
            for ext in [
                ".py",
                ".js",
                ".ts",
                ".tsx",
                ".jsx",
                ".css",
                ".html",
                ".sql",
                ".yaml",
                ".yml",
            ]
        ):
            return "project_code"
        else:
            return "other"

    def analyze_session_timing(self, ui_messages: List[Dict]) -> Dict[str, float]:
        """Analyze time spent in different categories based on UI messages"""
        category_times = defaultdict(float)

        for i, message in enumerate(ui_messages):
            if not isinstance(message, dict):
                continue

            if message.get("type") != "say" or message.get("say") != "tool":
                continue

            timestamp = message.get("ts", 0)
            if not isinstance(timestamp, (int, float)):
                continue

            tool_text = message.get("text", "")
            if not tool_text:
                continue

            # Extract file path from tool usage
            file_path = None
            if '"path":' in tool_text:
                # Extract path from JSON-like tool text
                try:
                    # Simple regex to extract path
                    path_match = re.search(r'"path":\s*"([^"]+)"', tool_text)
                    if path_match:
                        file_path = path_match.group(1)
                except:
                    pass

            if not file_path:
                continue

            # Calculate time until next message
            duration = 0
            if i + 1 < len(ui_messages):
                next_message = ui_messages[i + 1]
                if isinstance(next_message, dict):
                    next_timestamp = next_message.get("ts", timestamp)
                    if isinstance(next_timestamp, (int, float)):
                        duration = (
                            next_timestamp - timestamp
                        ) / 1000.0  # Convert to seconds

            # Categorize and add time
            category = self.categorize_file_path(file_path)
            if category != "other" and duration >= 0:
                category_times[category] += duration

        return dict(category_times)

    def parse_financial_data(self, session_dir: Path) -> tuple[float, int, int]:
        """Parse API costs and token usage from session data"""
        api_cost = 0.0
        tokens_in = 0
        tokens_out = 0

        # Parse cost data from UI messages where Cline actually stores it
        ui_messages_file = session_dir / "ui_messages.json"
        if ui_messages_file.exists():
            try:
                with open(ui_messages_file, "r", encoding="utf-8") as f:
                    content = f.read().strip()

                if not content:
                    return api_cost, tokens_in, tokens_out

                # Use the same robust JSON parsing
                try:
                    ui_data = json.loads(content)
                except json.JSONDecodeError:
                    ui_data = self._parse_streaming_json(content)

                if not isinstance(ui_data, list):
                    return api_cost, tokens_in, tokens_out

                # Look for api_req_started messages which contain cost data
                for message in ui_data:
                    if (
                        isinstance(message, dict)
                        and message.get("say") == "api_req_started"
                    ):
                        text = message.get("text", "")
                        if text:
                            try:
                                # Parse the JSON data in the text field
                                req_info = json.loads(text)

                                # Extract cost and token data
                                cost = req_info.get("cost", 0)
                                if isinstance(cost, (int, float)) and cost > 0:
                                    api_cost += cost

                                tokens_in += req_info.get("tokensIn", 0)
                                tokens_out += req_info.get("tokensOut", 0)

                            except json.JSONDecodeError:
                                # Skip malformed JSON
                                continue

            except Exception:
                # Skip sessions with corrupted UI messages
                pass

        return api_cost, tokens_in, tokens_out

    def _get_model_pricing(self) -> dict:
        """Get model pricing from Cline's cache"""
        try:
            cache_file = (
                Path.home()
                / "Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/cache/openrouter_models.json"
            )
            if cache_file.exists():
                with open(cache_file, "r") as f:
                    cache_data = json.load(f)

                pricing = {}
                if "data" in cache_data:
                    for model in cache_data["data"]:
                        if (
                            isinstance(model, dict)
                            and "id" in model
                            and "pricing" in model
                        ):
                            model_id = model["id"]
                            pricing_info = model["pricing"]
                            pricing[model_id] = {
                                "prompt": float(pricing_info.get("prompt", 0)),
                                "completion": float(pricing_info.get("completion", 0)),
                            }

                return pricing
        except Exception:
            pass

        return {}

    def parse_code_metrics(self, ui_messages: List[Dict]) -> tuple[int, int, int, int]:
        """Parse code metrics from UI messages"""
        lines_added = 0
        files_created = 0
        files_modified = 0
        functions_added = 0

        for message in ui_messages:
            if not isinstance(message, dict):
                continue

            if message.get("type") == "say" and message.get("say") == "tool":
                tool_text = message.get("text", "")
                if not tool_text:
                    continue

                try:
                    # Parse tool message as JSON
                    tool_data = json.loads(tool_text)
                    tool_name = tool_data.get("tool", "")

                    # Count file operations using correct tool names
                    if tool_name == "newFileCreated":
                        files_created += 1
                    elif tool_name == "editedExistingFile":
                        files_modified += 1

                    # Get content for line counting (from writeToFile and replaceInFile)
                    if tool_name in [
                        "writeToFile",
                        "replaceInFile",
                        "newFileCreated",
                        "editedExistingFile",
                    ]:
                        content = tool_data.get("content", "")
                        if content and isinstance(content, str):
                            # Count actual lines (not escaped newlines)
                            lines_in_content = content.count("\n") + 1 if content else 0
                            lines_added += lines_in_content

                            # Count function definitions
                            functions_added += (
                                content.count("def ")
                                + content.count("function ")
                                + content.count("class ")
                            )

                except (json.JSONDecodeError, TypeError):
                    # Fallback to old parsing for any non-JSON tool messages
                    if "createdNewFile" in tool_text:
                        files_created += 1
                    elif "editedExistingFile" in tool_text:
                        files_modified += 1

        return lines_added, files_created, files_modified, functions_added

    def analyze_code_complexity(self, content: str, file_path: str) -> CodeAnalysis:
        """Analyze code content for complexity and quality metrics"""
        file_ext = Path(file_path).suffix.lower()

        # Determine file type
        if file_ext in [".py"]:
            file_type = "python"
        elif file_ext in [".js", ".jsx"]:
            file_type = "javascript"
        elif file_ext in [".ts", ".tsx"]:
            file_type = "typescript"
        elif file_ext in [".html"]:
            file_type = "html"
        elif file_ext in [".css"]:
            file_type = "css"
        elif file_ext in [".sql"]:
            file_type = "sql"
        else:
            file_type = "other"

        lines_of_code = len([line for line in content.split("\n") if line.strip()])

        # Basic complexity analysis
        complexity_score = 1.0
        function_count = 0
        class_count = 0
        import_count = 0

        # Language-specific analysis
        if file_type == "python":
            function_count = content.count("def ") + content.count("async def ")
            class_count = content.count("class ")
            import_count = content.count("import ") + content.count("from ")

            # Complexity indicators
            complexity_score += content.count("if ") * 0.1
            complexity_score += content.count("for ") * 0.1
            complexity_score += content.count("while ") * 0.1
            complexity_score += content.count("try:") * 0.2
            complexity_score += content.count("except") * 0.1

        elif file_type in ["javascript", "typescript"]:
            function_count = (
                content.count("function ")
                + content.count("=>")
                + content.count("async ")
            )
            class_count = content.count("class ")
            import_count = content.count("import ") + content.count("require(")

            complexity_score += content.count("if (") * 0.1
            complexity_score += content.count("for (") * 0.1
            complexity_score += content.count("while (") * 0.1
            complexity_score += content.count("try {") * 0.2
            complexity_score += content.count("catch") * 0.1

        # Quality indicators
        has_error_handling = (
            "try" in content.lower()
            or "except" in content.lower()
            or "catch" in content.lower()
        )
        has_comprehensive_comments = (
            content.count("#") + content.count("//") + content.count('"""')
        ) > lines_of_code * 0.1
        has_modular_design = function_count > 2 or class_count > 0
        has_type_annotations = ": " in content and file_type in ["python", "typescript"]

        return CodeAnalysis(
            file_path=file_path,
            file_type=file_type,
            lines_of_code=lines_of_code,
            complexity_score=min(complexity_score, 5.0),  # Cap at 5.0
            has_error_handling=has_error_handling,
            has_comprehensive_comments=has_comprehensive_comments,
            has_modular_design=has_modular_design,
            has_type_annotations=has_type_annotations,
            function_count=function_count,
            class_count=class_count,
            import_count=import_count,
        )

    def calculate_output_based_value(self, code_analysis: List[CodeAnalysis]) -> float:
        """Calculate value based on code output complexity and quality"""
        if not code_analysis:
            return 0.0

        total_value = 0.0
        base_rate_per_line = 0.50  # Base value per line of code

        # File type multipliers
        file_type_multipliers = {
            "python": 1.5,  # Backend/logic
            "typescript": 1.4,  # Complex frontend
            "javascript": 1.3,  # Frontend
            "sql": 1.4,  # Database
            "html": 0.9,  # Markup
            "css": 0.8,  # Styling
            "other": 1.0,  # Default
        }

        for analysis in code_analysis:
            # Base value from lines of code
            base_value = analysis.lines_of_code * base_rate_per_line

            # File type multiplier
            type_multiplier = file_type_multipliers.get(analysis.file_type, 1.0)

            # Complexity multiplier (1.0 - 2.5x based on complexity score)
            complexity_multiplier = 1.0 + (analysis.complexity_score - 1.0) * 0.3

            # Quality multipliers
            quality_multiplier = 1.0
            if analysis.has_error_handling:
                quality_multiplier += 0.2
            if analysis.has_comprehensive_comments:
                quality_multiplier += 0.1
            if analysis.has_modular_design:
                quality_multiplier += 0.1
            if analysis.has_type_annotations:
                quality_multiplier += 0.1

            # Calculate final value for this file
            file_value = (
                base_value
                * type_multiplier
                * complexity_multiplier
                * quality_multiplier
            )
            total_value += file_value

        return total_value

    def _parse_streaming_json(self, content: str) -> List[Dict]:
        """Parse streaming/concatenated JSON objects"""
        messages = []
        decoder = json.JSONDecoder()
        idx = 0

        while idx < len(content):
            content = content[idx:].lstrip()
            if not content:
                break

            try:
                obj, end_idx = decoder.raw_decode(content)
                if isinstance(obj, dict):
                    messages.append(obj)
                elif isinstance(obj, list):
                    messages.extend(obj)
                idx += end_idx
            except json.JSONDecodeError:
                # Try to find the next valid JSON object
                next_brace = content.find("{", 1)
                next_bracket = content.find("[", 1)

                if next_brace == -1 and next_bracket == -1:
                    break

                next_json = min(pos for pos in [next_brace, next_bracket] if pos > 0)
                idx += next_json
                content = content[next_json:]

        return messages

    def parse_session(self, session_dir: Path) -> Optional[SessionMetrics]:
        """Parse a single session directory"""
        try:
            session_id = session_dir.name

            # Read UI messages
            ui_messages_file = session_dir / "ui_messages.json"
            if not ui_messages_file.exists():
                return None

            # Read file content and handle malformed JSON
            try:
                with open(ui_messages_file, "r", encoding="utf-8") as f:
                    content = f.read().strip()

                if not content:
                    return None

                # Try to parse as regular JSON first
                try:
                    ui_messages = json.loads(content)
                except json.JSONDecodeError as e:
                    # Handle concatenated JSON objects or streaming JSON
                    ui_messages = self._parse_streaming_json(content)
                    if not ui_messages:
                        raise e

            except (json.JSONDecodeError, UnicodeDecodeError) as e:
                print(f"JSON parsing error in session {session_id}: {str(e)[:100]}...")
                return None

            if not ui_messages or not isinstance(ui_messages, list):
                return None

            # Get session timing - handle missing or invalid timestamps
            try:
                first_message = next(
                    (
                        msg
                        for msg in ui_messages
                        if isinstance(msg, dict) and "ts" in msg
                    ),
                    None,
                )
                last_message = next(
                    (
                        msg
                        for msg in reversed(ui_messages)
                        if isinstance(msg, dict) and "ts" in msg
                    ),
                    None,
                )

                if not first_message or not last_message:
                    return None

                start_time = datetime.fromtimestamp(first_message["ts"] / 1000.0)
                end_time = datetime.fromtimestamp(last_message["ts"] / 1000.0)
                duration_minutes = (end_time - start_time).total_seconds() / 60.0

                if duration_minutes < 0:
                    duration_minutes = 0

            except (KeyError, ValueError, OSError) as e:
                print(f"Invalid timestamp in session {session_id}: {e}")
                return None

            # Analyze time allocation
            category_times = self.analyze_session_timing(ui_messages)

            # Count file operations using proper JSON parsing
            memory_bank_files = []
            project_files = []
            total_edits = 0

            for message in ui_messages:
                if not isinstance(message, dict):
                    continue

                if message.get("type") == "say" and message.get("say") == "tool":
                    tool_text = message.get("text", "")
                    if not tool_text:
                        continue

                    try:
                        # Parse tool message as JSON
                        tool_data = json.loads(tool_text)
                        tool_name = tool_data.get("tool", "")

                        # Count file operations using correct tool names
                        if tool_name in [
                            "newFileCreated",
                            "editedExistingFile",
                            "writeToFile",
                            "replaceInFile",
                        ]:
                            total_edits += 1

                            # Extract file path
                            file_path = tool_data.get("path", "")
                            if file_path:
                                category = self.categorize_file_path(file_path)
                                if category == "memory_bank":
                                    memory_bank_files.append(file_path)
                                elif category == "project_code":
                                    project_files.append(file_path)

                    except (json.JSONDecodeError, TypeError):
                        # Fallback to old parsing for any non-JSON tool messages
                        if any(
                            action in tool_text
                            for action in ["editedExistingFile", "createdNewFile"]
                        ):
                            total_edits += 1

                            # Extract file path
                            path_match = re.search(r'"path":\s*"([^"]+)"', tool_text)
                            if path_match:
                                file_path = path_match.group(1)
                                category = self.categorize_file_path(file_path)
                                if category == "memory_bank":
                                    memory_bank_files.append(file_path)
                                elif category == "project_code":
                                    project_files.append(file_path)

            # Parse financial metrics
            api_cost, tokens_in, tokens_out = self.parse_financial_data(session_dir)
            lines_added, files_created, files_modified, functions_added = (
                self.parse_code_metrics(ui_messages)
            )

            # Enhanced code analysis - extract actual code content for analysis
            code_analysis = []
            for message in ui_messages:
                if message.get("type") == "say" and message.get("say") == "tool":
                    tool_text = message.get("text", "")

                    try:
                        tool_data = json.loads(tool_text)
                        tool_name = tool_data.get("tool", "")

                        # Analyze code content from file operations
                        if tool_name in [
                            "writeToFile",
                            "replaceInFile",
                            "newFileCreated",
                            "editedExistingFile",
                        ]:
                            file_path = tool_data.get("path", "")
                            content = tool_data.get("content", "")

                            # Only analyze project code files (not memory bank or config)
                            if (
                                file_path
                                and content
                                and self.categorize_file_path(file_path)
                                == "project_code"
                            ):
                                # Only analyze actual code files
                                file_ext = Path(file_path).suffix.lower()
                                if file_ext in [
                                    ".py",
                                    ".js",
                                    ".jsx",
                                    ".ts",
                                    ".tsx",
                                    ".html",
                                    ".css",
                                    ".sql",
                                ]:
                                    analysis = self.analyze_code_complexity(
                                        content, file_path
                                    )
                                    code_analysis.append(analysis)

                    except json.JSONDecodeError:
                        continue

            # Calculate output-based value
            output_based_value = self.calculate_output_based_value(code_analysis)

            # Calculate time-based value for comparison
            total_hours = duration_minutes / 60.0
            time_based_value = total_hours * 80  # Standard rate

            return SessionMetrics(
                session_id=session_id,
                start_time=start_time,
                end_time=end_time,
                duration_minutes=duration_minutes,
                memory_bank_time=category_times.get("memory_bank", 0)
                / 60.0,  # Convert to minutes
                task_management_time=category_times.get("task_management", 0) / 60.0,
                project_code_time=category_times.get("project_code", 0) / 60.0,
                config_time=category_times.get("config", 0) / 60.0,
                tool_time=sum(category_times.values()) / 60.0,
                total_file_edits=total_edits,
                memory_bank_files=memory_bank_files,
                project_files=project_files,
                # Financial metrics
                api_cost=api_cost,
                tokens_in=tokens_in,
                tokens_out=tokens_out,
                lines_of_code_added=lines_added,
                files_created=files_created,
                files_modified=files_modified,
                functions_added=functions_added,
                # Enhanced value analysis
                code_analysis=code_analysis,
                output_based_value=output_based_value,
                time_based_value=time_based_value,
            )

        except Exception as e:
            print(f"Error parsing session {session_dir.name}: {e}")
            return None

    def analyze_all_sessions(self, limit: Optional[int] = None) -> None:
        """Analyze all sessions in the directory"""
        if not self.sessions_path.exists():
            print(f"Sessions path does not exist: {self.sessions_path}")
            return

        session_dirs = [d for d in self.sessions_path.iterdir() if d.is_dir()]
        session_dirs.sort(key=lambda x: x.name, reverse=True)  # Most recent first

        if limit:
            session_dirs = session_dirs[:limit]

        print(f"Analyzing {len(session_dirs)} sessions...")

        for session_dir in session_dirs:
            metrics = self.parse_session(session_dir)
            if (
                metrics and metrics.duration_minutes > 1
            ):  # Only include sessions > 1 minute
                self.sessions.append(metrics)

        print(f"Successfully parsed {len(self.sessions)} sessions")

    def generate_report(self) -> None:
        """Generate analysis report"""
        if not self.sessions:
            print("No sessions to analyze!")
            return

        # Calculate totals
        total_duration = sum(s.duration_minutes for s in self.sessions)
        total_memory_bank = sum(s.memory_bank_time for s in self.sessions)
        total_task_mgmt = sum(s.task_management_time for s in self.sessions)
        total_project_code = sum(s.project_code_time for s in self.sessions)
        total_config = sum(s.config_time for s in self.sessions)
        total_tool_time = sum(s.tool_time for s in self.sessions)

        print("\n" + "=" * 60)
        print("📊 CLINE SESSION ANALYSIS REPORT")
        print("=" * 60)

        print(f"\n📈 OVERALL STATISTICS")
        print(f"Total Sessions Analyzed: {len(self.sessions)}")
        print(
            f"Total Time Spent: {total_duration:.1f} minutes ({total_duration/60:.1f} hours)"
        )
        print(
            f"Average Session Length: {total_duration/len(self.sessions):.1f} minutes"
        )

        print(f"\n⏰ TIME ALLOCATION BREAKDOWN")
        if total_tool_time > 0:
            memory_bank_pct = (total_memory_bank / total_tool_time) * 100
            task_mgmt_pct = (total_task_mgmt / total_tool_time) * 100
            project_code_pct = (total_project_code / total_tool_time) * 100
            config_pct = (total_config / total_tool_time) * 100

            print(
                f"Memory Bank Work:     {total_memory_bank:.1f}m ({memory_bank_pct:.1f}%)"
            )
            print(
                f"Task Management:      {total_task_mgmt:.1f}m ({task_mgmt_pct:.1f}%)"
            )
            print(
                f"Project Code:         {total_project_code:.1f}m ({project_code_pct:.1f}%)"
            )
            print(f"Configuration:        {total_config:.1f}m ({config_pct:.1f}%)")
            print(f"Total Tracked Time:   {total_tool_time:.1f}m")

            # Key insight
            overhead_time = total_memory_bank + total_task_mgmt + total_config
            overhead_pct = (overhead_time / total_tool_time) * 100

            print(f"\n🎯 KEY INSIGHTS")
            print(f"Memory Bank Investment: {memory_bank_pct:.1f}% of tracked time")
            print(f"Total Overhead (Memory Bank + Tasks + Config): {overhead_pct:.1f}%")
            print(f"Actual Development Time: {project_code_pct:.1f}%")
            print(
                f"Development Efficiency Ratio: {project_code_pct/overhead_pct:.2f}:1"
                if overhead_pct > 0
                else "N/A"
            )

        # File activity analysis
        all_memory_bank_files = []
        all_project_files = []

        for session in self.sessions:
            all_memory_bank_files.extend(session.memory_bank_files)
            all_project_files.extend(session.project_files)

        if all_memory_bank_files:
            print(f"\n📁 MEMORY BANK FILE ACTIVITY")
            memory_bank_counter = Counter(Path(f).name for f in all_memory_bank_files)
            for filename, count in memory_bank_counter.most_common(5):
                print(f"  {filename}: {count} edits")

        # Financial Analysis
        self.generate_financial_report()

        # Recent trends
        print(f"\n📅 RECENT SESSION TRENDS (Last 10 sessions)")
        recent_sessions = self.sessions[:10]
        for session in recent_sessions:
            if session.tool_time > 0:
                mb_pct = (session.memory_bank_time / session.tool_time) * 100
                code_pct = (session.project_code_time / session.tool_time) * 100
                date_str = session.start_time.strftime("%m/%d %H:%M")
                print(
                    f"  {date_str}: Memory Bank {mb_pct:.0f}%, Code {code_pct:.0f}% ({session.duration_minutes:.0f}m)"
                )

    def generate_financial_report(self) -> None:
        """Generate financial analysis tables"""
        # Calculate financial totals
        total_api_cost = sum(s.api_cost for s in self.sessions)
        total_tokens_in = sum(s.tokens_in for s in self.sessions)
        total_tokens_out = sum(s.tokens_out for s in self.sessions)
        total_lines_added = sum(s.lines_of_code_added for s in self.sessions)
        total_files_created = sum(s.files_created for s in self.sessions)
        total_files_modified = sum(s.files_modified for s in self.sessions)
        total_functions_added = sum(s.functions_added for s in self.sessions)

        # Development hours - use total session time since users are actively developing
        total_hours = sum(s.duration_minutes for s in self.sessions) / 60.0
        dev_hours = total_hours  # Total time is development time when using Cline
        memory_bank_hours = sum(s.memory_bank_time for s in self.sessions) / 60.0
        task_mgmt_hours = sum(s.task_management_time for s in self.sessions) / 60.0

        # Standard hourly rates
        senior_rate = 120
        standard_rate = 80
        junior_rate = 50
        tech_writer_rate = 60

        print("\n" + "=" * 60)
        print("💰 FINANCIAL ANALYSIS")
        print("=" * 60)

        # Table 1: API Costs
        print(f"\n💸 API SPENDING ANALYSIS")
        print("╔" + "=" * 54 + "╗")
        print(f"║ Total API Costs:           ${total_api_cost:.2f}".ljust(55) + "║")
        if len(self.sessions) > 0:
            print(
                f"║ Average Cost/Session:      ${total_api_cost/len(self.sessions):.2f}".ljust(
                    55
                )
                + "║"
            )
            if dev_hours > 0:
                print(
                    f"║ Cost per Development Hour: ${total_api_cost/dev_hours:.2f}".ljust(
                        55
                    )
                    + "║"
                )
        print(f"║ Total Tokens (In):         {total_tokens_in:,}".ljust(55) + "║")
        print(f"║ Total Tokens (Out):        {total_tokens_out:,}".ljust(55) + "║")
        print("╚" + "=" * 54 + "╝")

        # Table 2: Code Production
        print(f"\n📊 CODE OUTPUT ANALYSIS")
        print("╔" + "=" * 54 + "╗")
        print(f"║ Total Lines Added:         {total_lines_added:,}".ljust(55) + "║")
        print(f"║ Files Created:             {total_files_created}".ljust(55) + "║")
        print(f"║ Files Modified:            {total_files_modified}".ljust(55) + "║")
        print(f"║ Functions/Classes Added:   {total_functions_added}".ljust(55) + "║")
        if dev_hours > 0:
            print(
                f"║ Lines per Hour:            {total_lines_added/dev_hours:.1f}".ljust(
                    55
                )
                + "║"
            )
        if len(self.sessions) > 0:
            print(
                f"║ Files per Session:         {(total_files_created + total_files_modified)/len(self.sessions):.1f}".ljust(
                    55
                )
                + "║"
            )
        print("╚" + "=" * 54 + "╝")

        # Table 3: Time Value Estimation
        print(f"\n💼 ENGINEERING TIME VALUE")
        print("╔" + "=" * 54 + "╗")
        print(f"║ Development Hours:         {dev_hours:.1f}".ljust(55) + "║")
        print(
            f"║ @ ${standard_rate}/hour (Standard):     ${dev_hours * standard_rate:,.0f}".ljust(
                55
            )
            + "║"
        )
        print(
            f"║ @ ${senior_rate}/hour (Senior):       ${dev_hours * senior_rate:,.0f}".ljust(
                55
            )
            + "║"
        )
        print(
            f"║ @ ${junior_rate}/hour (Junior):       ${dev_hours * junior_rate:,.0f}".ljust(
                55
            )
            + "║"
        )
        print("║".ljust(55) + "║")
        print(f"║ Memory Bank Hours:         {memory_bank_hours:.1f}".ljust(55) + "║")
        print(
            f"║ @ ${tech_writer_rate}/hour (Tech Writer):   ${memory_bank_hours * tech_writer_rate:,.0f}".ljust(
                55
            )
            + "║"
        )
        print("╚" + "=" * 54 + "╝")

        # Output-based value analysis
        total_output_value = sum(s.output_based_value for s in self.sessions)
        total_time_value = sum(s.time_based_value for s in self.sessions)

        # Table 4: Output-Based Value Analysis
        if total_output_value > 0:
            print(f"\n🎨 OUTPUT-BASED VALUE ANALYSIS")
            print("╔" + "=" * 54 + "╗")
            print(
                f"║ Time-Based Value:          ${total_time_value:,.0f}".ljust(55) + "║"
            )
            print(
                f"║ Output-Based Value:        ${total_output_value:,.0f}".ljust(55)
                + "║"
            )

            if total_time_value > 0:
                value_ratio = total_output_value / total_time_value
                print(
                    f"║ Output/Time Ratio:         {value_ratio:.2f}x".ljust(55) + "║"
                )
                if value_ratio > 1:
                    print(
                        "║ Result: Output > Time Value (High Quality)".ljust(55) + "║"
                    )
                else:
                    print("║ Result: Time > Output Value (Basic Code)".ljust(55) + "║")

            if total_api_cost > 0:
                output_roi = total_output_value / total_api_cost
                print(
                    f"║ Output-Based ROI:          {output_roi:.0f}:1".ljust(55) + "║"
                )
            print("╚" + "=" * 54 + "╝")

        # Table 5: Code Quality Analysis
        all_code_analysis = []
        for session in self.sessions:
            all_code_analysis.extend(session.code_analysis)

        if all_code_analysis:
            # Analyze by file type
            type_stats = defaultdict(
                lambda: {"count": 0, "lines": 0, "value": 0, "complexity": 0}
            )
            quality_counts = {
                "error_handling": 0,
                "comments": 0,
                "modular": 0,
                "typed": 0,
            }

            for analysis in all_code_analysis:
                type_stats[analysis.file_type]["count"] += 1
                type_stats[analysis.file_type]["lines"] += analysis.lines_of_code
                type_stats[analysis.file_type][
                    "complexity"
                ] += analysis.complexity_score

                if analysis.has_error_handling:
                    quality_counts["error_handling"] += 1
                if analysis.has_comprehensive_comments:
                    quality_counts["comments"] += 1
                if analysis.has_modular_design:
                    quality_counts["modular"] += 1
                if analysis.has_type_annotations:
                    quality_counts["typed"] += 1

            print(f"\n🔧 CODE QUALITY BREAKDOWN")
            print("╔" + "=" * 54 + "╗")

            # Show file type distribution
            for file_type, stats in sorted(
                type_stats.items(), key=lambda x: x[1]["lines"], reverse=True
            ):
                if stats["count"] > 0:
                    avg_complexity = stats["complexity"] / stats["count"]
                    print(
                        f"║ {file_type.title():12} {stats['count']:3} files, {stats['lines']:4} lines, {avg_complexity:.1f} complexity".ljust(
                            55
                        )
                        + "║"
                    )

            print("║".ljust(55) + "║")

            # Show quality metrics
            total_files = len(all_code_analysis)
            if total_files > 0:
                print(
                    f"║ Error Handling:            {quality_counts['error_handling']}/{total_files} files ({quality_counts['error_handling']/total_files*100:.0f}%)".ljust(
                        55
                    )
                    + "║"
                )
                print(
                    f"║ Well Commented:            {quality_counts['comments']}/{total_files} files ({quality_counts['comments']/total_files*100:.0f}%)".ljust(
                        55
                    )
                    + "║"
                )
                print(
                    f"║ Modular Design:            {quality_counts['modular']}/{total_files} files ({quality_counts['modular']/total_files*100:.0f}%)".ljust(
                        55
                    )
                    + "║"
                )
                print(
                    f"║ Type Annotations:          {quality_counts['typed']}/{total_files} files ({quality_counts['typed']/total_files*100:.0f}%)".ljust(
                        55
                    )
                    + "║"
                )

            print("╚" + "=" * 54 + "╝")

        # Table 6: ROI Analysis
        if total_api_cost > 0:
            # Use output-based value if available, otherwise time-based
            estimated_value = (
                total_output_value
                if total_output_value > 0
                else (dev_hours * standard_rate + memory_bank_hours * tech_writer_rate)
            )
            roi_ratio = estimated_value / total_api_cost if total_api_cost > 0 else 0
            cost_per_line = (
                total_api_cost / total_lines_added if total_lines_added > 0 else 0
            )

            print(f"\n📈 RETURN ON INVESTMENT")
            print("╔" + "=" * 54 + "╗")
            print(f"║ Money Invested (API):      ${total_api_cost:.2f}".ljust(55) + "║")
            print(
                f"║ Estimated Value Created:   ${estimated_value:,.0f}".ljust(55) + "║"
            )
            value_method = "Output-Based" if total_output_value > 0 else "Time-Based"
            print(f"║ Valuation Method:          {value_method}".ljust(55) + "║")
            print(f"║ ROI Ratio:                 {roi_ratio:.0f}:1".ljust(55) + "║")
            if total_lines_added > 0:
                print(
                    f"║ Cost per Line of Code:     ${cost_per_line:.3f}".ljust(55) + "║"
                )
            print(f"║ Value per Dollar Spent:    ${roi_ratio:.2f}".ljust(55) + "║")
            print("╚" + "=" * 54 + "╝")

        # Table 5: Activity Cost Breakdown
        if total_api_cost > 0:
            # Estimate cost allocation based on time percentages
            total_tracked_time = sum(s.tool_time for s in self.sessions)
            if total_tracked_time > 0:
                dev_cost_pct = (
                    sum(s.project_code_time for s in self.sessions)
                    / total_tracked_time
                    * 100
                )
                mb_cost_pct = (
                    sum(s.memory_bank_time for s in self.sessions)
                    / total_tracked_time
                    * 100
                )
                task_cost_pct = (
                    sum(s.task_management_time for s in self.sessions)
                    / total_tracked_time
                    * 100
                )

                print(f"\n🎯 COST BY ACTIVITY TYPE")
                print("╔" + "=" * 54 + "╗")
                print(
                    f"║ Development Work:     ${total_api_cost * dev_cost_pct/100:.2f} ({dev_cost_pct:.1f}%)".ljust(
                        55
                    )
                    + "║"
                )
                print(
                    f"║ Memory Bank:          ${total_api_cost * mb_cost_pct/100:.2f} ({mb_cost_pct:.1f}%)".ljust(
                        55
                    )
                    + "║"
                )
                print(
                    f"║ Task Management:      ${total_api_cost * task_cost_pct/100:.2f} ({task_cost_pct:.1f}%)".ljust(
                        55
                    )
                    + "║"
                )
                print("║".ljust(55) + "║")
                if dev_cost_pct >= mb_cost_pct and dev_cost_pct >= task_cost_pct:
                    print("║ Most Efficient:      Development".ljust(55) + "║")
                elif mb_cost_pct >= dev_cost_pct and mb_cost_pct >= task_cost_pct:
                    print("║ Highest Cost/Hour:    Memory Bank".ljust(55) + "║")
                else:
                    print("║ Highest Cost/Hour:    Task Management".ljust(55) + "║")
                print("╚" + "=" * 54 + "╝")


def get_default_cline_path():
    """Get the default Cline sessions path based on the operating system"""
    system = platform.system()
    home = Path.home()

    if system == "Darwin":  # macOS
        return (
            home
            / "Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
        )
    elif system == "Windows":
        # Check both VSCode and VSCodium paths
        vscode_path = (
            home
            / "AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
        )
        vscodium_path = (
            home
            / "AppData/Roaming/VSCodium/User/globalStorage/saoudrizwan.claude-dev/tasks"
        )
        if vscode_path.exists():
            return vscode_path
        elif vscodium_path.exists():
            return vscodium_path
        else:
            return vscode_path  # Default to VSCode path if neither exists
    elif system == "Linux":
        return home / ".config/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
    else:
        # Fallback - try common paths
        paths = [
            home / ".config/Code/User/globalStorage/saoudrizwan.claude-dev/tasks",
            home
            / "AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/tasks",
            home
            / "Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks",
        ]
        for path in paths:
            if path.exists():
                return path
        return paths[0]  # Return first path as fallback


def main():
    parser = argparse.ArgumentParser(
        description="Analyze Cline session data for time allocation metrics"
    )
    parser.add_argument(
        "--path",
        type=str,
        default=None,
        help="Custom path to Cline sessions directory (auto-detected if not provided)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Limit analysis to the N most recent sessions",
    )

    args = parser.parse_args()

    # Use provided path or auto-detect
    if args.path:
        sessions_path = Path(args.path)
    else:
        sessions_path = get_default_cline_path()

    print(f"🔍 Searching for Cline sessions at: {sessions_path}")

    if not sessions_path.exists():
        print(f"❌ Path does not exist: {sessions_path}")
        print("\n💡 To specify a custom path, use:")
        print(f"   python {sys.argv[0]} --path /your/custom/path")
        print("\n🔍 Common Cline session locations:")
        print(
            "   macOS:   ~/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
        )
        print(
            "   Windows: ~/AppData/Roaming/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
        )
        print(
            "   Linux:   ~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/tasks"
        )
        sys.exit(1)

    analyzer = ClineSessionAnalyzer(str(sessions_path))
    analyzer.analyze_all_sessions(limit=args.limit)
    analyzer.generate_report()


if __name__ == "__main__":
    main()
