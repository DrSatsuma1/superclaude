# Testing Guide

## Testing Strategy

### Test Pyramid

```
       /\
      /  \   E2E Tests (Few)
     /____\
    /      \  Integration Tests (Some)
   /________\
  /          \ Unit Tests (Many)
 /____________\
```

- **Unit Tests**: Test individual functions/methods in isolation
- **Integration Tests**: Test multiple components working together
- **E2E Tests**: Test complete user flows

## Setup

### Installation

```bash
npm install -D jest @types/jest ts-jest
npm install -D supertest @types/supertest
npm install -D @faker-js/faker
```

### Jest Configuration

```typescript
// jest.config.js
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/tests'],
  testMatch: ['**/*.test.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/app.ts',
    '!src/server.ts'
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80
    }
  },
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts']
};
```

### Test Setup

```typescript
// tests/setup.ts
import { sequelize } from '../src/config/database';

// Setup before all tests
beforeAll(async () => {
  await sequelize.sync({ force: true });
});

// Cleanup after all tests
afterAll(async () => {
  await sequelize.close();
});

// Clear database between tests
afterEach(async () => {
  const models = Object.values(sequelize.models);
  for (const model of models) {
    await model.destroy({ where: {}, force: true });
  }
});
```

## Unit Tests

### Testing Services

```typescript
// tests/unit/services/userService.test.ts
import { userService } from '../../../src/services/userService';
import { userRepository } from '../../../src/repositories/userRepository';
import { emailService } from '../../../src/services/emailService';
import { ConflictError, NotFoundError } from '../../../src/errors/AppError';
import { hashPassword } from '../../../src/utils/crypto';

// Mock dependencies
jest.mock('../../../src/repositories/userRepository');
jest.mock('../../../src/services/emailService');
jest.mock('../../../src/utils/crypto');

describe('UserService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    const userData = {
      email: 'test@example.com',
      password: 'password123',
      firstName: 'John',
      lastName: 'Doe'
    };

    it('should create a user successfully', async () => {
      // Arrange
      const mockUser = {
        id: '123',
        ...userData,
        password: 'hashed',
        createdAt: new Date(),
        updatedAt: new Date(),
        toJSON: () => ({ id: '123', ...userData, password: 'hashed' })
      };

      (userRepository.findByEmail as jest.Mock).mockResolvedValue(null);
      (hashPassword as jest.Mock).mockResolvedValue('hashed');
      (userRepository.create as jest.Mock).mockResolvedValue(mockUser);
      (emailService.sendWelcome as jest.Mock).mockResolvedValue(undefined);

      // Act
      const result = await userService.create(userData);

      // Assert
      expect(userRepository.findByEmail).toHaveBeenCalledWith(userData.email);
      expect(hashPassword).toHaveBeenCalledWith(userData.password);
      expect(userRepository.create).toHaveBeenCalled();
      expect(emailService.sendWelcome).toHaveBeenCalledWith(userData.email);
      expect(result).toEqual({
        id: '123',
        email: userData.email,
        firstName: userData.firstName,
        lastName: userData.lastName,
        createdAt: expect.any(Date),
        updatedAt: expect.any(Date)
      });
      expect(result).not.toHaveProperty('password'); // Password should not be in DTO
    });

    it('should throw ConflictError if email exists', async () => {
      // Arrange
      (userRepository.findByEmail as jest.Mock).mockResolvedValue({
        id: '123',
        email: userData.email
      });

      // Act & Assert
      await expect(userService.create(userData)).rejects.toThrow(ConflictError);
      await expect(userService.create(userData)).rejects.toThrow('Email already registered');
      expect(userRepository.create).not.toHaveBeenCalled();
    });
  });

  describe('getById', () => {
    it('should return user if found', async () => {
      // Arrange
      const mockUser = {
        id: '123',
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        password: 'hashed',
        toJSON: () => ({
          id: '123',
          email: 'test@example.com',
          firstName: 'John',
          lastName: 'Doe',
          password: 'hashed'
        })
      };

      (userRepository.findById as jest.Mock).mockResolvedValue(mockUser);

      // Act
      const result = await userService.getById('123');

      // Assert
      expect(userRepository.findById).toHaveBeenCalledWith('123');
      expect(result.id).toBe('123');
      expect(result).not.toHaveProperty('password');
    });

    it('should throw NotFoundError if user not found', async () => {
      // Arrange
      (userRepository.findById as jest.Mock).mockResolvedValue(null);

      // Act & Assert
      await expect(userService.getById('123')).rejects.toThrow(NotFoundError);
      await expect(userService.getById('123')).rejects.toThrow('User not found');
    });
  });

  describe('update', () => {
    it('should update user successfully', async () => {
      // Arrange
      const existingUser = {
        id: '123',
        email: 'old@example.com',
        firstName: 'John',
        lastName: 'Doe'
      };

      const updateData = {
        firstName: 'Jane'
      };

      const updatedUser = {
        ...existingUser,
        ...updateData,
        toJSON: () => ({ ...existingUser, ...updateData })
      };

      (userRepository.findById as jest.Mock).mockResolvedValue(existingUser);
      (userRepository.update as jest.Mock).mockResolvedValue(updatedUser);

      // Act
      const result = await userService.update('123', updateData);

      // Assert
      expect(result.firstName).toBe('Jane');
    });

    it('should throw ConflictError when changing to existing email', async () => {
      // Arrange
      const user = { id: '123', email: 'old@example.com' };
      const existingEmailUser = { id: '456', email: 'existing@example.com' };

      (userRepository.findById as jest.Mock).mockResolvedValue(user);
      (userRepository.findByEmail as jest.Mock).mockResolvedValue(existingEmailUser);

      // Act & Assert
      await expect(
        userService.update('123', { email: 'existing@example.com' })
      ).rejects.toThrow(ConflictError);
    });
  });
});
```

