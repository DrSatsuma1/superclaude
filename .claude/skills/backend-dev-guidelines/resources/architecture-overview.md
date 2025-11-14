# Architecture Overview

## System Architecture

Our backend follows a layered architecture pattern with clear separation of concerns:

```
┌─────────────────────────────────────┐
│         HTTP Layer (Routes)         │
├─────────────────────────────────────┤
│        Controllers (Handlers)       │
├─────────────────────────────────────┤
│      Services (Business Logic)      │
├─────────────────────────────────────┤
│    Repositories (Data Access)       │
├─────────────────────────────────────┤
│      Models/Entities (ORM)          │
├─────────────────────────────────────┤
│           Database                  │
└─────────────────────────────────────┘
```

## Layer Responsibilities

### 1. Routes Layer
**Purpose**: Define HTTP endpoints and wire them to controllers

**Responsibilities**:
- Define URL patterns and HTTP methods
- Apply middleware (auth, validation, rate limiting)
- Route requests to appropriate controllers

**Example**:
```typescript
// routes/users.ts
import { Router } from 'express';
import { userController } from '../controllers/userController';
import { authenticate } from '../middleware/auth';
import { validateRequest } from '../middleware/validation';
import { createUserSchema } from '../schemas/userSchemas';

const router = Router();

router.post(
  '/users',
  validateRequest(createUserSchema),
  userController.create
);

router.get(
  '/users/:id',
  authenticate,
  userController.getById
);

export default router;
```

**Guidelines**:
- Keep routes file focused on routing only
- Don't put business logic in routes
- Group related routes together
- Use consistent naming conventions
- Apply middleware in correct order (validation before auth, etc.)

### 2. Controllers Layer
**Purpose**: Handle HTTP request/response lifecycle

**Responsibilities**:
- Extract data from HTTP requests
- Call appropriate service methods
- Format responses
- Delegate to next middleware for errors
- Set proper HTTP status codes

**Example**:
```typescript
// controllers/userController.ts
import { Request, Response, NextFunction } from 'express';
import { userService } from '../services/userService';

export class UserController {
  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await userService.create(req.body);
      res.status(201).json({
        success: true,
        data: user
      });
    } catch (error) {
      next(error);
    }
  }

  async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await userService.getById(req.params.id);
      res.json({
        success: true,
        data: user
      });
    } catch (error) {
      next(error);
    }
  }
}

export const userController = new UserController();
```

**Guidelines**:
- Keep controllers thin - they should orchestrate, not implement
- Always wrap async calls in try-catch
- Pass errors to `next()` for centralized handling
- Don't put business logic in controllers
- Use consistent response formats
- Set appropriate HTTP status codes

### 3. Services Layer
**Purpose**: Implement business logic and orchestrate operations

**Responsibilities**:
- Implement business rules and validation
- Orchestrate multiple repository calls
- Transform data between layers
- Throw business exceptions
- Handle transactions

**Example**:
```typescript
// services/userService.ts
import { userRepository } from '../repositories/userRepository';
import { CreateUserDTO, UpdateUserDTO, UserDTO } from '../types/user';
import { ConflictError, NotFoundError } from '../errors/AppError';
import { hashPassword } from '../utils/crypto';
import { emailService } from './emailService';

export class UserService {
  async create(data: CreateUserDTO): Promise<UserDTO> {
    // Business rule: email must be unique
    const existing = await userRepository.findByEmail(data.email);
    if (existing) {
      throw new ConflictError('Email already registered');
    }

    // Transform data
    const hashedPassword = await hashPassword(data.password);

    // Persist to database
    const user = await userRepository.create({
      ...data,
      password: hashedPassword
    });

    // Orchestrate side effects
    await emailService.sendWelcome(user.email);

    // Transform to DTO (hide sensitive fields)
    return this.toDTO(user);
  }

  async getById(id: string): Promise<UserDTO> {
    const user = await userRepository.findById(id);
    if (!user) {
      throw new NotFoundError('User not found');
    }
    return this.toDTO(user);
  }

  async update(id: string, data: UpdateUserDTO): Promise<UserDTO> {
    const user = await userRepository.findById(id);
    if (!user) {
      throw new NotFoundError('User not found');
    }

    // Business rule: can't change email to existing email
    if (data.email && data.email !== user.email) {
      const existing = await userRepository.findByEmail(data.email);
      if (existing) {
        throw new ConflictError('Email already in use');
      }
    }

    const updated = await userRepository.update(id, data);
    return this.toDTO(updated);
  }

  private toDTO(user: any): UserDTO {
    // Don't expose password or other sensitive fields
    const { password, ...userDTO } = user.toJSON();
    return userDTO;
  }
}

export const userService = new UserService();
```

**Guidelines**:
- All business logic lives in services
- Services should be independent of HTTP layer
- Throw custom errors for business rule violations
- Use repositories for all data access
- Transform entities to DTOs before returning
- Keep services focused (single responsibility)
- Use dependency injection for testability

### 4. Repositories Layer
**Purpose**: Abstract database operations

**Responsibilities**:
- CRUD operations
- Query building
- Database-specific logic
- Transaction management
- Data mapping

