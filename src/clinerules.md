# ClineRules Instructions

---

This document provides a categorized overview of all Cline rules, covering both global rules defined in the central
`.clinerules/` directory and any workspace-specific rules that may exist in individual projects. It serves as a quick
reference for understanding the scope and purpose of each rule.

## Categories

### Core Behaviors

Rules related to Cline's fundamental operational protocols and identity.

- [`core-operational-principles`](./clinerules/core-operational-principles.md): Defines Cline's core operational rules,
  collaborative approach, and the Baby Steps™ Methodology which emphasizes incremental progress, process documentation,
  and validation at every step. `['core-behavior', 'protocol', 'incremental-progress', 'baby-steps']`
- [`identity-capabilities-and-quality`](./clinerules/identity-capabilities-and-quality.md): Establishes Cline's identity
  as an autonomous software engineering agent, detailing core competencies, operational principles, quality standards,
  and best practices across various domains.
  `['identity', 'autonomous-agent', 'software-engineering', 'quality-standards', 'core-behavior']`
- [`knowledge-and-context-management`](./clinerules/knowledge-and-context-management.md): Describes Cline's Knowledge
  Management System and Memory Bank for maintaining project knowledge across sessions, including file structures,
  maintenance protocols, and continuous improvement processes.
  `['knowledge-management', 'context-preservation', 'memory-bank', 'continuous-improvement', 'core-behavior']`

### Development Practices

Technical and architectural guidelines for development practices.

- [`development-practices`](./clinerules/development-practices.md): Comprehensive guide for development practices
  including version control with conventional commits, testing strategies, documentation standards, code quality,
  security best practices, performance optimization, CI/CD, and accessibility.
  `['version-control', 'testing', 'documentation', 'best-practices', 'security', 'reliability']`
- [`identity-capabilities-and-quality`](./clinerules/identity-capabilities-and-quality.md): Includes detailed quality
  standards for software architecture, code maintainability, security, reliability, development processes,
  collaboration, persistence, and problem-solving approaches.
  `['software-engineering', 'architecture', 'code-quality', 'collaboration', 'security', 'reliability']`

### Workflows

Rules governing task management and operational workflows.

- [`new-task-workflow`](./clinerules/new-task-workflow.md): Provides mandatory instructions for task breakdown, handoff
  strategies, and context window management to ensure continuity and efficient task completion across sessions.
  `['context-management', 'new-task', 'workflow', 'task-handoff']`
- [`product-development-task-management`](./clinerules/product-development-task-management.md): Outlines the complete
  product development lifecycle from understanding user needs and creating PRDs to task generation, execution, and
  project optimization.
  `['product-management', 'requirements', 'development-lifecycle', 'task-management', 'documentation']`

### Product Development & Task Management

Comprehensive guide for the entire product development lifecycle.

- [`product-development-task-management`](./clinerules/product-development-task-management.md): Defines Cline's role as
  a product manager and engineer, covering project initialization, user needs analysis, PRD creation, task execution,
  and best practices for product development and task management.
  `['product-management', 'requirements', 'development-lifecycle', 'task-management', 'documentation']`

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
