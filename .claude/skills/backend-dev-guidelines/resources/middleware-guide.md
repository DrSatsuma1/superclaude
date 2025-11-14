# Middleware Guide

## What is Middleware?

Middleware functions have access to the request, response, and the next middleware function in the application's request-response cycle. They can:
- Execute code
- Make changes to request/response objects
- End the request-response cycle
- Call the next middleware in the stack

```typescript
function middleware(req: Request, res: Response, next: NextFunction) {
  // Do something
  next(); // Pass to next middleware
}
```

## Built-in Middleware

### Body Parsing

```typescript
import express from 'express';

const app = express();

// Parse JSON bodies
app.use(express.json({ limit: '10mb' }));

// Parse URL-encoded bodies
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Parse raw bodies
app.use(express.raw({ type: 'application/octet-stream' }));

// Parse text bodies
app.use(express.text({ type: 'text/plain' }));
```

### Static Files

```typescript
import path from 'path';

// Serve static files from public directory
app.use('/static', express.static(path.join(__dirname, 'public')));

// With caching
app.use('/static', express.static(path.join(__dirname, 'public'), {
  maxAge: '1d',
  etag: true
}));
```

## Custom Middleware

### Request Logging

```typescript
// middleware/requestLogger.ts
import { Request, Response, NextFunction } from 'express';
import logger from '../config/logger';

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const start = Date.now();

  // Log when response finishes
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info('Request completed', {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      ip: req.ip,
      userAgent: req.get('user-agent')
    });
  });

  next();
}
```

### Correlation ID

```typescript
// middleware/correlationId.ts
import { Request, Response, NextFunction } from 'express';
import { v4 as uuidv4 } from 'uuid';

declare global {
  namespace Express {
    interface Request {
      correlationId?: string;
    }
  }
}

export function correlationId(req: Request, res: Response, next: NextFunction) {
  const id = req.headers['x-correlation-id'] as string || uuidv4();
  req.correlationId = id;
  res.setHeader('X-Correlation-ID', id);
  next();
}
```

## Authentication Middleware

### JWT Authentication

```typescript
// middleware/auth.ts
import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { UnauthorizedError } from '../errors/AppError';
import { userRepository } from '../repositories/userRepository';
import config from '../config/app';

interface JWTPayload {
  userId: string;
  email: string;
  role: string;
}

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        email: string;
        role: string;
      };
    }
  }
}

export async function authenticate(
  req: Request,
  res: Response,
  next: NextFunction
) {
  try {
    // Extract token
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedError('No token provided');
    }

    const token = authHeader.substring(7);

    // Verify token
    const payload = jwt.verify(token, config.auth.jwtSecret) as JWTPayload;

    // Optionally verify user still exists
    const user = await userRepository.findById(payload.userId);
    if (!user) {
      throw new UnauthorizedError('User not found');
    }

    if (!user.isActive) {
      throw new UnauthorizedError('User account is inactive');
    }

    // Attach user to request
    req.user = {
      id: user.id,
      email: user.email,
      role: user.role
    };

    next();
  } catch (error) {
    if (error instanceof jwt.JsonWebTokenError) {
      next(new UnauthorizedError('Invalid token'));
    } else if (error instanceof jwt.TokenExpiredError) {
      next(new UnauthorizedError('Token expired'));
    } else {
      next(error);
    }
  }
}

// Optional authentication (doesn't fail if no token)
export async function optionalAuth(
  req: Request,
  res: Response,
  next: NextFunction
) {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      await authenticate(req, res, next);
    } else {
      next();
    }
  } catch (error) {
    // Ignore auth errors for optional auth
    next();
  }
}
```

## Authorization Middleware

### Role-Based Authorization

