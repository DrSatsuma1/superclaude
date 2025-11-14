# Routing and Controllers

## Route Organization

### Directory Structure

```
routes/
├── index.ts          # Main router
├── auth.ts           # Authentication routes
├── users.ts          # User routes
├── posts.ts          # Post routes
└── admin/            # Admin-specific routes
    ├── index.ts
    └── users.ts
```

### Main Router

```typescript
// routes/index.ts
import { Router } from 'express';
import authRoutes from './auth';
import userRoutes from './users';
import postRoutes from './posts';
import adminRoutes from './admin';
import { authenticate } from '../middleware/auth';

const router = Router();

// Public routes
router.use('/auth', authRoutes);

// Protected routes
router.use('/users', authenticate, userRoutes);
router.use('/posts', authenticate, postRoutes);

// Admin routes
router.use('/admin', authenticate, adminRoutes);

// Health check
router.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

export default router;
```

## Route Patterns

### RESTful Routes

```typescript
// routes/users.ts
import { Router } from 'express';
import { userController } from '../controllers/userController';
import { validateRequest } from '../middleware/validation';
import { authorize } from '../middleware/authorize';
import {
  createUserSchema,
  updateUserSchema,
  userIdSchema
} from '../schemas/userSchemas';

const router = Router();

// Collection routes
router.get('/', userController.list);
router.post(
  '/',
  validateRequest({ body: createUserSchema }),
  userController.create
);

// Resource routes
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
  authorize('admin'),
  userController.delete
);

// Nested resources
router.get(
  '/:id/posts',
  validateRequest({ params: userIdSchema }),
  userController.getPosts
);

// Custom actions
router.post(
  '/:id/activate',
  validateRequest({ params: userIdSchema }),
  authorize('admin'),
  userController.activate
);

router.post(
  '/:id/reset-password',
  validateRequest({ params: userIdSchema }),
  userController.resetPassword
);

export default router;
```

### Route Naming Conventions

**RESTful Resources:**
- `GET /users` - List users
- `POST /users` - Create user
- `GET /users/:id` - Get user
- `PUT /users/:id` - Replace user (full update)
- `PATCH /users/:id` - Update user (partial update)
- `DELETE /users/:id` - Delete user

**Nested Resources:**
- `GET /users/:userId/posts` - List user's posts
- `POST /users/:userId/posts` - Create post for user
- `GET /users/:userId/posts/:id` - Get specific post

**Custom Actions:**
- `POST /users/:id/activate` - Activate user
- `POST /users/:id/deactivate` - Deactivate user
- `POST /orders/:id/cancel` - Cancel order
- `POST /invoices/:id/send` - Send invoice

## Controllers

### Basic Controller Structure

```typescript
// controllers/userController.ts
import { Request, Response, NextFunction } from 'express';
import { userService } from '../services/userService';
import logger from '../config/logger';

export class UserController {
  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await userService.create(req.body);

      logger.info('User created', {
        userId: user.id,
        email: user.email
      });

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
      const filters = {
        search: req.query.search as string,
        role: req.query.role as string,
        page: parseInt(req.query.page as string) || 1,
        pageSize: parseInt(req.query.pageSize as string) || 20
      };

      const result = await userService.list(filters);

      res.json({
        success: true,
        data: result.users,
        pagination: {
          page: filters.page,
          pageSize: filters.pageSize,
          total: result.total,
          totalPages: result.totalPages
        }
      });
    } catch (error) {
      next(error);
    }
  }

  async update(req: Request, res: Response, next: NextFunction) {
    try {
      const user = await userService.update(req.params.id, req.body);

      logger.info('User updated', {
        userId: user.id,
        changes: Object.keys(req.body)
      });

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

      logger.info('User deleted', {
        userId: req.params.id,
        deletedBy: req.user?.id
      });

      res.status(204).send();
    } catch (error) {
      next(error);
    }
  }
}

export const userController = new UserController();
```

### Controller Best Practices

**1. Keep Controllers Thin:**
```typescript
// ❌ Bad - Business logic in controller
async create(req: Request, res: Response, next: NextFunction) {
  try {
    const existing = await User.findOne({ where: { email: req.body.email } });
    if (existing) {
      return res.status(409).json({ error: 'Email exists' });
    }

    const hashedPassword = await bcrypt.hash(req.body.password, 10);
    const user = await User.create({ ...req.body, password: hashedPassword });

    await sendWelcomeEmail(user.email);

    res.status(201).json({ data: user });
  } catch (error) {
    next(error);
  }
}

// ✅ Good - Delegate to service
async create(req: Request, res: Response, next: NextFunction) {
  try {
    const user = await userService.create(req.body);
    res.status(201).json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
}
```

