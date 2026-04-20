# Claude Code Build Automation Scripts — Complete Guide

## Overview

You now have **two complementary scripts** to automate and manage your agentic build:

1. **`claude-code-build.sh`** — Command-line task manager (bash)
2. **`claude-code-build-manager.jl`** — Interactive Julia build manager

Together, they help you:
- Stay organized during the 4-week build
- Generate prompts for Claude Code automatically
- Track progress
- Know what to build each day
- Manage commit workflow

---

## 🚀 Quick Start

### Option A: Command Line (Recommended for most workflows)

```bash
# Make script executable
chmod +x claude-code-build.sh

# See next task
./claude-code-build.sh next

# See current task with details
./claude-code-build.sh current

# Get prompt for Claude Code
./claude-code-build.sh prompt

# Mark task as completed
./claude-code-build.sh done 1.1

# See all tasks
./claude-code-build.sh list

# Show progress
./claude-code-build.sh progress
```

### Option B: Interactive Julia Menu

```bash
# Run Julia build manager
julia claude-code-build-manager.jl

# Choose from interactive menu:
# 1. Show all tasks by week
# 2. Show current task
# 3. Show build progress
# 4. Show week summary
# 5. Show Claude Code prompt
# etc.
```

---

## 📋 Recommended Daily Workflow

### Morning

```bash
# See what needs to be built today
./claude-code-build.sh current

# Copy the Claude Code prompt it shows
./claude-code-build.sh prompt

# Start Claude Code
claude-code start
```

### During Development

**In Claude Code, paste the prompt you got from the script.**

Example prompt from script:
```
Create src/episode/ServiceLineTypes.jl with data structures:

Required:
- ServiceLine struct
- ServiceLineAnalysisResult struct
- Validation functions
- Full docstrings

Then write test/test_service_line_types.jl
```

Claude Code will:
1. Create the files
2. Implement the functions
3. Write tests
4. Run and verify

### End of Day

```bash
# After Claude Code completes the task, mark it done
./claude-code-build.sh done 1.1

# This automatically:
# - Marks task 1.1 as completed
# - Moves to next task (1.2)
# - Updates progress

# See what's next
./claude-code-build.sh next

# Commit your work
git status
git add .
git commit -m "feat: implement ServiceLineTypes (task 1.1)"
```

---

## 💬 Example Workflow Day 1

### Morning: Get Task
```bash
$ ./claude-code-build.sh current

╔════════════════════════════════════════════════════════════════╗
║  Rural Hospital Economics - v0.2.0 Build Manager              ║
╚════════════════════════════════════════════════════════════════╝

📌 Current Task: 1.1

[Task 1.1 - Week 1] ServiceLineTypes.jl
  Description: Create data structures for service line analysis
  File: src/episode/ServiceLineTypes.jl

🎯 Claude Code Prompt:

---
Create src/episode/ServiceLineTypes.jl for:
Create data structures for service line analysis

Reference: .claude-code/BUILD_PLAN.md
Pattern: Look at src/health_economics/QALY.jl
Test: Write comprehensive unit tests
---
```

### Get Detailed Prompt
```bash
$ ./claude-code-build.sh prompt

💬 Prompt for Claude Code:

---
Create src/episode/ServiceLineTypes.jl with data structures:

Required:
- ServiceLine struct
- ServiceLineAnalysisResult struct
- Validation functions
- Full docstrings

Then write test/test_service_line_types.jl

---

Then ask Claude Code to test and verify implementation.
```

### Launch Claude Code
```bash
$ claude-code start
```

Paste the prompt into Claude Code. It will create the files and tests.

### End of Day: Mark Complete
```bash
$ ./claude-code-build.sh done 1.1

✓ Task 1.1 marked as completed
✓ Next task: 1.2

$ ./claude-code-build.sh next

📋 Next Task:

[Task 1.2 - Week 1] ServiceLineCostAllocation.jl
  Description: Implement cost allocation to service lines
  File: src/episode/ServiceLineCostAllocation.jl
```

---

## 📊 Tracking Progress

### During the Day
```bash
# Quick progress check
./claude-code-build.sh progress

📊 Build Progress

  Week: 1/4
  Current Task: 1.1
  Completed: 0/9 tasks (0%)

  [░░░░░░░░░░]
```

### After Completing Tasks
```bash
./claude-code-build.sh progress

📊 Build Progress

  Week: 1/4
  Current Task: 1.2
  Completed: 1/9 tasks (11%)

  [█░░░░░░░░░]
```

### List All Tasks
```bash
./claude-code-build.sh list

📋 All Tasks for v0.2.0

📅 Week 1

  ✓ [1.1] ServiceLineTypes.jl
  ▶ [1.2] ServiceLineCostAllocation.jl
  ○ [1.3] ServiceLineMetrics.jl

📅 Week 2

  ○ [2.1] Benchmarking.jl
  ○ [2.2] HospitalClustering.jl

...
```

---

## 🎓 Task Breakdown by Script

### `claude-code-build.sh` (Command Line)

**When to use:**
- Quick checks throughout the day
- Getting prompts to paste into Claude Code
- Marking tasks complete
- Checking progress

**Key commands:**
```bash
./claude-code-build.sh next       # What's next?
./claude-code-build.sh prompt     # Get Claude Code prompt
./claude-code-build.sh done 1.1   # Mark complete
./claude-code-build.sh progress   # Check progress
```

### `claude-code-build-manager.jl` (Interactive Julia)

