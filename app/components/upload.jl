"""
    upload.jl — Reusable universal file-intake component (E2).

Exposes the `upload(; ...)` function that returns a Quasar stepper UI for:
  1. Drop file  — q-uploader, single file, mime-filtered, size-capped.
  2. Preview    — first 20 rows, inferred column types, % missing, PHI sniff.
  3. Map columns — drag/drop to target schema; template saved/loaded from
                   data/templates/.
  4. Validate   — calls validate_data_source, validate_icd10_code,
                  validate_cpt_code, validate_patient_encounter.
  5. De-identify — default ON when PHI flagged; calls deidentify_encounter /
                   generate_pseudonym. Offers salt management.
  6. Commit     — writes to data/uploads/<uuid>/ and emits a DataAsset record.

Supported formats:
  .csv, .tsv, .xls, .xlsx, .json, .jsonl, .parquet, .feather,
  .sav, .dta, .sas7bdat, HCRIS .rpt/.csv

Usage:
  upload(
      id         = :my_upload,
      schema     = :patient,
      on_committed = "my_on_committed",
      allow_phi  = false,
      max_mb     = 500,
  )
"""

# ============================================================================
# SUPPORTED MIME TYPES & EXTENSIONS
# ============================================================================

const SUPPORTED_MIME_TYPES = [
    "text/csv",
    "text/tab-separated-values",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/json",
    "application/x-ndjson",
    "application/octet-stream",   # parquet, feather, sav, dta, sas7bdat
    "text/plain",                  # .rpt
]

const SUPPORTED_EXTENSIONS = [
    ".csv", ".tsv", ".xls", ".xlsx",
    ".json", ".jsonl",
    ".parquet", ".feather",
    ".sav", ".dta", ".sas7bdat",
    ".rpt",
]

const SCHEMA_OPTIONS = ["patient", "claim", "financial", "registry", "hcris", "custom"]

const MAX_UPLOAD_MB_DEFAULT = 500

# ============================================================================
# PHI PATTERN DETECTION
# ============================================================================

"""
    PHI_PATTERNS — Named regex patterns for common PHI column names and values.

Covers HIPAA Safe Harbor 18 identifiers across column names and data values.
"""
const PHI_COLUMN_PATTERNS = [
    r"(?i)\b(ssn|social.?security|social_security_number)\b",
    r"(?i)\b(dob|date.?of.?birth|birth.?date|birthdate)\b",
    r"(?i)\b(mrn|medical.?record.?number|patient.?id|pat.?id)\b",
    r"(?i)\b(first.?name|last.?name|full.?name|patient.?name|name)\b",
    r"(?i)\b(phone|telephone|fax|cell|mobile)\b",
    r"(?i)\b(email|e.?mail)\b",
    r"(?i)\b(address|street|addr|zip|zipcode|postal)\b",
    r"(?i)\b(license.?plate|vehicle|device.?id|serial.?number)\b",
    r"(?i)\b(ip.?address|url|web.?address)\b",
    r"(?i)\b(passport|account.?number|insurance.?id|member.?id)\b",
    r"(?i)\b(biometric|photo|image|face)\b",
]

const PHI_VALUE_PATTERNS = [
    r"\b\d{3}-\d{2}-\d{4}\b",                    # SSN: 123-45-6789
    r"\b\d{9}\b",                                  # SSN (no dashes): 123456789
    r"\b\d{1,2}/\d{1,2}/\d{2,4}\b",              # Date: 01/15/2024
    r"\b\d{4}-\d{2}-\d{2}\b",                     # Date: 2024-01-15
    r"\b\d{3}-\d{3}-\d{4}\b",                     # Phone: 555-123-4567
    r"\(\d{3}\)\s*\d{3}-\d{4}",                   # Phone: (555) 123-4567
    r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b",  # Email
    r"\b\d{5}(-\d{4})?\b",                        # ZIP code
]