**2. Use Consistent Response Format:**
```typescript
// Success response
{
  "success": true,
  "data": { /* ... */ }
}

// List response with pagination
{
  "success": true,
  "data": [ /* ... */ ],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "total": 100,
    "totalPages": 5
  }
}

// Error response
{
  "success": false,
  "error": "Error message"
}

// Validation error response
{
  "success": false,
  "error": "Validation failed",
  "errors": {
    "email": ["Email is required", "Email must be valid"],
    "password": ["Password must be at least 8 characters"]
  }
}
```

**3. Use Proper HTTP Status Codes:**
```typescript
// 200 - OK (successful GET, PUT, PATCH)
res.status(200).json({ data: user });

// 201 - Created (successful POST)
res.status(201).json({ data: user });

// 204 - No Content (successful DELETE)
res.status(204).send();

// 400 - Bad Request (invalid input)
throw new BadRequestError('Invalid data');

// 401 - Unauthorized (not authenticated)
throw new UnauthorizedError('Token required');

// 403 - Forbidden (not authorized)
throw new ForbiddenError('Insufficient permissions');

// 404 - Not Found (resource doesn't exist)
throw new NotFoundError('User not found');

// 409 - Conflict (duplicate, race condition)
throw new ConflictError('Email already exists');

// 422 - Unprocessable Entity (validation failed)
throw new ValidationError('Validation failed', errors);

// 500 - Internal Server Error (unexpected error)
throw new InternalError('Something went wrong');
```

**4. Always Handle Async Errors:**
```typescript
// ❌ Bad - Unhandled promise rejection
async badController(req: Request, res: Response) {
  const user = await userService.getById(req.params.id); // Can throw!
  res.json({ data: user });
}

// ✅ Good - Errors passed to error handler
async goodController(req: Request, res: Response, next: NextFunction) {
  try {
    const user = await userService.getById(req.params.id);
    res.json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
}

// ✅ Also Good - Using async handler wrapper
import { asyncHandler } from '../middleware/errorHandler';

const controller = asyncHandler(async (req, res) => {
  const user = await userService.getById(req.params.id);
  res.json({ success: true, data: user });
});
```

## Request Data Extraction

### Query Parameters

```typescript
// GET /users?search=john&role=admin&page=2&pageSize=20

async list(req: Request, res: Response, next: NextFunction) {
  try {
    const filters = {
      search: req.query.search as string,
      role: req.query.role as string,
      page: parseInt(req.query.page as string) || 1,
      pageSize: Math.min(parseInt(req.query.pageSize as string) || 20, 100)
    };

    const result = await userService.list(filters);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
}
```

### Route Parameters

```typescript
// GET /users/:id/posts/:postId

async getPost(req: Request, res: Response, next: NextFunction) {
  try {
    const { id: userId, postId } = req.params;
    const post = await postService.getUserPost(userId, postId);
    res.json({ success: true, data: post });
  } catch (error) {
    next(error);
  }
}
```

### Request Body

```typescript
// POST /users
// Body: { "email": "user@example.com", "password": "secret" }

async create(req: Request, res: Response, next: NextFunction) {
  try {
    const user = await userService.create(req.body);
    res.status(201).json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
}
```

### Headers

```typescript
async download(req: Request, res: Response, next: NextFunction) {
  try {
    const acceptLanguage = req.headers['accept-language'] || 'en';
    const userAgent = req.get('user-agent');

    const file = await fileService.generate(req.params.id, {
      language: acceptLanguage
    });

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="${file.name}"`);
    res.send(file.buffer);
  } catch (error) {
    next(error);
  }
}
```

### Authenticated User

```typescript
async getCurrentUser(req: Request, res: Response, next: NextFunction) {
  try {
    // req.user is set by authentication middleware
    const user = await userService.getById(req.user!.id);
    res.json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
}

async createPost(req: Request, res: Response, next: NextFunction) {
  try {
    const post = await postService.create({
      ...req.body,
      authorId: req.user!.id // Use authenticated user's ID
    });
    res.status(201).json({ success: true, data: post });
  } catch (error) {
    next(error);
  }
}
```

## File Uploads

### Using Multer

```typescript
// middleware/upload.ts
import multer from 'multer';
import path from 'path';
import { BadRequestError } from '../errors/AppError';

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, 'uploads/');
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req: any, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];

  if (!allowedTypes.includes(file.mimetype)) {
    return cb(new BadRequestError('Invalid file type. Only JPEG, PNG and GIF allowed'));
  }

  cb(null, true);
};

