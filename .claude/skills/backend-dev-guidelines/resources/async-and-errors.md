# Async and Error Handling

## Async/Await Patterns

### Always Use Async/Await
Modern Node.js code should use async/await instead of callbacks or raw promises.

**Bad - Callback Hell**:
```typescript
// ❌ Don't use callbacks
function getUser(id, callback) {
  db.query('SELECT * FROM users WHERE id = ?', [id], (err, user) => {
    if (err) return callback(err);
    db.query('SELECT * FROM orders WHERE userId = ?', [id], (err, orders) => {
      if (err) return callback(err);
      callback(null, { user, orders });
    });
  });
}
```

**Good - Async/Await**:
```typescript
// ✅ Use async/await
async function getUser(id: string) {
  const user = await User.findByPk(id);
  const orders = await Order.findAll({ where: { userId: id } });
  return { user, orders };
}
```

### Error Handling in Async Functions

**Always wrap async operations in try-catch**:

```typescript
// Controllers
async create(req: Request, res: Response, next: NextFunction) {
  try {
    const result = await userService.create(req.body);
    res.status(201).json({ data: result });
  } catch (error) {
    next(error); // Pass to error handling middleware
  }
}

// Services
async create(data: CreateUserDTO): Promise<User> {
  try {
    const user = await userRepository.create(data);
    await emailService.sendWelcome(user.email);
    return user;
  } catch (error) {
    logger.error('Failed to create user:', error);
    throw error; // Re-throw for upper layers
  }
}
```

### Parallel vs Sequential Async

**Sequential** (when operations depend on each other):
```typescript
async function createOrder(userId: string, items: Item[]) {
  // Must happen in order
  const user = await userRepository.findById(userId);
  const order = await orderRepository.create({ userId, items });
  const payment = await paymentService.charge(user, order.total);
  return { order, payment };
}
```

**Parallel** (when operations are independent):
```typescript
async function getDashboardData(userId: string) {
  // Can run in parallel
  const [user, orders, notifications] = await Promise.all([
    userRepository.findById(userId),
    orderRepository.findByUser(userId),
    notificationRepository.findByUser(userId)
  ]);
  return { user, orders, notifications };
}
```

**Mixed** (some parallel, some sequential):
```typescript
async function processOrder(orderId: string) {
  // Step 1: Fetch order and user in parallel
  const [order, user] = await Promise.all([
    orderRepository.findById(orderId),
    userRepository.findById(order.userId)
  ]);

  // Step 2: Process payment (depends on step 1)
  const payment = await paymentService.charge(user, order.total);

  // Step 3: Update order and send notification in parallel
  await Promise.all([
    orderRepository.update(orderId, { status: 'paid' }),
    emailService.sendReceipt(user.email, order)
  ]);

  return { order, payment };
}
```

### Error Recovery

**With fallback**:
```typescript
async function getUserWithCache(id: string): Promise<User> {
  try {
    // Try cache first
    return await cache.get(`user:${id}`);
  } catch (error) {
    // Fallback to database
    logger.warn('Cache miss, fetching from DB', { id });
    return await userRepository.findById(id);
  }
}
```

**With retry logic**:
```typescript
async function fetchWithRetry(
  fn: () => Promise<any>,
  maxRetries = 3
): Promise<any> {
  let lastError: Error;

  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (i < maxRetries - 1) {
        await sleep(1000 * Math.pow(2, i)); // Exponential backoff
      }
    }
  }

  throw lastError;
}

// Usage
const data = await fetchWithRetry(() => externalApi.fetch());
```

## Error Handling

### Custom Error Classes

Create custom error classes for different error types:

