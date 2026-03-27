// Rural Hospital Economics Simulator - Custom JavaScript
// Minimal JS since Stipple.jl handles reactivity via Vue.js

document.addEventListener('DOMContentLoaded', function() {
    console.log('Rural Hospital Economics Simulator loaded');
});

// Format currency values for display
function formatCurrency(value) {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        maximumFractionDigits: 0
    }).format(value);
}

// Format percentage values
function formatPercent(value) {
    return (value * 100).toFixed(1) + '%';
}

// Export chart as PNG
function exportChart(chartId) {
    var chart = document.getElementById(chartId);
    if (chart && window.Plotly) {
        Plotly.downloadImage(chart, {
            format: 'png',
            width: 1200,
            height: 600,
            filename: 'hospital-simulation-chart'
        });
    }
}
