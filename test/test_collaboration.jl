@testset "Collaboration Manager" begin
    mgr = CollaborationManager(max_users_per_room=3)

    room = create_room!(mgr, "room-1")
    @test room.room_id == "room-1"

    @test join_room!(mgr, "room-1", "user-a") == true
    @test join_room!(mgr, "room-1", "user-b") == true
    @test join_room!(mgr, "room-1", "user-c") == true

    users = get_active_users(mgr, "room-1")
    @test length(users) == 3
    @test "user-a" in users

    @test join_room!(mgr, "room-1", "user-d") == false

    leave_room!(mgr, "room-1", "user-a")
    @test length(get_active_users(mgr, "room-1")) == 2

    @test join_room!(mgr, "room-1", "user-d") == true
end
