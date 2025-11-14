# Validation Patterns

## Input Validation

### Why Validate?

1. **Security**: Prevent injection attacks
2. **Data Integrity**: Ensure valid data in database
3. **Better UX**: Clear error messages
4. **Reliability**: Catch errors early

### Where to Validate?

Validation should happen at multiple layers:

1. **Request Layer** (Middleware): Validate HTTP request structure
2. **Service Layer**: Validate business rules
3. **Database Layer**: Database constraints as last resort

## Joi Validation

### Installation

```bash
npm install joi
npm install -D @types/joi
```

### Basic Schema

```typescript
// schemas/userSchemas.ts
import Joi from 'joi';

export const createUserSchema = Joi.object({
  email: Joi.string()
    .email()
    .required()
    .messages({
      'string.email': 'Email must be a valid email address',
      'any.required': 'Email is required'
    }),

  password: Joi.string()
    .min(8)
    .max(128)
    .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
    .required()
    .messages({
      'string.min': 'Password must be at least 8 characters',
      'string.max': 'Password must be at most 128 characters',
      'string.pattern.base': 'Password must contain uppercase, lowercase, and number'
    }),

  firstName: Joi.string()
    .min(2)
    .max(50)
    .required(),

  lastName: Joi.string()
    .min(2)
    .max(50)
    .required(),

  age: Joi.number()
    .integer()
    .min(18)
    .max(120)
    .optional(),

  role: Joi.string()
    .valid('user', 'admin')
    .default('user'),

  phoneNumber: Joi.string()
    .pattern(/^\+?[1-9]\d{1,14}$/)
    .optional()
    .messages({
      'string.pattern.base': 'Phone number must be in E.164 format'
    })
});

export const updateUserSchema = Joi.object({
  email: Joi.string().email().optional(),
  firstName: Joi.string().min(2).max(50).optional(),
  lastName: Joi.string().min(2).max(50).optional(),
  phoneNumber: Joi.string().pattern(/^\+?[1-9]\d{1,14}$/).optional()
}).min(1); // At least one field must be present

export const userIdSchema = Joi.object({
  id: Joi.string().uuid().required()
});

export const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().required()
});
```

### Complex Schemas

```typescript
// Nested objects
export const addressSchema = Joi.object({
  street: Joi.string().required(),
  city: Joi.string().required(),
  state: Joi.string().length(2).required(),
  zipCode: Joi.string().pattern(/^\d{5}(-\d{4})?$/).required(),
  country: Joi.string().length(2).default('US')
});

export const createUserWithAddressSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).required(),
  firstName: Joi.string().required(),
  lastName: Joi.string().required(),
  address: addressSchema.required()
});

// Arrays
export const createOrderSchema = Joi.object({
  userId: Joi.string().uuid().required(),
  items: Joi.array()
    .items(
      Joi.object({
        productId: Joi.string().uuid().required(),
        quantity: Joi.number().integer().min(1).required(),
        price: Joi.number().positive().required()
      })
    )
    .min(1)
    .required()
    .messages({
      'array.min': 'Order must contain at least one item'
    }),
  shippingAddress: addressSchema.required(),
  notes: Joi.string().max(500).optional()
});

// Conditional validation
export const paymentSchema = Joi.object({
  method: Joi.string().valid('credit_card', 'paypal', 'bank_transfer').required(),
  // Credit card details required only if method is credit_card
  cardNumber: Joi.when('method', {
    is: 'credit_card',
    then: Joi.string().creditCard().required(),
    otherwise: Joi.forbidden()
  }),
  cardExpiry: Joi.when('method', {
    is: 'credit_card',
    then: Joi.string().pattern(/^\d{2}\/\d{2}$/).required(),
    otherwise: Joi.forbidden()
  }),
  cardCvv: Joi.when('method', {
    is: 'credit_card',
    then: Joi.string().pattern(/^\d{3,4}$/).required(),
    otherwise: Joi.forbidden()
  }),
  // PayPal email required only if method is paypal
  paypalEmail: Joi.when('method', {
    is: 'paypal',
    then: Joi.string().email().required(),
    otherwise: Joi.forbidden()
  })
});
```

### Custom Validators

```typescript
// Custom validation function
const validatePassword = (value: string, helpers: Joi.CustomHelpers) => {
  // Check for common passwords
  const commonPasswords = ['password', '12345678', 'qwerty'];
  if (commonPasswords.includes(value.toLowerCase())) {
    return helpers.error('password.common');
  }

  // Check for sequential characters
  if (/(.)\1{2,}/.test(value)) {
    return helpers.error('password.sequential');
  }

  return value;
};

export const securePasswordSchema = Joi.string()
  .min(8)
  .custom(validatePassword)
  .messages({
    'password.common': 'Password is too common',
    'password.sequential': 'Password cannot contain sequential characters'
  });

// Custom email domain validator
const validateEmailDomain = (value: string, helpers: Joi.CustomHelpers) => {
  const allowedDomains = ['company.com', 'partner.com'];
  const domain = value.split('@')[1];

  if (!allowedDomains.includes(domain)) {
    return helpers.error('email.domain');
  }

  return value;
};

export const corporateEmailSchema = Joi.string()
  .email()
  .custom(validateEmailDomain)
  .messages({
    'email.domain': 'Email must be from allowed domain'
  });
```

