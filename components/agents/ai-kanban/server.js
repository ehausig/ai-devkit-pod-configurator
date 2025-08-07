const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');
const fs = require('fs');
const os = require('os');
const JournalReader = require('./lib/journal-reader');
const StateBuilder = require('./lib/state-builder');
const MetricsCalculator = require('./lib/metrics');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Determine the correct journal path
const journalPath = process.env.JOURNAL_PATH || 
                   path.join(os.homedir(), 'workspace', 'JOURNAL.md') ||
                   '/home/devuser/workspace/JOURNAL.md';

console.log(`Looking for journal at: ${journalPath}`);

// Initialize components
const stateBuilder = new StateBuilder();
const metricsCalculator = new MetricsCalculator();
const journalReader = new JournalReader(journalPath);

// Track current status
let currentStatus = {
  type: 'initializing',
  message: 'Starting up...'
};

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// REST API endpoints
app.get('/api/state', (req, res) => {
  res.json({
    cards: stateBuilder.getCurrentState(),
    metrics: metricsCalculator.getMetrics(stateBuilder.getCurrentState(), stateBuilder.getEvents()),
    status: currentStatus
  });
});

app.get('/api/events', (req, res) => {
  const limit = parseInt(req.query.limit) || 50;
  const events = stateBuilder.getEvents();
  res.json(events.slice(-limit));
});

app.get('/api/agents', (req, res) => {
  res.json(stateBuilder.getActiveAgents());
});

app.get('/api/status', (req, res) => {
  res.json(currentStatus);
});

// Add debug endpoint
app.get('/api/debug', (req, res) => {
  res.json({
    journalPath: journalPath,
    journalExists: fs.existsSync(journalPath),
    eventCount: stateBuilder.getEvents().length,
    cardCount: stateBuilder.getCurrentState().length,
    status: currentStatus
  });
});

// WebSocket connection handling
wss.on('connection', (ws) => {
  console.log('New WebSocket connection established');
  
  // Send initial state
  ws.send(JSON.stringify({
    type: 'initial',
    data: {
      cards: stateBuilder.getCurrentState(),
      metrics: metricsCalculator.getMetrics(stateBuilder.getCurrentState(), stateBuilder.getEvents()),
      agents: stateBuilder.getActiveAgents(),
      recentEvents: stateBuilder.getEvents().slice(-20),
      status: currentStatus
    }
  }));
  
  ws.on('close', () => {
    console.log('WebSocket connection closed');
  });
  
  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
  });
});

// Broadcast updates to all connected clients
function broadcastUpdate(type, data) {
  const message = JSON.stringify({ type, data });
  wss.clients.forEach((client) => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
}

// Handle journal reader status updates
journalReader.on('status', (status) => {
  console.log('Journal reader status:', status);
  currentStatus = status;
  broadcastUpdate('status', status);
});

// Process journal events
journalReader.on('event', (event) => {
  // Log event details for debugging
  console.log('New event:', {
    type: event.event_type,
    agent: event.agent,
    card: event.card_id || ''
  });
  
  // Update state
  stateBuilder.processEvent(event);
  
  // Calculate new metrics
  const metrics = metricsCalculator.getMetrics(stateBuilder.getCurrentState(), stateBuilder.getEvents());
  
  // Broadcast the update
  broadcastUpdate('event', {
    event: event,
    cards: stateBuilder.getCurrentState(),
    metrics: metrics,
    agents: stateBuilder.getActiveAgents()
  });
});

journalReader.on('error', (error) => {
  console.error('Journal reader error:', error);
  currentStatus = {
    type: 'error',
    message: 'Error reading journal file',
    details: error.message
  };
  broadcastUpdate('status', currentStatus);
});

// Start the journal reader
journalReader.start();

// Start the server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`AI Kanban Dashboard running on http://localhost:${PORT}`);
  console.log(`Monitoring journal at: ${journalPath}`);
  console.log(`Journal exists: ${fs.existsSync(journalPath)}`);
  
  // Create journal file if it doesn't exist
  if (!fs.existsSync(journalPath)) {
    console.log('Journal file not found, creating empty file...');
    try {
      const dir = path.dirname(journalPath);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.writeFileSync(journalPath, '');
      console.log('Created empty journal file');
    } catch (err) {
      console.error('Could not create journal file:', err);
    }
  }
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  journalReader.stop();
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});

// Add debug mode
if (process.env.DEBUG) {
  process.env.DEBUG_JOURNAL = 'true';
}
