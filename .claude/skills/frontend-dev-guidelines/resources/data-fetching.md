# Data Fetching

Patterns and best practices for fetching, caching, and managing remote data in React applications.

## Table of Contents

- [Basic Fetch Patterns](#basic-fetch-patterns)
- [Custom Hooks](#custom-hooks)
- [Query Libraries](#query-libraries)
- [Caching Strategies](#caching-strategies)
- [Error Handling](#error-handling)
- [Optimistic Updates](#optimistic-updates)
- [Pagination and Infinite Scroll](#pagination-and-infinite-scroll)

## Basic Fetch Patterns

### Simple Data Fetching

```typescript
interface User {
  id: string;
  name: string;
  email: string;
}

function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchUser() {
      try {
        setLoading(true);
        setError(null);

        const response = await fetch(`/api/users/${userId}`);
        if (!response.ok) {
          throw new Error('Failed to fetch user');
        }

        const data = await response.json();

        if (!cancelled) {
          setUser(data);
        }
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof Error ? err : new Error('Unknown error'));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    fetchUser();

    return () => {
      cancelled = true;
    };
  }, [userId]);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (!user) return <div>User not found</div>;

  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  );
}
```

### AbortController for Cancellation

```typescript
function SearchResults({ query }: { query: string }) {
  const [results, setResults] = useState<Result[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const controller = new AbortController();

    async function search() {
      if (!query) {
        setResults([]);
        return;
      }

      setLoading(true);

      try {
        const response = await fetch(`/api/search?q=${query}`, {
          signal: controller.signal,
        });

        const data = await response.json();
        setResults(data);
      } catch (err) {
        if (err.name !== 'AbortError') {
          console.error('Search failed:', err);
        }
      } finally {
        setLoading(false);
      }
    }

    search();

    return () => {
      controller.abort();
    };
  }, [query]);

  return (
    <div>
      {loading && <div>Searching...</div>}
      {results.map(result => (
        <div key={result.id}>{result.title}</div>
      ))}
    </div>
  );
}
```

## Custom Hooks

### Generic Fetch Hook

```typescript
interface FetchState<T> {
  data: T | null;
  loading: boolean;
  error: Error | null;
}

interface UseFetchOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE';
  body?: any;
  headers?: Record<string, string>;
}

function useFetch<T>(url: string, options: UseFetchOptions = {}): FetchState<T> & {
  refetch: () => void;
} {
  const [state, setState] = useState<FetchState<T>>({
    data: null,
    loading: true,
    error: null,
  });

  const fetchData = useCallback(async () => {
    setState(prev => ({ ...prev, loading: true, error: null }));

    try {
      const response = await fetch(url, {
        method: options.method || 'GET',
        headers: {
          'Content-Type': 'application/json',
          ...options.headers,
        },
        body: options.body ? JSON.stringify(options.body) : undefined,
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      setState({ data, loading: false, error: null });
    } catch (error) {
      setState({
        data: null,
        loading: false,
        error: error instanceof Error ? error : new Error('Unknown error'),
      });
    }
  }, [url, options.method, options.body, options.headers]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return { ...state, refetch: fetchData };
}

// Usage
function UserList() {
  const { data: users, loading, error, refetch } = useFetch<User[]>('/api/users');

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;

  return (
    <div>
      <button onClick={refetch}>Refresh</button>
      {users?.map(user => (
        <div key={user.id}>{user.name}</div>
      ))}
    </div>
  );
}
```

### Mutation Hook

```typescript
interface UseMutationResult<TData, TVariables> {
  mutate: (variables: TVariables) => Promise<TData>;
  data: TData | null;
  loading: boolean;
  error: Error | null;
  reset: () => void;
}

function useMutation<TData = any, TVariables = any>(
  mutationFn: (variables: TVariables) => Promise<TData>
): UseMutationResult<TData, TVariables> {
  const [state, setState] = useState<{
    data: TData | null;
    loading: boolean;
    error: Error | null;
  }>({
    data: null,
    loading: false,
    error: null,
  });

  const mutate = useCallback(
    async (variables: TVariables) => {
      setState({ data: null, loading: true, error: null });

      try {
        const data = await mutationFn(variables);
        setState({ data, loading: false, error: null });
        return data;
      } catch (error) {
        const err = error instanceof Error ? error : new Error('Unknown error');
        setState({ data: null, loading: false, error: err });
        throw err;
      }
    },
    [mutationFn]
  );

  const reset = useCallback(() => {
    setState({ data: null, loading: false, error: null });
  }, []);

  return { mutate, ...state, reset };
}

// Usage
interface CreateUserVariables {
  name: string;
  email: string;
}

function CreateUserForm() {
  const { mutate, loading, error } = useMutation<User, CreateUserVariables>(
    async (variables) => {
      const response = await fetch('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(variables),
      });
      return response.json();
    }
  );

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);

    try {
      await mutate({
        name: formData.get('name') as string,
        email: formData.get('email') as string,
      });
      alert('User created!');
    } catch (error) {
      // Error is already in state
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      <input name="name" required />
      <input name="email" type="email" required />
      <button type="submit" disabled={loading}>
        {loading ? 'Creating...' : 'Create User'}
      </button>
      {error && <div className="error">{error.message}</div>}
    </form>
  );
}
```

## Query Libraries

### React Query Pattern

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

// Fetch function
async function fetchUser(userId: string): Promise<User> {
  const response = await fetch(`/api/users/${userId}`);
  if (!response.ok) throw new Error('Failed to fetch user');
  return response.json();
}

// Query hook
function useUser(userId: string) {
  return useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
    staleTime: 5 * 60 * 1000, // 5 minutes
    gcTime: 10 * 60 * 1000, // 10 minutes
  });
}

// Mutation hook
function useUpdateUser() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ userId, data }: { userId: string; data: Partial<User> }) => {
      const response = await fetch(`/api/users/${userId}`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });
      return response.json();
    },
    onSuccess: (data, variables) => {
      // Invalidate and refetch
      queryClient.invalidateQueries({ queryKey: ['user', variables.userId] });
      // Or update cache directly
      queryClient.setQueryData(['user', variables.userId], data);
    },
  });
}