## Validation Middleware

### Request Validation Middleware

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
      const { error, value } = schemas.body.validate(req.body, {
        abortEarly: false, // Get all errors, not just first
        stripUnknown: true, // Remove unknown fields
        convert: true // Convert types (e.g., string to number)
      });

      if (error) {
        errors.body = error.details.map(detail => ({
          field: detail.path.join('.'),
          message: detail.message,
          type: detail.type
        }));
      } else {
        req.body = value; // Use validated & sanitized value
      }
    }

    // Validate params
    if (schemas.params) {
      const { error, value } = schemas.params.validate(req.params, {
        abortEarly: false
      });

      if (error) {
        errors.params = error.details.map(detail => ({
          field: detail.path.join('.'),
          message: detail.message,
          type: detail.type
        }));
      } else {
        req.params = value;
      }
    }

    // Validate query
    if (schemas.query) {
      const { error, value } = schemas.query.validate(req.query, {
        abortEarly: false,
        stripUnknown: true,
        convert: true
      });

      if (error) {
        errors.query = error.details.map(detail => ({
          field: detail.path.join('.'),
          message: detail.message,
          type: detail.type
        }));
      } else {
        req.query = value;
      }
    }

    // If there are errors, return 422
    if (Object.keys(errors).length > 0) {
      return next(new ValidationError('Validation failed', errors));
    }

    next();
  };
}
```

### Usage in Routes

```typescript
// routes/users.ts
import { Router } from 'express';
import { userController } from '../controllers/userController';
import { validateRequest } from '../middleware/validation';
import {
  createUserSchema,
  updateUserSchema,
  userIdSchema
} from '../schemas/userSchemas';

const router = Router();

router.post(
  '/',
  validateRequest({ body: createUserSchema }),
  userController.create
);

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

// Validate query parameters
const listQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  pageSize: Joi.number().integer().min(1).max(100).default(20),
  search: Joi.string().optional(),
  role: Joi.string().valid('user', 'admin').optional()
});

router.get(
  '/',
  validateRequest({ query: listQuerySchema }),
  userController.list
);

export default router;
```

## Service Layer Validation

### Business Rule Validation

```typescript
// services/userService.ts
import { BadRequestError, ConflictError } from '../errors/AppError';

export class UserService {
  async create(data: CreateUserDTO): Promise<UserDTO> {
    // Business rule: Email must be unique
    const existingUser = await userRepository.findByEmail(data.email);
    if (existingUser) {
      throw new ConflictError('Email already registered');
    }

    // Business rule: Age requirement
    if (data.age && data.age < 18) {
      throw new BadRequestError('User must be at least 18 years old');
    }

    // Business rule: Validate email domain
    const emailDomain = data.email.split('@')[1];
    if (this.isBlockedDomain(emailDomain)) {
      throw new BadRequestError('Email domain is not allowed');
    }

    return userRepository.create(data);
  }

  async updateEmail(userId: string, newEmail: string): Promise<void> {
    // Business rule: Can't change email more than once per month
    const user = await userRepository.findById(userId);
    if (user.lastEmailChange) {
      const daysSinceChange = Math.floor(
        (Date.now() - user.lastEmailChange.getTime()) / (1000 * 60 * 60 * 24)
      );

      if (daysSinceChange < 30) {
        throw new BadRequestError(
          `Email can only be changed once per month. ${30 - daysSinceChange} days remaining.`
        );
      }
    }

    await userRepository.update(userId, {
      email: newEmail,
      lastEmailChange: new Date()
    });
  }

  private isBlockedDomain(domain: string): boolean {
    const blockedDomains = ['tempmail.com', 'throwaway.email'];
    return blockedDomains.includes(domain);
  }
}
```

## Validation Utilities

### Reusable Validators

```typescript
// utils/validators.ts
import validator from 'validator';

export class Validators {
  static isValidEmail(email: string): boolean {
    return validator.isEmail(email);
  }

  static isValidURL(url: string): boolean {
    return validator.isURL(url, {
      require_protocol: true,
      protocols: ['http', 'https']
    });
  }

  static isValidPhoneNumber(phone: string): boolean {
    // E.164 format
    return /^\+?[1-9]\d{1,14}$/.test(phone);
  }

  static isValidCreditCard(cardNumber: string): boolean {
    return validator.isCreditCard(cardNumber);
  }

  static isValidUUID(uuid: string): boolean {
    return validator.isUUID(uuid);
  }

  static sanitizeHtml(html: string): string {
    // Remove potentially dangerous tags
    return validator.stripLow(html);
  }