```typescript
// middleware/authorize.ts
import { Request, Response, NextFunction } from 'express';
import { ForbiddenError, UnauthorizedError } from '../errors/AppError';

export function authorize(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return next(new UnauthorizedError('Authentication required'));
    }

    if (!roles.includes(req.user.role)) {
      return next(new ForbiddenError('Insufficient permissions'));
    }

    next();
  };
}

// Usage:
// router.delete('/users/:id', authenticate, authorize('admin'), controller.delete);
```

### Resource Ownership

```typescript
// middleware/checkOwnership.ts
export function checkOwnership(resourceIdParam: string = 'id') {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      if (!req.user) {
        return next(new UnauthorizedError('Authentication required'));
      }

      const resourceId = req.params[resourceIdParam];
      const resource = await resourceRepository.findById(resourceId);

      if (!resource) {
        return next(new NotFoundError('Resource not found'));
      }

      // Check if user owns the resource or is admin
      if (resource.userId !== req.user.id && req.user.role !== 'admin') {
        return next(new ForbiddenError('You do not have access to this resource'));
      }

      next();
    } catch (error) {
      next(error);
    }
  };
}
```

## Validation Middleware

### Request Validation

```typescript
// middleware/validation.ts
import { Request, Response, NextFunction } from 'express';
import Joi from 'joi';
import { ValidationError } from '../errors/AppError';

interface ValidationSchemas {
  body?: Joi.Schema;
  params?: Joi.Schema;
  query?: Joi.Schema;
}

export function validateRequest(schemas: ValidationSchemas) {
  return (req: Request, res: Response, next: NextFunction) => {
    const errors: any = {};

    // Validate body
    if (schemas.body) {
      const { error } = schemas.body.validate(req.body, {
        abortEarly: false,
        stripUnknown: true
      });
      if (error) {
        errors.body = error.details.map(d => ({
          field: d.path.join('.'),
          message: d.message
        }));
      }
    }

    // Validate params
    if (schemas.params) {
      const { error } = schemas.params.validate(req.params, {
        abortEarly: false
      });
      if (error) {
        errors.params = error.details.map(d => ({
          field: d.path.join('.'),
          message: d.message
        }));
      }
    }

    // Validate query
    if (schemas.query) {
      const { error } = schemas.query.validate(req.query, {
        abortEarly: false,
        stripUnknown: true
      });
      if (error) {
        errors.query = error.details.map(d => ({
          field: d.path.join('.'),
          message: d.message
        }));
      }
    }

    if (Object.keys(errors).length > 0) {
      return next(new ValidationError('Validation failed', errors));
    }

    next();
  };
}

// Usage:
// router.post('/users',
//   validateRequest({
//     body: createUserSchema
//   }),
//   userController.create
// );
```

## Rate Limiting

```typescript
// middleware/rateLimiter.ts
import rateLimit from 'express-rate-limit';
import RedisStore from 'rate-limit-redis';
import { redis } from '../config/redis';

// General API rate limiter
export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per window
  standardHeaders: true,
  legacyHeaders: false,
  store: new RedisStore({
    client: redis,
    prefix: 'rate-limit:'
  }),
  message: 'Too many requests from this IP, please try again later'
});

// Strict limiter for auth endpoints
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5, // 5 attempts per 15 minutes
  skipSuccessfulRequests: true, // Don't count successful requests
  message: 'Too many login attempts, please try again later'
});

// Usage:
// app.use('/api', apiLimiter);
// app.use('/api/auth/login', authLimiter);
```

## Error Handling

### Error Handler Middleware

