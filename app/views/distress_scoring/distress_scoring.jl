"""
UI for distress scoring (Altman Z″ + Beneish M).
"""

function ui_distress_scoring(model::M) where {M}
    app_layout(model, "Distress Scoring (Altman Z″ + Beneish M)", [
        row([cell(class="col", [
            md"## Current Year Financials",
            card(class="q-mb-md", [
                card_section([
                    row([
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:revenue_current, label="Revenue", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:expenses_current, label="Expenses", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:ebit_current, label="EBIT", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:interest_current, label="Interest", filled=true, dense=true)
                        ])
                    ])
                ])
            ])
        ])]),

        row([cell(class="col", [
            md"## Balance Sheet (Snapshot)",
            card(class="q-mb-md", [
                card_section([
                    row([
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:cash_curr, label="Cash", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:ar_curr, label="AR", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:ppe_gross_curr, label="Gross PP&E", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:depr_accum_curr, label="Accum. Depr.", filled=true, dense=true)
                        ])
                    ]),
                    row([
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:ap_curr, label="AP", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:ltd_curr, label="LT Debt", filled=true, dense=true)
                        ]),
                        cell(class="col-md-3", [
                            q__input(:"v-model.number"=>:na_curr, label="Net Assets", filled=true, dense=true)
                        ])
                    ])
                ])
            ])
        ])]),

        row([cell(class="col", [
            q__btn(color="primary", label="Score Distress Risk", @click=(:run_analysis => true), dense=true, class="q-mb-md")
        ])]),

        row([cell(class="col", [
            @if(:is_loading)
                card(class="q-mb-md", [card_section(["Computing scores..."])])
            end,
            @if(!isempty(:error_message))
                card(class="q-mb-md bg-negative", [card_section([:error_message])])
            end
        ])]),

        @if(!isnothing(:altman))
            [
                row([cell(class="col", [
                    md"## Altman Z″-Score",
                    card([
                        card_section([
                            row([
                                cell(class="col-md-6", [
                                    div(class="text-center", [
                                        div(class="text-h4", [
                                            string(round(:altman["z_double_prime"], digits=2))
                                        ]),
                                        div(class="text-caption", ["Z″ Score"])
                                    ])
                                ]),
                                cell(class="col-md-6", [
                                    div(class="text-center", [
                                        q__chip(
                                            :label => uppercase(:altman["band"]),
                                            :color => (
                                                :altman["band"] == "safe" ? "positive" :
                                                :altman["band"] == "grey" ? "warning" :
                                                "negative"
                                            ),
                                            dense=true
                                        )
                                    ])
                                ])
                            ]),
                            md"**Components:**",
                            row([
                                cell(class="col-md-3", [
                                    div(class="text-center", [
                                        div(class="text-body2", [string(round(:altman["x1"], digits=4))]),
                                        div(class="text-caption", ["X1: WC/TA"])
                                    ])
                                ]),
                                cell(class="col-md-3", [
                                    div(class="text-center", [
                                        div(class="text-body2", [string(round(:altman["x2"], digits=4))]),
                                        div(class="text-caption", ["X2: RE/TA"])
                                    ])
                                ]),
                                cell(class="col-md-3", [
                                    div(class="text-center", [
                                        div(class="text-body2", [string(round(:altman["x3"], digits=4))]),
                                        div(class="text-caption", ["X3: EBIT/TA"])
                                    ])
                                ]),
                                cell(class="col-md-3", [
                                    div(class="text-center", [
                                        div(class="text-body2", [string(round(:altman["x4"], digits=4))]),
                                        div(class="text-caption", ["X4: E/L"])
                                    ])
                                ])
                            ])
                        ])
                    ])
                ])]),

                row([cell(class="col", [
                    md"## Beneish M-Score (Earnings Quality)",
                    card([
                        card_section([
                            row([
                                cell(class="col-md-6", [
                                    div(class="text-center", [
                                        div(class="text-h4", [
                                            string(round(:beneish["m_score"], digits=2))
                                        ]),
                                        div(class="text-caption", ["M-Score"])
                                    ])
                                ]),
                                cell(class="col-md-6", [
                                    @if(:beneish["flag_manipulation"])
                                        q__chip(
                                            :label => "⚠ Likely Manipulator",
                                            :color => "negative",
                                            dense=true
                                        )
                                    else
                                        q__chip(
                                            :label => "✓ Appears Clean",
                                            :color => "positive",
                                            dense=true
                                        )
                                    end
                                ])
                            ])
                        ])
                    ])
                ])])
            ]
        end
    ])
end
