# Services and Repositories

## Service Layer

### What is a Service?

Services contain business logic and orchestrate operations across multiple repositories. They:
- Implement business rules
- Validate business constraints
- Orchestrate multiple repository calls
- Transform data between layers
- Handle transactions
- Throw business exceptions

### Service Structure

```typescript
// services/userService.ts
import { userRepository } from '../repositories/userRepository';
import { CreateUserDTO, UpdateUserDTO, UserDTO } from '../types/user';
import { ConflictError, NotFoundError, BadRequestError } from '../errors/AppError';
import { hashPassword, comparePassword } from '../utils/crypto';
import { emailService } from './emailService';
import logger from '../config/logger';

export class UserService {
  async create(data: CreateUserDTO): Promise<UserDTO> {
    logger.info('Creating user', { email: data.email });

    // Business rule: Email must be unique
    const existing = await userRepository.findByEmail(data.email);
    if (existing) {
      throw new ConflictError('Email already registered');
    }

    // Business rule: Age requirement
    if (data.age && data.age < 18) {
      throw new BadRequestError('User must be at least 18 years old');
    }

    // Transform data
    const hashedPassword = await hashPassword(data.password);

    // Persist to database
    const user = await userRepository.create({
      ...data,
      password: hashedPassword
    });

    // Side effect: Send welcome email
    await emailService.sendWelcome(user.email);

    logger.info('User created successfully', { userId: user.id });

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

  async authenticate(email: string, password: string): Promise<{
    user: UserDTO;
    token: string;
  }> {
    const user = await userRepository.findByEmail(email);
    if (!user) {
      throw new BadRequestError('Invalid credentials');
    }

    const isValid = await comparePassword(password, user.password);
    if (!isValid) {
      throw new BadRequestError('Invalid credentials');
    }

    // Business rule: Account must be active
    if (!user.isActive) {
      throw new BadRequestError('Account is inactive');
    }

    // Update last login
    await userRepository.update(user.id, {
      lastLoginAt: new Date()
    });

    // Generate token
    const token = generateToken({ userId: user.id, email: user.email });

    return {
      user: this.toDTO(user),
      token
    };
  }

  async update(id: string, data: UpdateUserDTO): Promise<UserDTO> {
    const user = await userRepository.findById(id);
    if (!user) {
      throw new NotFoundError('User not found');
    }

    // Business rule: Can't change email to existing email
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

    // Business rule: Can't delete user with active subscriptions
    const hasActiveSubscription = await subscriptionRepository.hasActive(id);
    if (hasActiveSubscription) {
      throw new BadRequestError('Cannot delete user with active subscription');
    }

    await userRepository.delete(id);
    logger.info('User deleted', { userId: id });
  }

  // Transform entity to DTO (hide sensitive fields)
  private toDTO(user: any): UserDTO {
    const { password, ...userDTO } = user.toJSON();
    return userDTO;
  }
}

export const userService = new UserService();
```

### Service Best Practices

**1. Business Logic Belongs Here:**
```typescript
// ✅ Good - Business logic in service
export class OrderService {
  async create(data: CreateOrderDTO): Promise<OrderDTO> {
    // Business rule: Minimum order amount
    if (data.total < 10) {
      throw new BadRequestError('Minimum order amount is $10');
    }

    // Business rule: Check inventory
    for (const item of data.items) {
      const product = await productRepository.findById(item.productId);
      if (product.stock < item.quantity) {
        throw new BadRequestError(`Insufficient stock for ${product.name}`);
      }
    }

    return orderRepository.create(data);
  }
}

// ❌ Bad - Business logic in controller or repository
```

**2. Orchestrate Multiple Operations:**
```typescript
export class OrderService {
  async processOrder(orderId: string): Promise<OrderDTO> {
    const order = await orderRepository.findById(orderId);
    if (!order) {
      throw new NotFoundError('Order not found');
    }

    // Orchestrate multiple operations
    const payment = await paymentService.charge(order.userId, order.total);
    await inventoryService.decreaseStock(order.items);
    await emailService.sendReceipt(order.userId, order);
    await notificationService.notifyShipping(order);

    // Update order status
    const updated = await orderRepository.update(orderId, {
      status: 'processing',
      paymentId: payment.id
    });

    return this.toDTO(updated);
  }
}
```

**3. Use Transactions for Multi-Step Operations:**
```typescript
import { sequelize } from '../config/database';

export class TransferService {
  async transfer(fromId: string, toId: string, amount: number): Promise<void> {
    // Business rules
    if (amount <= 0) {
      throw new BadRequestError('Amount must be positive');
    }

    return sequelize.transaction(async (transaction) => {
      // Get accounts with lock
      const fromAccount = await accountRepository.findById(fromId, { transaction });
      const toAccount = await accountRepository.findById(toId, { transaction });

      if (!fromAccount || !toAccount) {
        throw new NotFoundError('Account not found');
      }

      // Business rule: Sufficient balance
      if (fromAccount.balance < amount) {
        throw new BadRequestError('Insufficient balance');
      }

      // Perform transfer
      await accountRepository.updateBalance(fromId, -amount, { transaction });
      await accountRepository.updateBalance(toId, amount, { transaction });

      // Record transaction
      await transactionRepository.create({
        fromAccountId: fromId,
        toAccountId: toId,
        amount
      }, { transaction });

      // Transaction auto-commits if all succeed
    });
  }
}
```

