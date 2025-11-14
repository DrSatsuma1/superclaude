# File Organization

Best practices for organizing files and folders in React applications.

## Table of Contents

- [Project Structure](#project-structure)
- [Naming Conventions](#naming-conventions)
- [Component Organization](#component-organization)
- [Feature-Based Structure](#feature-based-structure)
- [Shared Code](#shared-code)
- [Import Organization](#import-organization)

## Project Structure

### Standard React Project

```
src/
├── assets/                 # Static assets (images, fonts, etc.)
│   ├── images/
│   ├── fonts/
│   └── icons/
├── components/            # Shared/reusable components
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   ├── Button.module.css
│   │   └── index.ts
│   ├── Input/
│   └── Card/
├── features/              # Feature-based modules
│   ├── auth/
│   │   ├── components/
│   │   ├── hooks/
│   │   ├── services/
│   │   ├── types/
│   │   └── index.ts
│   ├── dashboard/
│   └── profile/
├── hooks/                 # Shared custom hooks
│   ├── useAuth.ts
│   ├── useLocalStorage.ts
│   └── useDebounce.ts
├── layouts/               # Layout components
│   ├── MainLayout.tsx
│   ├── AuthLayout.tsx
│   └── DashboardLayout.tsx
├── lib/                   # Third-party library configs
│   ├── api.ts
│   ├── queryClient.ts
│   └── router.ts
├── pages/                 # Page/route components
│   ├── HomePage.tsx
│   ├── LoginPage.tsx
│   └── DashboardPage.tsx
├── services/              # API and external services
│   ├── api/
│   │   ├── users.ts
│   │   ├── posts.ts
│   │   └── index.ts
│   └── analytics.ts
├── store/                 # Global state management
│   ├── slices/
│   ├── hooks.ts
│   └── index.ts
├── styles/                # Global styles
│   ├── globals.css
│   ├── variables.css
│   └── reset.css
├── types/                 # Shared TypeScript types
│   ├── user.ts
│   ├── api.ts
│   └── index.ts
├── utils/                 # Utility functions
│   ├── format.ts
│   ├── validation.ts
│   └── helpers.ts
├── App.tsx               # Root component
├── main.tsx              # Entry point
└── vite-env.d.ts         # Type definitions
```

### Next.js App Router Structure

```
src/
├── app/                   # App router pages
│   ├── (auth)/           # Route groups
│   │   ├── login/
│   │   └── register/
│   ├── (dashboard)/
│   │   ├── layout.tsx
│   │   ├── page.tsx
│   │   └── settings/
│   ├── api/              # API routes
│   │   └── users/
│   ├── layout.tsx        # Root layout
│   └── page.tsx          # Home page
├── components/           # Shared components
├── features/             # Feature modules
├── lib/                  # Utilities and configs
└── types/                # TypeScript types
```

## Naming Conventions

### Files and Folders

```
# Components: PascalCase
Button.tsx
UserProfile.tsx
NavigationMenu.tsx

# Hooks: camelCase with 'use' prefix
useAuth.ts
useLocalStorage.ts
useDebounce.ts

# Utilities: camelCase
formatDate.ts
validateEmail.ts
parseQueryString.ts

# Types: camelCase or PascalCase
user.ts or User.ts
api.ts or API.ts

# Constants: UPPER_SNAKE_CASE or camelCase
API_ENDPOINTS.ts
config.ts

# Tests: Match source file with .test or .spec
Button.test.tsx
useAuth.test.ts
formatDate.spec.ts

# Styles: Match component name
Button.module.css
Button.styles.ts
```

### Import/Export Patterns

```typescript
// index.ts - Barrel exports
export { Button } from './Button';
export { Input } from './Input';
export { Card } from './Card';
export type { ButtonProps } from './Button';
export type { InputProps } from './Input';

// Named exports (preferred)
export function Button() { }
export const config = { };
export type ButtonProps = { };

// Default exports (use sparingly)
export default function HomePage() { }  // Pages/routes only
```

## Component Organization

### Single Component File

```typescript
// Button.tsx
import { ButtonHTMLAttributes } from 'react';
import styles from './Button.module.css';

// Types defined in same file for simple components
export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary';
  size?: 'small' | 'medium' | 'large';
}

// Component
export function Button({
  variant = 'primary',
  size = 'medium',
  className = '',
  ...props
}: ButtonProps) {
  return (
    <button
      className={`${styles.button} ${styles[variant]} ${styles[size]} ${className}`}
      {...props}
    />
  );
}
```

### Complex Component Folder

```
Button/
├── Button.tsx              # Main component
├── Button.test.tsx         # Tests
├── Button.module.css       # Styles
├── Button.types.ts         # Complex types
├── ButtonGroup.tsx         # Related component
├── useButtonState.ts       # Component-specific hook
├── constants.ts            # Component constants
└── index.ts                # Exports

// index.ts
export { Button } from './Button';
export { ButtonGroup } from './ButtonGroup';
export type { ButtonProps } from './Button.types';
```

### Compound Components

```
Tabs/
├── Tabs.tsx                # Main container
├── Tab.tsx                 # Individual tab
├── TabList.tsx             # Tab list container
├── TabPanel.tsx            # Tab panel
├── TabContext.tsx          # Shared context
├── Tabs.types.ts           # All types
├── Tabs.test.tsx           # Tests
└── index.ts                # Exports

// index.ts
export { Tabs } from './Tabs';
export { Tab } from './Tab';
export { TabList } from './TabList';
export { TabPanel } from './TabPanel';
export type { TabsProps, TabProps } from './Tabs.types';
```

## Feature-Based Structure

### Feature Module

```
features/
└── auth/
    ├── components/         # Feature-specific components
    │   ├── LoginForm/
    │   ├── RegisterForm/
    │   └── PasswordReset/
    ├── hooks/             # Feature hooks
    │   ├── useAuth.ts
    │   ├── useLogin.ts
    │   └── useRegister.ts
    ├── services/          # API calls
    │   ├── authApi.ts
    │   └── tokenStorage.ts
    ├── store/             # Feature state
    │   ├── authSlice.ts
    │   └── authSelectors.ts
    ├── types/             # Feature types
    │   ├── user.ts
    │   └── auth.ts
    ├── utils/             # Feature utilities
    │   └── validation.ts
    ├── constants.ts       # Feature constants
    └── index.ts           # Public API

// index.ts - Only export what's needed outside the feature
export { LoginForm, RegisterForm } from './components';
export { useAuth } from './hooks';
export type { User, AuthState } from './types';
```

### Feature Boundaries

```typescript
// Good: Features export clear public API
// features/auth/index.ts
export { useAuth } from './hooks/useAuth';
export { LoginForm } from './components/LoginForm';
export type { User } from './types/user';

// Usage in other features
import { useAuth, type User } from '@/features/auth';

// Bad: Importing from feature internals
import { useAuth } from '@/features/auth/hooks/useAuth';  // Don't do this
```

## Shared Code

### Shared Components

```
components/
├── ui/                    # Basic UI components
│   ├── Button/
│   ├── Input/
│   ├── Card/
│   └── Modal/
├── forms/                 # Form components
│   ├── FormField/
│   ├── FormError/
│   └── FormLabel/
├── layout/               # Layout components
│   ├── Container/
│   ├── Grid/
│   └── Stack/
└── feedback/             # Feedback components
    ├── Alert/
    ├── Toast/
    └── Spinner/
```

### Shared Utilities

```
utils/
├── format/               # Formatting utilities
│   ├── date.ts
│   ├── currency.ts
│   └── number.ts
├── validation/           # Validation functions
│   ├── email.ts
│   ├── password.ts
│   └── url.ts
├── dom/                  # DOM utilities
│   ├── classNames.ts
│   └── scrollTo.ts
└── string/               # String utilities
    ├── truncate.ts
    └── slugify.ts
```

### Shared Types

```typescript
// types/index.ts - Central type exports
export type * from './api';
export type * from './common';
export type * from './models';

// types/api.ts
export interface ApiResponse<T> {
  data: T;
  status: number;
  message?: string;
}

export interface ApiError {
  message: string;
  code: string;
  details?: Record<string, any>;
}

// types/common.ts
export type ID = string | number;

export interface Timestamps {
  createdAt: string;
  updatedAt: string;
}

export interface Pagination {
  page: number;
  pageSize: number;
  total: number;
}

// types/models/user.ts
import { ID, Timestamps } from '../common';

export interface User extends Timestamps {
  id: ID;
  name: string;
  email: string;
  role: 'admin' | 'user';
}
```

## Import Organization

### Import Order

```typescript
// 1. External dependencies
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';

// 2. Internal absolute imports (aliased)
import { Button } from '@/components/ui/Button';
import { useAuth } from '@/hooks/useAuth';
import { formatDate } from '@/utils/format';

// 3. Relative imports (same feature/module)
import { UserCard } from './UserCard';
import { useUserData } from './hooks';
import type { UserProfileProps } from './types';

// 4. Styles
import styles from './UserProfile.module.css';

// 5. Types (if not inline)
import type { User } from '@/types';
```

### Path Aliases

```typescript
// tsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"],
      "@/components/*": ["./src/components/*"],
      "@/features/*": ["./src/features/*"],
      "@/hooks/*": ["./src/hooks/*"],
      "@/utils/*": ["./src/utils/*"],
      "@/types/*": ["./src/types/*"]
    }
  }
}

// vite.config.ts
import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});

// Usage
import { Button } from '@/components/ui/Button';
import { useAuth } from '@/hooks/useAuth';
import type { User } from '@/types';
```

### Barrel Exports

```typescript
// components/ui/index.ts
export { Button } from './Button';
export { Input } from './Input';
export { Card } from './Card';
export { Modal } from './Modal';

// Export types
export type { ButtonProps } from './Button';
export type { InputProps } from './Input';

// Usage - single import for multiple components
import { Button, Input, Card, type ButtonProps } from '@/components/ui';

// Note: Be cautious with barrel exports in large apps
// They can impact tree-shaking and bundle size
```

## Configuration Files

### Project Root

```
project/
├── .env                    # Environment variables
├── .env.example            # Example env file
├── .eslintrc.cjs          # ESLint config
├── .prettierrc            # Prettier config
├── .gitignore             # Git ignore
├── tsconfig.json          # TypeScript config
├── tsconfig.node.json     # Node TypeScript config
├── vite.config.ts         # Vite config
├── package.json           # Dependencies
└── README.md              # Documentation
```

## Best Practices

1. **Colocation**: Keep related files close together
2. **Flat Structure**: Avoid deeply nested folders (max 3-4 levels)
3. **Feature Folders**: Group by feature when the app grows
4. **Barrel Exports**: Use index.ts to expose public API
5. **Path Aliases**: Use absolute imports with aliases
6. **Consistent Naming**: Follow naming conventions strictly
7. **Single Responsibility**: One component/utility per file
8. **Type Safety**: Colocate types with their usage
9. **Documentation**: README.md in complex feature folders
10. **Test Proximity**: Keep tests next to source files

## Anti-Patterns to Avoid

```
# Bad: Too deeply nested
src/components/forms/inputs/text/variants/primary/Primary.tsx

# Good: Flatter structure
src/components/forms/TextInput/PrimaryTextInput.tsx

# Bad: Mixing concerns
src/stuff/things/code.ts

# Good: Clear organization
src/features/auth/services/authApi.ts

# Bad: Generic names
src/utils/helpers.ts
src/components/Component.tsx

# Good: Descriptive names
src/utils/validation/emailValidator.ts
src/components/UserProfileCard.tsx
```

## Scaling Strategies

### Small Project (< 10 components)
```
src/
├── components/
├── hooks/
├── utils/
└── App.tsx
```

### Medium Project (10-50 components)
```
src/
├── components/
├── features/
├── hooks/
├── pages/
├── services/
└── utils/
```

### Large Project (50+ components)
```
src/
├── features/          # Feature-based modules
├── components/        # Only truly shared components
├── lib/              # Third-party configs
└── shared/           # Shared utilities, hooks, types
```

The key is to start simple and refactor as the project grows. Don't over-engineer the structure from the beginning.
