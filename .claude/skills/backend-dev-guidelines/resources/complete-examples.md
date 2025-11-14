# Complete Examples

## Example 1: User Management Feature

Complete implementation of a user management feature from route to database.

### 1. Type Definitions

```typescript
// types/user.ts
export interface CreateUserDTO {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
}

export interface UpdateUserDTO {
  email?: string;
  firstName?: string;
  lastName?: string;
}

export interface UserDTO {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserFilters {
  search?: string;
  limit?: number;
  offset?: number;
}
```

### 2. Validation Schemas

```typescript
// schemas/userSchemas.ts
import Joi from 'joi';

export const createUserSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).required(),
  firstName: Joi.string().min(2).max(50).required(),
  lastName: Joi.string().min(2).max(50).required()
});

export const updateUserSchema = Joi.object({
  email: Joi.string().email(),
  firstName: Joi.string().min(2).max(50),
  lastName: Joi.string().min(2).max(50)
}).min(1); // At least one field required

export const userIdSchema = Joi.object({
  id: Joi.string().uuid().required()
});
```

### 3. Model

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
  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;

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
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true,
      validate: {
        isEmail: true
      }
    },
    password: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    firstName: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    lastName: {
      type: DataTypes.STRING(100),
      allowNull: false
    }
  },
  {
    sequelize,
    tableName: 'users',
    timestamps: true,
    indexes: [
      {
        unique: true,
        fields: ['email']
      }
    ]
  }
);
```

### 4. Repository

```typescript
// repositories/userRepository.ts
import { User } from '../models/User';
import { CreateUserDTO, UpdateUserDTO, UserFilters } from '../types/user';
import { Op } from 'sequelize';

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

  async findAll(filters: UserFilters = {}): Promise<User[]> {
    const { search, limit = 50, offset = 0 } = filters;

    const where: any = {};
    if (search) {
      where[Op.or] = [
        { firstName: { [Op.iLike]: `%${search}%` } },
        { lastName: { [Op.iLike]: `%${search}%` } },
        { email: { [Op.iLike]: `%${search}%` } }
      ];
    }

    return User.findAll({
      where,
      limit,
      offset,
      order: [['createdAt', 'DESC']]
    });
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

  async count(filters: UserFilters = {}): Promise<number> {
    const { search } = filters;

    const where: any = {};
    if (search) {
      where[Op.or] = [
        { firstName: { [Op.iLike]: `%${search}%` } },
        { lastName: { [Op.iLike]: `%${search}%` } },
        { email: { [Op.iLike]: `%${search}%` } }
      ];
    }

    return User.count({ where });
  }
}

export const userRepository = new UserRepository();
```

### 5. Service

```typescript
// services/userService.ts
import { userRepository } from '../repositories/userRepository';
import { CreateUserDTO, UpdateUserDTO, UserDTO, UserFilters } from '../types/user';
import { ConflictError, NotFoundError } from '../errors/AppError';
import { hashPassword } from '../utils/crypto';
import logger from '../config/logger';

export class UserService {
  async create(data: CreateUserDTO): Promise<UserDTO> {
    logger.info('Creating user', { email: data.email });

    // Check if user already exists
    const existing = await userRepository.findByEmail(data.email);
    if (existing) {
      throw new ConflictError('Email already registered');
    }

    // Hash password
    const hashedPassword = await hashPassword(data.password);

    // Create user
    const user = await userRepository.create({
      ...data,
      password: hashedPassword
    });

    logger.info('User created successfully', { userId: user.id });

    return this.toDTO(user);
  }

  async getById(id: string): Promise<UserDTO> {
    const user = await userRepository.findById(id);
    if (!user) {
      throw new NotFoundError('User not found');
    }
    return this.toDTO(user);
  }

  async list(filters: UserFilters): Promise<{
    users: UserDTO[];
    total: number;
    limit: number;
    offset: number;
  }> {
    const [users, total] = await Promise.all([
      userRepository.findAll(filters),
      userRepository.count(filters)
    ]);

    return {
      users: users.map(u => this.toDTO(u)),
      total,
      limit: filters.limit || 50,
      offset: filters.offset || 0
    };
  }

