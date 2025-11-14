# Database Patterns

## ORM Best Practices (Sequelize)

### Model Definition

```typescript
// models/User.ts
import { Model, DataTypes, Optional } from 'sequelize';
import { sequelize } from '../config/database';

interface UserAttributes {
  id: string;
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  role: 'user' | 'admin';
  isActive: boolean;
  lastLoginAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

interface UserCreationAttributes extends Optional<UserAttributes, 'id' | 'isActive' | 'lastLoginAt' | 'createdAt' | 'updatedAt'> {}

export class User extends Model<UserAttributes, UserCreationAttributes> implements UserAttributes {
  public id!: string;
  public email!: string;
  public password!: string;
  public firstName!: string;
  public lastName!: string;
  public role!: 'user' | 'admin';
  public isActive!: boolean;
  public lastLoginAt!: Date | null;
  public readonly createdAt!: Date;
  public readonly updatedAt!: Date;

  // Virtual field
  public get fullName(): string {
    return `${this.firstName} ${this.lastName}`;
  }

  // Instance method
  public isAdmin(): boolean {
    return this.role === 'admin';
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
    },
    role: {
      type: DataTypes.ENUM('user', 'admin'),
      defaultValue: 'user',
      allowNull: false
    },
    isActive: {
      type: DataTypes.BOOLEAN,
      defaultValue: true,
      allowNull: false
    },
    lastLoginAt: {
      type: DataTypes.DATE,
      allowNull: true
    }
  },
  {
    sequelize,
    tableName: 'users',
    timestamps: true,
    paranoid: true, // Soft deletes
    indexes: [
      {
        unique: true,
        fields: ['email']
      },
      {
        fields: ['role']
      },
      {
        fields: ['createdAt']
      }
    ]
  }
);
```

### Relationships

```typescript
// models/index.ts - Define all associations here
import { User } from './User';
import { Post } from './Post';
import { Comment } from './Comment';
import { Profile } from './Profile';

// One-to-One
User.hasOne(Profile, { foreignKey: 'userId', as: 'profile' });
Profile.belongsTo(User, { foreignKey: 'userId', as: 'user' });

// One-to-Many
User.hasMany(Post, { foreignKey: 'authorId', as: 'posts' });
Post.belongsTo(User, { foreignKey: 'authorId', as: 'author' });

// Many-to-Many
Post.belongsToMany(Tag, { through: 'PostTags', as: 'tags' });
Tag.belongsToMany(Post, { through: 'PostTags', as: 'posts' });

export { User, Post, Comment, Profile };
```

## Query Patterns

### Basic CRUD

```typescript
// repositories/userRepository.ts
export class UserRepository {
  // Create
  async create(data: CreateUserDTO): Promise<User> {
    return User.create(data);
  }

  // Read
  async findById(id: string): Promise<User | null> {
    return User.findByPk(id);
  }

  async findByEmail(email: string): Promise<User | null> {
    return User.findOne({ where: { email } });
  }

  // Update
  async update(id: string, data: UpdateUserDTO): Promise<User> {
    const user = await this.findById(id);
    if (!user) {
      throw new Error('User not found');
    }
    return user.update(data);
  }

  // Delete (soft delete if paranoid: true)
  async delete(id: string): Promise<void> {
    await User.destroy({ where: { id } });
  }

  // Hard delete
  async hardDelete(id: string): Promise<void> {
    await User.destroy({ where: { id }, force: true });
  }
}
```

### Complex Queries

```typescript
import { Op } from 'sequelize';

export class UserRepository {
  // Search with multiple conditions
  async search(filters: {
    search?: string;
    role?: string;
    isActive?: boolean;
    createdAfter?: Date;
  }): Promise<User[]> {
    const where: any = {};

    if (filters.search) {
      where[Op.or] = [
        { firstName: { [Op.iLike]: `%${filters.search}%` } },
        { lastName: { [Op.iLike]: `%${filters.search}%` } },
        { email: { [Op.iLike]: `%${filters.search}%` } }
      ];
    }

    if (filters.role) {
      where.role = filters.role;
    }

    if (filters.isActive !== undefined) {
      where.isActive = filters.isActive;
    }

    if (filters.createdAfter) {
      where.createdAt = { [Op.gte]: filters.createdAfter };
    }

    return User.findAll({
      where,
      order: [['createdAt', 'DESC']],
      limit: 100
    });
  }

  // Pagination
  async findAllPaginated(options: {
    page: number;
    pageSize: number;
    orderBy?: string;
    orderDirection?: 'ASC' | 'DESC';
  }): Promise<{ users: User[]; total: number; totalPages: number }> {
    const { page, pageSize, orderBy = 'createdAt', orderDirection = 'DESC' } = options;

    const offset = (page - 1) * pageSize;

    const { count, rows } = await User.findAndCountAll({
      offset,
      limit: pageSize,
      order: [[orderBy, orderDirection]],
      distinct: true
    });

    return {
      users: rows,
      total: count,
      totalPages: Math.ceil(count / pageSize)
    };
  }

  // With associations
  async findWithPosts(id: string): Promise<User | null> {
    return User.findByPk(id, {
      include: [
        {
          model: Post,
          as: 'posts',
          where: { published: true },
          required: false, // LEFT JOIN
          order: [['createdAt', 'DESC']],
          limit: 10
        }
      ]
    });
  }

  // Aggregations
  async getStatsByRole(): Promise<Array<{ role: string; count: number }>> {
    return User.findAll({
      attributes: [
        'role',
        [sequelize.fn('COUNT', sequelize.col('id')), 'count']
      ],
      group: ['role']
    }) as any;
  }
}
```