**4. Transform Data Between Layers:**
```typescript
export class UserService {
  // Accept DTO from controller
  async create(data: CreateUserDTO): Promise<UserDTO> {
    // Transform DTO to entity data
    const entityData = {
      ...data,
      password: await hashPassword(data.password),
      role: 'user',
      isActive: true
    };

    const user = await userRepository.create(entityData);

    // Transform entity to DTO for response
    return this.toDTO(user);
  }

  // Hide sensitive fields
  private toDTO(user: User): UserDTO {
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      role: user.role,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
      // password not included!
    };
  }
}
```

**5. Service Calling Another Service:**
```typescript
export class OrderService {
  constructor(
    private readonly paymentService: PaymentService,
    private readonly emailService: EmailService
  ) {}

  async create(data: CreateOrderDTO): Promise<OrderDTO> {
    const order = await orderRepository.create(data);

    // Call other services
    await this.paymentService.createIntent(order.total);
    await this.emailService.sendOrderConfirmation(order.userId, order);

    return this.toDTO(order);
  }
}

// ❌ Don't do circular dependencies
// OrderService -> PaymentService -> OrderService (BAD!)
```

## Repository Layer

### What is a Repository?

Repositories abstract database operations. They:
- Encapsulate data access logic
- Provide clean API for querying
- Hide ORM/database implementation details
- Return model instances
- Handle database-specific operations

### Repository Structure

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
    const { search, role, isActive, limit = 50, offset = 0 } = filters;

    const where: any = {};

    if (search) {
      where[Op.or] = [
        { firstName: { [Op.iLike]: `%${search}%` } },
        { lastName: { [Op.iLike]: `%${search}%` } },
        { email: { [Op.iLike]: `%${search}%` } }
      ];
    }

    if (role) {
      where.role = role;
    }

    if (isActive !== undefined) {
      where.isActive = isActive;
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
    const { search, role, isActive } = filters;

    const where: any = {};

    if (search) {
      where[Op.or] = [
        { firstName: { [Op.iLike]: `%${search}%` } },
        { lastName: { [Op.iLike]: `%${search}%` } },
        { email: { [Op.iLike]: `%${search}%` } }
      ];
    }

    if (role) {
      where.role = role;
    }

    if (isActive !== undefined) {
      where.isActive = isActive;
    }

    return User.count({ where });
  }

  async findWithPosts(id: string): Promise<User | null> {
    return User.findByPk(id, {
      include: [{
        model: Post,
        as: 'posts',
        where: { published: true },
        required: false
      }]
    });
  }
}

export const userRepository = new UserRepository();
```

### Repository Best Practices

**1. One Repository Per Entity:**
```typescript
// ✅ Good - Separate repositories
class UserRepository { }
class PostRepository { }
class CommentRepository { }

// ❌ Bad - Generic repository for everything
class GenericRepository {
  findUserById() { }
  findPostById() { }
  // Don't do this!
}
```

**2. Return Models, Not Plain Objects:**
```typescript
// ✅ Good - Return model instance
async findById(id: string): Promise<User | null> {
  return User.findByPk(id);
}

// ❌ Bad - Return plain object
async findById(id: string): Promise<any | null> {
  const user = await User.findByPk(id);
  return user?.toJSON(); // Loses model methods!
}
```

**3. No Business Logic in Repositories:**
```typescript
// ❌ Bad - Business logic in repository
class UserRepository {
  async create(data: CreateUserDTO): Promise<User> {
    // Business rule - should be in service!
    if (data.age < 18) {
      throw new Error('Must be 18+');
    }
    return User.create(data);
  }
}

// ✅ Good - Only data access
class UserRepository {
  async create(data: CreateUserDTO): Promise<User> {
    return User.create(data);
  }
}
```

**4. Encapsulate Complex Queries:**
```typescript
export class OrderRepository {
  // Encapsulate complex query logic
  async findPendingOrders(userId: string): Promise<Order[]> {
    return Order.findAll({
      where: {
        userId,
        status: 'pending',
        createdAt: {
          [Op.gte]: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) // 30 days
        }
      },
      include: [{
        model: OrderItem,
        as: 'items',
        include: [{
          model: Product,
          as: 'product'
        }]
      }],
      order: [['createdAt', 'DESC']]
    });
  }
}
```

**5. Support Transactions:**
```typescript
import { Transaction } from 'sequelize';

export class AccountRepository {
  async updateBalance(
    id: string,
    amount: number,
    options?: { transaction?: Transaction }
  ): Promise<Account> {
    const account = await this.findById(id, options);
    if (!account) {
      throw new Error('Account not found');
    }

    return account.update(
      { balance: account.balance + amount },
      options
    );
  }

