const request = require('supertest');
const { app } = require('../src/app');

test('GET / returns hello message', async () => {
  const res = await request(app).get('/');
  expect(res.status).toBe(200);
  expect(res.body.message).toBe('Hello from DevOps Task!');
  expect(res.body.status).toBe('running');
  expect(res.body).toHaveProperty('version');
});

test('GET /health returns ok', async () => {
  const res = await request(app).get('/health');
  expect(res.status).toBe(200);
  expect(res.body.status).toBe('ok');
});

test('GET /metrics exposes prometheus metrics', async () => {
  await request(app).get('/');
  const res = await request(app).get('/metrics');
  expect(res.status).toBe(200);
  expect(res.text).toContain('http_requests_total');
  expect(res.text).toContain('http_request_duration_seconds_bucket');
});

test('GET /error returns 500 and is counted', async () => {
  const res = await request(app).get('/error');
  expect(res.status).toBe(500);
  const metrics = await request(app).get('/metrics');
  expect(metrics.text).toContain('http_errors_total');
});
