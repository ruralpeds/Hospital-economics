# ============================================================================
# Rural Hospital Economics Platform - Claude Code Build Manager
# 
# This script manages the agentic build workflow for v0.2.0
# Run this in Claude Code CLI to automate task management and progress tracking
#
# Usage: julia claude-code-build-manager.jl
# ============================================================================

using Dates

# Build task structure
struct BuildTask
    id::String
    name::String
    description::String
    files::Vector{String}
    tests::Vector{String}
    status::String  # "pending", "in_progress", "completed", "blocked"
    week::Int
    priority::Int
end

# Initialize all tasks for v0.2.0
const TASKS = [
    # Week 1: Core Service Line Module
    BuildTask(
        "1.1", 
        "ServiceLineTypes.jl",
        "Create data structures for service line analysis",
        ["src/episode/ServiceLineTypes.jl"],
        ["test/test_service_line_types.jl"],
        "pending",
        1,
        1
    ),
    BuildTask(
        "1.2",
        "ServiceLineCostAllocation.jl",
        "Implement cost allocation to service lines",
        ["src/episode/ServiceLineCostAllocation.jl"],
        ["test/test_cost_allocation.jl"],
        "pending",
        1,
        2
    ),
    BuildTask(
        "1.3",
        "ServiceLineMetrics.jl",
        "Calculate profitability metrics",
        ["src/episode/ServiceLineMetrics.jl"],
        ["test/test_service_line_metrics.jl"],
        "pending",
        1,
        3
    ),
    
    # Week 2: Benchmarking & Comparison
    BuildTask(
        "2.1",
        "Benchmarking Framework",
        "Load and compare against rural hospital benchmarks",
        ["src/episode/Benchmarking.jl"],
        ["test/test_benchmarking.jl"],
        "pending",
        2,
        1
    ),
    BuildTask(
        "2.2",
        "Hospital Clustering",
        "Match hospitals to similar cohorts",
        ["src/episode/HospitalClustering.jl"],
        ["test/test_clustering.jl"],
        "pending",
        2,
        2
    ),
    
    # Week 3: Examples & Integration
    BuildTask(
        "3.1",
        "Complete Example",
        "Create full working example with real hospital data",
        ["examples/05_service_line_profitability.jl"],
        [],
        "pending",
        3,
        1
    ),
    BuildTask(
        "3.2",
        "Integration Tests",
        "Test integration of all components",
        [],
        ["test/test_integration.jl"],
        "pending",
        3,
        2
    ),
    
    # Week 4: Documentation & Polish
    BuildTask(
        "4.1",
        "User Documentation",
        "Write guide for rural hospital users",
        ["docs/SERVICE_LINE_GUIDE.md"],
        [],
        "pending",
        4,
        1
    ),
    BuildTask(
        "4.2",
        "Coverage & Polish",
        "Achieve >90% test coverage and clean up",
        [],
        [],
        "pending",
        4,
        2
    ),
]

# Status tracking
mutable struct BuildStatus
    tasks::Vector{BuildTask}
    start_date::Date
    current_week::Int
    completed_tasks::Int
    in_progress_tasks::Int
end

function BuildStatus()
    BuildStatus(TASKS, today(), 1, 0, 0)
end

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

function print_header()
    println("\n" * "="^76)
    println("  Rural Hospital Economics Platform - v0.2.0 Build Manager")
    println("="^76 * "\n")
end

function print_task(task::BuildTask)
    status_icon = if task.status == "completed"
        "✓"
    elseif task.status == "in_progress"
        "▶"
    elseif task.status == "blocked"
        "✗"
    else
        "○"
    end
    
    println("  $status_icon [$task.priority] Task $task.id (Week $task.week): $task.name")
    println("     $task.description")
    if !isempty(task.files)
        println("     Files: $(join(task.files, ", "))")
    end
    println()
end

function print_tasks_by_week()
    print_header()
    
    for week in 1:4
        week_tasks = filter(t -> t.week == week, TASKS)
        if !isempty(week_tasks)
            println("📅 WEEK $week TASKS\n")
            for task in sort(week_tasks, by=t->t.priority)
                print_task(task)
            end
            println()
        end
    end
end

