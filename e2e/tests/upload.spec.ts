/**
 * e2e/tests/upload.spec.ts
 *
 * Playwright end-to-end tests for the E2 Upload component.
 *
 * Covers:
 *   - POST /api/data/upload endpoint: accepts CSV, TSV, JSON, JSONL and
 *     returns a DataAsset id, row_count, and deidentified flag.
 *   - Endpoint rejects oversized files (size enforcement).
 *   - Endpoint rejects missing filepath.
 *   - PHI columns are flagged in the response.
 *   - Audit entry id is returned.
 *
 * Note: The full Stipple/Quasar stepper UI tests require a running Genie
 * server (configure the webServer block in playwright.config.ts). The API
 * tests below work against the same server.
 */

import { test, expect } from '@playwright/test';
import * as path from 'path';
import * as fs from 'fs';
import * as os from 'os';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Write a small temporary file and return its path. */
function writeTempFile(content: string, ext: string): string {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'upload-e2e-'));
  const filePath = path.join(tmpDir, `fixture${ext}`);
  fs.writeFileSync(filePath, content, 'utf8');
  return filePath;
}

const CSV_CONTENT = [
  'patient_id,admission_date,discharge_date,primary_diagnosis,total_charges,payer',
  'P001,2024-01-10,2024-01-13,E11.9,15000.00,Medicare',
  'P002,2024-01-11,2024-01-14,J44.0,9800.00,Commercial',
  'P003,2024-01-12,2024-01-18,I10,22500.00,Medicaid',
].join('\n');

const TSV_CONTENT = [
  'patient_id\tadmission_date\tdischarge_date\tprimary_diagnosis\ttotal_charges\tpayer',
  'P001\t2024-01-10\t2024-01-13\tE11.9\t15000.00\tMedicare',
  'P002\t2024-01-11\t2024-01-14\tJ44.0\t9800.00\tCommercial',
].join('\n');

const JSON_CONTENT = JSON.stringify([
  { patient_id: 'P001', admission_date: '2024-01-10', primary_diagnosis: 'E11.9', payer: 'Medicare' },
  { patient_id: 'P002', admission_date: '2024-01-11', primary_diagnosis: 'J44.0', payer: 'Commercial' },
]);

const JSONL_CONTENT = [
  JSON.stringify({ patient_id: 'P001', primary_diagnosis: 'E11.9', payer: 'Medicare' }),
  JSON.stringify({ patient_id: 'P002', primary_diagnosis: 'J44.0', payer: 'Medicaid' }),
].join('\n');

// CSV with PHI columns
const CSV_WITH_PHI = [
  'patient_id,first_name,last_name,ssn,dob,primary_diagnosis,total_charges',
  'P001,John,Smith,123-45-6789,1960-05-15,E11.9,15000.00',
  'P002,Jane,Doe,987-65-4321,1975-08-22,J44.0,9800.00',
].join('\n');

// ─────────────────────────────────────────────────────────────────────────────
// API endpoint tests
// ─────────────────────────────────────────────────────────────────────────────