  async update(id: string, data: UpdateUserDTO): Promise<UserDTO> {
    const user = await userRepository.findById(id);
    if (!user) {
      throw new NotFoundError('User not found');
    }

    // If email is being updated, check for conflicts
    if (data.email && data.email !== user.email) {
      const existing = await userRepository.findByEmail(data.email);
      if (existing) {
        throw new ConflictError('Email already in use');
      }
    }

    const updated = await userRepository.update(id, data);
    logger.info('User updated', { userId: id });

    return this.toDTO(updated);
  }

  async delete(id: string): Promise<void> {
    const user = await userRepository.findById(id);
    if (!user) {
      throw new NotFoundError('User not found');
    }

    await userRepository.delete(id);
    logger.info('User deleted', { userId: id });
  }

  private toDTO(user: User): UserDTO {
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };
  }
}

export const userService = new UserService();
```

### 6. Controller

```typescript
// controllers/userController.ts
import { Request, Response, NextFunction } from 'express';
import { userService } from '../services/userService';
import { UserFilters } from '../types/user';

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

  async list(req: Request, res: Response, next: NextFunction) {
    try {
      const filters: UserFilters = {
        search: req.query.search as string,
        limit: parseInt(req.query.limit as string) || 50,
        offset: parseInt(req.query.offset as string) || 0
      };

      const result = await userService.list(filters);
      res.json({
        success: true,
        data: result.users,
        pagination: {
          total: result.total,
          limit: result.limit,
          offset: result.offset
        }
      });
    } catch (error) {
      next(error);
    }
  }

  async update(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await userService.update(req.params.id, req.body);
      res.json({
        success: true,
        data: user
      });
    } catch (error) {
      next(error);
    }
  }

  async delete(req: Request, res: Response, next: NextFunction) {
    try {
      await userService.delete(req.params.id);
      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
}

export const userController = new UserController();
```

### 7. Routes

```typescript
// routes/users.ts
import { Router } from 'express';
import { userController } from '../controllers/userController';
import { validateRequest } from '../middleware/validation';
import { authenticate } from '../middleware/auth';
import {
  createUserSchema,
  updateUserSchema,
  userIdSchema
} from '../schemas/userSchemas';

const router = Router();

// Public routes
router.post(
  '/',
  validateRequest({ body: createUserSchema }),
  userController.create
);

// Protected routes
router.use(authenticate);

router.get('/', userController.list);

router.get(
  '/:id',
  validateRequest({ params: userIdSchema }),
  userController.getById
);

router.patch(
  '/:id',
  validateRequest({
    params: userIdSchema,
    body: updateUserSchema
  }),
  userController.update
);

router.delete(
  '/:id',
  validateRequest({ params: userIdSchema }),
  userController.delete
);

export default router;
```

### 8. Tests

```typescript
// tests/services/userService.test.ts
import { userService } from '../../src/services/userService';
import { userRepository } from '../../src/repositories/userRepository';
import { ConflictError, NotFoundError } from '../../src/errors/AppError';
import { hashPassword } from '../../src/utils/crypto';

jest.mock('../../src/repositories/userRepository');
jest.mock('../../src/utils/crypto');

describe('UserService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('create', () => {
    it('should create a user successfully', async () => {
      const mockUser = {
        id: '123',
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        password: 'hashedpass',
        createdAt: new Date(),
        updatedAt: new Date()
      };

      (userRepository.findByEmail as jest.Mock).mockResolvedValue(null);
      (hashPassword as jest.Mock).mockResolvedValue('hashedpass');
      (userRepository.create as jest.Mock).mockResolvedValue(mockUser);

      const result = await userService.create({
        email: 'test@example.com',
        password: 'password123',
        firstName: 'John',
        lastName: 'Doe'
      });

      expect(result.email).toBe('test@example.com');
      expect(result).not.toHaveProperty('password');
    });

    it('should throw ConflictError if email exists', async () => {
      (userRepository.findByEmail as jest.Mock).mockResolvedValue({
        id: '123',
        email: 'test@example.com'
      });

      await expect(
        userService.create({
          email: 'test@example.com',
          password: 'password123',
          firstName: 'John',
          lastName: 'Doe'
        })
      ).rejects.toThrow(ConflictError);
    });
  });

  describe('getById', () => {
    it('should return user if found', async () => {
      const mockUser = {
        id: '123',
        email: 'test@example.com',
        firstName: 'John',
        lastName: 'Doe',
        password: 'hashedpass',
        createdAt: new Date(),
        updatedAt: new Date()
      };

      (userRepository.findById as jest.Mock).mockResolvedValue(mockUser);

      const result = await userService.getById('123');

      expect(result.id).toBe('123');
      expect(result).not.toHaveProperty('password');
    });

    it('should throw NotFoundError if user not found', async () => {
      (userRepository.findById as jest.Mock).mockResolvedValue(null);

      await expect(userService.getById('123')).rejects.toThrow(NotFoundError);
    });
  });
});
```

## Example 2: Order Processing with Transactions

### Service with Transaction

```typescript
// services/orderService.ts
import { sequelize } from '../config/database';
import { orderRepository } from '../repositories/orderRepository';
import { inventoryRepository } from '../repositories/inventoryRepository';
import { CreateOrderDTO, OrderDTO } from '../types/order';
import { BadRequestError, NotFoundError } from '../errors/AppError';
import { emailService } from './emailService';
import logger from '../config/logger';