**Example**:
```typescript
// repositories/userRepository.ts
import { User } from '../models/User';
import { CreateUserDTO, UpdateUserDTO } from '../types/user';

export class UserRepository {
  async create(data: CreateUserDTO): Promise<User> {
    return User.create(data);
  }

  async findById(id: string): Promise<User | null> {
    return User.findByPk(id);
  }

  async findByEmail(email: string): Promise<User | null> {
    return User.findOne({ where: { email } });
  }

  async update(id: string, data: UpdateUserDTO): Promise<User> {
    const user = await this.findById(id);
    if (!user) {
      throw new Error('User not found');
    }
    return user.update(data);
  }

  async delete(id: string): Promise<void> {
    await User.destroy({ where: { id } });
  }

  async findAll(options?: {
    limit?: number;
    offset?: number;
    where?: any;
  }): Promise<User[]> {
    return User.findAll(options);
  }
}

export const userRepository = new UserRepository();
```

**Guidelines**:
- One repository per entity/model
- Only database operations in repositories
- No business logic in repositories
- Return model instances, not plain objects
- Use proper typing
- Handle database errors appropriately

### 5. Models Layer
**Purpose**: Define database schema and entity behavior

**Responsibilities**:
- Define table structure
- Define relationships
- Instance methods for entity-specific behavior
- Validation at database level

**Example**:
```typescript
// models/User.ts
import { Model, DataTypes } from 'sequelize';
import { sequelize } from '../config/database';

export class User extends Model {
  public id!: string;
  public email!: string;
  public password!: string;
  public firstName!: string;
  public lastName!: string;
  public createdAt!: Date;
  public updatedAt!: Date;

  // Instance method
  public getFullName(): string {
    return `${this.firstName} ${this.lastName}`;
  }
}

User.init(
  {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true
    },
    email: {
      type: DataTypes.STRING,
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true
      }
    },
    password: {
      type: DataTypes.STRING,
      allowNull: false
    },
    firstName: {
      type: DataTypes.STRING,
      allowNull: false
    },
    lastName: {
      type: DataTypes.STRING,
      allowNull: false
    }
  },
  {
    sequelize,
    tableName: 'users',
    timestamps: true
  }
);
```

## Cross-Cutting Concerns

### Middleware
Middleware handles concerns that span multiple endpoints:

- **Authentication**: Verify user identity
- **Authorization**: Check user permissions
- **Validation**: Validate request data
- **Logging**: Log requests/responses
- **Error Handling**: Catch and format errors
- **Rate Limiting**: Prevent abuse
- **CORS**: Handle cross-origin requests

### Utilities
Shared helper functions:

- **Crypto**: Password hashing, encryption
- **Date**: Date formatting and manipulation
- **String**: String utilities
- **Validation**: Reusable validators

### Configuration
Centralized configuration management:

- Environment variables
- Application settings
- Database configuration
- External service credentials

## Dependency Flow

**Correct Dependency Direction**:
```
Controllers → Services → Repositories → Models
```

**Rules**:
- Upper layers can depend on lower layers
- Lower layers NEVER depend on upper layers
- Controllers call services, not repositories
- Services call repositories, not controllers
- No circular dependencies

**Bad Example** (Service calling controller):
```typescript
// ❌ WRONG - Service should not import controller
import { userController } from '../controllers/userController';

export class OrderService {
  async create(data: CreateOrderDTO) {
    // Wrong: service calling controller
    await userController.notifyUser();
  }
}
```

**Good Example** (Proper layering):
```typescript
// ✅ CORRECT - Service calls another service
import { emailService } from './emailService';

export class OrderService {
  async create(data: CreateOrderDTO) {
    const order = await orderRepository.create(data);
    // Correct: service calling another service
    await emailService.sendOrderConfirmation(order);
    return order;
  }
}
```

## Data Flow

### Request Flow
```
Client Request
    ↓
Route (matches URL)
    ↓
Middleware (validation, auth)
    ↓
Controller (extract data)
    ↓
Service (business logic)
    ↓
Repository (database query)
    ↓
Model (ORM)
    ↓
Database
```

### Response Flow
```
Database
    ↓
Model (ORM instance)
    ↓
Repository (return model)
    ↓
Service (transform to DTO)
    ↓
Controller (format response)
    ↓
Middleware (logging, etc.)
    ↓
Client Response
```

## Project Structure

```
src/
├── config/           # Configuration files
│   ├── database.ts
│   ├── app.ts
│   └── logger.ts
├── controllers/      # HTTP handlers
│   ├── userController.ts
│   └── orderController.ts
├── services/         # Business logic
│   ├── userService.ts
│   └── orderService.ts
├── repositories/     # Data access
│   ├── userRepository.ts
│   └── orderRepository.ts
├── models/           # Database models
│   ├── User.ts
│   └── Order.ts
├── routes/           # Route definitions
│   ├── index.ts
│   ├── users.ts
│   └── orders.ts
├── middleware/       # Custom middleware
│   ├── auth.ts
│   ├── validation.ts
│   ├── errorHandler.ts
│   └── logger.ts
├── types/            # TypeScript types/interfaces
│   ├── user.ts
│   └── order.ts
├── errors/           # Custom error classes
│   └── AppError.ts
├── utils/            # Utility functions
│   ├── crypto.ts
│   └── validators.ts
├── schemas/          # Validation schemas
│   ├── userSchemas.ts
│   └── orderSchemas.ts
└── app.ts           # Application entry point
```

## Summary

- **Layered Architecture**: Clear separation between HTTP, business logic, and data access
- **Dependency Rule**: Upper layers depend on lower layers, never the reverse
- **Single Responsibility**: Each layer has one clear purpose
- **Testability**: Layers can be tested in isolation
- **Maintainability**: Changes are localized to appropriate layers
- **Scalability**: Easy to add new features following established patterns