// Component using the hooks
function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = useUser(userId);
  const updateUser = useUpdateUser();

  if (isLoading) return <div>Loading...</div>;
  if (error) return <div>Error: {error.message}</div>;
  if (!user) return <div>User not found</div>;

  const handleUpdate = async () => {
    await updateUser.mutateAsync({
      userId,
      data: { name: 'New Name' },
    });
  };

  return (
    <div>
      <h1>{user.name}</h1>
      <button onClick={handleUpdate} disabled={updateUser.isPending}>
        Update Name
      </button>
    </div>
  );
}
```

### Prefetching Data

```typescript
function UserListWithPrefetch() {
  const queryClient = useQueryClient();
  const { data: users } = useQuery({
    queryKey: ['users'],
    queryFn: fetchUsers,
  });

  const handleMouseEnter = (userId: string) => {
    // Prefetch user details on hover
    queryClient.prefetchQuery({
      queryKey: ['user', userId],
      queryFn: () => fetchUser(userId),
      staleTime: 5 * 60 * 1000,
    });
  };

  return (
    <div>
      {users?.map(user => (
        <Link
          key={user.id}
          to={`/users/${user.id}`}
          onMouseEnter={() => handleMouseEnter(user.id)}
        >
          {user.name}
        </Link>
      ))}
    </div>
  );
}
```

## Caching Strategies

### Memory Cache

```typescript
class DataCache<T> {
  private cache = new Map<string, { data: T; timestamp: number }>();
  private maxAge: number;

  constructor(maxAge: number = 5 * 60 * 1000) {
    this.maxAge = maxAge;
  }

  set(key: string, data: T): void {
    this.cache.set(key, { data, timestamp: Date.now() });
  }

  get(key: string): T | null {
    const entry = this.cache.get(key);
    if (!entry) return null;

    const age = Date.now() - entry.timestamp;
    if (age > this.maxAge) {
      this.cache.delete(key);
      return null;
    }

    return entry.data;
  }

  clear(): void {
    this.cache.clear();
  }
}

// Usage
const userCache = new DataCache<User>(5 * 60 * 1000);

