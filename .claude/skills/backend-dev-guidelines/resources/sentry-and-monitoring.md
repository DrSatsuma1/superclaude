# Sentry and Monitoring

## Sentry Setup

### Installation

```bash
npm install @sentry/node @sentry/tracing
```

### Configuration

```typescript
// config/sentry.ts
import * as Sentry from '@sentry/node';
import * as Tracing from '@sentry/tracing';
import { Express } from 'express';
import config from './app';

export function initSentry(app: Express): void {
  if (!config.monitoring.sentryDsn) {
    console.warn('Sentry DSN not configured, skipping Sentry initialization');
    return;
  }

  Sentry.init({
    dsn: config.monitoring.sentryDsn,
    environment: config.env,
    release: process.env.APP_VERSION || 'unknown',

    // Performance monitoring
    tracesSampleRate: config.env === 'production' ? 0.1 : 1.0,

    // Session tracking
    autoSessionTracking: true,

    integrations: [
      // Express integration
      new Sentry.Integrations.Http({ tracing: true }),
      new Tracing.Integrations.Express({ app }),

      // Database integration (Postgres)
      new Tracing.Integrations.Postgres(),
    ],

    beforeSend(event, hint) {
      // Filter out sensitive data
      if (event.request) {
        delete event.request.cookies;
        if (event.request.headers) {
          delete event.request.headers['authorization'];
          delete event.request.headers['cookie'];
        }
      }

      // Don't send errors in development
      if (config.env === 'development') {
        console.error(hint.originalException || hint.syntheticException);
        return null;
      }

      return event;
    }
  });
}

export { Sentry };
```

### Express Integration

```typescript
// app.ts
import express from 'express';
import { initSentry, Sentry } from './config/sentry';
import routes from './routes';
import { errorHandler } from './middleware/errorHandler';

const app = express();

// Initialize Sentry FIRST
initSentry(app);

// Sentry request handler must be first middleware
app.use(Sentry.Handlers.requestHandler());

// Sentry tracing middleware
app.use(Sentry.Handlers.tracingHandler());

// Body parsing
app.use(express.json());

// Routes
app.use('/api', routes);

// Sentry error handler must be before other error handlers
app.use(Sentry.Handlers.errorHandler({
  shouldHandleError(error) {
    // Capture all errors with status code >= 500
    if (error.statusCode >= 500) {
      return true;
    }
    return false;
  }
}));

// Custom error handler
app.use(errorHandler);

export default app;
```

## Error Tracking

### Capturing Errors

```typescript
import { Sentry } from '../config/sentry';

// Capture exception
try {
  await riskyOperation();
} catch (error) {
  Sentry.captureException(error, {
    tags: {
      section: 'payment',
      operation: 'charge'
    },
    extra: {
      userId: user.id,
      amount: payment.amount
    }
  });
  throw error;
}

// Capture message
Sentry.captureMessage('Something important happened', {
  level: 'warning',
  tags: {
    feature: 'checkout'
  }
});
```

### Adding Context

```typescript
// Set user context
Sentry.setUser({
  id: user.id,
  email: user.email,
  username: user.username
});

// Set tags
Sentry.setTag('page_locale', 'en-us');
Sentry.setTag('user_type', 'premium');

// Set context
Sentry.setContext('payment', {
  method: 'credit_card',
  amount: 99.99,
  currency: 'USD'
});

// Add breadcrumb
Sentry.addBreadcrumb({
  category: 'auth',
  message: 'User logged in',
  level: 'info'
});
```

### In Middleware

```typescript
// middleware/sentryContext.ts
import { Request, Response, NextFunction } from 'express';
import { Sentry } from '../config/sentry';

export function sentryContext(req: Request, res: Response, next: NextFunction) {
  // Set user context if authenticated
  if (req.user) {
    Sentry.setUser({
      id: req.user.id,
      email: req.user.email
    });
  }

  // Set request context
  Sentry.setContext('request', {
    correlationId: req.correlationId,
    method: req.method,
    url: req.url,
    userAgent: req.get('user-agent')
  });

  next();
}
```

## Performance Monitoring

### Transaction Monitoring

