using Test
using Dates

include(joinpath(@__DIR__, "..", "src", "streaming", "collaboration.jl"))

# ═══════════════════════════════════════════════════════════════
# Collaboration Room
# ═══════════════════════════════════════════════════════════════

@testset "Collaboration Room" begin
    @testset "room creation" begin
        room = create_room("Financial Review")

        @test room.name == "Financial Review"
        @test !isempty(room.id)
        @test room.max_capacity == 10  # default
        @test isempty(room.users)
        @test room.created_at <= Dates.now()
    end

    @testset "room creation — custom capacity" begin
        room = create_room("Small Room"; max_capacity=3)

        @test room.max_capacity == 3
        @test isempty(room.users)
    end

    @testset "room creation — invalid capacity" begin
        @test_throws ErrorException create_room("Bad Room"; max_capacity=0)
        @test_throws ErrorException create_room("Bad Room"; max_capacity=-1)
    end

    @testset "room creation — empty name" begin
        @test_throws ErrorException create_room("")
    end

    @testset "join room — basic" begin
        room = create_room("Test Room"; max_capacity=5)

        @test join_room!(room, "user-a") == true
        @test join_room!(room, "user-b") == true

        @test length(room.users) == 2
        @test "user-a" in room.users
        @test "user-b" in room.users
    end

    @testset "join room — duplicate user rejected" begin
        room = create_room("Test Room")

        @test join_room!(room, "user-a") == true
        @test join_room!(room, "user-a") == false  # already in room

        @test length(room.users) == 1
    end

    @testset "join room — empty user_id" begin
        room = create_room("Test Room")
        @test_throws ErrorException join_room!(room, "")
    end

    @testset "leave room — basic" begin
        room = create_room("Test Room")
        join_room!(room, "user-a")
        join_room!(room, "user-b")

        @test leave_room!(room, "user-a") == true
        @test length(room.users) == 1
        @test !("user-a" in room.users)
        @test "user-b" in room.users
    end

    @testset "leave room — user not in room" begin
        room = create_room("Test Room")
        join_room!(room, "user-a")

        @test leave_room!(room, "nonexistent") == false
        @test length(room.users) == 1
    end

    @testset "active users — returns copy" begin
        room = create_room("Test Room")
        join_room!(room, "user-a")
        join_room!(room, "user-b")

        users = active_users(room)
        @test length(users) == 2
        @test "user-a" in users
        @test "user-b" in users

        # Modifying the returned list should not affect the room
        push!(users, "phantom")
        @test length(room.users) == 2
    end

    @testset "active users — empty room" begin
        room = create_room("Empty Room")
        users = active_users(room)
        @test isempty(users)
    end

    @testset "max capacity — enforced" begin
        room = create_room("Tiny Room"; max_capacity=3)

        @test join_room!(room, "user-a") == true
        @test join_room!(room, "user-b") == true
        @test join_room!(room, "user-c") == true
        @test join_room!(room, "user-d") == false  # at capacity

        @test length(room.users) == 3
    end

    @testset "max capacity — room opens after leave" begin
        room = create_room("Cycling Room"; max_capacity=2)

        @test join_room!(room, "user-a") == true
        @test join_room!(room, "user-b") == true
        @test join_room!(room, "user-c") == false  # full

        @test leave_room!(room, "user-a") == true
        @test join_room!(room, "user-c") == true   # now space available

        @test length(room.users) == 2
        @test !("user-a" in room.users)
        @test "user-c" in room.users
    end

    @testset "max capacity — single-user room" begin
        room = create_room("Solo Room"; max_capacity=1)

        @test join_room!(room, "user-a") == true
        @test join_room!(room, "user-b") == false

        @test is_full(room) == true
    end

    @testset "is_full check" begin
        room = create_room("Test"; max_capacity=2)

        @test is_full(room) == false
        join_room!(room, "user-a")
        @test is_full(room) == false
        join_room!(room, "user-b")
        @test is_full(room) == true
    end

    @testset "join/leave sequence preserves order" begin
        room = create_room("Ordered Room"; max_capacity=10)

        join_room!(room, "alice")
        join_room!(room, "bob")
        join_room!(room, "charlie")

        @test room.users == ["alice", "bob", "charlie"]

        leave_room!(room, "bob")
        @test room.users == ["alice", "charlie"]

        join_room!(room, "diana")
        @test room.users == ["alice", "charlie", "diana"]
    end

    @testset "multiple rooms are independent" begin
        room1 = create_room("Room 1"; max_capacity=2)
        room2 = create_room("Room 2"; max_capacity=2)

        join_room!(room1, "user-a")
        join_room!(room2, "user-a")  # same user can be in multiple rooms

        @test length(room1.users) == 1
        @test length(room2.users) == 1

        join_room!(room1, "user-b")
        @test length(room2.users) == 1  # room2 unaffected
    end
end