```typescript
// errors/AppError.ts
export class AppError extends Error {
  constructor(
    public message: string,
    public statusCode: number,
    public isOperational = true
  ) {
    super(message);
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class BadRequestError extends AppError {
  constructor(message = 'Bad request') {
    super(message, 400);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized') {
    super(message, 401);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Forbidden') {
    super(message, 403);
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found') {
    super(message, 404);
  }
}

export class ConflictError extends AppError {
  constructor(message = 'Resource conflict') {
    super(message, 409);
  }
}

export class ValidationError extends AppError {
  constructor(
    message = 'Validation failed',
    public errors?: any
  ) {
    super(message, 422);
    this.errors = errors;
  }
}

export class InternalError extends AppError {
  constructor(message = 'Internal server error') {
    super(message, 500);
  }
}
```

### Using Custom Errors

**In Services**:
```typescript
export class UserService {
  async getById(id: string): Promise<UserDTO> {
    const user = await userRepository.findById(id);
    if (!user) {
      throw new NotFoundError('User not found');
    }
    return this.toDTO(user);
  }

  async create(data: CreateUserDTO): Promise<UserDTO> {
    const existing = await userRepository.findByEmail(data.email);
    if (existing) {
      throw new ConflictError('Email already registered');
    }

    if (!this.isValidAge(data.age)) {
      throw new BadRequestError('User must be at least 18 years old');
    }

    const user = await userRepository.create(data);
    return this.toDTO(user);
  }

  async updatePermissions(userId: string, requesterId: string, permissions: string[]) {
    const requester = await userRepository.findById(requesterId);
    if (!requester.isAdmin) {
      throw new ForbiddenError('Only admins can update permissions');
    }

    return userRepository.updatePermissions(userId, permissions);
  }
}
```

### Centralized Error Handler

Create a centralized error handling middleware:

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
    user: req.user?.id
  });

  // Handle known errors
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      error: err.message,
      ...(err instanceof ValidationError && { errors: err.errors })
    });
  }

  // Handle Sequelize/ORM errors
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

  if (err.name === 'TokenExpiredError') {
    return res.status(401).json({
      success: false,
      error: 'Token expired'
    });
  }

  // Unknown errors (500)
  logger.error('Unexpected error:', err);
  res.status(500).json({
    success: false,
    error: process.env.NODE_ENV === 'production'
      ? 'Internal server error'
      : err.message
  });
}

// Async handler wrapper
export function asyncHandler(fn: Function) {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}
```

### Using Error Handler in App

```typescript
// app.ts
import express from 'express';
import { errorHandler } from './middleware/errorHandler';
import routes from './routes';

const app = express();

// Body parsing
app.use(express.json());

// Routes
app.use('/api', routes);

// 404 handler (must be before error handler)
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found'
  });
});

// Error handler (must be last)
app.use(errorHandler);

export default app;
```

### Async Handler Pattern

**Option 1 - Wrapper function**:
```typescript
import { asyncHandler } from '../middleware/errorHandler';

router.get('/users/:id', asyncHandler(async (req, res) => {
  const user = await userService.getById(req.params.id);
  res.json({ data: user });
}));
```

**Option 2 - Try-catch in controller**:
```typescript
router.get('/users/:id', async (req, res, next) => {
  try {
    const user = await userService.getById(req.params.id);
    res.json({ data: user });
  } catch (error) {
    next(error);
  }
});
```

Both are acceptable, choose one and be consistent.

## Database Transaction Handling

### Basic Transaction

```typescript
async create(data: CreateOrderDTO): Promise<Order> {
  const transaction = await sequelize.transaction();

  try {
    // All operations in transaction
    const order = await Order.create(data, { transaction });
    await OrderItem.bulkCreate(data.items, { transaction });
    await Inventory.decrement('quantity', {
      where: { id: data.items.map(i => i.productId) },
      transaction
    });

    // Commit if all succeed
    await transaction.commit();
    return order;
  } catch (error) {
    // Rollback on any error
    await transaction.rollback();
    throw error;
  }
}
```

### Managed Transaction (Recommended)

```typescript
async create(data: CreateOrderDTO): Promise<Order> {
  return sequelize.transaction(async (t) => {
    // Transaction auto-commits on success, auto-rolls back on error
    const order = await Order.create(data, { transaction: t });
    await OrderItem.bulkCreate(data.items, { transaction: t });
    await Inventory.decrement('quantity', {
      where: { id: data.items.map(i => i.productId) },
      transaction: t
    });
    return order;
  });
}
```

## Best Practices

### 1. Always Handle Errors
```typescript
// ❌ Bad - Unhandled promise rejection
async function badExample() {
  await riskyOperation(); // If this fails, unhandled rejection!
}