```typescript
// Automatic transaction for Express routes
// Enabled via Sentry.Handlers.tracingHandler()

// Manual transaction
import { Sentry } from '../config/sentry';

async function complexOperation() {
  const transaction = Sentry.startTransaction({
    op: 'task',
    name: 'Complex Operation'
  });

  try {
    // Span for database query
    const dbSpan = transaction.startChild({
      op: 'db',
      description: 'fetch users'
    });
    const users = await User.findAll();
    dbSpan.finish();

    // Span for external API call
    const apiSpan = transaction.startChild({
      op: 'http',
      description: 'POST /api/notify'
    });
    await notifyExternalService(users);
    apiSpan.finish();

    transaction.setStatus('ok');
  } catch (error) {
    transaction.setStatus('internal_error');
    throw error;
  } finally {
    transaction.finish();
  }
}
```

### Database Query Monitoring

```typescript
// Automatically tracked if using Postgres integration

// Manual tracking for specific queries
async function getUsers() {
  const span = Sentry.getCurrentHub()
    .getScope()
    ?.getTransaction()
    ?.startChild({
      op: 'db.query',
      description: 'SELECT * FROM users WHERE active = true'
    });

  try {
    const users = await User.findAll({ where: { active: true } });
    return users;
  } finally {
    span?.finish();
  }
}
```

## Logging

### Winston Logger Setup

```typescript
// config/logger.ts
import winston from 'winston';
import config from './app';
import { Sentry } from './sentry';

// Custom Sentry transport
class SentryTransport extends winston.Transport {
  log(info: any, callback: () => void) {
    setImmediate(() => {
      this.emit('logged', info);
    });

    const { level, message, ...meta } = info;

    if (level === 'error') {
      Sentry.captureException(new Error(message), {
        level: 'error',
        extra: meta
      });
    } else if (level === 'warn') {
      Sentry.captureMessage(message, {
        level: 'warning',
        extra: meta
      });
    }

    callback();
  }
}

const logger = winston.createLogger({
  level: config.monitoring.logLevel,
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: config.appName,
    environment: config.env
  },
  transports: [
    // Console
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      )
    }),

    // File - errors
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 5242880, // 5MB
      maxFiles: 5
    }),

    // File - all logs
    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 5242880,
      maxFiles: 5
    }),

    // Sentry for errors and warnings
    new SentryTransport({ level: 'warn' })
  ]
});

export default logger;
```

### Structured Logging

```typescript
import logger from '../config/logger';

// Basic logging
logger.info('User logged in');
logger.warn('Deprecated API endpoint used');
logger.error('Payment failed');

// Structured logging with context
logger.info('User created', {
  userId: user.id,
  email: user.email,
  role: user.role
});

logger.error('Database query failed', {
  error: error.message,
  query: 'SELECT * FROM users',
  duration: 1234
});

// With correlation ID
logger.info('Processing order', {
  correlationId: req.correlationId,
  orderId: order.id,
  userId: user.id,
  total: order.total
});
```

### Request Logging Middleware

```typescript
// middleware/requestLogger.ts
import { Request, Response, NextFunction } from 'express';
import logger from '../config/logger';

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();

  // Log request
  logger.info('Incoming request', {
    correlationId: req.correlationId,
    method: req.method,
    url: req.url,
    ip: req.ip,
    userAgent: req.get('user-agent'),
    userId: req.user?.id
  });

  // Log response when finished
  res.on('finish', () => {
    const duration = Date.now() - start;

    const logLevel = res.statusCode >= 500 ? 'error'
      : res.statusCode >= 400 ? 'warn'
      : 'info';

    logger[logLevel]('Request completed', {
      correlationId: req.correlationId,
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      userId: req.user?.id
    });
  });

  next();
}
```

## Metrics and Analytics

### Custom Metrics

```typescript
// utils/metrics.ts
import { Sentry } from '../config/sentry';

export class Metrics {
  static timing(name: string, value: number, tags?: Record<string, string>) {
    Sentry.addBreadcrumb({
      category: 'metric',
      message: name,
      level: 'info',
      data: {
        value,
        unit: 'ms',
        ...tags
      }
    });
  }

  static increment(name: string, tags?: Record<string, string>) {
    Sentry.addBreadcrumb({
      category: 'metric',
      message: name,
      level: 'info',
      data: {
        type: 'counter',
        ...tags
      }
    });
  }

  static gauge(name: string, value: number, tags?: Record<string, string>) {
    Sentry.addBreadcrumb({
      category: 'metric',
      message: name,
      level: 'info',
      data: {
        type: 'gauge',
        value,
        ...tags
      }
    });
  }
}

// Usage
Metrics.timing('api.response_time', 123, { endpoint: '/users' });
Metrics.increment('payment.success', { method: 'stripe' });
Metrics.gauge('queue.size', 42, { queue: 'emails' });
```

