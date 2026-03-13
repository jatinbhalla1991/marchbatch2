const express = require('express');
const client = require('prom-client');

const app = express();
const port = process.env.PORT || 3000;

// Create a Registry to register metrics
const register = new client.Registry();

// Add default metrics
client.collectDefaultMetrics({ register });

// Create custom metrics
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
  registers: [register]
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5],
  registers: [register]
});

const businessOperations = new client.Counter({
  name: 'business_operations_total',
  help: 'Total number of business operations',
  labelNames: ['operation_type', 'status'],
  registers: [register]
});

// Middleware to track request metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequestsTotal.inc({
      method: req.method,
      route: route,
      status_code: res.statusCode
    });
    
    httpRequestDuration.observe({
      method: req.method,
      route: route,
      status_code: res.statusCode
    }, duration);
  });
  
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// Readiness check endpoint
app.get('/ready', (req, res) => {
  res.json({ 
    status: 'ready',
    timestamp: new Date().toISOString()
  });
});

// Metrics endpoint for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Sample API endpoints
app.get('/', (req, res) => {
  businessOperations.inc({ operation_type: 'page_view', status: 'success' });
  res.json({ 
    message: 'Welcome to Sample App',
    version: '1.0.0',
    endpoints: ['/health', '/ready', '/metrics', '/api/users', '/api/orders', '/api/products']
  });
});

app.get('/api/users', (req, res) => {
  businessOperations.inc({ operation_type: 'user_fetch', status: 'success' });
  res.json({ 
    users: [
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' },
      { id: 3, name: 'Charlie', email: 'charlie@example.com' }
    ]
  });
});

app.get('/api/orders', (req, res) => {
  businessOperations.inc({ operation_type: 'order_fetch', status: 'success' });
  res.json({ 
    orders: [
      { id: 101, userId: 1, total: 99.99, status: 'completed' },
      { id: 102, userId: 2, total: 149.99, status: 'pending' },
      { id: 103, userId: 3, total: 79.99, status: 'shipped' }
    ]
  });
});

app.get('/api/products', (req, res) => {
  businessOperations.inc({ operation_type: 'product_fetch', status: 'success' });
  res.json({ 
    products: [
      { id: 1, name: 'Laptop', price: 999.99, stock: 50 },
      { id: 2, name: 'Mouse', price: 29.99, stock: 200 },
      { id: 3, name: 'Keyboard', price: 79.99, stock: 150 }
    ]
  });
});

app.post('/api/users', express.json(), (req, res) => {
  businessOperations.inc({ operation_type: 'user_create', status: 'success' });
  res.status(201).json({ 
    id: Math.floor(Math.random() * 1000),
    ...req.body,
    created_at: new Date().toISOString()
  });
});

// Error endpoint for testing
app.get('/api/error', (req, res) => {
  businessOperations.inc({ operation_type: 'error_test', status: 'error' });
  res.status(500).json({ error: 'Internal Server Error', message: 'This is a test error' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found', path: req.path });
});

// Start server
app.listen(port, '0.0.0.0', () => {
  console.log(`Sample app listening on port ${port}`);
  console.log(`Health check: http://localhost:${port}/health`);
  console.log(`Metrics: http://localhost:${port}/metrics`);
});
