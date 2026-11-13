const express = require('express');
const client = require('prom-client');
const pino = require('pino');
const pkg = require('../package.json');

// Structured JSON logs to stdout. Config comes from environment variables.
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: { env: process.env.ENV_NAME || 'local' },
  timestamp: pino.stdTimeFunctions.isoTime,
  formatters: { level: (label) => ({ level: label }) },
});

// Prometheus metrics: request count, error count, latency histogram
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const requestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register],
});
const errorsTotal = new client.Counter({
  name: 'http_errors_total',
  help: 'Total HTTP 5xx responses',
  labelNames: ['route'],
  registers: [register],
});
const latency = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request latency in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
  registers: [register],
});

const app = express();

app.use((req, res, next) => {
  const stop = latency.startTimer();
  res.on('finish', () => {
    const route = req.route ? req.route.path : 'unmatched';
    stop({ method: req.method, route });
    requestsTotal.inc({ method: req.method, route, status: res.statusCode });
    if (res.statusCode >= 500) errorsTotal.inc({ route });
    // Do not log health checks and scrapes (too noisy)
    if (route !== '/health' && route !== '/metrics') {
      const requestLog = { method: req.method, path: req.path, status: res.statusCode };
      if (res.statusCode >= 500) logger.error(requestLog, 'request');
      else logger.info(requestLog, 'request');
    }
  });
  next();
});

app.get('/', (req, res) => {
  res.json({
    message: 'Hello from DevOps Task!',
    status: 'running',
    version: process.env.APP_VERSION || pkg.version,
  });
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));

// Used only to generate errors for the dashboards and alerts demo
app.get('/error', (req, res) => res.status(500).json({ error: 'simulated error' }));

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

module.exports = { app, logger };