export class OrderService {
  async create(userId: string, data: CreateOrderDTO): Promise<OrderDTO> {
    logger.info('Creating order', { userId, itemCount: data.items.length });

    // Validate items
    if (data.items.length === 0) {
      throw new BadRequestError('Order must contain at least one item');
    }

    // Use transaction for atomicity
    return sequelize.transaction(async (transaction) => {
      // 1. Check inventory availability
      for (const item of data.items) {
        const product = await inventoryRepository.findById(
          item.productId,
          { transaction }
        );

        if (!product) {
          throw new NotFoundError(`Product ${item.productId} not found`);
        }

        if (product.quantity < item.quantity) {
          throw new BadRequestError(
            `Insufficient stock for product ${product.name}`
          );
        }
      }

      // 2. Create order
      const order = await orderRepository.create(
        {
          userId,
          items: data.items,
          total: this.calculateTotal(data.items)
        },
        { transaction }
      );

      // 3. Decrease inventory
      for (const item of data.items) {
        await inventoryRepository.decreaseQuantity(
          item.productId,
          item.quantity,
          { transaction }
        );
      }

      // 4. Transaction will auto-commit here if all succeeded
      logger.info('Order created successfully', { orderId: order.id });

      // 5. Send email (outside transaction - non-critical)
      emailService.sendOrderConfirmation(userId, order).catch(error => {
        logger.error('Failed to send order confirmation', { error });
      });

      return this.toDTO(order);
    });
  }

  private calculateTotal(items: Array<{ price: number; quantity: number }>): number {
    return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  }

  private toDTO(order: any): OrderDTO {
    return {
      id: order.id,
      userId: order.userId,
      items: order.items,
      total: order.total,
      status: order.status,
      createdAt: order.createdAt
    };
  }
}

export const orderService = new OrderService();
```

## Example 3: Authentication Middleware

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
}

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        email: string;
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
    const payload = jwt.verify(token, config.jwtSecret) as JWTPayload;

    // Fetch user
    const user = await userRepository.findById(payload.userId);
    if (!user) {
      throw new UnauthorizedError('User not found');
    }

    // Attach user to request
    req.user = {
      id: user.id,
      email: user.email
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
```

## Summary

These examples demonstrate:
- Complete feature implementation from route to database
- Proper layering and separation of concerns
- Error handling at each layer
- Type safety with TypeScript
- Validation with Joi
- Transaction management
- Testing strategies
- Authentication middleware
- DTO pattern for hiding sensitive data
- Logging and monitoring
