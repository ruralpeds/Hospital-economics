"""
    scenario_persistence.jl — SQLite-based scenario storage and retrieval

    Phase 7 Advanced Feature: Save and load ABM scenarios with metadata and results.
    Supports full scenario reconstruction from persisted parameters and outputs.
"""

using SQLite, DataFrames, JSON3, Dates, UUIDs

"""
    Scenario — Complete scenario definition with parameters, results, and metadata
"""
@kwdef struct Scenario
    id::String  # UUID-based unique identifier
    name::String
    description::String = ""
    app_type::String  # "batch", "labor", "causal", "quality", etc.
    created_at::DateTime
    modified_at::DateTime
    parameters::Dict{String, Any}  # Full parameter set
    results::Union{Dict, Nothing} = nothing  # Full results if available
    is_favorite::Bool = false
end

"""
    ScenarioStorage — SQLite database connection and schema management
"""
mutable struct ScenarioStorage
    db::SQLite.DB
    
    function ScenarioStorage(db_path::String = "scenarios.db")
        db = SQLite.DB(db_path)
        storage = new(db)
        _init_schema(storage)
        storage
    end
end

"""Initialize SQLite schema for scenario storage"""
function _init_schema(storage::ScenarioStorage)
    db = storage.db
    
    # Create scenarios table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS scenarios (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            app_type TEXT NOT NULL,
            created_at DATETIME NOT NULL,
            modified_at DATETIME NOT NULL,
            is_favorite BOOLEAN DEFAULT 0
        )
    """)
    
    # Create parameters table (JSON storage)
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS scenario_parameters (
            scenario_id TEXT PRIMARY KEY,
            parameters_json TEXT NOT NULL,
            FOREIGN KEY(scenario_id) REFERENCES scenarios(id) ON DELETE CASCADE
        )
    """)
    
    # Create results table (JSON storage)
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS scenario_results (
            scenario_id TEXT PRIMARY KEY,
            results_json TEXT NOT NULL,
            FOREIGN KEY(scenario_id) REFERENCES scenarios(id) ON DELETE CASCADE
        )
    """)
    
    # Create version history table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS scenario_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            scenario_id TEXT NOT NULL,
            version_num INTEGER NOT NULL,
            parameters_json TEXT NOT NULL,
            results_json TEXT,
            created_at DATETIME NOT NULL,
            FOREIGN KEY(scenario_id) REFERENCES scenarios(id) ON DELETE CASCADE
        )
    """)
end

