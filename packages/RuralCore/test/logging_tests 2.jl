"""
    logging_tests.jl

Test logging configuration and formatting.
"""

using Test
using RuralCore
using Logging
using Dates
using Base

@testset "Logging Configuration" begin
    @testset "configure_logging! accepts app_name parameter" begin
        # Should not throw
        @test_nowarn configure_logging!(app_name="test_app")
    end

    @testset "configure_logging! accepts level parameter" begin
        # Should accept different log levels
        @test_nowarn configure_logging!(app_name="test_app", level=Debug)
        @test_nowarn configure_logging!(app_name="test_app", level=Info)
        @test_nowarn configure_logging!(app_name="test_app", level=Warn)
    end

    @testset "configure_logging! sets global logger to ConsoleLogger" begin
        configure_logging!(app_name="test_app")
        logger = global_logger()
        @test isa(logger, ConsoleLogger)
    end

    @testset "configured logger respects requested level" begin
        # Debug level should log everything
        configure_logging!(app_name="test_app", level=Debug)
        @test global_logger().min_level == Debug

        # Info level should skip debug
        configure_logging!(app_name="test_app", level=Info)
        @test global_logger().min_level == Info
    end

    @testset "log_to_file parameter is accepted" begin
        # Should not throw even when attempting file logging
        @test_nowarn configure_logging!(app_name="test_app", log_to_file=false)
    end

    @testset "default values work correctly" begin
        # Call with no arguments — should use defaults
        @test_nowarn configure_logging!()
        logger = global_logger()
        @test isa(logger, ConsoleLogger)
        @test logger.min_level == Info
    end
end
