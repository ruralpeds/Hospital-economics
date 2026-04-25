"""
    undo_redo.jl — Command pattern implementation for undo/redo functionality

    Phase 7 Advanced Feature: Navigate parameter change history within a session.
    Supports multiple undo/redo with keyboard shortcuts (Ctrl+Z, Ctrl+Shift+Z).
"""

"""
    Command — Base type for undoable/redoable actions
"""
abstract type Command end

"""Execute a command — concrete subtypes must implement this method."""
function execute!(cmd::Command)::Nothing
    throw(StateError("Command", string(typeof(cmd)),
        "concrete subtype implementing execute!",
        "Abstract Command does not have a default execute! implementation"))
end

"""Undo a command — concrete subtypes must implement this method."""
function undo!(cmd::Command)::Nothing
    throw(StateError("Command", string(typeof(cmd)),
        "concrete subtype implementing undo!",
        "Abstract Command does not have a default undo! implementation"))
end

"""Description of the command for UI display — concrete subtypes must implement this method."""
function description(cmd::Command)::String
    throw(StateError("Command", string(typeof(cmd)),
        "concrete subtype implementing description",
        "Abstract Command does not have a default description implementation"))
end

"""
    ParameterChangeCommand — Command for parameter value changes
"""
@kwdef struct ParameterChangeCommand <: Command
    param_name::String
    old_value::Any
    new_value::Any
    timestamp::DateTime = now()
    state_ref::Ref{Any} = Ref(Dict())  # Reference to shared state dict
end

"""Execute parameter change"""
function execute!(cmd::ParameterChangeCommand)
    state = cmd.state_ref[]
    if isa(state, Dict)
        state[cmd.param_name] = cmd.new_value
    end
end

"""Undo parameter change"""
function undo!(cmd::ParameterChangeCommand)
    state = cmd.state_ref[]
    if isa(state, Dict)
        state[cmd.param_name] = cmd.old_value
    end
end

"""Description for UI"""
function description(cmd::ParameterChangeCommand)::String
    return "$(cmd.param_name): $(cmd.old_value) → $(cmd.new_value)"
end

"""
    CommandHistory — Manages undo/redo stacks
"""
mutable struct CommandHistory
    undo_stack::Vector{Command}
    redo_stack::Vector{Command}
    max_history::Int
    
    function CommandHistory(max_history::Int = 50)
        new(Command[], Command[], max_history)
    end
end

"""Execute a command and add to history"""
function execute_and_record!(history::CommandHistory, cmd::Command)
    execute!(cmd)
    push!(history.undo_stack, cmd)
    
    # Clear redo stack when new command executed
    empty!(history.redo_stack)
    
    # Enforce max history size
    if length(history.undo_stack) > history.max_history
        popfirst!(history.undo_stack)
    end
end

"""Undo the last command"""
function undo!(history::CommandHistory)::Bool
    if isempty(history.undo_stack)
        return false
    end
    
    cmd = pop!(history.undo_stack)
    undo!(cmd)
    push!(history.redo_stack, cmd)
    
    return true
end

"""Redo the last undone command"""
function redo!(history::CommandHistory)::Bool
    if isempty(history.redo_stack)
        return false
    end
    
    cmd = pop!(history.redo_stack)
    execute!(cmd)
    push!(history.undo_stack, cmd)
    
    return true
end

"""Check if undo is possible"""
can_undo(history::CommandHistory)::Bool = !isempty(history.undo_stack)

"""Check if redo is possible"""
can_redo(history::CommandHistory)::Bool = !isempty(history.redo_stack)

"""Get description of next undo action"""
function next_undo_description(history::CommandHistory)::Union{String, Nothing}
    if isempty(history.undo_stack)
        return nothing
    end
    return "Undo: " * description(history.undo_stack[end])
end

"""Get description of next redo action"""
function next_redo_description(history::CommandHistory)::Union{String, Nothing}
    if isempty(history.redo_stack)
        return nothing
    end
    return "Redo: " * description(history.redo_stack[end])
end

"""Clear all history"""
function clear_history!(history::CommandHistory)
    empty!(history.undo_stack)
    empty!(history.redo_stack)
end

"""Get full history as array of descriptions"""
function get_history(history::CommandHistory)::Vector{String}
    descriptions = String[]
    
    for cmd in history.undo_stack
        push!(descriptions, description(cmd))
    end
    
    return descriptions
end

"""Get undo/redo state for UI display"""
function get_state(history::CommandHistory)::Dict
    return Dict(
        "can_undo" => can_undo(history),
        "can_redo" => can_redo(history),
        "undo_description" => next_undo_description(history),
        "redo_description" => next_redo_description(history),
        "history_count" => length(history.undo_stack),
        "redo_count" => length(history.redo_stack)
    )
end

export Command, ParameterChangeCommand, CommandHistory,
       execute!, undo!, redo!, description, can_undo, can_redo,
       next_undo_description, next_redo_description, clear_history!,
       get_history, get_state, execute_and_record!
