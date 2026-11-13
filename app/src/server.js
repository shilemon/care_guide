const { app, logger } = require('./app');

const port = Number(process.env.PORT) || 3000;
const server = app.listen(port, () => logger.info({ port }, 'server started'));

// Graceful shutdown: stop accepting requests, finish the running ones, then exit
function shutdown(signal) {
  logger.info({ signal }, 'shutting down');
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10000).unref(); // safety net
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