"""Save a scenario to the database"""
function save_scenario(storage::ScenarioStorage, scenario::Scenario)::String
    db = storage.db
    scenario_id = scenario.id
    
    try
        # Insert/update main scenario record
        SQLite.execute(db, """
            INSERT OR REPLACE INTO scenarios 
            (id, name, description, app_type, created_at, modified_at, is_favorite)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, [scenario_id, scenario.name, scenario.description, scenario.app_type, 
              scenario.created_at, scenario.modified_at, scenario.is_favorite])
        
        # Save parameters as JSON
        params_json = JSON3.write(scenario.parameters)
        SQLite.execute(db, """
            INSERT OR REPLACE INTO scenario_parameters (scenario_id, parameters_json)
            VALUES (?, ?)
        """, [scenario_id, params_json])
        
        # Save results if available
        if scenario.results !== nothing
            results_json = JSON3.write(scenario.results)
            SQLite.execute(db, """
                INSERT OR REPLACE INTO scenario_results (scenario_id, results_json)
                VALUES (?, ?)
            """, [scenario_id, results_json])
        end
        
        return scenario_id
    catch e
        @error "Failed to save scenario" scenario_id=scenario_id exception=e
        rethrow()
    end
end

"""Load a scenario from the database"""
function load_scenario(storage::ScenarioStorage, scenario_id::String)::Union{Scenario, Nothing}
    db = storage.db
    
    try
        # Get main scenario record
        result = SQLite.execute(db, 
            "SELECT * FROM scenarios WHERE id = ?", [scenario_id]) |> DataFrame
        
        if nrow(result) == 0
            return nothing
        end
        
        row = result[1, :]
        
        # Get parameters
        params_result = SQLite.execute(db,
            "SELECT parameters_json FROM scenario_parameters WHERE scenario_id = ?",
            [scenario_id]) |> DataFrame
        
        params = if nrow(params_result) > 0
            JSON3.read(params_result[1, :parameters_json], Dict)
        else
            Dict()
        end
        
        # Get results if available
        results = nothing
        results_result = SQLite.execute(db,
            "SELECT results_json FROM scenario_results WHERE scenario_id = ?",
            [scenario_id]) |> DataFrame
        
        if nrow(results_result) > 0
            results = JSON3.read(results_result[1, :results_json], Dict)
        end
        
        return Scenario(
            id = scenario_id,
            name = row.name,
            description = row.description,
            app_type = row.app_type,
            created_at = row.created_at,
            modified_at = row.modified_at,
            parameters = params,
            results = results,
            is_favorite = row.is_favorite
        )
    catch e
        @error "Failed to load scenario" scenario_id=scenario_id exception=e
        return nothing
    end
end

"""List all scenarios with optional filtering"""
function list_scenarios(storage::ScenarioStorage; app_type::Union{String, Nothing} = nothing,
                       favorites_only::Bool = false)::Vector{Scenario}
    db = storage.db
    
    try
        query = "SELECT * FROM scenarios"
        params = []
        
        if app_type !== nothing
            query *= " WHERE app_type = ?"
            push!(params, app_type)
        end
        
        if favorites_only
            query *= (app_type !== nothing ? " AND" : " WHERE") * " is_favorite = 1"
        end
        
        query *= " ORDER BY modified_at DESC"
        
        result = SQLite.execute(db, query, params) |> DataFrame
        scenarios = Scenario[]
        
        for row in eachrow(result)
            scenario = load_scenario(storage, row.id)
            if scenario !== nothing
                push!(scenarios, scenario)
            end
        end
        
        return scenarios
    catch e
        @error "Failed to list scenarios" exception=e
        return Scenario[]
    end
end

"""Delete a scenario"""
function delete_scenario(storage::ScenarioStorage, scenario_id::String)::Bool
    db = storage.db
    
    try
        SQLite.execute(db, "DELETE FROM scenarios WHERE id = ?", [scenario_id])
        return true
    catch e
        @error "Failed to delete scenario" scenario_id=scenario_id exception=e
        return false
    end
end

"""Toggle favorite status"""
function toggle_favorite(storage::ScenarioStorage, scenario_id::String)::Bool
    db = storage.db
    
    try
        SQLite.execute(db, """
            UPDATE scenarios SET is_favorite = NOT is_favorite 
            WHERE id = ?
        """, [scenario_id])
        return true
    catch e
        @error "Failed to toggle favorite" scenario_id=scenario_id exception=e
        return false
    end
end

"""Export scenario to JSON file"""
function export_scenario_to_json(scenario::Scenario, file_path::String)::Bool
    try
        data = Dict(
            "id" => scenario.id,
            "name" => scenario.name,
            "description" => scenario.description,
            "app_type" => scenario.app_type,
            "created_at" => string(scenario.created_at),
            "modified_at" => string(scenario.modified_at),
            "parameters" => scenario.parameters,
            "results" => scenario.results
        )
        
        open(file_path, "w") do io
            JSON3.write(io, data)
        end
        
        return true
    catch e
        @error "Failed to export scenario" file_path=file_path exception=e
        return false
    end
end

"""Import scenario from JSON file"""
function import_scenario_from_json(file_path::String)::Union{Scenario, Nothing}
    try
        data = open(file_path) do io
            JSON3.read(io)
        end
        
        return Scenario(
            id = get(data, "id", string(uuid4())),
            name = data["name"],
            description = get(data, "description", ""),
            app_type = data["app_type"],
            created_at = DateTime(get(data, "created_at", string(now()))),
            modified_at = DateTime(get(data, "modified_at", string(now()))),
            parameters = Dict(data["parameters"]),
            results = get(data, "results", nothing) |> 
                     (x -> x !== nothing ? Dict(x) : nothing),
            is_favorite = get(data, "is_favorite", false)
        )
    catch e
        @error "Failed to import scenario" file_path=file_path exception=e
        return nothing
    end
end

export Scenario, ScenarioStorage, save_scenario, load_scenario, list_scenarios,
       delete_scenario, toggle_favorite, export_scenario_to_json, import_scenario_from_json
