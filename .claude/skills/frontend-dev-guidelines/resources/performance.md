# Performance Optimization

Best practices and techniques for optimizing React application performance.

## Table of Contents

- [Rendering Optimization](#rendering-optimization)
- [Code Splitting](#code-splitting)
- [Asset Optimization](#asset-optimization)
- [State Management](#state-management)
- [Network Optimization](#network-optimization)
- [Measuring Performance](#measuring-performance)

## Rendering Optimization

### React.memo

```typescript
// Memoize expensive components
interface UserCardProps {
  user: User;
  onSelect: (id: string) => void;
}

export const UserCard = memo(function UserCard({ user, onSelect }: UserCardProps) {
  return (
    <div onClick={() => onSelect(user.id)}>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
});

// With custom comparison
export const UserCard = memo(
  function UserCard({ user, onSelect }: UserCardProps) {
    return (
      <div onClick={() => onSelect(user.id)}>
        <h3>{user.name}</h3>
        <p>{user.email}</p>
      </div>
    );
  },
  (prevProps, nextProps) => {
    // Only re-render if user data changed
    return (
      prevProps.user.id === nextProps.user.id &&
      prevProps.user.name === nextProps.user.name &&
      prevProps.user.email === nextProps.user.email
    );
  }
);
```

### useMemo

```typescript
function DataTable({ data, filters }: { data: Item[]; filters: Filters }) {
  // Expensive calculation - only recompute when dependencies change
  const filteredData = useMemo(() => {
    return data.filter(item => {
      return (
        item.category === filters.category &&
        item.price >= filters.minPrice &&
        item.price <= filters.maxPrice
      );
    });
  }, [data, filters]);

  const sortedData = useMemo(() => {
    return [...filteredData].sort((a, b) => {
      return a.name.localeCompare(b.name);
    });
  }, [filteredData]);

  return (
    <table>
      {sortedData.map(item => (
        <TableRow key={item.id} item={item} />
      ))}
    </table>
  );
}

// Anti-pattern: Don't useMemo for cheap calculations
function Component({ count }: { count: number }) {
  // Bad: useMemo overhead > calculation cost
  const doubled = useMemo(() => count * 2, [count]);

  // Good: Just calculate directly
  const doubled = count * 2;

  return <div>{doubled}</div>;
}
```

### useCallback

```typescript
function TodoList() {
  const [todos, setTodos] = useState<Todo[]>([]);

  // Memoize callback to prevent child re-renders
  const handleToggle = useCallback((id: string) => {
    setTodos(prev =>
      prev.map(todo =>
        todo.id === id ? { ...todo, completed: !todo.completed } : todo
      )
    );
  }, []);

  const handleDelete = useCallback((id: string) => {
    setTodos(prev => prev.filter(todo => todo.id !== id));
  }, []);

  return (
    <ul>
      {todos.map(todo => (
        <TodoItem
          key={todo.id}
          todo={todo}
          onToggle={handleToggle}
          onDelete={handleDelete}
        />
      ))}
    </ul>
  );
}

const TodoItem = memo(function TodoItem({
  todo,
  onToggle,
  onDelete,
}: {
  todo: Todo;
  onToggle: (id: string) => void;
  onDelete: (id: string) => void;
}) {
  // This won't re-render unless todo changes
  return (
    <li>
      <input
        type="checkbox"
        checked={todo.completed}
        onChange={() => onToggle(todo.id)}
      />
      <span>{todo.text}</span>
      <button onClick={() => onDelete(todo.id)}>Delete</button>
    </li>
  );
});
```

### Virtual Scrolling

```typescript
import { useVirtualizer } from '@tanstack/react-virtual';

function VirtualList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 50, // Estimated item height
    overscan: 5, // Render 5 items outside viewport
  });

  return (
    <div
      ref={parentRef}
      style={{
        height: '400px',
        overflow: 'auto',
      }}
    >
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          width: '100%',
          position: 'relative',
        }}
      >
        {virtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.index}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <ItemRow item={items[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  );
}
```

### Windowing Large Lists

```typescript
import { FixedSizeList } from 'react-window';

function LargeList({ items }: { items: Item[] }) {
  const Row = ({ index, style }: { index: number; style: React.CSSProperties }) => (
    <div style={style}>
      <ItemRow item={items[index]} />
    </div>
  );

  return (
    <FixedSizeList
      height={600}
      itemCount={items.length}
      itemSize={50}
      width="100%"
    >
      {Row}
    </FixedSizeList>
  );
}
```

## Code Splitting

### Route-Based Code Splitting

```typescript
import { lazy, Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';

// Lazy load route components
const HomePage = lazy(() => import('./pages/HomePage'));
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Settings = lazy(() => import('./pages/Settings'));
const Profile = lazy(() => import('./pages/Profile'));

function App() {
  return (
    <Suspense fallback={<LoadingScreen />}>
      <Routes>
        <Route path="/" element={<HomePage />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/profile" element={<Profile />} />
      </Routes>
    </Suspense>
  );
}
```

### Component-Based Code Splitting

```typescript
import { lazy, Suspense, useState } from 'react';

// Lazy load heavy components
const HeavyChart = lazy(() => import('./components/HeavyChart'));
const HeavyTable = lazy(() => import('./components/HeavyTable'));

function AnalyticsPage() {
  const [showChart, setShowChart] = useState(false);

  return (
    <div>
      <h1>Analytics</h1>

      <button onClick={() => setShowChart(!showChart)}>
        {showChart ? 'Hide' : 'Show'} Chart
      </button>

      {showChart && (
        <Suspense fallback={<div>Loading chart...</div>}>
          <HeavyChart />
        </Suspense>
      )}

      <Suspense fallback={<div>Loading table...</div>}>
        <HeavyTable />
      </Suspense>
    </div>
  );
}
```

### Dynamic Imports

```typescript
// Dynamically import utilities when needed
async function processLargeFile(file: File) {
  const { processFile } = await import('./utils/fileProcessor');
  return processFile(file);
}

// Dynamically import libraries
async function showMap(location: Location) {
  const mapboxgl = await import('mapbox-gl');
  const map = new mapboxgl.Map({
    container: 'map',
    center: [location.lng, location.lat],
  });
}
```

### Prefetching

```typescript
function ProductList({ products }: { products: Product[] }) {
  // Prefetch details on hover
  const prefetchDetails = (productId: string) => {
    const link = document.createElement('link');
    link.rel = 'prefetch';
    link.href = `/api/products/${productId}`;
    document.head.appendChild(link);
  };

  return (
    <div>
      {products.map(product => (
        <Link
          key={product.id}
          to={`/products/${product.id}`}
          onMouseEnter={() => prefetchDetails(product.id)}
        >
          {product.name}
        </Link>
      ))}
    </div>
  );
}
```

## Asset Optimization

### Image Optimization

```typescript
// Use modern image formats
function ProductImage({ src, alt }: { src: string; alt: string }) {
  return (
    <picture>
      <source srcSet={`${src}.webp`} type="image/webp" />
      <source srcSet={`${src}.avif`} type="image/avif" />
      <img src={`${src}.jpg`} alt={alt} loading="lazy" />
    </picture>
  );
}

// Responsive images
function ResponsiveImage({ src, alt }: { src: string; alt: string }) {
  return (
    <img
      src={`${src}-800.jpg`}
      srcSet={`
        ${src}-400.jpg 400w,
        ${src}-800.jpg 800w,
        ${src}-1200.jpg 1200w
      `}
      sizes="(max-width: 600px) 400px, (max-width: 1200px) 800px, 1200px"
      alt={alt}
      loading="lazy"
    />
  );
}

// Lazy load images with intersection observer
function LazyImage({ src, alt }: { src: string; alt: string }) {
  const [imageSrc, setImageSrc] = useState<string | null>(null);
  const imgRef = useRef<HTMLImageElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setImageSrc(src);
          if (imgRef.current) {
            observer.unobserve(imgRef.current);
          }
        }
      },
      { rootMargin: '50px' }
    );

    if (imgRef.current) {
      observer.observe(imgRef.current);
    }

    return () => observer.disconnect();
  }, [src]);

  return (
    <img
      ref={imgRef}
      src={imageSrc || '/placeholder.jpg'}
      alt={alt}
      style={{ opacity: imageSrc ? 1 : 0.5 }}
    />
  );
}
```

### Font Optimization

```css
/* preload critical fonts */
<link rel="preload" href="/fonts/main.woff2" as="font" type="font/woff2" crossorigin>

/* Use font-display for faster rendering */
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom.woff2') format('woff2');
  font-display: swap; /* Show fallback font immediately */
  font-weight: 400;
}

/* Subset fonts to include only needed characters */
@font-face {
  font-family: 'CustomFont';
  src: url('/fonts/custom-latin.woff2') format('woff2');
  unicode-range: U+0000-00FF, U+0131, U+0152-0153;
}
```

### Bundle Analysis

```typescript
// vite.config.ts
import { defineConfig } from 'vite';
import { visualizer } from 'rollup-plugin-visualizer';

export default defineConfig({
  plugins: [
    visualizer({
      open: true,
      gzipSize: true,
      brotliSize: true,
    }),
  ],
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'react-vendor': ['react', 'react-dom'],
          'router': ['react-router-dom'],
          'ui': ['@radix-ui/react-dialog', '@radix-ui/react-dropdown-menu'],
        },
      },
    },
  },
});
```

## State Management

### Context Optimization

```typescript
// Split context to prevent unnecessary re-renders
const UserStateContext = createContext<User | null>(null);
const UserDispatchContext = createContext<{
  updateUser: (user: User) => void;
  logout: () => void;
} | null>(null);

export function UserProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);

  // Memoize dispatch functions
  const dispatch = useMemo(
    () => ({
      updateUser: setUser,
      logout: () => setUser(null),
    }),
    []
  );

  return (
    <UserStateContext.Provider value={user}>
      <UserDispatchContext.Provider value={dispatch}>
        {children}
      </UserDispatchContext.Provider>
    </UserStateContext.Provider>
  );
}

// Components only re-render when their specific context changes
export const useUser = () => useContext(UserStateContext);
export const useUserDispatch = () => useContext(UserDispatchContext);
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

// Bad: Storing derived state
function ShoppingCart({ items }: { items: CartItem[] }) {
  const [total, setTotal] = useState(0);
  const [itemCount, setItemCount] = useState(0);

  useEffect(() => {
    setTotal(items.reduce((sum, item) => sum + item.price * item.quantity, 0));
    setItemCount(items.reduce((sum, item) => sum + item.quantity, 0));
  }, [items]); // Unnecessary state synchronization

  return (
    <div>
      <p>Items: {itemCount}</p>
      <p>Total: ${total.toFixed(2)}</p>
    </div>
  );
}
```

## Network Optimization

### Request Batching

```typescript
class RequestBatcher {
  private queue: Array<{
    id: string;
    resolve: (data: any) => void;
    reject: (error: Error) => void;
  }> = [];
  private timeout: NodeJS.Timeout | null = null;

  request(id: string): Promise<any> {
    return new Promise((resolve, reject) => {
      this.queue.push({ id, resolve, reject });

      if (this.timeout) {
        clearTimeout(this.timeout);
      }

      this.timeout = setTimeout(() => this.flush(), 10);
    });
  }

  private async flush() {
    const requests = this.queue.splice(0);
    const ids = requests.map(r => r.id);

    try {
      const response = await fetch('/api/batch', {
        method: 'POST',
        body: JSON.stringify({ ids }),
      });
      const data = await response.json();

      requests.forEach(({ id, resolve }) => {
        resolve(data[id]);
      });
    } catch (error) {
      requests.forEach(({ reject }) => {
        reject(error as Error);
      });
    }
  }
}

const batcher = new RequestBatcher();

// Usage
function UserName({ userId }: { userId: string }) {
  const [user, setUser] = useState(null);

  useEffect(() => {
    batcher.request(userId).then(setUser);
  }, [userId]);

  return <div>{user?.name}</div>;
}
```

### Request Deduplication

```typescript
class RequestCache {
  private cache = new Map<string, Promise<any>>();

  async fetch(url: string): Promise<any> {
    if (this.cache.has(url)) {
      return this.cache.get(url);
    }

    const promise = fetch(url)
      .then(r => r.json())
      .finally(() => {
        // Remove from cache after completion
        setTimeout(() => this.cache.delete(url), 1000);
      });

    this.cache.set(url, promise);
    return promise;
  }
}

const requestCache = new RequestCache();

// Multiple components requesting same data will share one request
function Component1() {
  const [data, setData] = useState(null);
  useEffect(() => {
    requestCache.fetch('/api/user').then(setData);
  }, []);
  return <div>{data?.name}</div>;
}

function Component2() {
  const [data, setData] = useState(null);
  useEffect(() => {
    requestCache.fetch('/api/user').then(setData); // Same request
  }, []);
  return <div>{data?.email}</div>;
}
```

## Measuring Performance

### React Profiler

```typescript
import { Profiler, ProfilerOnRenderCallback } from 'react';

const onRender: ProfilerOnRenderCallback = (
  id,
  phase,
  actualDuration,
  baseDuration,
  startTime,
  commitTime
) => {
  console.log({
    id,
    phase,
    actualDuration,
    baseDuration,
    startTime,
    commitTime,
  });

  // Send to analytics
  if (actualDuration > 16) {
    // More than one frame
    analytics.track('slow-render', {
      component: id,
      duration: actualDuration,
    });
  }
};

function App() {
  return (
    <Profiler id="App" onRender={onRender}>
      <Dashboard />
    </Profiler>
  );
}
```

### Web Vitals

```typescript
import { onCLS, onFID, onFCP, onLCP, onTTFB } from 'web-vitals';

function sendToAnalytics(metric: any) {
  const body = JSON.stringify(metric);
  const url = '/api/analytics';

  if (navigator.sendBeacon) {
    navigator.sendBeacon(url, body);
  } else {
    fetch(url, { body, method: 'POST', keepalive: true });
  }
}

onCLS(sendToAnalytics);
onFID(sendToAnalytics);
onFCP(sendToAnalytics);
onLCP(sendToAnalytics);
onTTFB(sendToAnalytics);
```

### Custom Performance Marks

```typescript
function measurePerformance(name: string, fn: () => void) {
  performance.mark(`${name}-start`);
  fn();
  performance.mark(`${name}-end`);
  performance.measure(name, `${name}-start`, `${name}-end`);

  const measure = performance.getEntriesByName(name)[0];
  console.log(`${name}: ${measure.duration}ms`);

  performance.clearMarks();
  performance.clearMeasures();
}

// Usage
measurePerformance('render-list', () => {
  // Expensive operation
});
```

## Best Practices

1. **Measure First**: Profile before optimizing
2. **Lazy Load**: Code split routes and heavy components
3. **Memoize Wisely**: Only memoize expensive operations
4. **Optimize Images**: Use modern formats, lazy loading, responsive images
5. **Virtual Lists**: Use windowing for long lists
6. **Debounce/Throttle**: Limit expensive operations
7. **Avoid Inline Functions**: In render when passing to memoized children
8. **Split Context**: Prevent unnecessary re-renders
9. **Cache Requests**: Avoid duplicate network calls
10. **Monitor Vitals**: Track Core Web Vitals in production