### Testing Utilities

```typescript
// tests/unit/utils/crypto.test.ts
import { hashPassword, comparePassword } from '../../../src/utils/crypto';

describe('Crypto Utils', () => {
  describe('hashPassword', () => {
    it('should hash password', async () => {
      const password = 'password123';
      const hash = await hashPassword(password);

      expect(hash).toBeDefined();
      expect(hash).not.toBe(password);
      expect(hash.length).toBeGreaterThan(20);
    });

    it('should generate different hashes for same password', async () => {
      const password = 'password123';
      const hash1 = await hashPassword(password);
      const hash2 = await hashPassword(password);

      expect(hash1).not.toBe(hash2); // Different due to salt
    });
  });

  describe('comparePassword', () => {
    it('should return true for correct password', async () => {
      const password = 'password123';
      const hash = await hashPassword(password);
      const isValid = await comparePassword(password, hash);

      expect(isValid).toBe(true);
    });

    it('should return false for incorrect password', async () => {
      const hash = await hashPassword('password123');
      const isValid = await comparePassword('wrongpassword', hash);

      expect(isValid).toBe(false);
    });
  });
});
```

## Integration Tests

### Testing API Endpoints

```typescript
// tests/integration/users.test.ts
import request from 'supertest';
import app from '../../src/app';
import { User } from '../../src/models/User';
import { generateToken } from '../../src/utils/auth';

describe('User API', () => {
  let authToken: string;
  let userId: string;

  beforeEach(async () => {
    // Create test user
    const user = await User.create({
      email: 'test@example.com',
      password: 'hashedpassword',
      firstName: 'Test',
      lastName: 'User'
    });
    userId = user.id;
    authToken = generateToken({ userId: user.id, email: user.email });
  });

  describe('POST /api/users', () => {
    it('should create a new user', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({
          email: 'newuser@example.com',
          password: 'password123',
          firstName: 'New',
          lastName: 'User'
        })
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('id');
      expect(response.body.data.email).toBe('newuser@example.com');
      expect(response.body.data).not.toHaveProperty('password');

      // Verify in database
      const user = await User.findByPk(response.body.data.id);
      expect(user).toBeDefined();
      expect(user?.email).toBe('newuser@example.com');
    });

    it('should return 409 for duplicate email', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({
          email: 'test@example.com', // Already exists
          password: 'password123',
          firstName: 'Test',
          lastName: 'User'
        })
        .expect(409);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('already');
    });

    it('should return 422 for invalid data', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({
          email: 'invalid-email', // Invalid email
          password: '123' // Too short
        })
        .expect(422);

      expect(response.body.success).toBe(false);
      expect(response.body.errors).toBeDefined();
    });
  });

  describe('GET /api/users/:id', () => {
    it('should return user by id', async () => {
      const response = await request(app)
        .get(`/api/users/${userId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.id).toBe(userId);
      expect(response.body.data.email).toBe('test@example.com');
      expect(response.body.data).not.toHaveProperty('password');
    });

    it('should return 404 for non-existent user', async () => {
      const response = await request(app)
        .get('/api/users/00000000-0000-0000-0000-000000000000')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error).toContain('not found');
    });

    it('should return 401 without auth token', async () => {
      await request(app)
        .get(`/api/users/${userId}`)
        .expect(401);
    });
  });

  describe('PATCH /api/users/:id', () => {
    it('should update user', async () => {
      const response = await request(app)
        .patch(`/api/users/${userId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          firstName: 'Updated'
        })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.firstName).toBe('Updated');

      // Verify in database
      const user = await User.findByPk(userId);
      expect(user?.firstName).toBe('Updated');
    });
  });

  describe('DELETE /api/users/:id', () => {
    it('should delete user', async () => {
      await request(app)
        .delete(`/api/users/${userId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(204);

      // Verify deletion
      const user = await User.findByPk(userId);
      expect(user).toBeNull();
    });
  });
});
```

### Testing with Database

```typescript
// tests/integration/orderService.test.ts
import { orderService } from '../../src/services/orderService';
import { User } from '../../src/models/User';
import { Product } from '../../src/models/Product';

