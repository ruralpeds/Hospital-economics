"""
Advanced Analytics / ML UI (E20) — model training, batch prediction,
anomaly detection, and patient stratification with three sub-tabs.
"""

function ui_ml(model)
    app_layout(model, "Advanced Analytics / ML", [
        row(class="q-mb-md items-center", [
            cell(class="col", [
                h5("Advanced Analytics / ML", class="q-mb-none"),
                p("Risk prediction, readmission models, anomaly detection, and patient stratification",
                  class="text-grey-7"),
            ]),
        ]),

        # Error banner
        template(var"v-if"="errors && errors.length > 0", [
            card(class="q-mb-md bg-red-1 text-red-9", [
                card_section([
                    p("Errors:", class="text-weight-bold q-mb-xs"),
                    template(var"v-for"="(err, idx) in errors", var":key"="idx", [
                        p(class="q-mb-none", ["{{ err }}"]),
                    ]),
                ]),
            ]),
        ]),

        # Sub-tabs
        qtabs(:active_tab, class="q-mb-md", [
            qtab(name="train",   label="Train Model"),
            qtab(name="predict", label="Predict"),
            qtab(name="monitor", label="Anomaly Detection"),
        ]),
        qtabpanels(:active_tab, [
            # Train tab
            qtabpanel(name="train", [
                form_grid([
                    (name=:cohort_id,    type=:text,    label="Training Cohort Asset ID"),
                    (name=:outcome_col,  type=:text,    label="Outcome Column"),
                    (name=:algorithm,    type=:select,  label="Algorithm",
                     options=[
                         Dict("value"=>"glm", "label"=>"GLM (Logistic Regression)"),
                         Dict("value"=>"rf",  "label"=>"Random Forest"),
                         Dict("value"=>"gbm", "label"=>"Gradient Boosting (XGBoost)"),
                         Dict("value"=>"lr",  "label"=>"LASSO Regression"),
                     ]),
                    (name=:train_split,  type=:numeric, label="Train/Test Split",  help="e.g. 0.8 for 80% train"),
                    (name=:n_folds,      type=:numeric, label="CV Folds",          help="Number of cross-validation folds"),
                ], title="Model Configuration"),

                row(class="q-mb-md", [
                    cell(class="col-auto", [
                        btn("Train Model", icon="model_training", color="primary",
                            @click(:do_train), var":loading"="running"),
                    ]),
                ]),

                # Model metrics
                card(class="q-mb-md", [
                    card_section([
                        h6("Model Performance", class="q-mb-sm"),
                        row([
                            cell(class="col-md-3 col-xs-6", [
                                p("AUC-ROC", class="text-overline q-mb-none"),
                                p("{{ model_metrics.auc !== undefined ? model_metrics.auc.toFixed(4) : '—' }}", class="text-h6"),
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                p("Accuracy", class="text-overline q-mb-none"),
                                p("{{ model_metrics.accuracy !== undefined ? (model_metrics.accuracy * 100).toFixed(1) + '%' : '—' }}", class="text-h6"),
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                p("F1 Score", class="text-overline q-mb-none"),
                                p("{{ model_metrics.f1 !== undefined ? model_metrics.f1.toFixed(4) : '—' }}", class="text-h6"),
                            ]),
                            cell(class="col-md-3 col-xs-6", [
                                p("Brier Score", class="text-overline q-mb-none"),
                                p("{{ model_metrics.brier !== undefined ? model_metrics.brier.toFixed(4) : '—' }}", class="text-h6"),
                            ]),
                        ]),
                    ]),
                ]),

                # ROC and calibration plots
                row(class="q-mb-md q-gutter-md", [
                    cell(class="col-md-6 col-xs-12", [
                        plot_panel(:roc_data, :roc_layout, preset=:line, title="ROC Curve"),
                    ]),
                    cell(class="col-md-6 col-xs-12", [
                        plot_panel(:calibration_data, :calibration_layout,
                            preset=:scatter, title="Calibration Plot"),
                    ]),
                ]),

                # Saved models
                result_table(
                    :saved_models,
                    columns=[
                        (name="model_id",    label="Model ID",   field="model_id",   sortable=true),
                        (name="algorithm",   label="Algorithm",  field="algorithm",  sortable=true),
                        (name="auc",         label="AUC",        field="auc",        sortable=true),
                        (name="trained_at",  label="Trained At", field="trained_at", sortable=true),
                    ],
                    title="Saved Models",
                ),
            ]),

            # Predict tab
            qtabpanel(name="predict", [
                form_grid([
                    (name=:selected_model_id, type=:text, label="Saved Model ID",
                     help="Model ID from the Train tab"),
                    (name=:batch_asset_id,    type=:text, label="Batch Dataset Asset ID",
                     help="New cohort to score"),
                ], title="Prediction Configuration"),

                row(class="q-mb-md", [
                    cell(class="col-auto", [
                        btn("Predict", icon="play_arrow", color="primary",
                            @click(:do_predict), var":loading"="running"),
                    ]),
                ]),

                result_table(
                    :prediction_rows,
                    columns=[
                        (name="patient_id",  label="Patient ID",   field="patient_id",  sortable=true),
                        (name="probability", label="Risk Score",    field="probability", sortable=true),
                        (name="risk_tier",   label="Risk Tier",     field="risk_tier",   sortable=true),
                    ],
                    title="Predictions",
                ),
            ]),

            # Monitor / Anomaly tab
            qtabpanel(name="monitor", [
                form_grid([
                    (name=:batch_asset_id, type=:text, label="Dataset Asset ID",
                     help="Claims or encounters dataset to scan"),
                ], title="Anomaly Detection"),

                row(class="q-mb-md", [
                    cell(class="col-auto", [
                        btn("Detect Anomalies", icon="warning", color="warning",
                            @click(:do_anomaly), var":loading"="running"),
                    ]),
                ]),

                result_table(
                    :anomaly_rows,
                    columns=[
                        (name="record_id",     label="Record ID",     field="record_id",     sortable=true),
                        (name="anomaly_score", label="Anomaly Score", field="anomaly_score", sortable=true),
                        (name="reason",        label="Reason",        field="reason",        sortable=false),
                    ],
                    title="Detected Anomalies",
                ),
            ]),
        ]),

        export_bar(csv_field=:do_csv, xlsx_field=:do_xlsx),
    ])
end
