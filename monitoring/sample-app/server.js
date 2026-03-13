const express = require('express');
const promClient = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;

// Create a Registry to register metrics
const register = new promClient.Registry();

// Add default metrics (CPU, memory, etc.)
promClient.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeConnections = new promClient.Gauge({
  name: 'http_active_connections',
  help: 'Number of active HTTP connections'
});

const businessMetric = new promClient.Counter({
  name: 'business_operations_total',
  help: 'Total number of business operations',
  labelNames: ['operation_type', 'status']
});

// Register custom metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(activeConnections);
register.registerMetric(businessMetric);

// Middleware to track request metrics
app.use((req, res, next) => {
  const start = Date.now();
  activeConnections.inc();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.labels(req.method, req.path, res.statusCode).observe(duration);
    httpRequestsTotal.labels(req.method, req.path, res.statusCode).inc();
    activeConnections.dec();
  });

  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Home endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'Monitoring Demo Application',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      metrics: '/metrics',
      api: '/api/*'
    }
  });
});

// Simulate some business operations
app.get('/api/users', (req, res) => {
  // Simulate processing time
  const processingTime = Math.random() * 1000;
  
  setTimeout(() => {
    businessMetric.labels('get_users', 'success').inc();
    res.json({ 
      users: [
        { id: 1, name: 'Alice' },
        { id: 2, name: 'Bob' },
        { id: 3, name: 'Charlie' }
      ]
    });
  }, processingTime);
});

app.post('/api/users', (req, res) => {
  const success = Math.random() > 0.1; // 90% success rate
  
  if (success) {
    businessMetric.labels('create_user', 'success').inc();
    res.status(201).json({ id: Math.floor(Math.random() * 1000), created: true });
  } else {
    businessMetric.labels('create_user', 'error').inc();
    res.status(500).json({ error: 'Failed to create user' });
  }
});

app.get('/api/orders', (req, res) => {
  const processingTime = Math.random() * 2000;
  
  setTimeout(() => {
    businessMetric.labels('get_orders', 'success').inc();
    res.json({ 
      orders: [
        { id: 101, amount: 99.99, status: 'completed' },
        { id: 102, amount: 149.99, status: 'pending' }
      ]
    });
  }, processingTime);
});

// Simulate error endpoint
app.get('/api/error', (req, res) => {
  businessMetric.labels('error_test', 'error').inc();
  res.status(500).json({ error: 'Simulated error for testing' });
});

// Metrics endpoint for Prometheus to scrape
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.listen(PORT, () => {
  console.log(`Monitoring Demo App listening on port ${PORT}`);
  console.log(`Metrics available at http://localhost:${PORT}/metrics`);
});