"""
    sniff_phi_columns(column_names::Vector{String}) -> Vector{String}

Inspect column names for patterns matching HIPAA identifiers.
Returns the list of column names suspected to contain PHI.
"""
function sniff_phi_columns(column_names::Vector{String})::Vector{String}
    phi_cols = String[]
    for col in column_names
        for pat in PHI_COLUMN_PATTERNS
            if occursin(pat, col)
                push!(phi_cols, col)
                break
            end
        end
    end
    return phi_cols
end

"""
    sniff_phi_values(sample_values::Vector{String}) -> Bool

Check a sample of string values for PHI patterns.
Returns true if any PHI-like value is found.
"""
function sniff_phi_values(sample_values::Vector{String})::Bool
    for val in sample_values
        for pat in PHI_VALUE_PATTERNS
            if occursin(pat, val)
                return true
            end
        end
    end
    return false
end

# ============================================================================
# DATA ASSET (committed upload record)
# ============================================================================

"""
    DataAsset

Represents a successfully committed upload. Emitted after the Commit step.

# Fields
- asset_id::String: UUID for this upload
- original_filename::String: User-supplied filename
- format::String: Detected file format (.csv, .xlsx, …)
- schema::String: Target schema (patient, claim, financial, …)
- upload_dir::String: Absolute path to data/uploads/<asset_id>/
- row_count::Int: Number of rows after validation
- column_names::Vector{String}: Columns in the uploaded file
- column_mapping::Dict{String,String}: Source → target column map
- phi_columns::Vector{String}: Columns flagged as PHI
- deidentified::Bool: Whether de-identification was applied
- audit_entry_id::String: Reference to audit log entry
- committed_at::String: ISO-8601 timestamp
- user_id::String: User who committed the asset
- metadata::Dict{String,Any}: Any additional metadata
"""
struct DataAsset
    asset_id::String
    original_filename::String
    format::String
    schema::String
    upload_dir::String
    row_count::Int
    column_names::Vector{String}
    column_mapping::Dict{String,String}
    phi_columns::Vector{String}
    deidentified::Bool
    audit_entry_id::String
    committed_at::String
    user_id::String
    metadata::Dict{String,Any}
end

# ============================================================================
# UPLOAD STEP RESULTS (internal state passed between stepper steps)
# ============================================================================

"""
    UploadStepState

Internal stepper state — holds the result of each completed step so the
next step can build on it.
"""
mutable struct UploadStepState
    # Step 1 — Drop file
    filepath::String
    filename::String
    format::String
    file_size_bytes::Int64

    # Step 2 — Preview
    preview_rows::Vector{Dict{String,Any}}   # first ≤ 20 rows as Dicts
    column_names::Vector{String}
    column_types::Dict{String,String}        # col => inferred type string
    missing_pct::Dict{String,Float64}        # col => % missing
    phi_columns::Vector{String}
    phi_detected::Bool

    # Step 3 — Map columns
    column_mapping::Dict{String,String}      # source_col => target_field

    # Step 4 — Validate
    validation_passed::Bool
    validation_summary::Dict{String,Any}

    # Step 5 — De-identify
    deidentified::Bool
    deidentify_log::Vector{String}

    # Step 6 — Commit
    asset::Union{DataAsset,Nothing}
end

function UploadStepState()
    UploadStepState(
        "", "", "", 0,
        Dict{String,Any}[], String[], Dict{String,String}(), Dict{String,Float64}(), String[], false,
        Dict{String,String}(),
        false, Dict{String,Any}(),
        false, String[],
        nothing,
    )
end

# ============================================================================
# FILE FORMAT DETECTION
# ============================================================================

"""
    detect_format(filename::String) -> String

Determine file format from the filename extension.
Returns the normalised extension string (e.g. ".csv", ".xlsx").
"""
function detect_format(filename::String)::String
    ext = lowercase(splitext(filename)[2])
    ext in SUPPORTED_EXTENSIONS && return ext
    # Map aliases
    ext == ".txt" && return ".csv"   # treat plain text as CSV
    return ".csv"                    # fallback
