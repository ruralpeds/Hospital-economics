"""
Mutation tracking for CREATE/UPDATE/DELETE operations on entities.
"""

using Dates

@enum MutationKind begin
    MUTATION_CREATE
    MUTATION_UPDATE
    MUTATION_DELETE
end

"""
    MutationEntry

Record of a structural change to an entity (create, update, or delete).
"""
struct MutationEntry
    timestamp::DateTime
    entity_type::String
    entity_id::String
    kind::MutationKind
    old_state::Union{String, Nothing}  # JSON for UPDATE/DELETE, nothing for CREATE
    new_state::Union{String, Nothing}  # JSON for CREATE/UPDATE, nothing for DELETE
    reason::String
end

const MUTATION_LOG = Vector{MutationEntry}()

"""
    log_create(entity_type::String, entity_id::String, state::String, reason::String)::MutationEntry

Record creation of a new entity.
"""
function log_create(entity_type::String, entity_id::String, state::String, reason::String)::MutationEntry
    isempty(reason) && throw(ArgumentError("Reason for mutation cannot be empty"))

    entry = MutationEntry(
        now(UTC),
        entity_type,
        entity_id,
        MUTATION_CREATE,
        nothing,
        state,
        reason
    )
    push!(MUTATION_LOG, entry)
    entry
end

"""
    log_update(entity_type::String, entity_id::String, old_state::String, new_state::String, reason::String)::MutationEntry

Record update to an existing entity.
"""
function log_update(entity_type::String, entity_id::String, old_state::String, new_state::String, reason::String)::MutationEntry
    isempty(reason) && throw(ArgumentError("Reason for mutation cannot be empty"))

    entry = MutationEntry(
        now(UTC),
        entity_type,
        entity_id,
        MUTATION_UPDATE,
        old_state,
        new_state,
        reason
    )
    push!(MUTATION_LOG, entry)
    entry
end

"""
    log_delete(entity_type::String, entity_id::String, reason::String)::MutationEntry

Record deletion of an entity.
"""
function log_delete(entity_type::String, entity_id::String, reason::String)::MutationEntry
    isempty(reason) && throw(ArgumentError("Reason for mutation cannot be empty"))

    entry = MutationEntry(
        now(UTC),
        entity_type,
        entity_id,
        MUTATION_DELETE,
        nothing,
        nothing,
        reason
    )
    push!(MUTATION_LOG, entry)
    entry
end

"""
    get_mutation_log()::Vector{MutationEntry}

Retrieve all mutation entries from current session.
"""
function get_mutation_log()::Vector{MutationEntry}
    MUTATION_LOG
end

"""
    clear_mutation_log()

Clear all mutation entries from current session.
"""
function clear_mutation_log()
    empty!(MUTATION_LOG)
end

"""
    save_mutation_log(filepath::String)

Save mutation log to JSONL file.
"""
function save_mutation_log(filepath::String)
    open(filepath, "w") do f
        for entry in MUTATION_LOG
            json_str = JSON3.write(entry)
            println(f, json_str)
        end
    end
end
