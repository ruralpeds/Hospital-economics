import { test, expect } from '@playwright/test';
import { SIMULATION_ENDPOINTS, OPTIMIZATION_ENDPOINTS, DATA_ENDPOINTS } from '../fixtures/test-data';

test.describe('API Health & Endpoints', () => {

  test('GET /api/health returns 200 with expected fields', async ({ request }) => {
    const response = await request.get('/api/health');
    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body).toHaveProperty('status', 'ok');
    expect(body).toHaveProperty('version');
    expect(body).toHaveProperty('timestamp');
    expect(body).toHaveProperty('engines');
    expect(body).toHaveProperty('tools');
    expect(body.engines).toContain('deterministic');
    expect(body.engines).toContain('monte_carlo');
    expect(body.tools).toBeGreaterThanOrEqual(27);
  });

  test('health check version is semver-like', async ({ request }) => {
    const response = await request.get('/api/health');
    const body = await response.json();
    expect(body.version).toMatch(/^\d+\.\d+\.\d+$/);
  });

  // ── Simulation Endpoints ──────────────────────────────────────────

  test.describe('Simulation API endpoints', () => {
    for (const endpoint of SIMULATION_ENDPOINTS) {
      test(`POST ${endpoint} returns success with valid payload`, async ({ request }) => {
        const response = await request.post(endpoint, {
          data: { hospital_id: 1, params: {} },
          headers: { 'Content-Type': 'application/json' },
        });
        expect(response.status()).toBe(200);

        const body = await response.json();
        expect(body).toHaveProperty('status', 'success');
        expect(body).toHaveProperty('engine');
        expect(body).toHaveProperty('message');
      });
    }
  });

  // ── Optimization Endpoints ────────────────────────────────────────

  test.describe('Optimization API endpoints', () => {
    for (const endpoint of OPTIMIZATION_ENDPOINTS) {
      test(`POST ${endpoint} returns success`, async ({ request }) => {
        const response = await request.post(endpoint, {
          data: { hospital_id: 1, params: {} },
          headers: { 'Content-Type': 'application/json' },
        });
        expect(response.status()).toBe(200);

        const body = await response.json();
        expect(body).toHaveProperty('status', 'success');
        expect(body).toHaveProperty('type');
      });
    }
  });

  // ── Risk & Conversion Endpoints ───────────────────────────────────

  test('POST /api/risk/closure returns success', async ({ request }) => {
    const response = await request.post('/api/risk/closure', {
      data: { hospital_id: 1 },
      headers: { 'Content-Type': 'application/json' },
    });
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('success');
    expect(body.type).toBe('closure_risk');
  });

  test('POST /api/conversion returns success', async ({ request }) => {
    const response = await request.post('/api/conversion', {
      data: { hospital_id: 1 },
      headers: { 'Content-Type': 'application/json' },
    });
    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('success');
    expect(body.type).toBe('reh_conversion');
  });

  // ── Data Import/Export Endpoints ──────────────────────────────────

  test.describe('Data import/export endpoints', () => {
    for (const endpoint of DATA_ENDPOINTS) {
      test(`POST ${endpoint} returns success`, async ({ request }) => {
        const response = await request.post(endpoint, {
          data: {},
          headers: { 'Content-Type': 'application/json' },
        });
        expect(response.status()).toBe(200);

        const body = await response.json();
        expect(body).toHaveProperty('status', 'success');
      });
    }
  });
});
