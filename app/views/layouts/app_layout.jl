"""
Shared application layout with navigation sidebar.
Wraps all page content in a consistent Quasar layout with drawer navigation.

Navigation items are grouped into collapsible categories using q-expansion-item.
A search/filter input at the top of the drawer lets users find items quickly.

IMPORTANT: This function returns layout elements only. The calling route handler
wraps the result in `page(model, ui_func) |> html`.
"""

# ── Navigation item helper ──────────────────────────────────────────────
# Builds a single nav link with active-page highlighting and search filtering.
function _nav_item(label::String, href::String, icon::String)
    item(clickable=true, href=href,
        var"v-show"="!nav_search || '$(lowercase(label))'.includes(nav_search.toLowerCase())",
        var":class"="window.location.pathname === '$href' ? 'bg-blue-1 text-primary' : ''",
        dense=true, [
        item_section(avatar=true, [q__icon(name=icon, size="sm")]),
        item_section([item_label(label)]),
    ])
end

# ── Navigation group helper ─────────────────────────────────────────────
# Builds a collapsible expansion-item group containing multiple nav items.
function _nav_group(label::String, icon::String, items::Vector; default_opened::Bool=false)
    Html.div(
        var"v-show"="!nav_search || $(join(["'$(lowercase(it[1]))'.includes(nav_search.toLowerCase())" for it in items], " || "))",
        [
        quasar(:expansion_item,
            label=label, icon=icon,
            var"expand-separator"=true,
            var"dense-toggle"=true,
            var"header-class"="text-weight-bold",
            var"default-opened"=default_opened, [
            q__list(dense=true, padding=true,
                [_nav_item(it[1], it[2], it[3]) for it in items]
            ),
        ]),
        separator(),
    ])
end

