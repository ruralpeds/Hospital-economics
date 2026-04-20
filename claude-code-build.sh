#!/bin/bash

# ============================================================================
# Claude Code Build Manager - Command Line Interface
# 
# Manages the Rural Hospital Economics v0.2.0 agentic build workflow
# 
# Usage:
#   ./claude-code-build.sh next          # Show next task
#   ./claude-code-build.sh current       # Show current task details  
#   ./claude-code-build.sh progress      # Show build progress
#   ./claude-code-build.sh prompt        # Show Claude Code prompt
#   ./claude-code-build.sh done <id>     # Mark task as completed
#   ./claude-code-build.sh list          # List all tasks
#   ./claude-code-build.sh help          # Show help
# ============================================================================

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# State file
STATE_FILE=".claude-code/.build-state"

# Initialize state if not exists
initialize_state() {
    if [ ! -f "$STATE_FILE" ]; then
        mkdir -p .claude-code
        cat > "$STATE_FILE" << 'EOF'
CURRENT_WEEK=1
CURRENT_TASK=1.1
COMPLETED_TASKS=""
IN_PROGRESS_TASKS=""
EOF
    fi
    source "$STATE_FILE"
}

# Save state
save_state() {
    cat > "$STATE_FILE" << EOF
CURRENT_WEEK=$CURRENT_WEEK
CURRENT_TASK=$CURRENT_TASK
COMPLETED_TASKS="$COMPLETED_TASKS"
IN_PROGRESS_TASKS="$IN_PROGRESS_TASKS"
EOF
}

# Task definitions
declare -A TASKS=(
    # Week 1
    ["1.1"]="ServiceLineTypes.jl|Create data structures for service line analysis|src/episode/ServiceLineTypes.jl"
    ["1.2"]="ServiceLineCostAllocation.jl|Implement cost allocation to service lines|src/episode/ServiceLineCostAllocation.jl"
    ["1.3"]="ServiceLineMetrics.jl|Calculate profitability metrics|src/episode/ServiceLineMetrics.jl"
    
    # Week 2
    ["2.1"]="Benchmarking.jl|Load and compare against rural hospital benchmarks|src/episode/Benchmarking.jl"
    ["2.2"]="HospitalClustering.jl|Match hospitals to similar cohorts|src/episode/HospitalClustering.jl"
    
    # Week 3
    ["3.1"]="Complete Example|Create full working example with real hospital data|examples/05_service_line_profitability.jl"
    ["3.2"]="Integration Tests|Test integration of all components|test/test_integration.jl"
    
    # Week 4
    ["4.1"]="User Documentation|Write guide for rural hospital users|docs/SERVICE_LINE_GUIDE.md"
    ["4.2"]="Coverage & Polish|Achieve >90% test coverage and clean up|N/A"
)

# Task order
TASK_ORDER=("1.1" "1.2" "1.3" "2.1" "2.2" "3.1" "3.2" "4.1" "4.2")

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║  Rural Hospital Economics - v0.2.0 Build Manager              ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_task() {
    local task_id=$1
    local task_info="${TASKS[$task_id]}"
    local name=$(echo "$task_info" | cut -d'|' -f1)
    local desc=$(echo "$task_info" | cut -d'|' -f2)
    local file=$(echo "$task_info" | cut -d'|' -f3)
    local week=$(echo "$task_id" | cut -d'.' -f1)
    
    echo -e "${BLUE}[Task $task_id - Week $week]${NC} $name"
    echo "  Description: $desc"
    echo "  File: $file"
    echo ""
}

show_next_task() {
    print_header
    echo "📋 Next Task:"
    echo ""
    print_task "$CURRENT_TASK"
}

show_current_task() {
    print_header
    echo "📌 Current Task: $CURRENT_TASK"
    echo ""
    print_task "$CURRENT_TASK"
    
    local task_info="${TASKS[$CURRENT_TASK]}"
    local name=$(echo "$task_info" | cut -d'|' -f1)
    
    echo "🎯 Claude Code Prompt:"
    echo ""
    echo "---"
    echo "Create $(echo "$task_info" | cut -d'|' -f3) for:"
    echo "$(echo "$task_info" | cut -d'|' -f2)"
    echo ""
    echo "Reference: .claude-code/BUILD_PLAN.md"
    echo "Pattern: Look at src/health_economics/QALY.jl"
    echo "Test: Write comprehensive unit tests"
    echo "---"
    echo ""
}

