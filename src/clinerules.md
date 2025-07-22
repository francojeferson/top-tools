# ClineRules Instructions

---

This document provides a categorized overview of all Cline rules, covering both global rules defined in the central
`.clinerules/` directory and any workspace-specific rules that may exist in individual projects. It serves as a quick
reference for understanding the scope and purpose of each rule, aligned with the structure in `clinerules-index.md`.

## Categories

### Core Behaviors

Rules related to Cline's fundamental operational protocols and identity.

- [`baby-steps`](./clinerules/baby-steps.md): Establishes the Baby Steps™ Methodology as the core operational directive,
  focusing on incremental progress, process documentation, and validation at every step.
  `['protocol', 'incremental-progress', 'core-behavior']`
- [`cline-continuous-improvement`](./clinerules/cline-continuous-improvement.md): Mandates self-reflection and knowledge
  capture for continuous improvement using dedicated logs.
  `['protocol', 'meta', 'learning', 'reflection', 'knowledge-management', 'core-behavior']`
- [`cline-core-ruleset`](./clinerules/cline-core-ruleset.md): Defines collaborative operational rules for logical
  thinking and user interaction, emphasizing step-by-step reasoning. `['collaboration', 'reasoning', 'core-behavior']`
- [`cline-memory-bank`](./clinerules/cline-memory-bank.md): Describes Cline's Memory Bank system, its structure, and
  workflows for maintaining project knowledge across sessions.
  `['memory-bank', 'knowledge-base', 'core-behavior', 'documentation-protocol']`
- [`cline-self-improving`](./clinerules/cline-self-improving.md): Defines a process for reflecting on interactions and
  suggesting improvements to active `.clinerules`.
  `['meta', 'self-improvement', 'clinerules', 'reflection', 'core-behavior']`
- [`cline-ultimate`](./clinerules/cline-ultimate.md): Establishes Cline's identity as an autonomous software engineering
  agent with comprehensive capabilities. `['identity', 'core-behavior', 'software-engineering', 'autonomous-agent']`

### Development Guides

Technical and architectural guidelines for development practices.

- [`swe-best-practices`](./clinerules/swe-best-practices.md): Comprehensive guide to software engineering best practices
  across architecture, debugging, code quality, collaboration, security, and reliability.
  `['software-engineering', 'best-practices', 'architecture', 'security', 'reliability']`

### Workflows

Rules governing task management and operational workflows.

- [`workflows/new-task-workflow`](./clinerules/workflows/new-task-workflow.md): Provides instructions for task handoff
  strategies, especially for context window management. `['context-management', 'new-task', 'workflow']`
- [`workflows/process-task-list`](./clinerules/workflows/process-task-list.md): Outlines guidelines for managing task
  lists to track progress on PRDs. `['tasks', 'project-management', 'workflow']`
- [`workflows/generate-tasks-from-prd`](./clinerules/workflows/generate-tasks-from-prd.md): Defines the process for
  generating task lists from Product Requirements Documents (PRDs). `['tasks', 'prd', 'workflow', 'project-management']`
- [`workflows/mcp-research-workflow`](./clinerules/workflows/mcp-research-workflow.md): Guides the user through a
  research process using available MCP tools. `['research', 'mcp', 'workflow', 'assistant-behavior']`
- [`workflows/mcp-sequential-thinking`](./clinerules/workflows/mcp-sequential-thinking.md): Guide for using the
  sequential thinking MCP tool for dynamic and reflective problem-solving.
  `['mcp', 'sequential-thinking', 'problem-solving', 'workflow-guide']`

### Roles

Role-specific instructions and responsibilities.

- [`product-manager`](./clinerules/product-manager.md): Defines Cline's role as an experienced product manager for
  project planning and documentation. `['product-management', 'documentation', 'user-needs', 'role']`

### Processes

Specific processes, templates, or formats for various tasks.