end

"""
    enforce_file_size!(filepath::String, max_mb::Int)

Throws an error if the file at `filepath` exceeds `max_mb` megabytes.
Enforces the server-side maximum upload size.
"""
function enforce_file_size!(filepath::String, max_mb::Int)
    isfile(filepath) || error("File not found: $filepath")
    size_bytes = filesize(filepath)
    limit_bytes = max_mb * 1024 * 1024
    if size_bytes > limit_bytes
        error("File too large: $(round(size_bytes/1024/1024, digits=1)) MB " *
              "(limit: $max_mb MB). Please reduce file size or contact your administrator.")
    end
end

# ============================================================================
# COLUMN MAPPING TEMPLATES
# ============================================================================

"""
    template_path(schema::String) -> String

Return the path for the saved column-mapping template for the given schema.
Templates are stored in `data/templates/<schema>_mapping.json`.
"""
function template_path(schema::String)::String
    dir = joinpath(@__DIR__, "..", "..", "data", "templates")
    mkpath(dir)
    return joinpath(dir, "$(schema)_mapping.json")
end

"""
    load_column_mapping(schema::String) -> Dict{String,String}

Load a previously saved column mapping for `schema`, if one exists.
Returns an empty dict if no template is found.
"""
function load_column_mapping(schema::String)::Dict{String,String}
    path = template_path(schema)
    !isfile(path) && return Dict{String,String}()
    try
        content = read(path, String)
        # Parse simple JSON manually (avoid requiring JSON3 at load time)
        mapping = Dict{String,String}()
        # Use JSON3 if available, else return empty (mapping auto-populated on first use)
        try
            using_json3 = Base.loaded_modules[Base.PkgId(
                Base.UUID("0f8b85d8-7281-11e9-16c2-39a750bddbf1"), "JSON3")]
            raw = using_json3.read(content, Dict{String,String})
            for (k, v) in raw
                mapping[string(k)] = string(v)
            end
        catch
            # JSON3 not available; return empty mapping
        end
        return mapping
    catch
        return Dict{String,String}()
    end
end

"""
    save_column_mapping(schema::String, mapping::Dict{String,String})

Persist a column mapping template to `data/templates/<schema>_mapping.json`.
"""
function save_column_mapping(schema::String, mapping::Dict{String,String})
    path = template_path(schema)
    # Serialise as simple JSON manually
    pairs_str = join(["\"$(escape_string(k))\": \"$(escape_string(v))\"" for (k, v) in mapping], ",\n  ")
    content = "{\n  $(pairs_str)\n}\n"
    write(path, content)
end

# ============================================================================
# UPLOAD UI COMPONENT (Stipple / Quasar)
# ============================================================================