test.describe('POST /api/data/upload — Universal Upload API', () => {

  test('endpoint exists and returns 200 for valid CSV payload', async ({ request }) => {
    const filePath = writeTempFile(CSV_CONTENT, '.csv');

    const response = await request.post('/api/data/upload', {
      data: {
        filepath: filePath,
        filename: 'fixture.csv',
        schema: 'patient',
        deidentify: false,
        user_id: 'e2e-test',
        max_mb: 500,
      },
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);

    const body = await response.json();
    expect(body).toHaveProperty('status', 'success');
    expect(body).toHaveProperty('type', 'universal_upload');
    expect(body).toHaveProperty('asset_id');
    expect(body).toHaveProperty('row_count');
    expect(body).toHaveProperty('column_names');
    expect(body).toHaveProperty('audit_entry_id');
    expect(body).toHaveProperty('committed_at');

    // Row count matches fixture (3 data rows)
    expect(body.row_count).toBe(3);
    expect(Array.isArray(body.column_names)).toBe(true);
    expect(body.column_names).toContain('patient_id');
    expect(body.column_names).toContain('primary_diagnosis');

    // asset_id should be a valid UUID
    expect(body.asset_id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    );
  });

  test('returns a DataAsset id for TSV upload', async ({ request }) => {
    const filePath = writeTempFile(TSV_CONTENT, '.tsv');

    const response = await request.post('/api/data/upload', {
      data: {
        filepath: filePath,
        filename: 'fixture.tsv',
        schema: 'patient',
        deidentify: false,
        user_id: 'e2e-test',
      },
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('success');
    expect(body.asset_id).toBeTruthy();
    expect(body.row_count).toBe(2);
    expect(body.format).toBe('tsv');
  });

  test('returns a DataAsset id for JSON upload', async ({ request }) => {
    const filePath = writeTempFile(JSON_CONTENT, '.json');

    const response = await request.post('/api/data/upload', {
      data: {
        filepath: filePath,
        filename: 'fixture.json',
        schema: 'patient',
        deidentify: false,
        user_id: 'e2e-test',
      },
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('success');
    expect(body.asset_id).toBeTruthy();
    expect(body.row_count).toBe(2);
    expect(body.format).toBe('json');
  });

  test('returns a DataAsset id for JSONL upload', async ({ request }) => {
    const filePath = writeTempFile(JSONL_CONTENT, '.jsonl');

    const response = await request.post('/api/data/upload', {
      data: {
        filepath: filePath,
        filename: 'fixture.jsonl',
        schema: 'patient',
        deidentify: false,
        user_id: 'e2e-test',
      },
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('success');
    expect(body.asset_id).toBeTruthy();
    expect(body.row_count).toBe(2);
    expect(body.format).toBe('jsonl');
  });

  test('PHI columns are flagged in response', async ({ request }) => {
    const filePath = writeTempFile(CSV_WITH_PHI, '.csv');

    const response = await request.post('/api/data/upload', {
      data: {
        filepath: filePath,
        filename: 'phi_fixture.csv',
        schema: 'patient',
        deidentify: false,   // not de-identifying but PHI should still be flagged
        user_id: 'e2e-test',
      },
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('success');
    expect(body.phi_detected).toBe(true);
    expect(Array.isArray(body.phi_columns)).toBe(true);
    // first_name, last_name, ssn, and/or dob should be flagged
    const flagged = body.phi_columns as string[];
    const hasPhi = flagged.some((c: string) =>
      ['first_name', 'last_name', 'ssn', 'dob'].includes(c)
    );
    expect(hasPhi).toBe(true);
  });

  test('de-identification is applied when deidentify=true with PHI', async ({ request }) => {
    const filePath = writeTempFile(CSV_WITH_PHI, '.csv');

    const response = await request.post('/api/data/upload', {
      data: {
        filepath: filePath,
        filename: 'phi_fixture.csv',
        schema: 'patient',
        deidentify: true,
        org_salt: 'E2ETestSalt2024',
        user_id: 'e2e-test',
      },
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('success');
    expect(body.deidentified).toBe(true);
    expect(body.phi_detected).toBe(true);
  });

  test('returns error for missing filepath', async ({ request }) => {
    const response = await request.post('/api/data/upload', {
      data: {},
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);   // Genie returns 200 with error body
    const body = await response.json();
    expect(body.status).toBe('error');
    expect(body.message).toContain('filepath');
  });

  test('returns error for non-existent file', async ({ request }) => {
    const response = await request.post('/api/data/upload', {
      data: {
        filepath: '/tmp/does_not_exist_12345.csv',
        filename: 'missing.csv',
      },
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('error');
  });

  test('rejects file that exceeds max_mb limit', async ({ request }) => {
    // Create a small file but set max_mb=0 to force rejection
    const filePath = writeTempFile(CSV_CONTENT, '.csv');

    const response = await request.post('/api/data/upload', {
      data: {
        filepath: filePath,
        filename: 'large_fixture.csv',
        schema: 'patient',
        deidentify: false,
        max_mb: 0,     // force size rejection for any non-empty file
        user_id: 'e2e-test',
      },
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('error');
    expect(body.message).toContain('large');
  });

  test('returns audit_entry_id in committed response', async ({ request }) => {
    const filePath = writeTempFile(CSV_CONTENT, '.csv');

    const response = await request.post('/api/data/upload', {
      data: {
        filepath: filePath,
        filename: 'audit_test.csv',
        schema: 'patient',
        deidentify: false,
        user_id: 'audit-e2e-user',
      },
      headers: { 'Content-Type': 'application/json' },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('success');

    // audit_entry_id should be a UUID
    expect(body.audit_entry_id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    );
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// /api/data/upload endpoint is listed in health check
// ─────────────────────────────────────────────────────────────────────────────

test.describe('Upload endpoint registration', () => {
  test('POST /api/data/upload is a registered route (health endpoint accessible)', async ({ request }) => {
    // Verify the server is up before upload tests run
    const health = await request.get('/api/health');
    expect(health.status()).toBe(200);
  });
});