function print_current_task(status::BuildStatus)
    print_header()
    println("📋 CURRENT TASK (Week $(status.current_week))\n")
    
    week_tasks = filter(t -> t.week == status.current_week, status.tasks)
    pending = filter(t -> t.status == "pending", week_tasks)
    
    if !isempty(pending)
        task = first(sort(pending, by=t->t.priority))
        print_task(task)
        
        println("\n🎯 NEXT STEP:\n")
        println("Tell Claude Code:\n")
        println("\"\"\"")
        println("Create $(first(task.files)):")
        println(task.description)
        println()
        println("Reference: .claude-code/BUILD_PLAN.md")
        println("Pattern: Look at src/health_economics/QALY.jl for structure")
        println("\"\"\"")
    else
        println("✅ All tasks for Week $status.current_week completed!")
        println("\nMove to next week? (Not automated - update script manually)")
    end
end

function print_progress(status::BuildStatus)
    print_header()
    
    completed = count(t -> t.status == "completed", status.tasks)
    total = length(status.tasks)
    percent = round(Int, (completed / total) * 100)
    
    println("📊 BUILD PROGRESS\n")
    println("  Completed: $completed/$total tasks ($percent%)")
    println("  Current Week: $(status.current_week)")
    println("  Progress: ", "█"^(percent ÷ 10), "░"^(10 - percent ÷ 10))
    println()
    
    # Count by status
    by_status = Dict(
        "completed" => count(t -> t.status == "completed", status.tasks),
        "in_progress" => count(t -> t.status == "in_progress", status.tasks),
        "pending" => count(t -> t.status == "pending", status.tasks),
        "blocked" => count(t -> t.status == "blocked", status.tasks),
    )
    
    println("  Status Breakdown:")
    println("    ✓ Completed:   $(by_status["completed"])")
    println("    ▶ In Progress: $(by_status["in_progress"])")
    println("    ○ Pending:     $(by_status["pending"])")
    println("    ✗ Blocked:     $(by_status["blocked"])")
    println()
end

function print_week_summary(week::Int)
    print_header()
    println("📅 WEEK $week SUMMARY\n")
    
    week_tasks = filter(t -> t.week == week, TASKS)
    
    for task in sort(week_tasks, by=t->t.priority)
        status = task.status == "completed" ? "✓" : "○"
        println("  $status Task $(task.id): $(task.name)")
    end
    println()
end

function print_claude_code_prompt(task::BuildTask)
    print_header()
    println("💬 PROMPT FOR CLAUDE CODE\n")
    println("Copy and paste this into Claude Code:\n")
    println("---")
    println()
    
    if task.id == "1.1"
        println("Create $(first(task.files)) with the data structures from .claude-code/BUILD_PLAN.md:")
        println()
        println("Required:")
        println("- ServiceLine struct with fields: id, name, department, drg_codes, volume, revenue, direct_cost, allocated_indirect_cost")
        println("- ServiceLineAnalysisResult struct with fields: service_lines, total_margin, margin_by_service, cost_drivers, recommendations")
        println("- Full docstrings explaining rural hospital context")
        println("- Validation functions for financial constraints")
        println()
        println("Then write test/test_service_line_types.jl with comprehensive tests.")
        
    elseif task.id == "1.2"
        println("Create $(first(task.files)) with cost allocation functions:")
        println()
        println("Required functions:")
        println("- allocate_direct_costs() - allocate by department")
        println("- allocate_indirect_costs_proportional() - proportional allocation")
        println("- allocate_indirect_costs_activitybased() - activity-based allocation")
        println("- allocate_indirect_costs_stepdown() - step-down allocation")
        println("- calculate_margins() - compute profitability")
        println()
        println("Reference: src/health_economics/QALY.jl for design pattern")
        println("Write tests in test/test_cost_allocation.jl")
        
    elseif task.id == "1.3"
        println("Create $(first(task.files)) with profitability metric functions:")
        println()
        println("Required functions:")
        println("- calculate_margin() - % margin by service")
        println("- calculate_contribution_margin() - contribution to overhead")
        println("- efficiency_metrics() - volume and cost per unit")
        println("- identify_outliers() - high/low cost services")
        println()
        println("Include examples for rural hospitals.")
        println("Write tests in test/test_service_line_metrics.jl")
        
    elseif task.id == "2.1"
        println("Create $(first(task.files)) with benchmarking functions:")
        println()
        println("Required:")
        println("- load_benchmark_data() - load rural hospital benchmarks")
        println("- benchmark_compare() - compare hospital to benchmarks")
        println("- calculate_variance() - identify cost differences")
        println("- generate_report() - create comparison report")
        println()
        println("Write tests in test/test_benchmarking.jl")
        
    elseif task.id == "3.1"
        println("Create $(first(task.files)) - a complete working example:")
        println()
        println("Must include:")
        println("1. Load realistic rural hospital financial data")
        println("2. Allocate costs to service lines")
        println("3. Calculate profitability by service")
        println("4. Compare against rural hospital benchmarks")
        println("5. Generate actionable recommendations")
        println("6. Show output formats (tables, summary, etc.)")
        println()
        println("Make it understandable for a hospital CFO.")
        
    else
        println("Task $(task.id): $(task.name)")
        println("$(task.description)")
        if !isempty(task.files)
            println("\nFiles: $(join(task.files, ", "))")
        end
    end
    
    println()
    println("---")
    println()
    println("Then ask Claude Code to:")
    println("1. Run tests: jl-test")
    println("2. Show test coverage")
    println("3. Verify implementation")
    println()
