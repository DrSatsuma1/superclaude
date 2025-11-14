# TypeScript Standards

Best practices and patterns for writing type-safe React applications with TypeScript.

## Table of Contents

- [Component Types](#component-types)
- [Props Interfaces](#props-interfaces)
- [Hooks Types](#hooks-types)
- [Event Handlers](#event-handlers)
- [Generic Components](#generic-components)
- [API Types](#api-types)
- [Utility Types](#utility-types)

## Component Types

### Function Components

```typescript
// Basic function component
interface GreetingProps {
  name: string;
  age?: number;
}

export function Greeting({ name, age }: GreetingProps) {
  return (
    <div>
      Hello, {name}! {age && `You are ${age} years old.`}
    </div>
  );
}

// With React.FC (includes children by default)
export const Greeting: React.FC<GreetingProps> = ({ name, age }) => {
  return (
    <div>
      Hello, {name}! {age && `You are ${age} years old.`}
    </div>
  );
};

// Explicit children type (preferred)
interface CardProps {
  title: string;
  children: React.ReactNode;
}

export function Card({ title, children }: CardProps) {
  return (
    <div>
      <h2>{title}</h2>
      <div>{children}</div>
    </div>
  );
}
```

### Return Types

```typescript
// Explicit return type (optional but recommended for complex components)
function UserCard({ user }: { user: User }): JSX.Element {
  return (
    <div>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
}

// Conditional rendering with proper types
function Message({ type }: { type: 'error' | 'success' }): JSX.Element | null {
  if (type === 'error') {
    return <div className="error">Error message</div>;
  }

  if (type === 'success') {
    return <div className="success">Success message</div>;
  }

  return null;
}

// Array of elements
function List({ items }: { items: string[] }): JSX.Element[] {
  return items.map((item, index) => <li key={index}>{item}</li>);
}
```

## Props Interfaces

### Extending HTML Attributes

```typescript
import { ButtonHTMLAttributes, InputHTMLAttributes, HTMLAttributes } from 'react';

// Button extending native button props
interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary';
  loading?: boolean;
}

export function Button({ variant = 'primary', loading, children, ...props }: ButtonProps) {
  return (
    <button {...props} disabled={loading || props.disabled}>
      {loading ? 'Loading...' : children}
    </button>
  );
}

// Input extending native input props
interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export function Input({ label, error, ...props }: InputProps) {
  return (
    <div>
      {label && <label>{label}</label>}
      <input {...props} />
      {error && <span className="error">{error}</span>}
    </div>
  );
}

// Generic div with custom props
interface ContainerProps extends HTMLAttributes<HTMLDivElement> {
  maxWidth?: string;
}

export function Container({ maxWidth, children, style, ...props }: ContainerProps) {
  return (
    <div {...props} style={{ ...style, maxWidth }}>
      {children}
    </div>
  );
}
```

### Discriminated Unions

```typescript
// Button with different behaviors based on variant
type ButtonProps =
  | {
      variant: 'link';
      href: string;
      onClick?: never;
    }
  | {
      variant?: 'primary' | 'secondary';
      href?: never;
      onClick?: () => void;
    };

export function Button({ variant, href, onClick, children }: ButtonProps) {
  if (variant === 'link' && href) {
    return <a href={href}>{children}</a>;
  }

  return <button onClick={onClick}>{children}</button>;
}

// Usage
<Button variant="link" href="/about">About</Button>
<Button variant="primary" onClick={() => console.log('clicked')}>Click</Button>
// TypeScript error: Cannot use href with primary variant
// <Button variant="primary" href="/about">Invalid</Button>
```

### Optional vs Required Props

```typescript
// Make some props required
interface UserFormProps {
  initialData?: Partial<User>;
  onSubmit: (data: User) => void; // Required
  onCancel?: () => void; // Optional
}

// Require at least one prop
type NotificationProps = {
  message: string;
} & (
  | { type: 'success'; icon?: never }
  | { type: 'error'; icon: string }
);

// Using Required utility type
interface Config {
  apiUrl?: string;
  timeout?: number;
  retries?: number;
}

// Make all properties required
type RequiredConfig = Required<Config>;

// Make specific properties required
type PartiallyRequiredConfig = Config & Required<Pick<Config, 'apiUrl'>>;
```

## Hooks Types

### useState

```typescript
// Inferred type
const [count, setCount] = useState(0); // number
const [name, setName] = useState(''); // string

// Explicit type
const [user, setUser] = useState<User | null>(null);

// With initial complex value
interface FormData {
  name: string;
  email: string;
  age: number;
}

const [formData, setFormData] = useState<FormData>({
  name: '',
  email: '',
  age: 0,
});

// Array state
const [items, setItems] = useState<string[]>([]);
const [users, setUsers] = useState<User[]>([]);

// Union types
type Status = 'idle' | 'loading' | 'success' | 'error';
const [status, setStatus] = useState<Status>('idle');
```

### useRef

```typescript
// DOM element refs
const inputRef = useRef<HTMLInputElement>(null);
const divRef = useRef<HTMLDivElement>(null);

// Usage
useEffect(() => {
  inputRef.current?.focus();
}, []);

// Mutable value ref
const countRef = useRef<number>(0);
const timerRef = useRef<NodeJS.Timeout | null>(null);

// Usage
useEffect(() => {
  timerRef.current = setInterval(() => {
    countRef.current += 1;
  }, 1000);

  return () => {
    if (timerRef.current) {
      clearInterval(timerRef.current);
    }
  };
}, []);
```

### useReducer

```typescript
// State type
interface State {
  count: number;
  loading: boolean;
  error: string | null;
}

// Action types
type Action =
  | { type: 'INCREMENT' }
  | { type: 'DECREMENT' }
  | { type: 'SET_LOADING'; payload: boolean }
  | { type: 'SET_ERROR'; payload: string };

// Reducer function
function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'INCREMENT':
      return { ...state, count: state.count + 1 };
    case 'DECREMENT':
      return { ...state, count: state.count - 1 };
    case 'SET_LOADING':
      return { ...state, loading: action.payload };
    case 'SET_ERROR':
      return { ...state, error: action.payload };
    default:
      return state;
  }
}

// Usage
function Counter() {
  const [state, dispatch] = useReducer(reducer, {
    count: 0,
    loading: false,
    error: null,
  });

  return (
    <div>
      <p>Count: {state.count}</p>
      <button onClick={() => dispatch({ type: 'INCREMENT' })}>+</button>
      <button onClick={() => dispatch({ type: 'DECREMENT' })}>-</button>
    </div>
  );
}
```

### Custom Hooks

```typescript
// Return type inferred
function useCounter(initialValue = 0) {
  const [count, setCount] = useState(initialValue);

  const increment = () => setCount(c => c + 1);
  const decrement = () => setCount(c => c - 1);
  const reset = () => setCount(initialValue);

  return { count, increment, decrement, reset };
}

// Explicit return type
interface UseCounterReturn {
  count: number;
  increment: () => void;
  decrement: () => void;
  reset: () => void;
}

function useCounter(initialValue = 0): UseCounterReturn {
  // Implementation
}

// Generic hook
function useLocalStorage<T>(key: string, initialValue: T) {
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      return initialValue;
    }
  });

  const setValue = (value: T | ((val: T) => T)) => {
    try {
      const valueToStore = value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);
      window.localStorage.setItem(key, JSON.stringify(valueToStore));
    } catch (error) {
      console.error(error);
    }
  };

  return [storedValue, setValue] as const;
}

// Usage
const [user, setUser] = useLocalStorage<User>('user', {
  name: '',
  email: '',
});
```

## Event Handlers

### Common Events

```typescript
// Mouse events
const handleClick = (event: React.MouseEvent<HTMLButtonElement>) => {
  console.log('Clicked at', event.clientX, event.clientY);
};

const handleDivClick = (event: React.MouseEvent<HTMLDivElement>) => {
  event.preventDefault();
};

// Form events
const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
  event.preventDefault();
  const formData = new FormData(event.currentTarget);
};

// Input events
const handleChange = (event: React.ChangeEvent<HTMLInputElement>) => {
  console.log(event.target.value);
};

const handleTextAreaChange = (event: React.ChangeEvent<HTMLTextAreaElement>) => {
  console.log(event.target.value);
};

const handleSelectChange = (event: React.ChangeEvent<HTMLSelectElement>) => {
  console.log(event.target.value);
};

// Keyboard events
const handleKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
  if (event.key === 'Enter') {
    console.log('Enter pressed');
  }
};

// Focus events
const handleFocus = (event: React.FocusEvent<HTMLInputElement>) => {
  console.log('Input focused');
};
```

### Generic Event Handlers

```typescript
// Reusable event handler type
type ChangeEvent = React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>;

const handleChange = (event: ChangeEvent) => {
  console.log(event.target.value);
};

// Generic handler function
function createChangeHandler<T extends HTMLElement>(
  callback: (value: string) => void
) {
  return (event: React.ChangeEvent<T>) => {
    callback(event.currentTarget.value);
  };
}

// Usage
const handleNameChange = createChangeHandler<HTMLInputElement>(value => {
  console.log('Name:', value);
});
```

## Generic Components

### Generic List Component

```typescript
interface ListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  keyExtractor: (item: T, index: number) => string | number;
  emptyMessage?: string;
}

export function List<T>({
  items,
  renderItem,
  keyExtractor,
  emptyMessage = 'No items',
}: ListProps<T>) {
  if (items.length === 0) {
    return <div>{emptyMessage}</div>;
  }

  return (
    <ul>
      {items.map((item, index) => (
        <li key={keyExtractor(item, index)}>{renderItem(item, index)}</li>
      ))}
    </ul>
  );
}

// Usage
interface User {
  id: string;
  name: string;
}

function UserList({ users }: { users: User[] }) {
  return (
    <List
      items={users}
      renderItem={user => <span>{user.name}</span>}
      keyExtractor={user => user.id}
    />
  );
}
```

### Generic Form Field

```typescript
interface FieldProps<T> {
  value: T;
  onChange: (value: T) => void;
  label?: string;
  error?: string;
}

export function TextField({
  value,
  onChange,
  label,
  error,
}: FieldProps<string>) {
  return (
    <div>
      {label && <label>{label}</label>}
      <input
        type="text"
        value={value}
        onChange={e => onChange(e.target.value)}
      />
      {error && <span className="error">{error}</span>}
    </div>
  );
}

export function NumberField({
  value,
  onChange,
  label,
  error,
}: FieldProps<number>) {
  return (
    <div>
      {label && <label>{label}</label>}
      <input
        type="number"
        value={value}
        onChange={e => onChange(Number(e.target.value))}
      />
      {error && <span className="error">{error}</span>}
    </div>
  );
}
```

## API Types

### Request/Response Types

```typescript
// API response wrapper
interface ApiResponse<T> {
  data: T;
  status: number;
  message?: string;
}

// Paginated response
interface PaginatedResponse<T> {
  items: T[];
  page: number;
  pageSize: number;
  total: number;
  hasMore: boolean;
}

// Error response
interface ApiError {
  message: string;
  code: string;
  details?: Record<string, string[]>;
}

// Typed API client
class ApiClient {
  async get<T>(url: string): Promise<ApiResponse<T>> {
    const response = await fetch(url);
    return response.json();
  }

  async post<T, D = unknown>(url: string, data: D): Promise<ApiResponse<T>> {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    return response.json();
  }
}

// Usage
interface User {
  id: string;
  name: string;
  email: string;
}

interface CreateUserDto {
  name: string;
  email: string;
}

const api = new ApiClient();

async function fetchUser(id: string) {
  const response = await api.get<User>(`/api/users/${id}`);
  return response.data;
}

async function createUser(data: CreateUserDto) {
  const response = await api.post<User, CreateUserDto>('/api/users', data);
  return response.data;
}
```

### Type Guards

```typescript
// Type predicate
function isUser(obj: unknown): obj is User {
  return (
    typeof obj === 'object' &&
    obj !== null &&
    'id' in obj &&
    'name' in obj &&
    'email' in obj
  );
}

// Usage
async function fetchData(url: string) {
  const response = await fetch(url);
  const data = await response.json();

  if (isUser(data)) {
    // TypeScript knows data is User here
    console.log(data.name);
  }
}

// Discriminated union type guard
type Shape =
  | { kind: 'circle'; radius: number }
  | { kind: 'rectangle'; width: number; height: number };

function isCircle(shape: Shape): shape is Extract<Shape, { kind: 'circle' }> {
  return shape.kind === 'circle';
}

function getArea(shape: Shape): number {
  if (isCircle(shape)) {
    return Math.PI * shape.radius ** 2;
  }
  return shape.width * shape.height;
}
```

## Utility Types

### Common Utility Types

```typescript
interface User {
  id: string;
  name: string;
  email: string;
  age: number;
  role: 'admin' | 'user';
}

// Partial - Make all properties optional
type PartialUser = Partial<User>;
// { id?: string; name?: string; email?: string; age?: number; role?: 'admin' | 'user' }

// Required - Make all properties required
type RequiredUser = Required<Partial<User>>;

// Pick - Select specific properties
type UserBasicInfo = Pick<User, 'id' | 'name' | 'email'>;
// { id: string; name: string; email: string }

// Omit - Exclude specific properties
type UserWithoutId = Omit<User, 'id'>;
// { name: string; email: string; age: number; role: 'admin' | 'user' }

// Record - Create object type with specific keys
type UserRoles = Record<'admin' | 'user' | 'guest', string[]>;
// { admin: string[]; user: string[]; guest: string[] }

// Readonly - Make all properties readonly
type ImmutableUser = Readonly<User>;

// ReturnType - Extract return type of function
function getUser() {
  return { id: '1', name: 'John', email: 'john@example.com' };
}
type UserType = ReturnType<typeof getUser>;

// Parameters - Extract parameters type
function updateUser(id: string, data: Partial<User>) {
  // ...
}
type UpdateUserParams = Parameters<typeof updateUser>;
// [id: string, data: Partial<User>]
```

### Custom Utility Types

```typescript
// Make specific properties optional
type PartialBy<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;

type UserWithOptionalEmail = PartialBy<User, 'email'>;
// { id: string; name: string; email?: string; age: number; role: 'admin' | 'user' }

// Make specific properties required
type RequiredBy<T, K extends keyof T> = T & Required<Pick<T, K>>;

// Deep partial
type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends object ? DeepPartial<T[P]> : T[P];
};

// Nullable
type Nullable<T> = T | null;

// Maybe (nullable or undefined)
type Maybe<T> = T | null | undefined;

// NonNullable fields
type NonNullableFields<T> = {
  [P in keyof T]: NonNullable<T[P]>;
};
```

## Best Practices

1. **Prefer interfaces over types** for object shapes
2. **Use discriminated unions** for variant props
3. **Leverage utility types** to avoid duplication
4. **Type event handlers** explicitly
5. **Use generics** for reusable components
6. **Define strict types** for API responses
7. **Avoid `any`** - use `unknown` if type is truly unknown
8. **Use const assertions** for literal types
9. **Export types** alongside components
10. **Document complex types** with JSDoc comments

```typescript
/**
 * User object representing an authenticated user in the system
 * @property id - Unique identifier
 * @property name - Full display name
 * @property email - Contact email address
 * @property role - User's permission level
 */
interface User {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'user';
}
```