### N+1 Query Prevention

**Bad - N+1 Problem**:
```typescript
// ❌ This will execute 1 + N queries
const users = await User.findAll(); // 1 query
for (const user of users) {
  const posts = await Post.findAll({ where: { authorId: user.id } }); // N queries
  console.log(user.name, posts.length);
}
```

**Good - Eager Loading**:
```typescript
// ✅ This executes only 1 query
const users = await User.findAll({
  include: [{
    model: Post,
    as: 'posts'
  }]
});

for (const user of users) {
  console.log(user.name, user.posts.length);
}
```

**Good - Separate Query + In-Memory Join**:
```typescript
// ✅ This executes 2 queries total
const users = await User.findAll();
const userIds = users.map(u => u.id);

const posts = await Post.findAll({
  where: { authorId: { [Op.in]: userIds } }
});

// Group posts by user in memory
const postsByUser = posts.reduce((acc, post) => {
  acc[post.authorId] = acc[post.authorId] || [];
  acc[post.authorId].push(post);
  return acc;
}, {} as Record<string, Post[]>);

users.forEach(user => {
  const userPosts = postsByUser[user.id] || [];
  console.log(user.name, userPosts.length);
});
```

## Transaction Patterns

### Basic Transaction

```typescript
import { sequelize } from '../config/database';

async function transferMoney(fromId: string, toId: string, amount: number) {
  const transaction = await sequelize.transaction();

  try {
    // Deduct from sender
    await Account.decrement('balance', {
      by: amount,
      where: { id: fromId },
      transaction
    });

    // Add to receiver
    await Account.increment('balance', {
      by: amount,
      where: { id: toId },
      transaction
    });

    // Create transaction record
    await Transaction.create({
      fromAccountId: fromId,
      toAccountId: toId,
      amount
    }, { transaction });

    await transaction.commit();
  } catch (error) {
    await transaction.rollback();
    throw error;
  }
}
```

### Managed Transaction (Recommended)

```typescript
async function transferMoney(fromId: string, toId: string, amount: number) {
  return sequelize.transaction(async (t) => {
    // Auto-commits on success, auto-rolls back on error
    await Account.decrement('balance', {
      by: amount,
      where: { id: fromId },
      transaction: t
    });

    await Account.increment('balance', {
      by: amount,
      where: { id: toId },
      transaction: t
    });

    await Transaction.create({
      fromAccountId: fromId,
      toAccountId: toId,
      amount
    }, { transaction: t });
  });
}
```

### Nested Transactions

```typescript
async function complexOperation() {
  return sequelize.transaction(async (t1) => {
    await User.create({ name: 'User 1' }, { transaction: t1 });

    // Savepoint for nested operation
    await sequelize.transaction({ transaction: t1 }, async (t2) => {
      await User.create({ name: 'User 2' }, { transaction: t2 });
      // If this fails, only User 2 is rolled back
    });

    await User.create({ name: 'User 3' }, { transaction: t1 });
  });
}
```

### Transaction with Locking

```typescript
async function reserveInventory(productId: string, quantity: number) {
  return sequelize.transaction(async (t) => {
    // Lock row for update
    const product = await Product.findByPk(productId, {
      lock: t.LOCK.UPDATE,
      transaction: t
    });

    if (!product) {
      throw new NotFoundError('Product not found');
    }

    if (product.quantity < quantity) {
      throw new BadRequestError('Insufficient inventory');
    }

    await product.decrement('quantity', {
      by: quantity,
      transaction: t
    });

    return product;
  });
}
```

## Raw Queries

### When to Use Raw Queries

Use raw queries for:
- Complex analytical queries
- Database-specific features
- Performance optimization
- Bulk operations

**With Parameter Binding**:
```typescript
async function getTopSellingProducts(limit: number): Promise<any[]> {
  const [results] = await sequelize.query(
    `
    SELECT
      p.id,
      p.name,
      COUNT(oi.id) as order_count,
      SUM(oi.quantity) as total_sold,
      SUM(oi.quantity * oi.price) as revenue
    FROM products p
    JOIN order_items oi ON oi.product_id = p.id
    JOIN orders o ON o.id = oi.order_id
    WHERE o.created_at >= NOW() - INTERVAL '30 days'
    GROUP BY p.id, p.name
    ORDER BY revenue DESC
    LIMIT :limit
    `,
    {
      replacements: { limit },
      type: QueryTypes.SELECT
    }
  );
  return results;
}
```