end

# ============================================================================
# INTERACTIVE MENU
# ============================================================================

function show_menu()
    println("\n" * "="^76)
    println("  BUILD MANAGER MENU")
    println("="^76 * "\n")
    println("1. Show all tasks by week")
    println("2. Show current task")
    println("3. Show build progress")
    println("4. Show week summary")
    println("5. Show Claude Code prompt for current task")
    println("6. Mark task as completed")
    println("7. Show instructions")
    println("8. Exit")
    println()
    print("Choose option (1-8): ")
end

function mark_task_completed()
    print_header()
    println("Complete which task? (e.g., '1.1', '1.2', etc.)\n")
    print("Task ID: ")
    task_id = readline()
    
    idx = findfirst(t -> t.id == task_id, TASKS)
    if idx !== nothing
        TASKS[idx].status = "completed"
        println("\n✓ Task $task_id marked as completed!")
    else
        println("\n✗ Task not found")
    end
end

function show_instructions()
    print_header()
    println("📖 HOW TO USE BUILD MANAGER\n")
    println("1. Run this script: julia claude-code-build-manager.jl")
    println("2. Choose 'Show current task' (option 2)")
    println("3. Get the Claude Code prompt (option 5)")
    println("4. Copy prompt and paste into Claude Code")
    println("5. Claude Code will implement the feature")
    println("6. When done, mark task as completed (option 6)")
    println("7. Move to next task")
    println()
    println("💡 Tips:")
    println("- Always reference .claude-code/BUILD_PLAN.md")
    println("- Reference QALY.jl and ICER.jl for code patterns")
    println("- Write tests immediately after implementation")
    println("- Commit after each completed task")
    println()
end

# ============================================================================
# MAIN LOOP
# ============================================================================

function main()
    status = BuildStatus()
    
    while true
        show_menu()
        choice = readline()
        
        if choice == "1"
            print_tasks_by_week()
        elseif choice == "2"
            print_current_task(status)
        elseif choice == "3"
            print_progress(status)
        elseif choice == "4"
            print("\nWhich week? (1-4): ")
            week = parse(Int, readline())
            print_week_summary(week)
        elseif choice == "5"
            week_tasks = filter(t -> t.week == status.current_week, status.tasks)
            pending = filter(t -> t.status == "pending", week_tasks)
            if !isempty(pending)
                task = first(sort(pending, by=t->t.priority))
                print_claude_code_prompt(task)
            else
                println("\n✓ All tasks for week $(status.current_week) completed!")
            end
        elseif choice == "6"
            mark_task_completed()
        elseif choice == "7"
            show_instructions()
        elseif choice == "8"
            println("\n👋 Happy coding! Build v0.2.0! 🚀\n")
            break
        else
            println("\n✗ Invalid choice. Try again.\n")
        end
    end
end

# Run main menu if executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
