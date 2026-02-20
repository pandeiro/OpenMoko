import express from 'express';
import { ensureDataDir } from './lib/data.js';

// Route imports
import reposRouter from './routes/repos.js';
import transcribeRouter from './routes/transcribe.js';
import reformRouter from './routes/reform.js';
import sessionRouter from './routes/session.js';
import subscribeRouter from './routes/subscribe.js';
import failuresRouter from './routes/failures.js';
import webhooksRouter from './routes/webhooks.js';
import eventsRouter from './routes/events.js';

const app = express();
const PORT = process.env.PORT || 3001;

// --- Body parsing ---
// JSON parsing with rawBody capture for webhook HMAC validation
app.use((req, res, next) => {
  if (req.headers['x-github-event']) {
    // Webhook requests: capture raw body for signature verification
    const chunks = [];
    req.on('data', (chunk) => chunks.push(chunk));
    req.on('end', () => {
      req.rawBody = Buffer.concat(chunks);
      try {
        req.body = JSON.parse(req.rawBody.toString());
      } catch {
        req.body = {};
      }
      next();
    });
  } else {
    next();
  }
});

app.use(express.json({ limit: '10mb' }));

// --- Health check ---
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok' });
});

// --- Routes ---
app.use('/api/repos', reposRouter);
app.use('/api', transcribeRouter);
app.use('/api', reformRouter);
app.use('/api/session', sessionRouter);
app.use('/api', subscribeRouter);
app.use('/api/failures', failuresRouter);
app.use('/webhooks', webhooksRouter);
app.use('/events', eventsRouter);

// --- Startup ---
async function start() {
  await ensureDataDir();
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`openmoko-events listening on port ${PORT}`);
  });
}

start().catch((err) => {
  console.error('Failed to start events service:', err);
  process.exit(1);
});