  static isStrongPassword(password: string): boolean {
    return validator.isStrongPassword(password, {
      minLength: 8,
      minLowercase: 1,
      minUppercase: 1,
      minNumbers: 1,
      minSymbols: 1
    });
  }
}
```

### Custom Validation Functions

```typescript
// utils/businessValidators.ts
export class BusinessValidators {
  static isBusinessHours(): boolean {
    const now = new Date();
    const hour = now.getHours();
    const day = now.getDay();

    // Monday-Friday, 9am-5pm
    return day >= 1 && day <= 5 && hour >= 9 && hour < 17;
  }

  static isValidAge(birthDate: Date, minAge: number = 18): boolean {
    const today = new Date();
    const age = today.getFullYear() - birthDate.getFullYear();
    const monthDiff = today.getMonth() - birthDate.getMonth();

    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
      return age - 1 >= minAge;
    }

    return age >= minAge;
  }

  static isValidOrderAmount(amount: number, minAmount: number = 10): boolean {
    return amount >= minAmount && amount <= 10000;
  }

  static hasValidInventory(items: Array<{ quantity: number; stock: number }>): boolean {
    return items.every(item => item.quantity <= item.stock);
  }
}
```

## Database Validation

### Model Validators

```typescript
// models/User.ts
import { Model, DataTypes } from 'sequelize';
import { sequelize } from '../config/database';
import validator from 'validator';

export class User extends Model {
  public id!: string;
  public email!: string;
  public password!: string;
  // ...
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
        isEmail: {
          msg: 'Must be a valid email address'
        },
        notEmpty: {
          msg: 'Email cannot be empty'
        },
        // Custom validator
        isNotDisposable(value: string) {
          const disposableDomains = ['tempmail.com', 'throwaway.email'];
          const domain = value.split('@')[1];
          if (disposableDomains.includes(domain)) {
            throw new Error('Disposable email addresses are not allowed');
          }
        }
      }
    },
    password: {
      type: DataTypes.STRING(255),
      allowNull: false,
      validate: {
        notEmpty: true,
        len: {
          args: [8, 128],
          msg: 'Password must be between 8 and 128 characters'
        }
      }
    },
    age: {
      type: DataTypes.INTEGER,
      validate: {
        min: {
          args: [18],
          msg: 'User must be at least 18 years old'
        },
        max: {
          args: [120],
          msg: 'Age must be realistic'
        }
      }
    }
  },
  {
    sequelize,
    tableName: 'users',
    // Validate entire model
    validate: {
      // Custom model-level validator
      bothNamesOrNone() {
        if ((this.firstName && !this.lastName) || (!this.firstName && this.lastName)) {
          throw new Error('Both first name and last name are required');
        }
      }
    }
  }
);
```

## Sanitization

### Input Sanitization

```typescript
// utils/sanitize.ts
import validator from 'validator';

export class Sanitizer {
  static email(email: string): string {
    return validator.normalizeEmail(email) || email;
  }

  static trim(str: string): string {
    return validator.trim(str);
  }

  static stripHtml(str: string): string {
    return validator.stripLow(str);
  }

  static escape(str: string): string {
    return validator.escape(str);
  }

  static phoneNumber(phone: string): string {
    // Remove all non-digit characters
    return phone.replace(/\D/g, '');
  }

  static alphanumeric(str: string): string {
    return str.replace(/[^a-zA-Z0-9]/g, '');
  }
}

// Usage in service
export class UserService {
  async create(data: CreateUserDTO): Promise<UserDTO> {
    // Sanitize inputs
    const sanitizedData = {
      email: Sanitizer.email(data.email),
      firstName: Sanitizer.trim(data.firstName),
      lastName: Sanitizer.trim(data.lastName)
    };

    return userRepository.create(sanitizedData);
  }
}
```

## Best Practices

1. **Validate early** - At request layer before processing
2. **Clear error messages** - Help users fix issues
3. **Sanitize inputs** - Remove dangerous characters
4. **Validate at multiple layers** - Request, service, database
5. **Use schema validation** - Joi or similar library
6. **Don't trust client** - Always validate server-side
7. **Whitelist, not blacklist** - Define what's allowed
8. **Type coercion** - Convert strings to numbers, etc.
9. **Strip unknown fields** - Remove unexpected data
10. **Test validation** - Write tests for validation logic

## Common Pitfalls

1. **Client-side only validation** - Must validate server-side
2. **Vague error messages** - "Invalid input" not helpful
3. **No sanitization** - XSS and injection vulnerabilities
4. **Trusting user input** - Never trust client data
5. **Missing edge cases** - Test boundary conditions
6. **Inconsistent validation** - Same rules everywhere
7. **Not validating types** - String when expecting number
8. **Forgetting optional fields** - Use `.optional()` in Joi

## Summary

- Use Joi for request validation
- Validate at request, service, and database layers
- Provide clear, helpful error messages
- Sanitize all user inputs
- Use custom validators for business rules
- Test validation logic thoroughly
- Never trust client-side validation alone
- Use type coercion where appropriate
- Strip unknown fields from requests
- Document validation rules
