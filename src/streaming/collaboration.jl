# Collaboration Room — Real-Time Session Management
#
# Manages collaboration rooms for multi-user analysis sessions.
# Supports room creation, user join/leave, capacity enforcement,
# and active-user tracking.

using Dates

"""
    CollaborationRoom

A real-time collaboration session for multi-user analysis.

# Fields
- `id::String`: unique room identifier
- `name::String`: human-readable room name
- `created_at::DateTime`: when the room was created
- `max_capacity::Int`: maximum number of simultaneous users
- `users::Vector{String}`: currently active user IDs
"""
mutable struct CollaborationRoom
    id::String
    name::String
    created_at::DateTime
    max_capacity::Int
    users::Vector{String}
end

"""
    create_room(name::String; max_capacity::Int=10) -> CollaborationRoom

Create a new collaboration room with the given name and optional capacity limit.

# Arguments
- `name::String`: human-readable room name
- `max_capacity::Int`: maximum simultaneous users (default 10, must be >= 1)

# Returns
- `CollaborationRoom`: a new empty room
"""
function create_room(name::String; max_capacity::Int=10)::CollaborationRoom
    max_capacity >= 1 || error("max_capacity must be >= 1; got $max_capacity")
    !isempty(name) || error("room name must not be empty")

    id = string(hash(name * string(Dates.now())), base=16)
    return CollaborationRoom(id, name, Dates.now(), max_capacity, String[])
end

"""
    join_room!(room::CollaborationRoom, user_id::String) -> Bool

Add a user to the collaboration room.

Returns `true` if the user was successfully added, `false` if the room is
at capacity or the user is already in the room.
"""
function join_room!(room::CollaborationRoom, user_id::String)::Bool
    isempty(user_id) && error("user_id must not be empty")

    # Already in room
    if user_id in room.users
        return false
    end

    # Capacity check
    if length(room.users) >= room.max_capacity
        return false
    end

    push!(room.users, user_id)
    return true
end

"""
    leave_room!(room::CollaborationRoom, user_id::String) -> Bool

Remove a user from the collaboration room.

Returns `true` if the user was removed, `false` if the user was not in the room.
"""
function leave_room!(room::CollaborationRoom, user_id::String)::Bool
    idx = findfirst(==(user_id), room.users)
    if idx === nothing
        return false
    end
    deleteat!(room.users, idx)
    return true
end

"""
    active_users(room::CollaborationRoom) -> Vector{String}

Return the list of currently active user IDs in the room.
"""
function active_users(room::CollaborationRoom)::Vector{String}
    return copy(room.users)
end

"""
    is_full(room::CollaborationRoom) -> Bool

Check whether the room is at maximum capacity.
"""
function is_full(room::CollaborationRoom)::Bool
    return length(room.users) >= room.max_capacity
end