  async findById(
    id: string,
    options?: { transaction?: Transaction }
  ): Promise<Account | null> {
    return Account.findByPk(id, options);
  }
}
```

## Dependency Injection

### Manual Dependency Injection

```typescript
// services/orderService.ts
export class OrderService {
  constructor(
    private readonly orderRepository: OrderRepository,
    private readonly paymentService: PaymentService,
    private readonly emailService: EmailService
  ) {}

  async create(data: CreateOrderDTO): Promise<OrderDTO> {
    const order = await this.orderRepository.create(data);
    await this.paymentService.createIntent(order.total);
    await this.emailService.sendConfirmation(order);
    return this.toDTO(order);
  }
}

// Create instances with dependencies
export const orderService = new OrderService(
  orderRepository,
  paymentService,
  emailService
);
```

### Benefits of Dependency Injection

**1. Testability:**
```typescript
// Easy to mock dependencies in tests
describe('OrderService', () => {
  it('should create order', async () => {
    const mockOrderRepo = {
      create: jest.fn().mockResolvedValue(mockOrder)
    };
    const mockPaymentService = {
      createIntent: jest.fn()
    };
    const mockEmailService = {
      sendConfirmation: jest.fn()
    };

    const service = new OrderService(
      mockOrderRepo as any,
      mockPaymentService as any,
      mockEmailService as any
    );

    await service.create(orderData);

    expect(mockOrderRepo.create).toHaveBeenCalled();
  });
});
```

**2. Flexibility:**
```typescript
// Easy to swap implementations
const devEmailService = new ConsoleEmailService(); // Logs to console
const prodEmailService = new SendGridEmailService(); // Sends real emails

const service = config.env === 'production'
  ? new OrderService(orderRepository, paymentService, prodEmailService)
  : new OrderService(orderRepository, paymentService, devEmailService);
```

## Data Transfer Objects (DTOs)

### Input DTOs

```typescript
// types/user.ts
export interface CreateUserDTO {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  age?: number;
}

export interface UpdateUserDTO {
  email?: string;
  firstName?: string;
  lastName?: string;
}

export interface LoginDTO {
  email: string;
  password: string;
}
```

### Output DTOs

```typescript
// types/user.ts
export interface UserDTO {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  role: string;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
  // password NOT included!
}

export interface UserListDTO {
  users: UserDTO[];
  total: number;
  page: number;
  pageSize: number;
}
```

### DTO Transformers

```typescript
// utils/transformers.ts
import { User } from '../models/User';
import { UserDTO } from '../types/user';

export class UserTransformer {
  static toDTO(user: User): UserDTO {
    return {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      role: user.role,
      isActive: user.isActive,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt
    };
  }

  static toDTOs(users: User[]): UserDTO[] {
    return users.map(u => this.toDTO(u));
  }

  static toPublicDTO(user: User): Partial<UserDTO> {
    return {
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName
      // Even less info for public profiles
    };
  }
}
```

## Service Patterns

### Query Service Pattern

```typescript
// services/userQueryService.ts
// Separate service for complex read operations
export class UserQueryService {
  async getStats(): Promise<UserStatsDTO> {
    const [total, active, admins] = await Promise.all([
      userRepository.count(),
      userRepository.count({ isActive: true }),
      userRepository.count({ role: 'admin' })
    ]);

    return {
      total,
      active,
      admins,
      inactive: total - active
    };
  }

  async searchUsers(query: string): Promise<UserDTO[]> {
    const users = await userRepository.search(query);
    return users.map(u => UserTransformer.toDTO(u));
  }
}
```

### Command Service Pattern

```typescript
// services/userCommandService.ts
// Separate service for write operations
export class UserCommandService {
  async create(data: CreateUserDTO): Promise<UserDTO> {
    // Validation and business rules
    // Create user
    // Send emails
    // Return DTO
  }

  async update(id: string, data: UpdateUserDTO): Promise<UserDTO> {
    // Validation
    // Update user
    // Return DTO
  }
}
```

## Best Practices

1. **Services contain business logic** - Not controllers or repositories
2. **Repositories only handle data access** - No business rules
3. **Use DTOs** - Hide sensitive data, clear contracts
4. **Dependency injection** - For testability and flexibility
5. **One repository per entity** - Clear responsibility
6. **Return models from repositories** - Not plain objects
7. **Use transactions** - For multi-step operations
8. **Transform at service layer** - Entity to DTO conversion
9. **No circular dependencies** - Service A → Service B → Service A
10. **Keep methods focused** - Single responsibility

## Common Pitfalls

1. **Business logic in repositories** - Repositories should be dumb
2. **Business logic in controllers** - Controllers should orchestrate
3. **Services calling controllers** - Wrong dependency direction
4. **Circular dependencies** - Refactor to avoid
5. **Exposing entities directly** - Use DTOs
6. **Fat services** - Break up into smaller services
7. **No transactions** - Data inconsistency
8. **Forgetting to transform** - Sensitive data exposed

## Summary

- Services implement business logic and orchestrate operations
- Repositories encapsulate data access
- Use DTOs to hide sensitive data
- Apply dependency injection for testability
- Keep clear separation between layers
- Use transactions for multi-step operations
- Transform entities to DTOs in services
- One repository per entity
- Avoid circular dependencies