**Never concatenate user input**:
```typescript
// ❌ DANGEROUS - SQL Injection vulnerability!
const results = await sequelize.query(
  `SELECT * FROM users WHERE email = '${email}'`
);

// ✅ SAFE - Use parameter binding
const results = await sequelize.query(
  'SELECT * FROM users WHERE email = :email',
  {
    replacements: { email },
    type: QueryTypes.SELECT
  }
);
```

## Migrations

### Creating Migrations

```typescript
// migrations/20240101000000-create-users.ts
import { QueryInterface, DataTypes } from 'sequelize';

export async function up(queryInterface: QueryInterface): Promise<void> {
  await queryInterface.createTable('users', {
    id: {
      type: DataTypes.UUID,
      defaultValue: DataTypes.UUIDV4,
      primaryKey: true
    },
    email: {
      type: DataTypes.STRING(255),
      allowNull: false,
      unique: true
    },
    password: {
      type: DataTypes.STRING(255),
      allowNull: false
    },
    first_name: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    last_name: {
      type: DataTypes.STRING(100),
      allowNull: false
    },
    role: {
      type: DataTypes.ENUM('user', 'admin'),
      defaultValue: 'user'
    },
    is_active: {
      type: DataTypes.BOOLEAN,
      defaultValue: true
    },
    created_at: {
      type: DataTypes.DATE,
      allowNull: false
    },
    updated_at: {
      type: DataTypes.DATE,
      allowNull: false
    },
    deleted_at: {
      type: DataTypes.DATE,
      allowNull: true
    }
  });

  // Add indexes
  await queryInterface.addIndex('users', ['email'], {
    unique: true,
    name: 'users_email_unique'
  });

  await queryInterface.addIndex('users', ['role'], {
    name: 'users_role_index'
  });
}

export async function down(queryInterface: QueryInterface): Promise<void> {
  await queryInterface.dropTable('users');
}
```

### Adding Columns

```typescript
// migrations/20240102000000-add-phone-to-users.ts
export async function up(queryInterface: QueryInterface): Promise<void> {
  await queryInterface.addColumn('users', 'phone', {
    type: DataTypes.STRING(20),
    allowNull: true
  });

  await queryInterface.addIndex('users', ['phone'], {
    name: 'users_phone_index'
  });
}

export async function down(queryInterface: QueryInterface): Promise<void> {
  await queryInterface.removeColumn('users', 'phone');
}
```

## Performance Optimization

### Indexing Strategy

```typescript
// Add indexes for:
// 1. Foreign keys
// 2. Frequently queried columns
// 3. WHERE clause columns
// 4. ORDER BY columns
// 5. JOIN columns

User.init({
  // ...
}, {
  indexes: [
    // Unique constraint
    { unique: true, fields: ['email'] },

    // Single column
    { fields: ['role'] },
    { fields: ['created_at'] },

    // Composite index
    { fields: ['role', 'is_active'] },

    // Partial index
    {
      fields: ['email'],
      where: { is_active: true },
      name: 'active_users_email'
    }
  ]
});
```

### Select Only Needed Fields

```typescript
// ❌ Bad - Selects all columns
const users = await User.findAll();

// ✅ Good - Selects only needed columns
const users = await User.findAll({
  attributes: ['id', 'email', 'firstName']
});

// Exclude specific fields
const users = await User.findAll({
  attributes: { exclude: ['password', 'deletedAt'] }
});
```

### Batch Operations

```typescript
// Bulk create
await User.bulkCreate([
  { email: 'user1@example.com', password: 'hash1' },
  { email: 'user2@example.com', password: 'hash2' }
], {
  validate: true,
  individualHooks: false // Disable hooks for performance
});

// Bulk update
await User.update(
  { isActive: false },
  { where: { lastLoginAt: { [Op.lt]: thirtyDaysAgo } } }
);

// Bulk delete
await User.destroy({
  where: { isActive: false }
});
```

## Best Practices

1. **Use migrations** for schema changes
2. **Add indexes** to frequently queried columns
3. **Prevent N+1 queries** with eager loading
4. **Use transactions** for multi-step operations
5. **Use parameter binding** to prevent SQL injection
6. **Select only needed columns** to reduce data transfer
7. **Use batch operations** for bulk changes
8. **Add database constraints** for data integrity
9. **Use soft deletes** (paranoid) when data history is important
10. **Monitor slow queries** and optimize

## Common Pitfalls

1. **N+1 queries** - Forgetting to eager load associations
2. **Missing indexes** - Slow queries on large tables
3. **SQL injection** - Concatenating user input
4. **No transactions** - Inconsistent data from partial updates
5. **Over-fetching** - Selecting all columns when only few needed
6. **Missing validations** - Relying only on ORM validations
7. **No connection pooling** - Poor performance under load
8. **Ignoring migrations** - Manual schema changes

## Summary

- Define models with proper types and constraints
- Use repositories to encapsulate database logic
- Prevent N+1 queries with eager loading
- Use transactions for multi-step operations
- Always use parameter binding for raw queries
- Create migrations for all schema changes
- Add indexes for performance
- Select only needed fields
- Use bulk operations for multiple records