"""
    upload(; id, schema, on_committed, allow_phi, max_mb) -> HTML

Return a Quasar `q-stepper` UI component for universal file intake.

# Keyword Arguments
- `id::Symbol = :upload`: Reactive model field prefix (e.g. `:data_upload`).
- `schema::String = "patient"`: Target schema name used to auto-populate
  column mapping templates.
- `on_committed::String = ""`: Name of server handler called after commit step.
- `allow_phi::Bool = false`: If false (default), always de-identify PHI-flagged
  columns before commit.
- `max_mb::Int = 500`: Maximum accepted file size in MB.

The returned HTML string is Stipple-reactive — bind the upload `@app` model
fields (prefixed by `id`) in the parent tab model.
"""
function upload(;
    id::Symbol = :upload,
    schema::String = "patient",
    on_committed::String = "",
    allow_phi::Bool = false,
    max_mb::Int = MAX_UPLOAD_MB_DEFAULT,
)::String
    prefix = string(id)
    accept_str = join(SUPPORTED_EXTENSIONS, ",")
    max_bytes = max_mb * 1024 * 1024

    """
    <div id="upload-$(prefix)" class="q-pa-md">
      <q-stepper
        v-model="$(prefix)_step"
        vertical
        color="primary"
        animated
        done-color="positive"
        error-color="negative"
      >

        <!-- ── Step 1: Drop File ─────────────────────────────────────── -->
        <q-step :name="1" title="Upload File" icon="cloud_upload"
                :done="$(prefix)_step > 1"
                :error="$(prefix)_step1_error">
          <div class="q-mb-md text-body2 text-grey-7">
            Accepted formats: <code>$(join(SUPPORTED_EXTENSIONS, " "))</code>.
            Maximum size: <strong>$(max_mb) MB</strong>.
          </div>

          <q-uploader
            :url="'/api/data/upload/stage'"
            :accept="'$(accept_str)'"
            :max-file-size="$(max_bytes)"
            :max-files="1"
            flat
            bordered
            color="primary"
            label="Drop file here or click to browse"
            field-name="file"
            :form-fields="[{name: 'schema', value: '$(schema)'}, {name: 'max_mb', value: '$(max_mb)'}]"
            @uploaded="$(prefix)_on_uploaded"
            @failed="$(prefix)_on_upload_failed"
            class="full-width"
            style="max-height: 300px"
          >
            <template v-slot:header="scope">
              <div class="row no-wrap items-center q-pa-sm q-gutter-xs">
                <q-btn v-if="scope.queuedFiles.length > 0" icon="clear_all" round dense flat
                       @click="scope.removeQueuedFiles" aria-label="Clear queued files">
                  <q-tooltip>Clear All</q-tooltip>
                </q-btn>
                <q-spinner v-if="scope.isUploading" class="q-uploader__spinner" />
                <div class="col">
                  <div class="q-uploader__title">Upload Data File</div>
                  <div class="q-uploader__subtitle">{{ scope.uploadSizeLabel }} / {{ scope.uploadProgressLabel }}</div>
                </div>
                <q-btn v-if="scope.canAddFiles" type="a" icon="add_box" round dense flat aria-label="Pick file">
                  <q-uploader-add-trigger />
                  <q-tooltip>Pick File</q-tooltip>
                </q-btn>
                <q-btn v-if="scope.canUpload" icon="cloud_upload" round dense flat
                       @click="scope.upload" aria-label="Upload file">
                  <q-tooltip>Upload</q-tooltip>
                </q-btn>
                <q-btn v-if="scope.isUploading" icon="clear" round dense flat
                       @click="scope.abort" aria-label="Abort upload">
                  <q-tooltip>Abort</q-tooltip>
                </q-btn>
              </div>
            </template>
          </q-uploader>

          <q-stepper-navigation>
            <q-btn :disable="!$(prefix)_file_staged" color="primary"
                   label="Next: Preview" @click="$(prefix)_step = 2"
                   aria-label="Proceed to preview step" />
          </q-stepper-navigation>
        </q-step>

        <!-- ── Step 2: Preview ───────────────────────────────────────── -->
        <q-step :name="2" title="Preview" icon="preview"
                :done="$(prefix)_step > 2"
                :error="$(prefix)_step2_error">
          <div class="row q-col-gutter-md q-mb-md">
            <div class="col-auto">
              <q-chip icon="description" :label="$(prefix)_filename" color="grey-3" text-color="black" />
            </div>
            <div class="col-auto">
              <q-chip icon="table_rows" :label="$(prefix)_row_count + ' rows'" color="blue-1" />
            </div>
            <div v-if="$(prefix)_phi_detected" class="col-auto">
              <q-chip icon="warning" label="PHI Detected" color="red-2" text-color="red-10" />
            </div>
          </div>

          <!-- Column type / missingness summary cards -->
          <div class="row q-col-gutter-sm q-mb-md">
            <div v-for="col in $(prefix)_column_summary" :key="col.name" class="col-auto">
              <q-card flat bordered class="q-pa-xs" style="min-width:120px">
                <div class="text-caption text-weight-bold ellipsis" :title="col.name">{{ col.name }}</div>
                <div class="text-caption text-grey-6">{{ col.type }}</div>
                <q-linear-progress
                  :value="col.missing_pct / 100"
                  :color="col.missing_pct > 20 ? 'red' : col.missing_pct > 5 ? 'orange' : 'green'"
                  rounded size="4px" class="q-mt-xs"
                  :aria-label="'Missing ' + col.missing_pct + '% for ' + col.name"
                />
                <div class="text-caption text-right">{{ col.missing_pct }}% missing</div>
                <q-badge v-if="col.is_phi" color="red" label="PHI" class="q-mt-xs" />
              </q-card>
            </div>
          </div>

          <!-- First 20 rows table -->
          <q-table
            :rows="$(prefix)_preview_rows"
            :columns="$(prefix)_preview_columns"
            :rows-per-page-options="[20]"
            dense
            flat
            bordered
            virtual-scroll
            :style="'max-height: 300px'"
            aria-label="File preview table — first 20 rows"
          >
            <template v-slot:top>
              <span class="text-subtitle2">Preview — first 20 rows</span>
            </template>
          </q-table>

          <q-stepper-navigation>
            <q-btn flat color="primary" label="Back" @click="$(prefix)_step = 1"
                   class="q-mr-sm" aria-label="Back to upload step" />
            <q-btn color="primary" label="Next: Map Columns" @click="$(prefix)_step = 3"
                   aria-label="Proceed to column mapping step" />
          </q-stepper-navigation>
        </q-step>

        <!-- ── Step 3: Map Columns ───────────────────────────────────── -->
        <q-step :name="3" title="Map Columns" icon="swap_horiz"
                :done="$(prefix)_step > 3"
                :error="$(prefix)_step3_error">
          <div class="text-body2 q-mb-md">
            Map source columns to <strong>$(schema)</strong> schema fields.
            <q-btn flat dense color="secondary" icon="save" label="Save template"
                   @click="$(prefix)_save_mapping" class="q-ml-md"
                   aria-label="Save column mapping as reusable template" />
            <q-btn flat dense color="secondary" icon="folder_open" label="Load template"
                   @click="$(prefix)_load_mapping" class="q-ml-xs"
                   aria-label="Load saved column mapping template" />
          </div>
          <q-list bordered separator>
            <q-item v-for="col in $(prefix)_column_names" :key="col" dense>
              <q-item-section>
                <q-item-label>{{ col }}</q-item-label>
                <q-item-label caption>{{ $(prefix)_column_types[col] }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-select
                  v-model="$(prefix)_column_mapping[col]"
                  :options="$(prefix)_target_fields"
                  dense
                  options-dense
                  label="Target field"
                  clearable
                  style="min-width: 180px"
                  :aria-label="'Map column ' + col + ' to target field'"
                />
              </q-item-section>
            </q-item>
          </q-list>

          <q-stepper-navigation>
            <q-btn flat color="primary" label="Back" @click="$(prefix)_step = 2"
                   class="q-mr-sm" aria-label="Back to preview step" />
            <q-btn color="primary" label="Next: Validate" @click="$(prefix)_step = 4"
                   aria-label="Proceed to validation step" />
          </q-stepper-navigation>
        </q-step>

        <!-- ── Step 4: Validate ──────────────────────────────────────── -->
        <q-step :name="4" title="Validate" icon="fact_check"
                :done="$(prefix)_step > 4"
                :error="$(prefix)_validation_failed">
          <div class="q-mb-md">
            <q-btn color="primary" icon="play_arrow" label="Run Validation"
                   @click="$(prefix)_run_validation"
                   :loading="$(prefix)_validating"
                   aria-label="Run data validation" />
          </div>

          <q-list v-if="$(prefix)_validation_rules.length > 0" bordered separator>
            <q-item v-for="rule in $(prefix)_validation_rules" :key="rule.name" dense>
              <q-item-section avatar>
                <q-icon
                  :name="rule.status === 'pass' ? 'check_circle' : rule.status === 'warn' ? 'warning' : 'error'"
                  :color="rule.status === 'pass' ? 'positive' : rule.status === 'warn' ? 'warning' : 'negative'"
                  :aria-label="rule.status"
                />
              </q-item-section>
              <q-item-section>
                <q-item-label>{{ rule.name }}</q-item-label>
                <q-item-label caption>{{ rule.message }}</q-item-label>
              </q-item-section>
              <q-item-section side>
                <q-badge :color="rule.status === 'pass' ? 'positive' : rule.status === 'warn' ? 'warning' : 'negative'"
                         :label="rule.row_count + ' rows'" />
              </q-item-section>
            </q-item>
          </q-list>

          <q-stepper-navigation>
            <q-btn flat color="primary" label="Back" @click="$(prefix)_step = 3"
                   class="q-mr-sm" aria-label="Back to column mapping step" />
            <q-btn color="primary" label="Next: De-identify" @click="$(prefix)_step = 5"
                   :disable="$(prefix)_validation_failed && !$(allow_phi)"
                   aria-label="Proceed to de-identification step" />
          </q-stepper-navigation>
        </q-step>

        <!-- ── Step 5: De-identify ───────────────────────────────────── -->
        <q-step :name="5" title="De-identify" icon="privacy_tip"
                :done="$(prefix)_step > 5"
                :error="$(prefix)_step5_error">
          <q-banner v-if="$(prefix)_phi_detected" class="bg-red-1 q-mb-md" rounded>
            <template v-slot:avatar>
              <q-icon name="warning" color="red" />
            </template>
            <strong>PHI Detected:</strong> The following columns contain or may contain
            protected health information: <code>{{ $(prefix)_phi_columns.join(', ') }}</code>.
            De-identification is strongly recommended.
          </q-banner>

          <q-toggle
            v-model="$(prefix)_apply_deidentify"
            :label="$(prefix)_apply_deidentify ? 'De-identification ON' : 'De-identification OFF'"
            color="positive"
            aria-label="Toggle PHI de-identification"
          />

          <div v-if="$(prefix)_apply_deidentify" class="q-mt-md">
            <q-input
              v-model="$(prefix)_org_salt"
              label="Organisation Salt (secret key for pseudonymisation)"
              type="password"
              outlined
              dense
              hint="Keep this secret. The same salt must be used for all ingestions from your organisation to allow cross-batch patient linking."
              aria-label="Organisation salt for pseudonymisation"
            />
          </div>

          <q-stepper-navigation>
            <q-btn flat color="primary" label="Back" @click="$(prefix)_step = 4"
                   class="q-mr-sm" aria-label="Back to validation step" />
            <q-btn color="primary" label="Next: Commit" @click="$(prefix)_step = 6"
                   aria-label="Proceed to commit step" />
          </q-stepper-navigation>
        </q-step>

        <!-- ── Step 6: Commit ────────────────────────────────────────── -->
        <q-step :name="6" title="Commit" icon="save_alt"
                :done="$(prefix)_committed"
                :error="$(prefix)_commit_error">
          <div class="q-mb-md">
            <q-btn color="positive" icon="save_alt" label="Commit Upload"
                   @click="$(prefix)_commit"
                   :loading="$(prefix)_committing"
                   :disable="$(prefix)_committed"
                   size="lg"
                   aria-label="Commit uploaded data" />
          </div>

          <q-card v-if="$(prefix)_committed" flat bordered class="q-pa-md bg-green-1">
            <q-card-section>
              <div class="text-h6 text-positive">
                <q-icon name="check_circle" /> Upload Committed
              </div>
            </q-card-section>
            <q-card-section>
              <div class="row q-col-gutter-sm">
                <div class="col-12">
                  <strong>Asset ID:</strong>
                  <code>{{ $(prefix)_asset_id }}</code>
                  <q-btn flat dense icon="content_copy" size="xs"
                         @click="navigator.clipboard.writeText($(prefix)_asset_id)"
                         aria-label="Copy asset ID to clipboard" />
                </div>
                <div class="col-12">
                  <strong>Rows committed:</strong> {{ $(prefix)_committed_rows }}
                </div>
                <div class="col-12">
                  <strong>De-identified:</strong> {{ $(prefix)_deidentified ? 'Yes' : 'No' }}
                </div>
                <div class="col-12">
                  <strong>Audit entry:</strong> <code>{{ $(prefix)_audit_entry_id }}</code>
                </div>
              </div>
            </q-card-section>
          </q-card>

          <q-banner v-if="$(prefix)_commit_error_msg" class="bg-red-1 q-mt-md" rounded>
            <template v-slot:avatar><q-icon name="error" color="red" /></template>
            {{ $(prefix)_commit_error_msg }}
          </q-banner>

          <q-stepper-navigation>
            <q-btn flat color="primary" label="Back" @click="$(prefix)_step = 5"
                   :disable="$(prefix)_committed"
                   class="q-mr-sm" aria-label="Back to de-identification step" />
            <q-btn v-if="$(prefix)_committed" color="secondary" icon="refresh"
                   label="Upload Another File" @click="$(prefix)_reset"
                   aria-label="Reset uploader to upload another file" />
          </q-stepper-navigation>
        </q-step>

      </q-stepper>
    </div>
    """
