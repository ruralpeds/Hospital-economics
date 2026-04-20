# Claude Code CLI Guide - Rural Hospital Economics Agentic Build

## Overview

This guide shows you how to use the Claude Code CLI to conduct an agentic build of the Rural Hospital Economics Platform (HospitalFinanceToolbox.jl v0.2.0).

---

## 🚀 Quick Start (5 minutes)

### 1. Download Bootstrap Script
```bash
cd ~/Downloads
curl -O https://raw.githubusercontent.com/timothyhartzog/Hospital-economics/main/claude-code-start.sh
chmod +x claude-code-start.sh
```

Or copy from `/mnt/user-data/outputs/claude-code-start.sh`

### 2. Run Bootstrap
```bash
bash claude-code-start.sh
```

This will:
- Clone the GitHub repository
- Create `.claude-code/` directory with all instructions
- Create `dev_environment.sh` for easy development
- Set up Julia environment

### 3. Set Up Environment
```bash
cd ~/HospitalFinanceToolbox.jl
source dev_environment.sh
```

### 4. Start Claude Code
```bash
claude-code start
```

---

## 📋 What the Bootstrap Creates

After running `claude-code-start.sh`, you'll have:

```
.claude-code/
├── AGENTIC_START.md              ← Read first
├── BUILD_PLAN.md                 ← Detailed specs
├── IMMEDIATE_TASKS.md            ← Task checklist
└── CLAUDE_CODE_INSTRUCTIONS.md   ← How to develop

dev_environment.sh                 ← Load development environment
```

---

## 🎯 How to Use Claude Code for Development

### Step 1: Start Claude Code Session
```bash
cd ~/HospitalFinanceToolbox.jl
source dev_environment.sh
claude-code start
```

### Step 2: In Claude Code Interface
You have access to:
- Full project directory
- Git integration
- File creation/editing
- Command execution (bash, julia)
- Automatic testing

### Step 3: Follow the Plan

Read files in this order:
1. `.claude-code/AGENTIC_START.md` - Understand the goal
2. `.claude-code/BUILD_PLAN.md` - See detailed specifications
3. `.claude-code/IMMEDIATE_TASKS.md` - Get the task list

### Step 4: Start Building

Claude Code will help you:
- Create `src/episode/ServiceLineTypes.jl`
- Implement cost allocation functions
- Write comprehensive tests
- Generate examples
- Document for users

---

## 💬 How to Communicate with Claude Code

### Tell Claude Code What to Build

**Example conversation:**

**You:** 
> I need to build ServiceLineTypes.jl for service line profitability analysis. 
> Read BUILD_PLAN.md and create the required structs.

**Claude Code will:**
1. Read BUILD_PLAN.md
2. Understand the ServiceLine and ServiceLineAnalysisResult structs
3. Create the file with complete implementation
4. Add docstrings with rural hospital context

### Tell Claude Code to Test

**You:**
> Write unit tests for ServiceLineTypes.jl that validate all fields and edge cases.

**Claude Code will:**
1. Create test/test_service_line_types.jl
2. Write comprehensive test cases
3. Run tests to verify they pass

### Tell Claude Code to Reference Code

**You:**
> Look at src/health_economics/QALY.jl for design patterns and implement 
> ServiceLineCostAllocation.jl following the same structure.

**Claude Code will:**
1. Review QALY.jl patterns
2. Implement similar structure
3. Use same design principles

---

## 🔄 Development Workflow with Claude Code

### Iteration Cycle
```
1. Read specification (BUILD_PLAN.md)
   ↓
2. Ask Claude Code to implement
   ↓
3. Claude Code creates files
   ↓
4. Review implementation
   ↓
5. Ask Claude Code to improve/test
   ↓
6. Claude Code fixes and validates
   ↓
7. Commit when complete
```

### Example Session

**Message 1:**
```
Create src/episode/ServiceLineTypes.jl with:
- ServiceLine struct (fields: id, name, department, drg_codes, volume, revenue, direct_cost, allocated_indirect_cost)
- ServiceLineAnalysisResult struct (fields: service_lines, total_margin, margin_by_service, cost_drivers, recommendations)
- Full docstrings for rural hospital context
- Include validation

Reference: BUILD_PLAN.md in .claude-code/ directory
```

**Message 2:**
```
Create test/test_service_line_types.jl with tests for:
- Creating ServiceLine with valid data
- Validating financial constraints
- ServiceLineAnalysisResult aggregation
- Edge cases (zero volume, negative costs)

Reference pattern from test/runtests.jl
```

**Message 3:**
```
Implement src/episode/ServiceLineCostAllocation.jl with:
- allocate_direct_costs() - by department
- allocate_indirect_costs_proportional() 
- allocate_indirect_costs_activitybased()
- calculate_margins()

Look at QALY.jl for structure pattern.
Run tests after implementation.
```

---

## ✅ Daily Workflow

### Morning: Plan
```bash
cd ~/HospitalFinanceToolbox.jl
source dev_environment.sh
claude-code start
```

Tell Claude Code:
> What's next on IMMEDIATE_TASKS.md? Show me the priority list and let's start the first unchecked item.

### During Day: Build
```
Claude Code: Here are the top 3 unchecked tasks:
  [ ] ServiceLineTypes.jl - Core data structures
  [ ] Unit tests for types
  [ ] Documentation

Let's start with ServiceLineTypes.jl. I'll:
1. Create the file with all required structs
2. Add comprehensive docstrings
3. Include validation
4. Reference BUILD_PLAN.md for exact specs

Ready?
```