export const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB
  }
});
```

### Single File Upload

```typescript
// routes/users.ts
import { upload } from '../middleware/upload';

router.post(
  '/:id/avatar',
  upload.single('avatar'),
  userController.uploadAvatar
);

// controllers/userController.ts
async uploadAvatar(req: Request, res: Response, next: NextFunction) {
  try {
    if (!req.file) {
      throw new BadRequestError('No file uploaded');
    }

    const avatarUrl = await userService.updateAvatar(
      req.params.id,
      req.file.path
    );

    res.json({
      success: true,
      data: { avatarUrl }
    });
  } catch (error) {
    next(error);
  }
}
```

### Multiple File Upload

```typescript
// routes/posts.ts
router.post(
  '/:id/images',
  upload.array('images', 10), // Max 10 images
  postController.uploadImages
);

// controllers/postController.ts
async uploadImages(req: Request, res: Response, next: NextFunction) {
  try {
    if (!req.files || req.files.length === 0) {
      throw new BadRequestError('No files uploaded');
    }

    const files = req.files as Express.Multer.File[];
    const imageUrls = await postService.addImages(
      req.params.id,
      files.map(f => f.path)
    );

    res.json({
      success: true,
      data: { imageUrls }
    });
  } catch (error) {
    next(error);
  }
}
```

## API Versioning

### URL Versioning

```typescript
// app.ts
import v1Routes from './routes/v1';
import v2Routes from './routes/v2';

app.use('/api/v1', v1Routes);
app.use('/api/v2', v2Routes);
```

### Header Versioning

```typescript
// middleware/apiVersion.ts
export function apiVersion(req: Request, res: Response, next: NextFunction) {
  const version = req.headers['api-version'] || '1';
  req.apiVersion = version;
  next();
}

// Use different logic based on version
async getUsers(req: Request, res: Response, next: NextFunction) {
  try {
    if (req.apiVersion === '2') {
      return this.getUsersV2(req, res, next);
    }
    return this.getUsersV1(req, res, next);
  } catch (error) {
    next(error);
  }
}
```

## Response Helpers

### Create Reusable Response Helpers

```typescript
// utils/response.ts
import { Response } from 'express';

export class ResponseHelper {
  static success(res: Response, data: any, statusCode = 200) {
    return res.status(statusCode).json({
      success: true,
      data
    });
  }

  static created(res: Response, data: any) {
    return this.success(res, data, 201);
  }

  static noContent(res: Response) {
    return res.status(204).send();
  }

  static paginated(
    res: Response,
    data: any[],
    pagination: {
      page: number;
      pageSize: number;
      total: number;
      totalPages: number;
    }
  ) {
    return res.json({
      success: true,
      data,
      pagination
    });
  }
}

// Usage in controller
async create(req: Request, res: Response, next: NextFunction) {
  try {
    const user = await userService.create(req.body);
    return ResponseHelper.created(res, user);
  } catch (error) {
    next(error);
  }
}
```

## Best Practices

1. **RESTful conventions** - Follow REST principles for resource routes
2. **Thin controllers** - Delegate business logic to services
3. **Consistent responses** - Use standard response format
4. **Proper status codes** - Use appropriate HTTP status codes
5. **Error handling** - Always wrap async code in try-catch
6. **Validation** - Validate input before passing to service
7. **Type safety** - Use TypeScript for request/response types
8. **Documentation** - Document routes with OpenAPI/Swagger
9. **Versioning** - Version your API for backward compatibility
10. **Logging** - Log important operations

## Common Pitfalls

1. **Business logic in controllers** - Controllers should orchestrate, not implement
2. **Inconsistent responses** - Different formats confuse clients
3. **Wrong status codes** - 200 for all responses is wrong
4. **No error handling** - Unhandled promise rejections
5. **Deep nesting** - Keep route nesting shallow (max 2 levels)
6. **Too many custom routes** - Prefer RESTful conventions
7. **No validation** - Trusting client input
8. **Exposing sensitive data** - Return DTOs, not raw models

## Summary

- Organize routes by resource
- Follow RESTful conventions
- Keep controllers thin - delegate to services
- Use consistent response formats
- Apply proper HTTP status codes
- Always handle async errors
- Validate all inputs
- Implement file uploads properly
- Version your API
- Document all endpoints
