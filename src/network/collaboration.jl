# Collaboration Manager — Multi-User Room Management
#
# Manages real-time collaboration rooms for hospital analytics dashboards.
# Tracks connected users per room with join/leave timestamps and enforces
# maximum occupancy limits.

using Dates

# ============================================================================
# Types
# ============================================================================

"""
    CollaborationRoom

A collaboration room tracking connected users.

# Fields
- `room_id::String`: unique room identifier
- `connected_users::Dict{String,DateTime}`: user_id -> join timestamp
- `created_at::DateTime`: when the room was created
"""
@kwdef mutable struct CollaborationRoom
    room_id::String
    connected_users::Dict{String,DateTime}  = Dict{String,DateTime}()
    created_at::DateTime                    = Dates.now(Dates.UTC)
end

function Base.show(io::IO, r::CollaborationRoom)
    print(io, "CollaborationRoom($(r.room_id), users=$(length(r.connected_users)))")
end

"""
    CollaborationManager

Manages multiple collaboration rooms with occupancy limits.

# Fields
- `rooms::Dict{String,CollaborationRoom}`: room_id -> room mapping
- `max_users_per_room::Int`: maximum users allowed per room (default 20)
"""
@kwdef mutable struct CollaborationManager
    rooms::Dict{String,CollaborationRoom}   = Dict{String,CollaborationRoom}()
    max_users_per_room::Int                 = 20
end

function Base.show(io::IO, m::CollaborationManager)
    total_users = sum(length(r.connected_users) for r in values(m.rooms); init=0)
    print(io, "CollaborationManager(rooms=$(length(m.rooms)), total_users=$(total_users))")
end

# ============================================================================
# Core Functions
# ============================================================================

"""
    create_room!(manager::CollaborationManager, room_id::String) -> CollaborationRoom

Create a new collaboration room. Throws an error if a room with the same
ID already exists.

# Arguments
- `manager::CollaborationManager`: the manager to add the room to
- `room_id::String`: unique identifier for the new room

# Returns
- `CollaborationRoom`: the newly created room
"""
function create_room!(manager::CollaborationManager, room_id::String)::CollaborationRoom
    haskey(manager.rooms, room_id) && error("Room '$(room_id)' already exists")

    room = CollaborationRoom(room_id=room_id)
    manager.rooms[room_id] = room
    return room
end

"""
    join_room!(manager::CollaborationManager, room_id::String,
               user_id::String) -> CollaborationRoom

Add a user to an existing room. Creates a timestamp recording when the
user joined. Throws an error if the room does not exist or is at capacity.

If the user is already in the room, updates their join timestamp (reconnect).

# Arguments
- `manager::CollaborationManager`: the collaboration manager
- `room_id::String`: room to join
- `user_id::String`: user joining the room

# Returns
- `CollaborationRoom`: the updated room
"""
function join_room!(manager::CollaborationManager, room_id::String,
                     user_id::String)::CollaborationRoom
    haskey(manager.rooms, room_id) || error("Room '$(room_id)' does not exist")

    room = manager.rooms[room_id]

    # Check capacity (allow reconnects without counting toward limit)
    if !haskey(room.connected_users, user_id) &&
       length(room.connected_users) >= manager.max_users_per_room
        error("Room '$(room_id)' is at capacity ($(manager.max_users_per_room) users)")
    end

    room.connected_users[user_id] = Dates.now(Dates.UTC)
    return room
end

"""
    leave_room!(manager::CollaborationManager, room_id::String,
                 user_id::String) -> Bool

Remove a user from a room. Returns `true` if the user was present and
removed, `false` if the user was not in the room.

# Arguments
- `manager::CollaborationManager`: the collaboration manager
- `room_id::String`: room to leave
- `user_id::String`: user leaving the room

# Returns
- `Bool`: `true` if user was removed, `false` if user was not in the room
"""
function leave_room!(manager::CollaborationManager, room_id::String,
                      user_id::String)::Bool
    haskey(manager.rooms, room_id) || error("Room '$(room_id)' does not exist")

    room = manager.rooms[room_id]

    if haskey(room.connected_users, user_id)
        delete!(room.connected_users, user_id)
        return true
    end

    return false
end

"""
    get_active_users(manager::CollaborationManager,
                      room_id::String) -> Vector{NamedTuple}

List all active users in a room with their join timestamps.

Returns a vector of named tuples sorted by join time, each with:
- `user_id::String`: the user identifier
- `joined_at::DateTime`: when the user joined

# Arguments
- `manager::CollaborationManager`: the collaboration manager
- `room_id::String`: room to query

# Returns
- `Vector{NamedTuple}`: active users sorted by join time (earliest first)
"""
function get_active_users(manager::CollaborationManager,
                           room_id::String)::Vector{NamedTuple}
    haskey(manager.rooms, room_id) || error("Room '$(room_id)' does not exist")

    room = manager.rooms[room_id]
    users = [(user_id=uid, joined_at=ts) for (uid, ts) in room.connected_users]
    sort!(users, by=u -> u.joined_at)
    return users
end
