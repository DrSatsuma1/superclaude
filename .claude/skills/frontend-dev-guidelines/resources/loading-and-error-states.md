# Loading and Error States

Best practices for handling loading states, errors, and edge cases in React applications.

## Table of Contents

- [Loading States](#loading-states)
- [Error Handling](#error-handling)
- [Error Boundaries](#error-boundaries)
- [Empty States](#empty-states)
- [Skeleton Screens](#skeleton-screens)
- [Retry Logic](#retry-logic)

## Loading States

### Basic Loading Pattern

```typescript
function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    async function fetchUser() {
      try {
        setLoading(true);
        setError(null);
        const data = await fetchUserData(userId);
        setUser(data);
      } catch (err) {
        setError(err instanceof Error ? err : new Error('Unknown error'));
      } finally {
        setLoading(false);
      }
    }

    fetchUser();
  }, [userId]);

  if (loading) {
    return <LoadingSpinner />;
  }

  if (error) {
    return <ErrorMessage error={error} />;
  }

  if (!user) {
    return <NotFound />;
  }

  return <UserProfileView user={user} />;
}
```

### Progressive Loading

```typescript
function Dashboard() {
  const { data: user, loading: userLoading } = useUser();
  const { data: stats, loading: statsLoading } = useStats();
  const { data: notifications, loading: notificationsLoading } = useNotifications();

  return (
    <div className="dashboard">
      <header>
        {userLoading ? (
          <UserHeaderSkeleton />
        ) : (
          <UserHeader user={user} />
        )}
      </header>

      <main>
        {statsLoading ? (
          <StatsSkeleton />
        ) : (
          <StatsCards stats={stats} />
        )}

        {notificationsLoading ? (
          <NotificationsSkeleton />
        ) : (
          <NotificationsList notifications={notifications} />
        )}
      </main>
    </div>
  );
}
```

### Loading with Minimum Duration

```typescript
function useMinimumLoadingTime<T>(
  promise: Promise<T>,
  minimumMs: number = 500
): {
  data: T | null;
  loading: boolean;
  error: Error | null;
} {
  const [state, setState] = useState<{
    data: T | null;
    loading: boolean;
    error: Error | null;
  }>({
    data: null,
    loading: true,
    error: null,
  });

  useEffect(() => {
    let cancelled = false;
    const startTime = Date.now();

    Promise.all([
      promise,
      new Promise(resolve => setTimeout(resolve, minimumMs)),
    ])
      .then(([data]) => {
        if (!cancelled) {
          setState({ data: data as T, loading: false, error: null });
        }
      })
      .catch(error => {
        if (!cancelled) {
          setState({ data: null, loading: false, error });
        }
      });

    return () => {
      cancelled = true;
    };
  }, [promise, minimumMs]);

  return state;
}

// Usage
function DataComponent() {
  const { data, loading, error } = useMinimumLoadingTime(
    fetch('/api/data').then(r => r.json()),
    500 // Show spinner for at least 500ms to avoid flash
  );

  // ...
}
```

## Error Handling

### Error Display Component

```typescript
interface ErrorMessageProps {
  error: Error;
  onRetry?: () => void;
  title?: string;
}

export function ErrorMessage({
  error,
  onRetry,
  title = 'Something went wrong',
}: ErrorMessageProps) {
  return (
    <div className="error-message" role="alert">
      <div className="error-icon">⚠️</div>
      <h3>{title}</h3>
      <p>{error.message}</p>
      {onRetry && (
        <button onClick={onRetry} className="retry-button">
          Try Again
        </button>
      )}
    </div>
  );
}
```

### Typed Error Handling

```typescript
// Define custom error types
class NetworkError extends Error {
  constructor(message: string, public statusCode: number) {
    super(message);
    this.name = 'NetworkError';
  }
}

class ValidationError extends Error {
  constructor(message: string, public fields: Record<string, string>) {
    super(message);
    this.name = 'ValidationError';
  }
}

// Error display component
function ErrorDisplay({ error }: { error: Error }) {
  if (error instanceof NetworkError) {
    if (error.statusCode === 404) {
      return <NotFoundError />;
    }
    if (error.statusCode === 401) {
      return <UnauthorizedError />;
    }
    return <NetworkErrorDisplay error={error} />;
  }

  if (error instanceof ValidationError) {
    return <ValidationErrorDisplay error={error} />;
  }

  return <GenericError error={error} />;
}
```

### Form Error Handling

```typescript
interface FormErrors {
  [key: string]: string;
}

function RegistrationForm() {
  const [errors, setErrors] = useState<FormErrors>({});
  const [submitError, setSubmitError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setErrors({});
    setSubmitError(null);
    setSubmitting(true);

    try {
      const formData = new FormData(e.currentTarget);
      const response = await fetch('/api/register', {
        method: 'POST',
        body: formData,
      });

      if (!response.ok) {
        const error = await response.json();

        if (error.fields) {
          // Field-level validation errors
          setErrors(error.fields);
        } else {
          // General submission error
          setSubmitError(error.message || 'Registration failed');
        }
        return;
      }

      // Success
      window.location.href = '/dashboard';
    } catch (error) {
      setSubmitError('Network error. Please try again.');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      {submitError && (
        <div className="form-error" role="alert">
          {submitError}
        </div>
      )}

      <div className="form-field">
        <label htmlFor="email">Email</label>
        <input
          id="email"
          name="email"
          type="email"
          aria-invalid={!!errors.email}
          aria-describedby={errors.email ? 'email-error' : undefined}
        />
        {errors.email && (
          <span id="email-error" className="field-error">
            {errors.email}
          </span>
        )}
      </div>

      <button type="submit" disabled={submitting}>
        {submitting ? 'Registering...' : 'Register'}
      </button>
    </form>
  );
}
```

## Error Boundaries

### Basic Error Boundary

```typescript
import { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
    // Send to error reporting service
    reportError(error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <div className="error-boundary">
          <h2>Something went wrong</h2>
          <p>{this.state.error?.message}</p>
          <button onClick={() => this.setState({ hasError: false, error: null })}>
            Try again
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}

// Usage
function App() {
  return (
    <ErrorBoundary fallback={<ErrorPage />}>
      <Dashboard />
    </ErrorBoundary>
  );
}
```

### Error Boundary with Reset

```typescript
import { ErrorBoundary as ReactErrorBoundary } from 'react-error-boundary';

function ErrorFallback({
  error,
  resetErrorBoundary,
}: {
  error: Error;
  resetErrorBoundary: () => void;
}) {
  return (
    <div role="alert">
      <h2>Oops! Something went wrong</h2>
      <pre>{error.message}</pre>
      <button onClick={resetErrorBoundary}>Try again</button>
    </div>
  );
}

function App() {
  return (
    <ReactErrorBoundary
      FallbackComponent={ErrorFallback}
      onReset={() => {
        // Reset app state here
        window.location.href = '/';
      }}
      onError={(error, errorInfo) => {
        // Log to error reporting service
        console.error('Error:', error, errorInfo);
      }}
    >
      <Dashboard />
    </ReactErrorBoundary>
  );
}
```

### Per-Feature Error Boundaries

```typescript
function App() {
  return (
    <div className="app">
      <header>
        <Navigation />
      </header>

      <main>
        <ErrorBoundary fallback={<div>Failed to load sidebar</div>}>
          <Sidebar />
        </ErrorBoundary>

        <ErrorBoundary fallback={<div>Failed to load content</div>}>
          <MainContent />
        </ErrorBoundary>
      </main>
    </div>
  );
}
```

## Empty States

### List Empty State

```typescript
interface ListProps<T> {
  items: T[];
  renderItem: (item: T) => ReactNode;
  emptyState?: ReactNode;
  loading?: boolean;
}

function List<T extends { id: string }>({
  items,
  renderItem,
  emptyState,
  loading,
}: ListProps<T>) {
  if (loading) {
    return <ListSkeleton />;
  }

  if (items.length === 0) {
    return (
      <div className="empty-state">
        {emptyState || <DefaultEmptyState />}
      </div>
    );
  }

  return (
    <ul>
      {items.map(item => (
        <li key={item.id}>{renderItem(item)}</li>
      ))}
    </ul>
  );
}

// Usage
function TodoList() {
  const { todos, loading } = useTodos();

  return (
    <List
      items={todos}
      loading={loading}
      renderItem={todo => <TodoItem todo={todo} />}
      emptyState={
        <div>
          <h3>No todos yet</h3>
          <p>Create your first todo to get started!</p>
          <button>Create Todo</button>
        </div>
      }
    />
  );
}
```

### Search Empty State

```typescript
function SearchResults({ query }: { query: string }) {
  const { results, loading, error } = useSearch(query);

  if (loading) return <SearchSkeleton />;
  if (error) return <ErrorMessage error={error} />;

  if (!query) {
    return (
      <div className="empty-state">
        <p>Enter a search term to find results</p>
      </div>
    );
  }

  if (results.length === 0) {
    return (
      <div className="empty-state">
        <h3>No results found for "{query}"</h3>
        <p>Try a different search term</p>
      </div>
    );
  }

  return (
    <ul>
      {results.map(result => (
        <SearchResultItem key={result.id} result={result} />
      ))}
    </ul>
  );
}
```

## Skeleton Screens

### Component Skeleton

```typescript
// UserCardSkeleton.tsx
export function UserCardSkeleton() {
  return (
    <div className="user-card skeleton" aria-busy="true" aria-live="polite">
      <div className="skeleton-avatar" />
      <div className="skeleton-content">
        <div className="skeleton-line skeleton-line-title" />
        <div className="skeleton-line skeleton-line-subtitle" />
      </div>
    </div>
  );
}

// UserCardSkeleton.css
.skeleton {
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

.skeleton-line {
  height: 1rem;
  background: linear-gradient(
    90deg,
    #f0f0f0 25%,
    #e0e0e0 50%,
    #f0f0f0 75%
  );
  background-size: 200% 100%;
  animation: shimmer 2s infinite;
  border-radius: 4px;
}

@keyframes shimmer {
  0% {
    background-position: -200% 0;
  }
  100% {
    background-position: 200% 0;
  }
}
```

### Generic Skeleton Component

```typescript
interface SkeletonProps {
  width?: string | number;
  height?: string | number;
  variant?: 'text' | 'circular' | 'rectangular';
  className?: string;
}

export function Skeleton({
  width,
  height,
  variant = 'text',
  className = '',
}: SkeletonProps) {
  const style = {
    width: typeof width === 'number' ? `${width}px` : width,
    height: typeof height === 'number' ? `${height}px` : height,
  };

  return (
    <div
      className={`skeleton skeleton-${variant} ${className}`}
      style={style}
      aria-busy="true"
    />
  );
}

// Usage
function UserProfileSkeleton() {
  return (
    <div className="user-profile">
      <Skeleton variant="circular" width={80} height={80} />
      <div className="user-info">
        <Skeleton width="60%" height={24} />
        <Skeleton width="40%" height={20} />
        <Skeleton width="80%" height={16} />
      </div>
    </div>
  );
}
```

## Retry Logic

### Automatic Retry

```typescript
async function fetchWithRetry<T>(
  fetcher: () => Promise<T>,
  options: {
    maxRetries?: number;
    delay?: number;
    backoff?: boolean;
  } = {}
): Promise<T> {
  const { maxRetries = 3, delay = 1000, backoff = true } = options;

  let lastError: Error;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fetcher();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error('Unknown error');

      if (attempt < maxRetries - 1) {
        const waitTime = backoff ? delay * Math.pow(2, attempt) : delay;
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }

  throw lastError!;
}

// Usage
function DataComponent() {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetchWithRetry(() => fetch('/api/data').then(r => r.json()), {
      maxRetries: 3,
      delay: 1000,
      backoff: true,
    })
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, []);

  // ...
}
```

### Manual Retry

```typescript
function useRetryableQuery<T>(fetcher: () => Promise<T>) {
  const [state, setState] = useState<{
    data: T | null;
    loading: boolean;
    error: Error | null;
    retryCount: number;
  }>({
    data: null,
    loading: true,
    error: null,
    retryCount: 0,
  });

  const execute = useCallback(async () => {
    setState(prev => ({ ...prev, loading: true, error: null }));

    try {
      const data = await fetcher();
      setState({ data, loading: false, error: null, retryCount: 0 });
    } catch (error) {
      setState(prev => ({
        data: null,
        loading: false,
        error: error instanceof Error ? error : new Error('Unknown error'),
        retryCount: prev.retryCount + 1,
      }));
    }
  }, [fetcher]);

  useEffect(() => {
    execute();
  }, [execute]);

  return {
    ...state,
    retry: execute,
  };
}

// Usage
function DataComponent() {
  const { data, loading, error, retryCount, retry } = useRetryableQuery(() =>
    fetch('/api/data').then(r => r.json())
  );

  if (loading) return <LoadingSpinner />;

  if (error) {
    return (
      <div>
        <p>Error: {error.message}</p>
        <p>Retry attempts: {retryCount}</p>
        <button onClick={retry}>Retry</button>
      </div>
    );
  }

  return <DataView data={data} />;
}
```

## Best Practices

1. **Always handle all states**: loading, error, empty, success
2. **Provide meaningful error messages**: Help users understand what went wrong
3. **Allow retry**: Give users a way to recover from errors
4. **Use skeleton screens**: Better UX than spinners for content-heavy pages
5. **Minimize loading time**: Show partial content as it loads
6. **Accessible errors**: Use ARIA attributes for screen readers
7. **Log errors**: Send errors to monitoring service
8. **Graceful degradation**: App should work even if some parts fail
9. **Clear empty states**: Guide users on what to do next
10. **Test error scenarios**: Don't just test the happy path
