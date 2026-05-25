/**
 * Rural Hospital Economics Simulator — Client-side JavaScript
 *
 * Most interactivity is handled by Stipple's reactive model (Vue.js under the hood).
 * This file provides lightweight utilities for enhanced UX.
 */

(function () {
    "use strict";

    // ── Number Formatting Helpers ───────────────────────────────────────
    window.HospitalEcon = {
        /**
         * Format a number as US currency.
         * @param {number} value
         * @param {number} decimals
         * @returns {string}
         */
        formatCurrency: function (value, decimals) {
            decimals = decimals !== undefined ? decimals : 0;
            return new Intl.NumberFormat("en-US", {
                style: "currency",
                currency: "USD",
                minimumFractionDigits: decimals,
                maximumFractionDigits: decimals,
            }).format(value);
        },

        /**
         * Format a decimal as a percentage string.
         * @param {number} value  — e.g. 0.038
         * @param {number} decimals
         * @returns {string}
         */
        formatPercent: function (value, decimals) {
            decimals = decimals !== undefined ? decimals : 1;
            return (value * 100).toFixed(decimals) + "%";
        },

        /**
         * Abbreviate large numbers ($18,500,000 -> "$18.5M").
         * @param {number} value
         * @returns {string}
         */
        abbreviateNumber: function (value) {
            var abs = Math.abs(value);
            var sign = value < 0 ? "-" : "";
            if (abs >= 1e9) return sign + "$" + (abs / 1e9).toFixed(1) + "B";
            if (abs >= 1e6) return sign + "$" + (abs / 1e6).toFixed(1) + "M";
            if (abs >= 1e3) return sign + "$" + (abs / 1e3).toFixed(0) + "K";
            return sign + "$" + abs.toFixed(0);
        },

        /**
         * Return a CSS class based on a margin value.
         * @param {number} margin
         * @returns {string}
         */
        marginColorClass: function (margin) {
            if (margin >= 0.02) return "text-green";
            if (margin >= 0) return "text-green-8";
            if (margin >= -0.03) return "text-orange";
            return "text-red";
        },

        /**
         * Return risk level label from a numeric score.
         * @param {number} score 0-100
         * @returns {string}
         */
        riskLevel: function (score) {
            if (score >= 80) return "critical";
            if (score >= 60) return "high";
            if (score >= 40) return "moderate";
            return "low";
        },
    };

    // ── Keyboard Shortcuts ──────────────────────────────────────────────
    document.addEventListener("keydown", function (e) {
        // Ctrl+Shift+D → Dashboard
        if (e.ctrlKey && e.shiftKey && e.key === "D") {
            e.preventDefault();
            window.location.href = "/dashboard";
        }
        // Ctrl+Shift+R → Results
        if (e.ctrlKey && e.shiftKey && e.key === "R") {
            e.preventDefault();
            window.location.href = "/results";
        }
        // Ctrl+Shift+S → Simulate
        if (e.ctrlKey && e.shiftKey && e.key === "S") {
            e.preventDefault();
            window.location.href = "/simulate";
        }
    });

    // ── Plotly Responsive Resize ────────────────────────────────────────
    var resizeTimer;
    window.addEventListener("resize", function () {
        clearTimeout(resizeTimer);
        resizeTimer = setTimeout(function () {
            var plots = document.querySelectorAll(".js-plotly-plot");
            plots.forEach(function (plot) {
                if (window.Plotly) {
                    Plotly.Plots.resize(plot);
                }
            });
        }, 250);
    });

    // ── Navigation Search Mixin ────────────────────────────────────────
    // Injects `nav_search` into every Vue instance so the sidebar filter
    // input works via v-model without modifying individual Stipple models.
    // Vue is loaded in <head> so window.Vue is available when this runs.
    // Stipple creates the Vue app in an inline script after this file,
    // so the mixin is registered in time.
    if (window.Vue && window.Vue.mixin) {
        window.Vue.mixin({
            data: function () {
                return { nav_search: "" };
            },
        });
    }

    // ── Page Load ───────────────────────────────────────────────────────
    document.addEventListener("DOMContentLoaded", function () {
        console.log(
            "%c Rural Hospital Economics Simulator ",
            "background: #1976d2; color: white; font-size: 14px; padding: 4px 8px; border-radius: 4px;"
        );
        console.log("Client utilities loaded. Use HospitalEcon.* for formatting helpers.");
    });
})();
