"""NSA-IDR Claim Evaluator UI."""
function ui_nsa_idr(model)
    app_layout(model, "NSA-IDR", [
        row(class="q-mb-md items-center", [
            cell(class="col", [h5("No Surprises Act — IDR Claim Evaluator", class="q-mb-none"),
                p("Baseball arbitration economics: expected payment vs QPA + admin fees", class="text-grey-7")]),
        ]),
        row(class="q-gutter-md", [
            cell(class="col-md-4 col-xs-12", [card([card_section([
                h6("Claim Details", class="q-mb-md"),
                textfield(:billed_amount, label="Billed Amount (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:qpa, label="QPA / Median Rate (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:our_offer, label="Our IDR Offer (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:payer_offer, label="Payer Offer (\$)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:win_probability, label="Provider Win Rate (%)", type="number", filled=true, dense=true, class="q-mb-sm"),
                textfield(:batch_size, label="Batch Size (# claims)", type="number", filled=true, dense=true, class="q-mb-sm"),
                quasar(:q_toggle, var"v-model"=:is_complex, label="Complex claim (\$350 fee)", class="q-mb-md"),
                btn("Evaluate Claim", icon="gavel", color="primary", @click(:evaluate_claim)),
            ])])]),
            cell(class="col-md-8 col-xs-12", [
                card(class="q-mb-md", [card_section([
                    h6("Claim Result", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-md", [
                        cell(class="col-md-3 col-xs-6", [card(class="text-center", [card_section([
                            p("Expected Payment", class="text-overline text-caption q-mb-none"),
                            p("\${{ expected_payment.toLocaleString(undefined,{maximumFractionDigits:0}) }}", class="text-weight-bold"),
                        ])])]),
                        cell(class="col-md-3 col-xs-6", [card(class="text-center", [card_section([
                            p("Admin Fee (our share)", class="text-overline text-caption q-mb-none"),
                            p("\${{ admin_fee.toFixed(0) }}", class="text-weight-bold text-orange"),
                        ])])]),
                        cell(class="col-md-3 col-xs-6", [card(class="text-center", [card_section([
                            p("Net Gain vs QPA", class="text-overline text-caption q-mb-none"),
                            p("\${{ net_gain_vs_qpa.toFixed(0) }}", class="text-weight-bold",
                              var":class"="net_gain_vs_qpa > 0 ? 'text-green' : 'text-red'"),
                        ])])]),
                        cell(class="col-md-3 col-xs-6", [card(class="text-center", [card_section([
                            p("Recommendation", class="text-overline text-caption q-mb-none"),
                            badge(var"v-if"="recommend_idr", "PURSUE IDR", color="green"),
                            badge(var"v-if"="!recommend_idr", "ACCEPT QPA", color="orange"),
                        ])])]),
                    ]),
                    quasar(:q_banner, class="bg-blue-1 q-pa-sm rounded-borders", [
                        p("{{ recommendation_text }}", class="text-body2 q-mb-none"),
                    ]),
                ])]),
                card([card_section([
                    h6("Portfolio IDR Opportunity", class="q-mb-md"),
                    row(class="q-gutter-sm q-mb-sm", [
                        cell(class="col-md-3 col-xs-6", [textfield(:annual_oon_claims, label="Annual OON Claims", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3 col-xs-6", [textfield(:avg_billed, label="Avg Billed (\$)", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3 col-xs-6", [textfield(:qpa_ratio, label="QPA % of Billed", type="number", filled=true, dense=true)]),
                        cell(class="col-md-3 col-xs-6", [textfield(:offer_ratio, label="Our Offer % of Billed", type="number", filled=true, dense=true)]),
                    ]),
                    btn("Run Portfolio Analysis", icon="account_balance", color="secondary", @click(:run_portfolio)),
                    separator(class="q-my-md"),
                    row(class="q-gutter-sm", [
                        cell(class="col-md-3", [card(class="text-center", [card_section([p("Annual Opportunity", class="text-overline text-caption q-mb-none"), p("\${{ (portfolio_annual_opportunity/1000).toFixed(0) }}K", class="text-weight-bold text-green")])])]),
                        cell(class="col-md-3", [card(class="text-center", [card_section([p("Viable Claims", class="text-overline text-caption q-mb-none"), p("{{ n_viable_claims }}", class="text-weight-bold")])])]),
                        cell(class="col-md-3", [card(class="text-center", [card_section([p("Per-Claim Net Gain", class="text-overline text-caption q-mb-none"), p("\${{ per_claim_net_gain.toFixed(0) }}", class="text-weight-bold")])])]),
                        cell(class="col-md-3", [card(class="text-center", [card_section([p("Viable?", class="text-overline text-caption q-mb-none"), badge(var"v-if"="portfolio_viable", "YES", color="green"), badge(var"v-if"="!portfolio_viable", "NO", color="orange")])])]),
                    ]),
                ])]),
            ]),
        ]),
    ])
end