### Business Metrics

```typescript
// Track important business events
import { Sentry } from '../config/sentry';
import logger from '../config/logger';

export class BusinessMetrics {
  static trackPurchase(order: Order) {
    logger.info('Purchase completed', {
      orderId: order.id,
      userId: order.userId,
      total: order.total,
      items: order.items.length
    });

    Sentry.addBreadcrumb({
      category: 'business',
      message: 'Purchase completed',
      level: 'info',
      data: {
        orderId: order.id,
        total: order.total
      }
    });
  }

  static trackSignup(user: User) {
    logger.info('User signed up', {
      userId: user.id,
      email: user.email
    });

    Sentry.addBreadcrumb({
      category: 'business',
      message: 'User signup',
      level: 'info',
      data: {
        userId: user.id
      }
    });
  }
}
```

## Health Checks

### Health Check Endpoint

```typescript
// routes/health.ts
import { Router } from 'express';
import { sequelize } from '../config/database';
import { redis } from '../config/redis';

const router = Router();

router.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    checks: {
      database: 'unknown',
      redis: 'unknown'
    }
  };

  // Check database
  try {
    await sequelize.authenticate();
    health.checks.database = 'ok';
  } catch (error) {
    health.status = 'degraded';
    health.checks.database = 'error';
  }

  // Check Redis
  try {
    await redis.ping();
    health.checks.redis = 'ok';
  } catch (error) {
    health.status = 'degraded';
    health.checks.redis = 'error';
  }

  const statusCode = health.status === 'ok' ? 200 : 503;
  res.status(statusCode).json(health);
});

router.get('/health/ready', async (req, res) => {
  // Readiness probe - is app ready to serve traffic?
  try {
    await sequelize.authenticate();
    res.status(200).json({ ready: true });
  } catch (error) {
    res.status(503).json({ ready: false });
  }
});

router.get('/health/live', (req, res) => {
  // Liveness probe - is app alive?
  res.status(200).json({ alive: true });
});

export default router;
```

## Alerts

### Error Rate Alerts

Configure in Sentry dashboard:
- Alert when error rate exceeds threshold
- Alert on new error types
- Alert on regression (previously resolved error returns)

### Performance Alerts

- Alert when p95 response time exceeds threshold
- Alert on slow database queries
- Alert on high memory usage

### Custom Alerts

```typescript
// services/alertService.ts
import logger from '../config/logger';
import { Sentry } from '../config/sentry';

export class AlertService {
  static async criticalError(message: string, context: any) {
    // Log to winston
    logger.error(message, context);

    // Send to Sentry
    Sentry.captureMessage(message, {
      level: 'fatal',
      extra: context
    });

    // Could also send to Slack, PagerDuty, etc.
  }

  static async highPriorityWarning(message: string, context: any) {
    logger.warn(message, context);

    Sentry.captureMessage(message, {
      level: 'warning',
      extra: context
    });
  }
}

// Usage
if (orderQueue.size > 10000) {
  AlertService.highPriorityWarning('Order queue backing up', {
    queueSize: orderQueue.size,
    threshold: 10000
  });
}
```

## Best Practices

1. **Initialize Sentry early** - Before other middleware
2. **Filter sensitive data** - Remove passwords, tokens from errors
3. **Add context** - User, request, custom data
4. **Use breadcrumbs** - Track user actions leading to error
5. **Set proper levels** - Error, warning, info
6. **Track performance** - Monitor slow operations
7. **Structured logging** - Use JSON with context
8. **Health checks** - Implement liveness and readiness probes
9. **Monitor metrics** - Track business and technical metrics
10. **Set up alerts** - Be notified of critical issues

## Common Pitfalls

1. **Logging sensitive data** - Passwords, credit cards in logs
2. **Too much logging** - Log levels too verbose in production
3. **No context** - Errors without enough info to debug
4. **Not tracking performance** - Only tracking errors
5. **Ignoring warnings** - Warnings often indicate issues
6. **No health checks** - Can't tell if app is healthy
7. **Alert fatigue** - Too many non-critical alerts
8. **Not using correlation IDs** - Can't trace requests

## Summary

- Set up Sentry for error tracking
- Use structured logging with Winston
- Add context to all errors
- Monitor performance with transactions
- Implement health check endpoints
- Track business metrics
- Set up meaningful alerts
- Use correlation IDs for request tracing
- Filter sensitive data from logs
- Monitor and optimize based on data
