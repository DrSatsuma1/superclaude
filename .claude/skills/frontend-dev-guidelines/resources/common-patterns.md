# Common React Patterns

Common patterns and best practices for React development.

## Table of Contents

- [Hooks Patterns](#hooks-patterns)
- [Component Composition](#component-composition)
- [Render Props](#render-props)
- [Higher-Order Components](#higher-order-components)
- [Context Patterns](#context-patterns)
- [Custom Hooks](#custom-hooks)
- [Memoization Patterns](#memoization-patterns)

## Hooks Patterns

### useState with Function Updates

```typescript
// Good: Use function updates for state based on previous state
const [count, setCount] = useState(0);

const increment = () => {
  setCount(prev => prev + 1);
};

// Bad: Direct state updates can cause race conditions
const increment = () => {
  setCount(count + 1);
};
```

### useEffect Dependencies

```typescript
// Good: Include all dependencies
useEffect(() => {
  fetchUser(userId);
}, [userId]);

// Good: Use function from context or props
useEffect(() => {
  onDataLoad(data);
}, [data, onDataLoad]);

// Bad: Missing dependencies
useEffect(() => {
  fetchUser(userId);
}, []); // userId should be in dependencies
```

### Lazy Initial State

```typescript
// Good: Use function for expensive initial state
const [state, setState] = useState(() => {
  const initialState = expensiveComputation();
  return initialState;
});

// Bad: Expensive computation runs on every render
const [state, setState] = useState(expensiveComputation());
```

## Component Composition

### Compound Components

```typescript
interface TabsContextValue {
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

const TabsContext = createContext<TabsContextValue | null>(null);

function Tabs({ children, defaultTab }: { children: React.ReactNode; defaultTab: string }) {
  const [activeTab, setActiveTab] = useState(defaultTab);

  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div className="tabs">{children}</div>
    </TabsContext.Provider>
  );
}

function TabList({ children }: { children: React.ReactNode }) {
  return <div className="tab-list">{children}</div>;
}

function Tab({ id, children }: { id: string; children: React.ReactNode }) {
  const context = useContext(TabsContext);
  if (!context) throw new Error('Tab must be used within Tabs');

  const { activeTab, setActiveTab } = context;

  return (
    <button
      className={activeTab === id ? 'active' : ''}
      onClick={() => setActiveTab(id)}
    >
      {children}
    </button>
  );
}

function TabPanel({ id, children }: { id: string; children: React.ReactNode }) {
  const context = useContext(TabsContext);
  if (!context) throw new Error('TabPanel must be used within Tabs');

  const { activeTab } = context;

  if (activeTab !== id) return null;

  return <div className="tab-panel">{children}</div>;
}

// Usage
<Tabs defaultTab="overview">
  <TabList>
    <Tab id="overview">Overview</Tab>
    <Tab id="details">Details</Tab>
  </TabList>
  <TabPanel id="overview">Overview content</TabPanel>
  <TabPanel id="details">Details content</TabPanel>
</Tabs>
```

### Render Props Pattern

```typescript
interface MousePosition {
  x: number;
  y: number;
}

interface MouseTrackerProps {
  render: (position: MousePosition) => React.ReactNode;
}

function MouseTracker({ render }: MouseTrackerProps) {
  const [position, setPosition] = useState<MousePosition>({ x: 0, y: 0 });

  useEffect(() => {
    const handleMouseMove = (e: MouseEvent) => {
      setPosition({ x: e.clientX, y: e.clientY });
    };

    window.addEventListener('mousemove', handleMouseMove);
    return () => window.removeEventListener('mousemove', handleMouseMove);
  }, []);

  return <>{render(position)}</>;
}

// Usage
<MouseTracker
  render={({ x, y }) => (
    <div>Mouse position: {x}, {y}</div>
  )}
/>
```

### Children as Function

```typescript
interface DataLoaderProps<T> {
  url: string;
  children: (data: T | null, loading: boolean, error: Error | null) => React.ReactNode;
}

function DataLoader<T>({ url, children }: DataLoaderProps<T>) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    fetch(url)
      .then(res => res.json())
      .then(setData)
      .catch(setError)
      .finally(() => setLoading(false));
  }, [url]);

  return <>{children(data, loading, error)}</>;
}

// Usage
<DataLoader<User> url="/api/user">
  {(user, loading, error) => {
    if (loading) return <Spinner />;
    if (error) return <Error message={error.message} />;
    if (!user) return null;
    return <UserProfile user={user} />;
  }}
</DataLoader>
```

## Higher-Order Components

```typescript
// Modern approach: Prefer hooks over HOCs
function withAuth<P extends object>(Component: React.ComponentType<P>) {
  return function AuthenticatedComponent(props: P) {
    const { user, loading } = useAuth();

    if (loading) return <Spinner />;
    if (!user) return <Navigate to="/login" />;

    return <Component {...props} />;
  };
}

// Usage
const ProtectedPage = withAuth(DashboardPage);
```

## Context Patterns

### Typed Context with Custom Hook

```typescript
interface AuthContextValue {
  user: User | null;
  login: (credentials: Credentials) => Promise<void>;
  logout: () => Promise<void>;
  loading: boolean;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check for existing session
    checkSession().then(setUser).finally(() => setLoading(false));
  }, []);

  const login = async (credentials: Credentials) => {
    const user = await loginAPI(credentials);
    setUser(user);
  };

  const logout = async () => {
    await logoutAPI();
    setUser(null);
  };

  const value = { user, login, logout, loading };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}
```

### Context Splitting

```typescript
// Split frequently changing values from static ones
const UserStateContext = createContext<User | null>(null);
const UserActionsContext = createContext<{
  updateUser: (user: User) => void;
  logout: () => void;
} | null>(null);

export function UserProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);

  // Actions don't change, preventing unnecessary rerenders
  const actions = useMemo(() => ({
    updateUser: setUser,
    logout: () => setUser(null),
  }), []);

  return (
    <UserStateContext.Provider value={user}>
      <UserActionsContext.Provider value={actions}>
        {children}
      </UserActionsContext.Provider>
    </UserStateContext.Provider>
  );
}

export const useUser = () => useContext(UserStateContext);
export const useUserActions = () => {
  const context = useContext(UserActionsContext);
  if (!context) throw new Error('useUserActions must be used within UserProvider');
  return context;
};
```

## Custom Hooks

### Data Fetching Hook

```typescript
interface UseQueryOptions {
  enabled?: boolean;
  refetchInterval?: number;
}

interface UseQueryResult<T> {
  data: T | null;
  loading: boolean;
  error: Error | null;
  refetch: () => void;
}

function useQuery<T>(url: string, options: UseQueryOptions = {}): UseQueryResult<T> {
  const { enabled = true, refetchInterval } = options;
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<Error | null>(null);

  const fetchData = useCallback(async () => {
    if (!enabled) return;

    setLoading(true);
    setError(null);

    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to fetch');
      const result = await response.json();
      setData(result);
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Unknown error'));
    } finally {
      setLoading(false);
    }
  }, [url, enabled]);

  useEffect(() => {
    fetchData();

    if (refetchInterval) {
      const interval = setInterval(fetchData, refetchInterval);
      return () => clearInterval(interval);
    }
  }, [fetchData, refetchInterval]);

  return { data, loading, error, refetch: fetchData };
}
```

### Local Storage Hook

```typescript
function useLocalStorage<T>(key: string, initialValue: T) {
  const [storedValue, setStoredValue] = useState<T>(() => {
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.error(error);
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
```

### Debounced Value Hook

```typescript
function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const handler = setTimeout(() => {
      setDebouncedValue(value);
    }, delay);

    return () => {
      clearTimeout(handler);
    };
  }, [value, delay]);

  return debouncedValue;
}

// Usage
function SearchComponent() {
  const [searchTerm, setSearchTerm] = useState('');
  const debouncedSearchTerm = useDebounce(searchTerm, 500);

  useEffect(() => {
    if (debouncedSearchTerm) {
      searchAPI(debouncedSearchTerm);
    }
  }, [debouncedSearchTerm]);

  return <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)} />;
}
```

## Memoization Patterns

### useMemo for Expensive Calculations

```typescript
function DataTable({ data, filterText }: { data: Item[]; filterText: string }) {
  const filteredData = useMemo(() => {
    return data.filter(item =>
      item.name.toLowerCase().includes(filterText.toLowerCase())
    );
  }, [data, filterText]);

  return (
    <table>
      {filteredData.map(item => (
        <tr key={item.id}>
          <td>{item.name}</td>
        </tr>
      ))}
    </table>
  );
}
```

### useCallback for Event Handlers

```typescript
function TodoList({ todos }: { todos: Todo[] }) {
  const [selectedId, setSelectedId] = useState<string | null>(null);

  // Memoize callback to prevent child rerenders
  const handleSelect = useCallback((id: string) => {
    setSelectedId(id);
  }, []);

  return (
    <ul>
      {todos.map(todo => (
        <TodoItem
          key={todo.id}
          todo={todo}
          onSelect={handleSelect}
          selected={todo.id === selectedId}
        />
      ))}
    </ul>
  );
}

const TodoItem = memo(function TodoItem({
  todo,
  onSelect,
  selected
}: {
  todo: Todo;
  onSelect: (id: string) => void;
  selected: boolean;
}) {
  return (
    <li onClick={() => onSelect(todo.id)}>
      {todo.text} {selected && '✓'}
    </li>
  );
});
```

### React.memo with Custom Comparison

```typescript
interface UserCardProps {
  user: User;
  onUpdate: (user: User) => void;
}

const UserCard = memo(
  function UserCard({ user, onUpdate }: UserCardProps) {
    return (
      <div>
        <h3>{user.name}</h3>
        <p>{user.email}</p>
        <button onClick={() => onUpdate(user)}>Update</button>
      </div>
    );
  },
  (prevProps, nextProps) => {
    // Only rerender if user data actually changed
    return prevProps.user.id === nextProps.user.id &&
           prevProps.user.name === nextProps.user.name &&
           prevProps.user.email === nextProps.user.email;
  }
);
```

## Best Practices

1. **Prefer Hooks Over HOCs**: Use custom hooks for reusable logic
2. **Keep Context Focused**: Don't put everything in one context
3. **Memoize Appropriately**: Only memoize when profiling shows benefit
4. **Use Composition**: Build complex UIs from simple components
5. **Type Everything**: Leverage TypeScript for better DX and fewer bugs
6. **Test Patterns**: Ensure patterns are testable and maintainable