**When to use:**
- Detailed interactive planning
- Reviewing week-by-week breakdown
- Getting detailed information
- Exploring the full build plan

**Start it:**
```bash
julia claude-code-build-manager.jl
```

**Menu options:**
```
1. Show all tasks by week
2. Show current task
3. Show build progress
4. Show week summary
5. Show Claude Code prompt
6. Mark task as completed
7. Show instructions
8. Exit
```

---

## 🔄 Complete Weekly Cycle

### Week 1: Core Service Line Module

**Monday-Wednesday:**
- Task 1.1: ServiceLineTypes.jl
- Task 1.2: ServiceLineCostAllocation.jl
- Task 1.3: ServiceLineMetrics.jl

**Thursday-Friday:**
- Run comprehensive tests
- Verify integration
- Commit all changes

### Week 2: Benchmarking

**Monday-Wednesday:**
- Task 2.1: Benchmarking.jl
- Task 2.2: HospitalClustering.jl

**Thursday-Friday:**
- Integration testing
- Commit changes

### Week 3: Examples & Integration

**Monday-Tuesday:**
- Task 3.1: Complete example
- Task 3.2: Integration tests

**Wednesday-Friday:**
- Test everything together
- Verify real-world scenarios

### Week 4: Polish & Release

**Monday-Wednesday:**
- Task 4.1: Documentation
- Task 4.2: Coverage & Polish

**Thursday-Friday:**
- Final testing
- Ready for v0.2.0 release

---

## 💾 How Progress Is Saved

The script uses `.claude-code/.build-state` to track:
```
CURRENT_WEEK=1
CURRENT_TASK=1.1
COMPLETED_TASKS="1.1,1.2"
IN_PROGRESS_TASKS=""
```

This persists across sessions, so:
- You can close Claude Code and resume later
- Progress is automatically saved
- No manual state management needed

---

## 🎯 Integration with Git

Each day, after marking a task complete:

```bash
# See what changed
git status

# Add your work
git add .

# Commit with task reference
git commit -m "feat: implement ServiceLineTypes (task 1.1)

- Define ServiceLine struct with all required fields
- Add ServiceLineAnalysisResult type
- Include validation for financial data
- Add comprehensive docstrings
- Write unit tests with >90% coverage

Task: 1.1
Week: 1"
```

---

## 🚨 If You Get Stuck

### Script won't run
```bash
# Make script executable
chmod +x claude-code-build.sh

# Run it
./claude-code-build.sh next
```

### Forget what to build
```bash
# See current task
./claude-code-build.sh current

# Get prompt to paste
./claude-code-build.sh prompt
```

### Lost progress
Check `.claude-code/.build-state`:
```bash
cat .claude-code/.build-state
```

### Want to reset
Delete state file and restart:
```bash
rm .claude-code/.build-state
./claude-code-build.sh next  # Reinitializes
```

---

## 📞 Helpful Tips

### 1. Use aliases for speed
```bash
alias build="./claude-code-build.sh"

# Then use:
build current
build prompt
build done 1.1
```

### 2. Combine with Julia testing
```bash
# Get next task
./claude-code-build.sh next

# Start Claude Code
claude-code start

# (Claude Code completes task)

# Run tests
jl-test

# Mark complete
./claude-code-build.sh done 1.1
```

### 3. Check progress daily
```bash
# Add to morning routine
./claude-code-build.sh progress
./claude-code-build.sh current
```

### 4. Keep a daily log
```bash
# Log progress
./claude-code-build.sh progress >> daily-log.txt
date >> daily-log.txt
```

---

## 🌟 Success Workflow

**This is the recommended workflow for maximum productivity:**

### Each Morning (5 minutes)
```bash
./claude-code-build.sh progress      # See overall progress
./claude-code-build.sh current       # See task details
./claude-code-build.sh prompt        # Copy prompt
claude-code start                    # Start Claude Code
```

### Each Evening (5 minutes)
```bash
jl-test                              # Run tests
./claude-code-build.sh done 1.1      # Mark complete
git commit -m "..."                  # Commit work
./claude-code-build.sh next          # See what's next
```

### Weekly (Friday)
```bash
./claude-code-build.sh list          # Review week
./claude-code-build.sh progress      # Check overall progress
git log --oneline                    # Review commits
```

---

## 📈 Expected Progress

| Week | Tasks | Status | Output |
|------|-------|--------|--------|
| 1 | 1.1, 1.2, 1.3 | Core module complete | Service line types, cost allocation |
| 2 | 2.1, 2.2 | Benchmarking complete | Comparison framework |
| 3 | 3.1, 3.2 | Integration complete | Working example |
| 4 | 4.1, 4.2 | Release ready | v0.2.0 production |

---

## 🎉 Final Notes

These scripts make your agentic build with Claude Code:
- ✅ Organized
- ✅ Trackable
- ✅ Repeatable
- ✅ Documented
- ✅ Automated

**You're ready to build v0.2.0!** 🚀

---

## Quick Reference Card

```bash
# Start build
chmod +x claude-code-build.sh
./claude-code-build.sh current

# Get prompt for Claude Code
./claude-code-build.sh prompt

# After Claude Code finishes
jl-test                    # Run tests
./claude-code-build.sh done 1.1   # Mark complete

# See progress
./claude-code-build.sh progress    # Overall progress
./claude-code-build.sh list        # All tasks
./claude-code-build.sh next        # What's next?

# Commit work
git add .
git commit -m "feat: task 1.1 complete"
```

**Repeat for 4 weeks → v0.2.0 production ready! 🎯**