// ✅ Good - Error is caught
async function goodExample() {
  try {
    await riskyOperation();
  } catch (error) {
    logger.error('Operation failed', error);
    throw new InternalError('Failed to complete operation');
  }
}
```

### 2. Provide Context in Errors
```typescript
// ❌ Bad - Generic error
throw new Error('Failed');

// ✅ Good - Specific error with context
throw new NotFoundError(`User with ID ${userId} not found`);
```

### 3. Don't Swallow Errors
```typescript
// ❌ Bad - Error is lost
try {
  await operation();
} catch (error) {
  console.log('Error occurred'); // Error info lost!
}

// ✅ Good - Error is logged and re-thrown
try {
  await operation();
} catch (error) {
  logger.error('Operation failed', { error, context });
  throw error; // or throw new custom error
}
```

### 4. Use Proper Error Types
```typescript
// ❌ Bad - Generic Error
if (!user) {
  throw new Error('Not found');
}

// ✅ Good - Specific error type
if (!user) {
  throw new NotFoundError('User not found');
}
```

### 5. Clean Up Resources
```typescript
async function processFile(filePath: string) {
  const fileHandle = await fs.open(filePath);

  try {
    const data = await fileHandle.readFile();
    return processData(data);
  } finally {
    await fileHandle.close(); // Always clean up
  }
}
```

## Common Pitfalls

### 1. Forgetting Await
```typescript
// ❌ Wrong - Returns promise, not value
async function wrong() {
  const user = userService.getById('123'); // Missing await!
  console.log(user.name); // Error: user is a Promise
}

// ✅ Correct
async function correct() {
  const user = await userService.getById('123');
  console.log(user.name); // Works!
}
```

### 2. Sequential When Could Be Parallel
```typescript
// ❌ Slow - Sequential
async function slow() {
  const user = await getUser();      // Wait 100ms
  const posts = await getPosts();    // Wait 100ms
  const comments = await getComments(); // Wait 100ms
  // Total: 300ms
}

// ✅ Fast - Parallel
async function fast() {
  const [user, posts, comments] = await Promise.all([
    getUser(),
    getPosts(),
    getComments()
  ]);
  // Total: 100ms
}
```

### 3. Not Handling Promise.all Rejections
```typescript
// ❌ Bad - One failure stops everything
try {
  await Promise.all([op1(), op2(), op3()]);
} catch (error) {
  // Which one failed? Don't know!
}

// ✅ Good - Handle each individually
const results = await Promise.allSettled([op1(), op2(), op3()]);
results.forEach((result, index) => {
  if (result.status === 'rejected') {
    logger.error(`Operation ${index} failed:`, result.reason);
  }
});
```

### 4. Mixing Callbacks and Async/Await
```typescript
// ❌ Bad - Mixed paradigms
async function mixed() {
  return new Promise((resolve) => {
    setTimeout(async () => {
      const data = await fetchData(); // Confusing!
      resolve(data);
    }, 1000);
  });
}

// ✅ Good - Consistent async/await
async function consistent() {
  await sleep(1000);
  return await fetchData();
}
```

## Summary

- **Use async/await** for all asynchronous code
- **Always handle errors** with try-catch
- **Use custom error classes** for different error types
- **Centralize error handling** with middleware
- **Provide context** in error messages
- **Run parallel operations** with Promise.all when possible
- **Use transactions** for multi-step database operations
- **Log errors** with sufficient context
- **Don't swallow errors** - log and re-throw or handle appropriately
