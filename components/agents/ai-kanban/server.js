const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const path = require('path');
const JournalReader = require('./lib/journal-reader');
const StateBuilder = require('./lib/state-builder');
const MetricsCalculator = require('./lib/metrics');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Initialize components
const journalPath = '/home/devuser/workspace/JOURNAL.md';
const stateBuilder = new StateBuilder();
const metricsCalculator = new MetricsCalculator();
const journalReader = new JournalReader(journalPath);

// Serve static files
app.use(express.static(path.join(__dirname, 'public')));

// REST API endpoints
app.get('/api/state', (req, res) => {
  res.json({
    cards: stateBuilder.getCurrentState(),
    metrics: metricsCalculator.getMetrics(stateBuilder.getCurrentState(), stateBuilder.getEvents())
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
      recentEvents: stateBuilder.getEvents().slice(-20)
    }
  }));
  
  ws.on('close', () => {
    console.log('WebSocket connection closed');
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

// Process journal events
journalReader.on('event', (event) => {
  console.log('New event:', event.event_type, event.card_id || '');
  
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
});

// Start the journal reader
journalReader.start();

// Start the server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`AI Kanban Dashboard running on http://localhost:${PORT}`);
  console.log(`Monitoring journal at: ${journalPath}`);
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