function useCachedUser(userId: string) {
  const [user, setUser] = useState<User | null>(() => userCache.get(userId));
  const [loading, setLoading] = useState(!user);

  useEffect(() => {
    const cached = userCache.get(userId);
    if (cached) {
      setUser(cached);
      setLoading(false);
      return;
    }

    fetchUser(userId).then(data => {
      userCache.set(userId, data);
      setUser(data);
      setLoading(false);
    });
  }, [userId]);

  return { user, loading };
}
```

### SWR Pattern (Stale-While-Revalidate)

```typescript
function useSWR<T>(key: string, fetcher: () => Promise<T>) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [isValidating, setIsValidating] = useState(false);

  const revalidate = useCallback(async () => {
    setIsValidating(true);
    try {
      const newData = await fetcher();
      setData(newData);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Unknown error'));
    } finally {
      setIsValidating(false);
    }
  }, [fetcher]);

  useEffect(() => {
    revalidate();

    // Revalidate on window focus
    const handleFocus = () => revalidate();
    window.addEventListener('focus', handleFocus);

    return () => window.removeEventListener('focus', handleFocus);
  }, [revalidate]);

  return {
    data,
    error,
    isValidating,
    mutate: revalidate,
  };
}
```

## Error Handling

### Retry Logic

```typescript
async function fetchWithRetry<T>(
  url: string,
  options: RequestInit = {},
  maxRetries = 3
): Promise<T> {
  let lastError: Error;

  for (let i = 0; i < maxRetries; i++) {
    try {
      const response = await fetch(url, options);

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      return await response.json();
    } catch (error) {
      lastError = error instanceof Error ? error : new Error('Unknown error');

      // Don't retry on 4xx errors
      if (error instanceof Error && error.message.startsWith('HTTP 4')) {
        throw error;
      }

      // Wait before retrying (exponential backoff)
      if (i < maxRetries - 1) {
        await new Promise(resolve => setTimeout(resolve, Math.pow(2, i) * 1000));
      }
    }
  }

  throw lastError!;
}
```

### Error Boundaries for Data Fetching

```typescript
import { ErrorBoundary } from 'react-error-boundary';

function ErrorFallback({ error, resetErrorBoundary }: {
  error: Error;
  resetErrorBoundary: () => void;
}) {
  return (
    <div role="alert">
      <p>Something went wrong:</p>
      <pre>{error.message}</pre>
      <button onClick={resetErrorBoundary}>Try again</button>
    </div>
  );
}

function App() {
  return (
    <ErrorBoundary
      FallbackComponent={ErrorFallback}
      onReset={() => {
        // Reset app state
      }}
    >
      <DataComponent />
    </ErrorBoundary>
  );
}
```

## Optimistic Updates

```typescript
function useTodoMutation() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (newTodo: Todo) => {
      const response = await fetch('/api/todos', {
        method: 'POST',
        body: JSON.stringify(newTodo),
      });
      return response.json();
    },
    onMutate: async (newTodo) => {
      // Cancel outgoing refetches
      await queryClient.cancelQueries({ queryKey: ['todos'] });

      // Snapshot previous value
      const previousTodos = queryClient.getQueryData(['todos']);

      // Optimistically update
      queryClient.setQueryData<Todo[]>(['todos'], (old) => [
        ...(old || []),
        { ...newTodo, id: 'temp-' + Date.now() },
      ]);

      return { previousTodos };
    },
    onError: (err, newTodo, context) => {
      // Rollback on error
      queryClient.setQueryData(['todos'], context?.previousTodos);
    },
    onSettled: () => {
      // Always refetch after error or success
      queryClient.invalidateQueries({ queryKey: ['todos'] });
    },
  });
}
```

## Pagination and Infinite Scroll

### Cursor-based Pagination

```typescript
interface PageParam {
  cursor?: string;
  limit: number;
}

function useInfiniteUsers() {
  return useInfiniteQuery({
    queryKey: ['users', 'infinite'],
    queryFn: async ({ pageParam = { limit: 20 } }) => {
      const response = await fetch(
        `/api/users?limit=${pageParam.limit}${
          pageParam.cursor ? `&cursor=${pageParam.cursor}` : ''
        }`
      );
      return response.json();
    },
    getNextPageParam: (lastPage) => {
      if (!lastPage.nextCursor) return undefined;
      return { cursor: lastPage.nextCursor, limit: 20 };
    },
    initialPageParam: { limit: 20 },
  });
}

// Component
function InfiniteUserList() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
  } = useInfiniteUsers();

  return (
    <div>
      {data?.pages.map((page, i) => (
        <div key={i}>
          {page.users.map((user: User) => (
            <div key={user.id}>{user.name}</div>
          ))}
        </div>
      ))}

      {hasNextPage && (
        <button onClick={() => fetchNextPage()} disabled={isFetchingNextPage}>
          {isFetchingNextPage ? 'Loading...' : 'Load More'}
        </button>
      )}
    </div>
  );
}
```

## Best Practices

1. **Always handle loading and error states**
2. **Cancel requests when components unmount**
3. **Use proper TypeScript types for API responses**
4. **Implement retry logic for transient failures**
5. **Cache data appropriately to reduce network requests**
6. **Use optimistic updates for better UX**
7. **Debounce search queries to avoid excessive requests**
8. **Implement proper error boundaries**
9. **Consider using a data fetching library like React Query or SWR**
10. **Test data fetching logic separately from components**