end

# ============================================================================
# REACTIVE MODEL MIXIN
# (Include the following @app fields in any tab that uses the upload component)
# ============================================================================

"""
    upload_model_fields(prefix::String) -> String

Returns the Stipple `@app` field declarations needed by the upload component
with the given `prefix`. Paste or `eval` these into the parent tab's `@app`
block.

Example:
    @app DataIntakeModel begin
        \$(upload_model_fields("upload"))
        @in  run_analysis::Bool = false
        ...
    end
"""
function upload_model_fields(prefix::String)::String
    """
    # ── Upload component state (prefix: $(prefix)) ──────────────────────────
    @in  $(prefix)_step::Int = 1
    @in  $(prefix)_file_staged::Bool = false
    @in  $(prefix)_filename::String = ""
    @in  $(prefix)_format::String = ""
    @in  $(prefix)_file_size_bytes::Int = 0
    @in  $(prefix)_row_count::Int = 0
    @out $(prefix)_column_names::Vector{String} = String[]
    @out $(prefix)_column_types::Dict = Dict()
    @out $(prefix)_column_summary::Vector = []
    @out $(prefix)_preview_rows::Vector = []
    @out $(prefix)_preview_columns::Vector = []
    @out $(prefix)_phi_detected::Bool = false
    @out $(prefix)_phi_columns::Vector{String} = String[]
    @in  $(prefix)_column_mapping::Dict = Dict()
    @out $(prefix)_target_fields::Vector{String} = String[]
    @in  $(prefix)_validating::Bool = false
    @out $(prefix)_validation_rules::Vector = []
    @out $(prefix)_validation_failed::Bool = false
    @in  $(prefix)_apply_deidentify::Bool = true
    # NOTE: Replace the default salt below with your organisation's secret key.
    # The default is a placeholder only; using it in production weakens pseudonymisation.
    @in  $(prefix)_org_salt::String = "HealthcareEconomicsOrg2024"
    @in  $(prefix)_committing::Bool = false
    @out $(prefix)_committed::Bool = false
    @out $(prefix)_asset_id::String = ""
    @out $(prefix)_committed_rows::Int = 0
    @out $(prefix)_deidentified::Bool = false
    @out $(prefix)_audit_entry_id::String = ""
    @out $(prefix)_commit_error::Bool = false
    @out $(prefix)_commit_error_msg::String = ""
    @out $(prefix)_step1_error::Bool = false
    @out $(prefix)_step2_error::Bool = false
    @out $(prefix)_step3_error::Bool = false
    @out $(prefix)_step5_error::Bool = false
    """
end