function app_layout(model, page_title::String, content::Vector)
    [
        quasar(:layout, view="hHh lpR fFf", [
            # ── Top Bar ──────────────────────────────────────────────
            quasar(:header, elevated=true, class="bg-primary text-white", [
                toolbar([
                    btn("", icon="menu", flat=true, round=true, dense=true,
                        @click("left_drawer_open = !left_drawer_open")),
                    toolbar_title("Rural Hospital Economics Simulator"),
                    span(page_title, class="text-subtitle2 q-ml-md"),
                ]),
            ]),

            # ── Left Navigation Drawer ───────────────────────────────
            quasar(:drawer, side="left", var"v-model"="left_drawer_open",
                bordered=true, var"show-if-above"=true, class="bg-grey-1",
                var":width"="320", [

                # ── App Logo / Title ────────────────────────────────
                Html.div(class="q-pa-md text-center bg-primary text-white", [
                    q__icon(name="local_hospital", size="36px", class="q-mb-xs"),
                    Html.div(class="text-h6 text-weight-bold", "RHES"),
                    Html.div(class="text-caption", "Rural Hospital Economics Simulator"),
                ]),

                # ── Search / Filter ─────────────────────────────────
                Html.div(class="q-pa-sm", [
                    q__input(var"v-model"="nav_search",
                        dense=true, outlined=true,
                        placeholder="Filter navigation...",
                        class="q-mb-xs", [
                        template("", var"v-slot:prepend"=true, [
                            q__icon(name="search"),
                        ]),
                        template("", var"v-slot:append"=true, [
                            q__icon(name="close", class="cursor-pointer",
                                var"v-show"="nav_search",
                                @click("nav_search = ''")),
                        ]),
                    ]),
                ]),

                separator(),

                # ── Grouped Navigation ──────────────────────────────
                Html.div(style="overflow-y:auto; max-height:calc(100vh - 180px);", [
                    q__list(padding=true, [

                        # ── Core ────────────────────────────────────
                        _nav_group("Core", "dashboard", [
                            ("Dashboard",        "/dashboard",   "dashboard"),
                            ("Hospital Profile", "/profile",     "business"),
                            ("Scenarios",        "/scenarios",   "science"),
                            ("Simulate",         "/simulate",    "play_circle"),
                            ("Results",          "/results",     "assessment"),
                            ("Education",        "/education",   "school"),
                        ]; default_opened=true),

                        # ── Finance ─────────────────────────────────
                        _nav_group("Finance", "account_balance", [
                            ("Financial Sim",         "/financial-sim",         "tune"),
                            ("Cost Structure",        "/cost-structure",        "pie_chart"),
                            ("Cost Reimbursement",    "/cost-reimbursement",    "receipt_long"),
                            ("Break-Even",            "/break-even",            "balance"),
                            ("Cash Flow",             "/cash-flow",             "account_balance"),
                            ("Debt Capacity",         "/debt-capacity",         "credit_score"),
                            ("Revenue Cycle",         "/revenue-cycle",         "loop"),
                            ("340B Program",          "/340b",                  "medication"),
                            ("TEAM Bundled",          "/team-bundled",          "group_work"),
                            ("Telehealth ROI",        "/telehealth",            "video_call"),
                            ("VBC Transition",        "/vbc-transition",        "trending_up"),
                            ("Medicaid Supplemental", "/medicaid-supplemental", "health_and_safety"),
                        ]),

                        # ── CFO Analytics ───────────────────────────
                        _nav_group("CFO Analytics", "analytics", [
                            ("CFO Dashboard",      "/cfo",               "speed"),
                            ("Three-Statement",    "/three-statement",   "table_chart"),
                            ("DuPont Analysis",    "/dupont",            "account_tree"),
                            ("Distress Scoring",   "/distress-scoring",  "monitor_heart"),
                            ("WACC Calculator",    "/wacc",              "percent"),
                            ("Capital Expenditure", "/capex",            "construction"),
                            ("LBO Analysis",       "/lbo",               "business_center"),
                            ("Real Options",       "/sensitivity",       "swap_vert"),
                            ("VaR/CVaR",           "/vbc-bayesian",      "psychology"),
                            ("Copula MC",          "/ma-risk",           "merge"),
                            ("Treasury Forecast",  "/cash-flow",         "account_balance"),
                            ("Forecasting",        "/scenario-lab",      "science"),
                            ("Revenue Variance",   "/revenue",           "attach_money"),
                            ("Physician Comp",     "/workforce",         "engineering"),
                        ]),

                        # ── Quality ─────────────────────────────────
                        _nav_group("Quality", "health_and_safety", [
                            ("CMS Programs",    "/quality",    "health_and_safety"),
                            ("SPC Charts",      "/benchmark",  "radar"),
                            ("Benchmarking",    "/benchmark",  "radar"),
                        ]),

                        # ── Risk & Strategy ─────────────────────────
                        _nav_group("Risk & Strategy", "shield", [
                            ("Closure Risk",          "/closure-risk",          "warning"),
                            ("REH Conversion",        "/conversion",            "swap_horiz"),
                            ("Staffing Optimization", "/staffing",              "groups"),
                            ("Payer Negotiation",     "/payer-negotiation",     "handshake"),
                            ("Strategic Planner",     "/strategic-plan",        "map"),
                            ("Policy Impact",         "/policy",                "gavel"),
                            ("Capital Scoring",       "/capital-scoring",       "analytics"),
                            ("Scenario Planning",     "/scenario-planning",     "explore"),
                            ("Blue Ocean",            "/blue-ocean",            "waves"),
                            ("Disaster Resilience",   "/disaster-resilience",   "emergency"),
                        ]),

                        # ── Community & Access ──────────────────────
                        _nav_group("Community & Access", "people", [
                            ("Community Impact",  "/community-impact",  "people"),
                            ("Community Benefit", "/community-benefit", "volunteer_activism"),
                            ("SDOH",              "/sdoh",              "diversity_3"),
                            ("Geographic Access", "/geographic-access", "map"),
                            ("Network Economics", "/network-economics", "hub"),
                        ]),

                        # ── Clinical ────────────────────────────────
                        _nav_group("Clinical", "medical_services", [
                            ("PK ODE",            "/throughput",       "timeline"),
                            ("Bayesian Analysis", "/vbc-bayesian",     "psychology"),
                            ("FMEA",              "/readmission-risk", "personal_injury"),
                        ]),

                        # ── Data & Analytics ────────────────────────
                        _nav_group("Data & Analytics", "storage", [
                            ("Data Intake",   "/data/intake",    "upload_file"),
                            ("Data Prepare",  "/data/prepare",   "build"),
                            ("Cohorts",       "/cohorts",        "group"),
                            ("Cost Analysis", "/cost-analysis",  "price_change"),
                            ("Revenue",       "/revenue",        "attach_money"),
                            ("Profitability", "/profitability",  "trending_up"),
                        ]),

                        # ── Statistical ─────────────────────────────
                        _nav_group("Statistical", "functions", [
                            ("Statistics",        "/stats",       "bar_chart"),
                            ("Regression",        "/regression",  "show_chart"),
                            ("Causal Inference",  "/causal",      "device_hub"),
                            ("CEA",               "/cea",         "compare_arrows"),
                            ("CBA",               "/cba",         "account_balance_wallet"),
                            ("Comparative",       "/comparative", "difference"),
                        ]),

                        # ── Advanced ────────────────────────────────
                        _nav_group("Advanced", "science", [
                            ("ML",            "/ml",           "psychology"),
                            ("Systems",       "/systems",      "account_tree"),
                            ("Scenario Lab",  "/scenario-lab", "science"),
                            ("Functions",     "/functions",    "functions"),
                            ("Visualize",     "/visualize",    "insert_chart"),
                            ("Reports",       "/reports",      "description"),
                            ("Database",      "/database",     "storage"),
                        ]),

                        # ── Compliance ──────────────────────────────
                        _nav_group("Compliance", "verified_user", [
                            ("Audit Trail", "/audit",   "policy"),
                            ("MA Risk",     "/ma-risk", "merge"),
                        ]),

                        # ── Dev tools (non-production only) ─────────
                        if get(ENV, "GENIE_ENV", "dev") != "prod"
                            [
                                _nav_group("Developer", "widgets", [
                                    ("Component Library", "/dev/components", "widgets"),
                                ]),
                            ]
                        else
                            []
                        end...,

                    ]),
                ]),
            ]),

            # ── Main Content Area ────────────────────────────────────
            quasar(:page_container, [
                quasar(:page, padding=true, [
                    Html.div(class="q-pa-md", content)
                ]),
            ]),
        ]),

        script(src="/js/app.js"),

        # ── BugReport floating action button (E27) ──────────────────────────
        # Rendered once here so every current and future page inherits it.
        bug_report_button()...,
    ]
end