```typescript
// middleware/errorHandler.ts
import { Request, Response, NextFunction } from 'express';
import { AppError } from '../errors/AppError';
import logger from '../config/logger';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
) {
  // Log error
  logger.error('Error occurred', {
    error: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    body: req.body,
    user: req.user?.id,
    correlationId: req.correlationId
  });

  // Handle known operational errors
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      error: err.message,
      ...(err instanceof ValidationError && { errors: err.errors })
    });
  }

  // Handle Sequelize errors
  if (err.name === 'SequelizeValidationError') {
    return res.status(422).json({
      success: false,
      error: 'Validation failed',
      errors: err.errors
    });
  }

  if (err.name === 'SequelizeUniqueConstraintError') {
    return res.status(409).json({
      success: false,
      error: 'Resource already exists'
    });
  }

  // Handle JWT errors
  if (err.name === 'JsonWebTokenError') {
    return res.status(401).json({
      success: false,
      error: 'Invalid token'
    });
  }

  // Unknown errors - send generic message in production
  const message = process.env.NODE_ENV === 'production'
    ? 'Internal server error'
    : err.message;

  res.status(500).json({
    success: false,
    error: message
  });
}

// 404 handler (must come before error handler)
export function notFoundHandler(req: Request, res: Response) {
  res.status(404).json({
    success: false,
    error: 'Route not found'
  });
}
```

## CORS

```typescript
// middleware/cors.ts
import cors from 'cors';
import config from '../config/app';

const allowedOrigins = config.env === 'production'
  ? ['https://myapp.com', 'https://www.myapp.com']
  : ['http://localhost:3000', 'http://localhost:3001'];

export const corsMiddleware = cors({
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, Postman)
    if (!origin) return callback(null, true);

    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Correlation-ID'],
  exposedHeaders: ['X-Correlation-ID'],
  maxAge: 86400 // 24 hours
});
```

## Security Headers

```typescript
// middleware/security.ts
import helmet from 'helmet';

export const securityMiddleware = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:']
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
});
```

## Request Timeout

```typescript
// middleware/timeout.ts
import { Request, Response, NextFunction } from 'express';

export function timeout(ms: number = 30000) {
  return (req: Request, res: Response, next: NextFunction) => {
    const timer = setTimeout(() => {
      if (!res.headersSent) {
        res.status(408).json({
          success: false,
          error: 'Request timeout'
        });
      }
    }, ms);

    res.on('finish', () => {
      clearTimeout(timer);
    });

    next();
  };
}
```

## Middleware Order

**Correct order is crucial!**

```typescript
// app.ts
import express from 'express';
import {
  correlationId,
  requestLogger,
  corsMiddleware,
  securityMiddleware,
  timeout,
  apiLimiter,
  errorHandler,
  notFoundHandler
} from './middleware';

const app = express();

// 1. Security (first!)
app.use(securityMiddleware);
app.use(corsMiddleware);

// 2. Request preprocessing
app.use(correlationId);
app.use(timeout(30000));

// 3. Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// 4. Logging
app.use(requestLogger);

// 5. Rate limiting
app.use('/api', apiLimiter);

// 6. Routes
app.use('/api/v1', routes);

// 7. 404 handler (must be after routes)
app.use(notFoundHandler);

// 8. Error handler (must be last!)
app.use(errorHandler);

export default app;
```

## Best Practices

1. **Order matters** - Place middleware in correct order
2. **Call next()** - Always call next() or end the response
3. **Error handling** - Pass errors to next(error)
4. **Async middleware** - Use try-catch for async operations
5. **Type safety** - Extend Express types for custom properties
6. **Reusability** - Create middleware factories for configurable middleware
7. **Single responsibility** - Each middleware should do one thing
8. **Performance** - Avoid expensive operations in frequently-called middleware

## Common Pitfalls

1. **Forgetting to call next()** - Request hangs
2. **Calling next() after sending response** - Error occurs
3. **Wrong order** - Error handler before routes, etc.
4. **Not handling async errors** - Unhandled promise rejections
5. **Modifying prototype** - Don't modify Express prototypes
6. **Synchronous blocking** - Avoid CPU-intensive operations

## Summary

- Use middleware for cross-cutting concerns
- Place middleware in correct order
- Always handle errors in middleware
- Use authentication/authorization middleware for protected routes
- Implement rate limiting for security
- Add request logging for debugging
- Use validation middleware for input validation
- Create reusable middleware factories
