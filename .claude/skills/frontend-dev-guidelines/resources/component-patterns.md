# Component Patterns

Best practices for building reusable, maintainable React components.

## Table of Contents

- [Component Structure](#component-structure)
- [Props Design](#props-design)
- [State Management](#state-management)
- [Component Composition](#component-composition)
- [Performance Optimization](#performance-optimization)
- [Testing Considerations](#testing-considerations)

## Component Structure

### File Organization

```typescript
// Good: One component per file with related types
// Button.tsx
import { ButtonHTMLAttributes } from 'react';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'small' | 'medium' | 'large';
  loading?: boolean;
}

export function Button({
  variant = 'primary',
  size = 'medium',
  loading = false,
  disabled,
  children,
  className = '',
  ...props
}: ButtonProps) {
  const baseClasses = 'button';
  const variantClass = `button-${variant}`;
  const sizeClass = `button-${size}`;
  const classes = `${baseClasses} ${variantClass} ${sizeClass} ${className}`.trim();

  return (
    <button
      className={classes}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? <Spinner /> : children}
    </button>
  );
}
```

### Component Naming

```typescript
// Good: Clear, descriptive names
export function UserProfileCard() { /* ... */ }
export function ShoppingCartItem() { /* ... */ }
export function NavigationMenuItem() { /* ... */ }

// Bad: Vague or overly generic names
export function Card() { /* ... */ }
export function Item() { /* ... */ }
export function Component() { /* ... */ }
```

### Exports

```typescript
// Good: Named exports for better refactoring
export function Button() { /* ... */ }
export function ButtonGroup() { /* ... */ }

// Also good: Barrel exports for related components
// index.ts
export { Button, type ButtonProps } from './Button';
export { ButtonGroup, type ButtonGroupProps } from './ButtonGroup';

// Avoid: Default exports make refactoring harder
export default function Button() { /* ... */ }
```

## Props Design

### Props Interface

```typescript
// Good: Extend native HTML props when appropriate
interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  helperText?: string;
}

// Good: Use discriminated unions for variants
type ButtonProps =
  | { variant: 'link'; href: string; onClick?: never }
  | { variant?: 'primary' | 'secondary'; href?: never; onClick?: () => void };

// Good: Make optional props truly optional with defaults
interface CardProps {
  title: string;
  subtitle?: string;
  elevation?: number; // Default handled in component
}
```

### Props Destructuring

```typescript
// Good: Destructure with defaults in parameters
export function Card({
  title,
  subtitle,
  elevation = 2,
  children,
  ...rest
}: CardProps) {
  return (
    <div className={`card elevation-${elevation}`} {...rest}>
      <h2>{title}</h2>
      {subtitle && <p>{subtitle}</p>}
      {children}
    </div>
  );
}

// Avoid: Setting defaults inside component body
export function Card(props: CardProps) {
  const elevation = props.elevation || 2; // Not as clear
  // ...
}
```

### Children Patterns

```typescript
// Pattern 1: Simple children
interface ContainerProps {
  children: React.ReactNode;
}

// Pattern 2: Typed children
interface ListProps<T> {
  items: T[];
  renderItem: (item: T) => React.ReactNode;
}

// Pattern 3: Multiple named children (composition)
interface LayoutProps {
  header: React.ReactNode;
  sidebar: React.ReactNode;
  content: React.ReactNode;
}

// Pattern 4: Children as function (render props)
interface DataProviderProps<T> {
  children: (data: T, loading: boolean) => React.ReactNode;
}
```

## State Management

### Local State

```typescript
// Good: State close to where it's used
function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([]);
  const [filter, setFilter] = useState<'all' | 'active' | 'completed'>('all');

  const filteredTodos = useMemo(() => {
    switch (filter) {
      case 'active':
        return todos.filter(t => !t.completed);
      case 'completed':
        return todos.filter(t => t.completed);
      default:
        return todos;
    }
  }, [todos, filter]);

  return (
    <div>
      <FilterButtons currentFilter={filter} onFilterChange={setFilter} />
      <TodoItems todos={filteredTodos} />
    </div>
  );
}
```

### Derived State

```typescript
// Good: Compute during render
function ShoppingCart({ items }: { items: CartItem[] }) {
  const total = items.reduce((sum, item) => sum + item.price * item.quantity, 0);
  const itemCount = items.reduce((sum, item) => sum + item.quantity, 0);

  return (
    <div>
      <p>Items: {itemCount}</p>
      <p>Total: ${total.toFixed(2)}</p>
    </div>
  );
}

// Avoid: Storing derived state
function ShoppingCart({ items }: { items: CartItem[] }) {
  const [total, setTotal] = useState(0);
  const [itemCount, setItemCount] = useState(0);

  useEffect(() => {
    setTotal(items.reduce((sum, item) => sum + item.price * item.quantity, 0));
    setItemCount(items.reduce((sum, item) => sum + item.quantity, 0));
  }, [items]); // Unnecessary state and effect

  // ...
}
```

### State Updates

```typescript
// Good: Functional updates for dependent state
const [count, setCount] = useState(0);

const increment = () => {
  setCount(prev => prev + 1);
};

// Good: Batch related state with useReducer
type State = {
  loading: boolean;
  data: Data | null;
  error: Error | null;
};

type Action =
  | { type: 'FETCH_START' }
  | { type: 'FETCH_SUCCESS'; payload: Data }
  | { type: 'FETCH_ERROR'; payload: Error };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case 'FETCH_START':
      return { loading: true, data: null, error: null };
    case 'FETCH_SUCCESS':
      return { loading: false, data: action.payload, error: null };
    case 'FETCH_ERROR':
      return { loading: false, data: null, error: action.payload };
    default:
      return state;
  }
}

function DataComponent() {
  const [state, dispatch] = useReducer(reducer, {
    loading: false,
    data: null,
    error: null,
  });

  // Use dispatch to update state
}
```

## Component Composition

### Container/Presenter Pattern

```typescript
// Presenter: Pure, presentational component
interface UserProfileViewProps {
  user: User;
  onEdit: () => void;
  onDelete: () => void;
}

function UserProfileView({ user, onEdit, onDelete }: UserProfileViewProps) {
  return (
    <div className="user-profile">
      <img src={user.avatar} alt={user.name} />
      <h2>{user.name}</h2>
      <p>{user.email}</p>
      <button onClick={onEdit}>Edit</button>
      <button onClick={onDelete}>Delete</button>
    </div>
  );
}

// Container: Handles logic and state
function UserProfileContainer({ userId }: { userId: string }) {
  const { data: user, loading, error } = useQuery<User>(`/api/users/${userId}`);
  const navigate = useNavigate();

  if (loading) return <Spinner />;
  if (error) return <ErrorMessage error={error} />;
  if (!user) return <NotFound />;

  const handleEdit = () => {
    navigate(`/users/${userId}/edit`);
  };

  const handleDelete = async () => {
    if (confirm('Are you sure?')) {
      await deleteUser(userId);
      navigate('/users');
    }
  };

  return <UserProfileView user={user} onEdit={handleEdit} onDelete={handleDelete} />;
}
```

### Composition over Props

```typescript
// Good: Flexible composition
function Card({ children }: { children: React.ReactNode }) {
  return <div className="card">{children}</div>;
}

function CardHeader({ children }: { children: React.ReactNode }) {
  return <div className="card-header">{children}</div>;
}

function CardBody({ children }: { children: React.ReactNode }) {
  return <div className="card-body">{children}</div>;
}

// Usage
<Card>
  <CardHeader>
    <h2>Title</h2>
  </CardHeader>
  <CardBody>
    <p>Content goes here</p>
  </CardBody>
</Card>

// Avoid: Too many props for variants
function Card({
  title,
  subtitle,
  headerAction,
  bodyContent,
  footer,
  // ... many more props
}: CardProps) {
  // Complex logic to handle all variations
}
```

### Slots Pattern

```typescript
interface PageLayoutProps {
  header?: React.ReactNode;
  sidebar?: React.ReactNode;
  content: React.ReactNode;
  footer?: React.ReactNode;
}

function PageLayout({ header, sidebar, content, footer }: PageLayoutProps) {
  return (
    <div className="page-layout">
      {header && <header>{header}</header>}
      <div className="main">
        {sidebar && <aside>{sidebar}</aside>}
        <main>{content}</main>
      </div>
      {footer && <footer>{footer}</footer>}
    </div>
  );
}

// Usage
<PageLayout
  header={<Navigation />}
  sidebar={<Sidebar />}
  content={<Dashboard />}
  footer={<Footer />}
/>
```

## Performance Optimization

### Memoization

```typescript
// Use React.memo for expensive components
const ExpensiveList = memo(function ExpensiveList({
  items
}: {
  items: Item[]
}) {
  return (
    <ul>
      {items.map(item => (
        <ExpensiveListItem key={item.id} item={item} />
      ))}
    </ul>
  );
});

// Use useMemo for expensive calculations
function DataVisualization({ data }: { data: number[] }) {
  const processedData = useMemo(() => {
    return data.map(value => ({
      value,
      normalized: value / Math.max(...data),
      percentile: calculatePercentile(value, data),
    }));
  }, [data]);

  return <Chart data={processedData} />;
}

// Use useCallback for callbacks passed to memoized children
function ParentComponent() {
  const [items, setItems] = useState<Item[]>([]);

  const handleItemClick = useCallback((id: string) => {
    setItems(prev => prev.filter(item => item.id !== id));
  }, []);

  return <ExpensiveList items={items} onItemClick={handleItemClick} />;
}
```

### Code Splitting

```typescript
// Lazy load routes
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));
const Profile = lazy(() => import('./pages/Profile'));

function App() {
  return (
    <Suspense fallback={<LoadingScreen />}>
      <Routes>
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/profile" element={<Profile />} />
      </Routes>
    </Suspense>
  );
}

// Lazy load heavy components
const HeavyChart = lazy(() => import('./components/HeavyChart'));

function AnalyticsPage() {
  const [showChart, setShowChart] = useState(false);

  return (
    <div>
      <button onClick={() => setShowChart(true)}>Show Chart</button>
      {showChart && (
        <Suspense fallback={<div>Loading chart...</div>}>
          <HeavyChart />
        </Suspense>
      )}
    </div>
  );
}
```

## Testing Considerations

### Testable Components

```typescript
// Good: Easy to test
export function SearchForm({
  onSearch
}: {
  onSearch: (query: string) => void
}) {
  const [query, setQuery] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSearch(query);
  };

  return (
    <form onSubmit={handleSubmit}>
      <input
        value={query}
        onChange={e => setQuery(e.target.value)}
        placeholder="Search..."
      />
      <button type="submit">Search</button>
    </form>
  );
}

// Test
test('calls onSearch with query on submit', () => {
  const handleSearch = jest.fn();
  render(<SearchForm onSearch={handleSearch} />);

  const input = screen.getByPlaceholderText('Search...');
  const button = screen.getByRole('button');

  fireEvent.change(input, { target: { value: 'test query' } });
  fireEvent.click(button);

  expect(handleSearch).toHaveBeenCalledWith('test query');
});
```

### Separation of Concerns

```typescript
// Good: Business logic separated
export function useSearch(initialQuery = '') {
  const [query, setQuery] = useState(initialQuery);
  const [results, setResults] = useState<Result[]>([]);
  const [loading, setLoading] = useState(false);

  const search = useCallback(async (searchQuery: string) => {
    setLoading(true);
    try {
      const data = await searchAPI(searchQuery);
      setResults(data);
    } catch (error) {
      setResults([]);
    } finally {
      setLoading(false);
    }
  }, []);

  return { query, setQuery, results, loading, search };
}

// Component uses the hook
export function SearchPage() {
  const { query, setQuery, results, loading, search } = useSearch();

  return (
    <div>
      <SearchForm
        value={query}
        onChange={setQuery}
        onSubmit={() => search(query)}
      />
      {loading ? <Spinner /> : <SearchResults results={results} />}
    </div>
  );
}

// Now you can test the hook and component separately
```

## Best Practices Summary

1. **Single Responsibility**: Each component should do one thing well
2. **Composition**: Build complex UIs from simple, reusable components
3. **Props Interface**: Design clear, type-safe prop interfaces
4. **State Management**: Keep state as local as possible
5. **Performance**: Optimize only when necessary, measure first
6. **Testability**: Write components that are easy to test
7. **TypeScript**: Leverage types for better DX and fewer bugs
8. **Accessibility**: Consider keyboard navigation and screen readers
9. **Error Boundaries**: Wrap components that might fail
10. **Documentation**: Comment complex logic and non-obvious decisions