You: > Yes, create it with full docstrings and include examples for rural hospitals.

### End of Day: Commit
```bash
jl-test      # Verify tests pass
git status
git add .
git commit -m "feat: add ServiceLine types with complete tests"
```

---

## 🛠️ Common Claude Code Commands

### Create a File
**You:**
> Create `src/episode/ServiceLineMetrics.jl` with functions for:
> - calculate_margin(service_line)
> - calculate_contribution_margin(service_line)
> - efficiency_metrics(service_line)
>
> Follow the pattern in QALY.jl for structure and documentation.

### Modify Existing File
**You:**
> Update ServiceLineTypes.jl to add a `validate()` function that checks:
> - revenue > 0
> - volume > 0  
> - costs <= revenue
> Include helpful error messages for rural hospitals.

### Run Tests
**You:**
> Run the test suite with `jl-test` and show me:
> - Which tests pass/fail
> - Test coverage percentage
> - Any errors to fix

### Generate Examples
**You:**
> Create examples/05_service_line_profitability.jl showing:
> - Load hospital financial data
> - Allocate costs to service lines
> - Calculate margins
> - Compare to benchmarks
> - Generate recommendations
>
> Use realistic rural hospital data.

### Check Code Quality
**You:**
> Review ServiceLineCostAllocation.jl for:
> - Code structure and clarity
> - Documentation completeness
> - Test coverage
> - Any improvements needed

---

## 📊 Weekly Milestones

### Week 1: Core Module ✅
- ServiceLineTypes.jl complete
- Cost allocation implemented
- Unit tests >90% coverage
- All tests passing

**Claude Code Tasks:**
- Create types
- Implement allocations
- Write tests
- Validate accuracy

### Week 2: Metrics & Benchmarking ✅
- Profitability metrics calculated
- Benchmarking framework built
- Comparison working
- Tests expanded

**Claude Code Tasks:**
- Implement metrics
- Add benchmarking
- Expand tests
- Validate results

### Week 3: Examples & Integration ✅
- Complete example working
- Real hospital data loaded
- Integration verified
- Results validated

**Claude Code Tasks:**
- Create examples
- Load real data
- Integration testing
- Output validation

### Week 4: Polish & Release ✅
- >90% test coverage
- Full documentation
- User guide complete
- Production ready

**Claude Code Tasks:**
- Improve coverage
- Write guides
- Polish code
- Final validation

---

## 🎓 Key Instructions for Claude Code

### #1: Reference the Plan
Always tell Claude Code to:
> Reference .claude-code/BUILD_PLAN.md for the exact specifications.

### #2: Check Patterns
Always tell Claude Code to:
> Look at src/health_economics/QALY.jl for similar patterns before implementing.

### #3: Test First
Always tell Claude Code to:
> Write tests immediately after implementing each function.

### #4: Rural Hospital Context
Always tell Claude Code to:
> Include docstrings that explain how rural hospitals would use this.

### #5: Validate Assumptions
Always tell Claude Code to:
> Run tests and show me the results before moving to the next feature.

---

## 🚀 Success Checklist

By end of development, you should have:

```
✓ ServiceLineTypes.jl created and tested
✓ Cost allocation module complete
✓ Profitability metrics implemented
✓ Benchmarking framework built
✓ Complete example working
✓ >90% test coverage
✓ All tests passing
✓ Full documentation
✓ User guide written
✓ Ready for rural hospital pilots
```

---

## 💡 Tips for Working with Claude Code

1. **Be Specific**
   - Instead of: "Create the module"
   - Say: "Create ServiceLineTypes.jl with ServiceLine struct containing: id, name, department, drg_codes, volume, revenue, direct_cost. Add full docstrings for rural hospitals."

2. **Reference Specs**
   - Always point to BUILD_PLAN.md
   - Let Claude Code read the detailed requirements

3. **Test Often**
   - Ask Claude Code to test after each major feature
   - Verify coverage regularly

4. **Small Commits**
   - Ask Claude Code to commit small, focused changes
   - Use clear commit messages

5. **Ask for Improvements**
   - "Can you improve error handling?"
   - "Add better validation?"
   - "Make output more CFO-friendly?"

---

## 📞 When You Get Stuck

If Claude Code is confused:

1. **Clarify the Goal**
   > The goal is: Rural hospital CFO loads data, runs analysis, gets service line profitability in <2 hours.

2. **Point to Examples**
   > Look at src/health_economics/ICER.jl (lines 15-40) for how cost-effectiveness results are structured.

3. **Break Into Steps**
   > Step 1: Create the struct. Step 2: Add validation. Step 3: Write tests. Which step shall we do first?

4. **Share Context**
   > This is for rural hospitals which typically have 50-200 beds, high Medicare/Medicaid payer mix, and limited IT resources. Keep it simple and fast.

---

## 🎯 Final Thoughts

You're building something that matters:
- **Who:** Rural hospital CFOs and leaders
- **What:** Service line profitability analysis  
- **Why:** Rural healthcare sustainability depends on understanding which services make money
- **How:** Practical Julia tools they actually use

Claude Code can help you build this faster and better. Use these instructions to guide it effectively.

**Good luck! 🚀**

---

*Last updated: April 15, 2026*