show_progress() {
    print_header
    
    local total=${#TASK_ORDER[@]}
    local completed=0
    
    if [ ! -z "$COMPLETED_TASKS" ]; then
        completed=$(echo "$COMPLETED_TASKS" | tr ',' '\n' | wc -l)
    fi
    
    local percent=$((completed * 100 / total))
    
    echo "📊 Build Progress"
    echo ""
    echo "  Week: $CURRENT_WEEK/4"
    echo "  Current Task: $CURRENT_TASK"
    echo "  Completed: $completed/$total tasks ($percent%)"
    echo ""
    
    # Progress bar
    local filled=$((percent / 10))
    local empty=$((10 - filled))
    echo -n "  ["
    for ((i=0; i<filled; i++)); do echo -n "█"; done
    for ((i=0; i<empty; i++)); do echo -n "░"; done
    echo "]"
    echo ""
}

show_prompt() {
    print_header
    
    local task_info="${TASKS[$CURRENT_TASK]}"
    local name=$(echo "$task_info" | cut -d'|' -f1)
    local file=$(echo "$task_info" | cut -d'|' -f3)
    local task_id=$CURRENT_TASK
    
    echo "💬 Prompt for Claude Code:"
    echo ""
    echo "---"
    
    if [ "$task_id" == "1.1" ]; then
        echo "Create $file with data structures:"
        echo ""
        echo "Required:"
        echo "- ServiceLine struct"
        echo "- ServiceLineAnalysisResult struct"
        echo "- Validation functions"
        echo "- Full docstrings"
        echo ""
        echo "Then write test/test_service_line_types.jl"
        
    elif [ "$task_id" == "1.2" ]; then
        echo "Create $file with cost allocation:"
        echo ""
        echo "Required functions:"
        echo "- allocate_direct_costs()"
        echo "- allocate_indirect_costs_proportional()"
        echo "- allocate_indirect_costs_activitybased()"
        echo "- allocate_indirect_costs_stepdown()"
        echo ""
        echo "Reference: src/health_economics/QALY.jl"
        
    elif [ "$task_id" == "3.1" ]; then
        echo "Create complete working example:"
        echo ""
        echo "Must include:"
        echo "1. Load hospital financial data"
        echo "2. Allocate costs"
        echo "3. Calculate margins"
        echo "4. Compare benchmarks"
        echo "5. Generate recommendations"
        
    else
        echo "Task $task_id: $name"
        echo "$(echo "$task_info" | cut -d'|' -f2)"
    fi
    
    echo ""
    echo "---"
    echo ""
    echo "Then ask Claude Code to test and verify implementation."
    echo ""
}

list_all_tasks() {
    print_header
    echo "📋 All Tasks for v0.2.0"
    echo ""
    
    local current_week=1
    for task_id in "${TASK_ORDER[@]}"; do
        local week=$(echo "$task_id" | cut -d'.' -f1)
        
        if [ "$week" != "$current_week" ]; then
            current_week=$week
            echo ""
            echo "📅 Week $current_week"
            echo ""
        fi
        
        local status="○"
        if [[ "$COMPLETED_TASKS" == *"$task_id"* ]]; then
            status="✓"
        elif [ "$task_id" == "$CURRENT_TASK" ]; then
            status="▶"
        fi
        
        local name=$(echo "${TASKS[$task_id]}" | cut -d'|' -f1)
        echo "  $status [$task_id] $name"
    done
    echo ""
}

mark_done() {
    local task_id=$1
    
    if [ -z "$task_id" ]; then
        echo -e "${RED}✗ Please specify task ID (e.g., 1.1)${NC}"
        return 1
    fi
    
    if [ ! ${TASKS[$task_id]+_} ]; then
        echo -e "${RED}✗ Task $task_id not found${NC}"
        return 1
    fi
    
    # Add to completed
    if [[ "$COMPLETED_TASKS" != *"$task_id"* ]]; then
        if [ -z "$COMPLETED_TASKS" ]; then
            COMPLETED_TASKS="$task_id"
        else
            COMPLETED_TASKS="$COMPLETED_TASKS,$task_id"
        fi
    fi
    
    # Move to next task
    local current_index=-1
    for i in "${!TASK_ORDER[@]}"; do
        if [[ "${TASK_ORDER[$i]}" == "$task_id" ]]; then
            current_index=$i
            break
        fi
    done
    
    if [ $current_index -ge 0 ] && [ $current_index -lt $((${#TASK_ORDER[@]} - 1)) ]; then
        CURRENT_TASK="${TASK_ORDER[$((current_index + 1))]}"
        CURRENT_WEEK=$(echo "$CURRENT_TASK" | cut -d'.' -f1)
    fi
    
    save_state
    
    echo -e "${GREEN}✓ Task $task_id marked as completed${NC}"
    echo -e "${GREEN}✓ Next task: $CURRENT_TASK${NC}"
}

show_help() {
    echo ""
    echo "Claude Code Build Manager - Commands"
    echo ""
    echo "  next              Show next task to build"
    echo "  current           Show current task with details"
    echo "  progress          Show build progress"
    echo "  prompt            Show Claude Code prompt for current task"
    echo "  done <task_id>    Mark task as completed (e.g., done 1.1)"
    echo "  list              List all tasks"
    echo "  help              Show this help"
    echo ""
    echo "Example workflow:"
    echo "  1. ./claude-code-build.sh current          # See what to build"
    echo "  2. ./claude-code-build.sh prompt           # Get prompt"
    echo "  3. (Copy prompt into Claude Code)"
    echo "  4. ./claude-code-build.sh done 1.1         # Mark complete"
    echo "  5. ./claude-code-build.sh next             # See next task"
    echo ""
}

# Main
initialize_state

case "${1:-help}" in
    next)
        show_next_task
        ;;
    current)
        show_current_task
        ;;
    progress)
        show_progress
        ;;
    prompt)
        show_prompt
        ;;
    done)
        mark_done "$2"
        ;;
    list)
        list_all_tasks
        ;;
    help)
        show_help
        ;;
    *)
        show_help
        ;;
esac