describe('OrderService Integration', () => {
  let user: User;
  let product: Product;

  beforeEach(async () => {
    user = await User.create({
      email: 'test@example.com',
      password: 'hashedpassword',
      firstName: 'Test',
      lastName: 'User'
    });

    product = await Product.create({
      name: 'Test Product',
      price: 29.99,
      stock: 100
    });
  });

  it('should create order and decrease stock', async () => {
    const order = await orderService.create({
      userId: user.id,
      items: [
        {
          productId: product.id,
          quantity: 2,
          price: product.price
        }
      ]
    });

    expect(order).toBeDefined();
    expect(order.total).toBe(59.98);

    // Verify stock decreased
    await product.reload();
    expect(product.stock).toBe(98);
  });

  it('should rollback on error', async () => {
    const initialStock = product.stock;

    await expect(
      orderService.create({
        userId: user.id,
        items: [
          {
            productId: product.id,
            quantity: 200, // More than available
            price: product.price
          }
        ]
      })
    ).rejects.toThrow();

    // Stock should be unchanged
    await product.reload();
    expect(product.stock).toBe(initialStock);
  });
});
```

## Test Factories

### Create Test Data Factories

```typescript
// tests/factories/userFactory.ts
import { faker } from '@faker-js/faker';
import { User } from '../../src/models/User';
import { hashPassword } from '../../src/utils/crypto';

export class UserFactory {
  static async create(overrides?: Partial<any>): Promise<User> {
    const userData = {
      email: faker.internet.email(),
      password: await hashPassword('password123'),
      firstName: faker.person.firstName(),
      lastName: faker.person.lastName(),
      ...overrides
    };

    return User.create(userData);
  }

  static async createMany(count: number, overrides?: Partial<any>): Promise<User[]> {
    const promises = Array.from({ length: count }, () =>
      this.create(overrides)
    );
    return Promise.all(promises);
  }

  static async createAdmin(): Promise<User> {
    return this.create({ role: 'admin' });
  }
}

// Usage in tests
const user = await UserFactory.create();
const admin = await UserFactory.createAdmin();
const users = await UserFactory.createMany(10);
const specificUser = await UserFactory.create({
  email: 'specific@example.com'
});
```

## Test Helpers

### Auth Helper

```typescript
// tests/helpers/auth.ts
import { generateToken } from '../../src/utils/auth';
import { User } from '../../src/models/User';
import { UserFactory } from '../factories/userFactory';

export class AuthHelper {
  static async createAuthenticatedUser(): Promise<{
    user: User;
    token: string;
  }> {
    const user = await UserFactory.create();
    const token = generateToken({
      userId: user.id,
      email: user.email
    });

    return { user, token };
  }

  static async createAdminUser(): Promise<{
    user: User;
    token: string;
  }> {
    const user = await UserFactory.createAdmin();
    const token = generateToken({
      userId: user.id,
      email: user.email,
      role: 'admin'
    });

    return { user, token };
  }
}

// Usage
const { user, token } = await AuthHelper.createAuthenticatedUser();
await request(app)
  .get('/api/users')
  .set('Authorization', `Bearer ${token}`);
```

## Best Practices

1. **Test behavior, not implementation** - Test what, not how
2. **One assertion per test** - Or at least test one thing
3. **Descriptive test names** - Should describe what is being tested
4. **AAA pattern** - Arrange, Act, Assert
5. **Mock external dependencies** - Don't call real APIs in tests
6. **Clean up after tests** - Reset database, clear mocks
7. **Test edge cases** - Not just happy path
8. **Use factories** - For creating test data
9. **Test errors** - Not just success cases
10. **Maintain high coverage** - Aim for 80%+

## Common Patterns

### Testing Async Code

```typescript
// ✅ Using async/await
it('should create user', async () => {
  const user = await userService.create(userData);
  expect(user.id).toBeDefined();
});

// ✅ Testing rejections
it('should throw error', async () => {
  await expect(
    userService.getById('invalid')
  ).rejects.toThrow(NotFoundError);
});
```

### Testing with Mocks

```typescript
// Mock entire module
jest.mock('../../../src/services/emailService');

// Mock specific function
const mockSendEmail = jest.fn();
emailService.sendWelcome = mockSendEmail;

// Assert mock was called
expect(mockSendEmail).toHaveBeenCalledWith('test@example.com');
expect(mockSendEmail).toHaveBeenCalledTimes(1);
```

### Testing Errors

```typescript
it('should handle database error', async () => {
  (userRepository.create as jest.Mock).mockRejectedValue(
    new Error('Database error')
  );

  await expect(
    userService.create(userData)
  ).rejects.toThrow('Database error');
});
```

## Running Tests

```bash
# Run all tests
npm test

# Run with coverage
npm test -- --coverage

# Run specific file
npm test -- users.test.ts

# Run in watch mode
npm test -- --watch

# Run integration tests only
npm test -- --testPathPattern=integration
```

## Summary

- Write unit tests for services and utilities
- Write integration tests for API endpoints
- Use test factories for creating test data
- Mock external dependencies in unit tests
- Test both success and error cases
- Maintain high test coverage (80%+)
- Use descriptive test names
- Follow AAA pattern (Arrange, Act, Assert)
- Clean up after each test
- Run tests in CI/CD pipeline