- [`create-prd`](./clinerules/create-prd.md): Outlines the process for generating Product Requirements Documents (PRDs).
  `['prd', 'requirements', 'documentation', 'workflow']`
- [`commit-message-format`](./clinerules/commit-message-format.md): Provides a standardized format for commit messages
  following conventional commits standard. `['git', 'commits', 'documentation', 'workflow']`

### Meta

Guidelines about rule creation, maintenance, and knowledge management.

- [`clinerules-best-practices`](./clinerules/clinerules-best-practices.md): Offers guidance on writing effective
  `.clinerules` for clarity, structure, and actionable content.
  `['meta', 'guideline', 'clinerules', 'documentation', 'best-practices']`
- [`clinerules-index`](./clinerules/clinerules-index.md): A unified index for cross-referencing and understanding
  interactions between different `.clinerules` files. `['index', 'cross-reference', 'clinerules-overview']`

### Website Development Guides

Guides specific to web development across different frameworks.

- [`web-design-bank`](./clinerules/web-design-bank.md): Resource for web design principles and practices, maintaining a
  consistent UI/UX design system across sessions. `['web-design', 'ui', 'ux', 'resource']`

### MCP Servers

Details about installed Model Context Protocol (MCP) servers that extend Cline's capabilities with additional tools and
resources.

- **Sequential Thinking (`github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking`)**: Provides the
  'sequentialthinking' tool for dynamic and reflective problem-solving. This tool aids in breaking down complex problems
  into iterative steps, allowing for hypothesis generation and verification. It is particularly useful for multi-step
  tasks and maintaining context over multiple interactions. `['mcp', 'sequential-thinking', 'problem-solving']`
- **Context7 (`github.com/upstash/context7-mcp`)**: Offers tools like 'resolve-library-id' and 'get-library-docs' for
  accessing up-to-date documentation and library information. This server is essential for retrieving
  Context7-compatible library IDs and detailed documentation, enhancing research and integration capabilities.
  `['mcp', 'context7', 'documentation', 'library']`

---

## Memory Bank Integration

### Key Commands

- **initialize memory bank**: Use when starting a new project

  ```bash
  # Creates initial Memory Bank structure
  # Generates base documentation files
  # Sets up version tracking
  ```

- **follow your custom instructions**: Read Memory Bank files and continue work

  ```bash
  # Loads all Memory Bank files
  # Understands current context
  # Maintains continuity
  ```

- **update memory bank**: Trigger full documentation review

  ```bash
  # Reviews all files
  # Updates documentation
  # Synchronizes information
  ```

### Mode Selection

- **PLAN MODE**: Information gathering and solution architecture

  - Review documentation
  - Ask questions
  - Create detailed plans
  - Get user approval

- **ACT MODE**: Implementation and execution
  - Execute planned changes
  - Update documentation
  - Verify results
  - Track progress

---

## Usage Examples

1. Starting a New Project:

   ```bash
   User: initialize memory bank
   Cline: *Creates Memory Bank structure*
   User: *Provides project requirements*
   Cline: *Sets up initial documentation*
   ```

2. Continuing Work:

   ```bash
   User: follow your custom instructions
   Cline: *Reads Memory Bank*
   User: *Provides task*
   Cline: *Continues with context*
   ```

3. Updating Documentation:

   ```bash
   User: update memory bank
   Cline: *Reviews all files*
   Cline: *Updates documentation*
   User: *Verifies changes*
   ```

---

## Troubleshooting

### Common Issues

1. Incomplete context loading

   - Solution: Use "follow your custom instructions"
   - Verify Memory Bank files exist

2. Mode confusion

   - Solution: Explicitly state needed mode
   - Check current mode in environment details

3. Documentation sync issues
   - Solution: Use "update memory bank"
   - Verify file modifications

### Best Practices

1. Regular Memory Bank updates
2. Clear mode transitions
3. Explicit command usage
4. Version control integration
5. Regular validation checks
