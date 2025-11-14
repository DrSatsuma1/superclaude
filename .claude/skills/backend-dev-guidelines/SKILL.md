# Backend Development Guidelines

## Description
Comprehensive backend development guidelines for Node.js/TypeScript applications. Covers architecture patterns, best practices, testing strategies, and common pitfalls to avoid.

## When to Use
- Building or modifying backend API endpoints
- Implementing database models and repositories
- Writing business logic and service layers
- Setting up middleware and error handling
- Configuring logging and monitoring
- Writing backend tests
- Reviewing backend code

## Overview
This skill provides detailed guidelines for backend development, including:
- Clean architecture principles
- Async/await patterns and error handling
- Database patterns and ORM usage
- Routing, controllers, and middleware
- Service layer and repository patterns
- Validation and configuration
- Testing strategies
- Monitoring and observability

## Core Principles

### 1. Separation of Concerns
- **Controllers**: Handle HTTP requests/responses, validation
- **Services**: Contain business logic
- **Repositories**: Handle data access
- **Middleware**: Cross-cutting concerns (auth, logging, etc.)

### 2. Error Handling
- Use custom error classes
- Centralized error handling middleware
- Proper async/await error propagation
- Meaningful error messages and status codes

### 3. Type Safety
- Use TypeScript for all backend code
- Define interfaces for DTOs, entities, and service contracts
- Avoid `any` types
- Use strict type checking

### 4. Testing
- Unit tests for services and repositories
- Integration tests for API endpoints
- Test error cases and edge conditions
- Mock external dependencies

### 5. Security
- Input validation on all endpoints
- Sanitize user inputs
- Use parameterized queries
- Implement proper authentication/authorization
- Rate limiting and request throttling

## Resources
The following resource files provide detailed guidance:

### Architecture
- [Architecture Overview](resources/architecture-overview.md) - System design and layer responsibilities
- [Routing and Controllers](resources/routing-and-controllers.md) - HTTP layer patterns
- [Services and Repositories](resources/services-and-repositories.md) - Business logic and data access

### Implementation Patterns
- [Async and Errors](resources/async-and-errors.md) - Error handling and async patterns
- [Validation Patterns](resources/validation-patterns.md) - Input validation strategies
- [Database Patterns](resources/database-patterns.md) - ORM usage and query patterns
- [Middleware Guide](resources/middleware-guide.md) - Middleware implementation

### Configuration and Operations
- [Configuration](resources/configuration.md) - Environment and app configuration
- [Sentry and Monitoring](resources/sentry-and-monitoring.md) - Observability and error tracking

### Testing and Examples
- [Testing Guide](resources/testing-guide.md) - Testing strategies and patterns
- [Complete Examples](resources/complete-examples.md) - Full feature implementations

## Quick Reference

### Creating a New Endpoint

```typescript
// 1. Define route (routes/users.ts)
router.post('/users', validateRequest(createUserSchema), userController.create);

// 2. Implement controller (controllers/userController.ts)
async create(req: Request, res: Response, next: NextFunction) {
  try {
    const user = await userService.create(req.body);
    res.status(201).json({ data: user });
  } catch (error) {
    next(error);
  }
}

// 3. Implement service (services/userService.ts)
async create(data: CreateUserDTO): Promise<User> {
  const existingUser = await userRepository.findByEmail(data.email);
  if (existingUser) {
    throw new ConflictError('Email already exists');
  }
  return userRepository.create(data);
}

// 4. Implement repository (repositories/userRepository.ts)
async create(data: CreateUserDTO): Promise<User> {
  return User.create(data);
}
```

### Error Handling Pattern

```typescript
// Custom error class
class AppError extends Error {
  constructor(
    public message: string,
    public statusCode: number,
    public isOperational = true
  ) {
    super(message);
  }
}

// Error handling middleware
app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      error: err.message
    });
  }
  logger.error('Unexpected error:', err);
  res.status(500).json({ error: 'Internal server error' });
});
```

## Common Pitfalls to Avoid

1. **Not handling async errors**: Always use try-catch or error middleware
2. **Business logic in controllers**: Keep controllers thin
3. **Direct database access in services**: Use repository pattern
4. **Missing input validation**: Validate all user inputs
5. **Exposing sensitive data**: Use DTOs for responses
6. **Not logging errors**: Log all errors with context
7. **Hardcoding configuration**: Use environment variables
8. **Missing database transactions**: Use transactions for multi-step operations
9. **Not testing error cases**: Test both happy and error paths
10. **Circular dependencies**: Design proper dependency flow

## Best Practices

- Use dependency injection for testability
- Implement request correlation IDs for tracing
- Use database migrations for schema changes
- Implement health check endpoints
- Use connection pooling for databases
- Cache frequently accessed data
- Implement rate limiting
- Use structured logging
- Document API with OpenAPI/Swagger
- Version your APIs

## Checklist for New Features

- [ ] Route defined with proper HTTP method
- [ ] Request validation schema defined
- [ ] Controller delegates to service
- [ ] Service contains business logic
- [ ] Repository handles data access
- [ ] Custom errors thrown for business rule violations
- [ ] Error handling middleware catches errors
- [ ] Unit tests for service logic
- [ ] Integration tests for endpoints
- [ ] Error cases tested
- [ ] Logging added for important operations
- [ ] Documentation updated
- [ ] Security reviewed (auth, validation, sanitization)

## Getting Started

When implementing a new backend feature:

1. Read [Architecture Overview](resources/architecture-overview.md) to understand the layers
2. Check [Complete Examples](resources/complete-examples.md) for similar features
3. Follow [Routing and Controllers](resources/routing-and-controllers.md) for HTTP layer
4. Implement business logic per [Services and Repositories](resources/services-and-repositories.md)
5. Add validation using [Validation Patterns](resources/validation-patterns.md)
6. Handle errors per [Async and Errors](resources/async-and-errors.md)
7. Write tests following [Testing Guide](resources/testing-guide.md)
8. Add monitoring per [Sentry and Monitoring](resources/sentry-and-monitoring.md)

## Maintaining Code Quality

- Run linter before committing
- Ensure all tests pass
- Keep test coverage above 80%
- Review your own code before submitting
- Add comments for complex business logic
- Keep functions small and focused
- Follow the single responsibility principle
- Use meaningful variable and function names
