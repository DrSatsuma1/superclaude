# Routing Guide

Best practices for client-side routing in React applications using React Router and Next.js.

## Table of Contents

- [React Router](#react-router)
- [Next.js App Router](#nextjs-app-router)
- [Route Protection](#route-protection)
- [Navigation](#navigation)
- [URL State Management](#url-state-management)
- [Nested Routes](#nested-routes)

## React Router

### Basic Setup

```typescript
// main.tsx
import { createBrowserRouter, RouterProvider } from 'react-router-dom';

const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    errorElement: <ErrorPage />,
    children: [
      {
        index: true,
        element: <HomePage />,
      },
      {
        path: 'about',
        element: <AboutPage />,
      },
      {
        path: 'users',
        element: <UsersLayout />,
        children: [
          {
            index: true,
            element: <UsersList />,
          },
          {
            path: ':userId',
            element: <UserProfile />,
            loader: userLoader,
          },
        ],
      },
    ],
  },
]);

function App() {
  return <RouterProvider router={router} />;
}
```

### Route Loaders

```typescript
import { LoaderFunctionArgs, useLoaderData } from 'react-router-dom';

interface User {
  id: string;
  name: string;
  email: string;
}

// Loader function
export async function userLoader({ params }: LoaderFunctionArgs) {
  const response = await fetch(`/api/users/${params.userId}`);
  if (!response.ok) {
    throw new Response('User not found', { status: 404 });
  }
  return response.json();
}

// Component
export function UserProfile() {
  const user = useLoaderData() as User;

  return (
    <div>
      <h1>{user.name}</h1>
      <p>{user.email}</p>
    </div>
  );
}

// Route configuration
{
  path: 'users/:userId',
  element: <UserProfile />,
  loader: userLoader,
  errorElement: <UserErrorPage />,
}
```

### Route Actions

```typescript
import { ActionFunctionArgs, Form, redirect, useActionData } from 'react-router-dom';

interface ActionData {
  errors?: {
    name?: string;
    email?: string;
  };
}

// Action function
export async function createUserAction({ request }: ActionFunctionArgs) {
  const formData = await request.formData();
  const name = formData.get('name') as string;
  const email = formData.get('email') as string;

  const errors: ActionData['errors'] = {};

  if (!name) {
    errors.name = 'Name is required';
  }
  if (!email) {
    errors.email = 'Email is required';
  }

  if (Object.keys(errors).length > 0) {
    return { errors };
  }

  const response = await fetch('/api/users', {
    method: 'POST',
    body: JSON.stringify({ name, email }),
  });

  const user = await response.json();
  return redirect(`/users/${user.id}`);
}

// Component
export function CreateUserPage() {
  const actionData = useActionData() as ActionData;

  return (
    <Form method="post">
      <div>
        <label htmlFor="name">Name</label>
        <input id="name" name="name" type="text" />
        {actionData?.errors?.name && <span>{actionData.errors.name}</span>}
      </div>

      <div>
        <label htmlFor="email">Email</label>
        <input id="email" name="email" type="email" />
        {actionData?.errors?.email && <span>{actionData.errors.email}</span>}
      </div>

      <button type="submit">Create User</button>
    </Form>
  );
}

// Route configuration
{
  path: 'users/new',
  element: <CreateUserPage />,
  action: createUserAction,
}
```

### Layout Routes

```typescript
import { Outlet, useNavigation } from 'react-router-dom';

function RootLayout() {
  const navigation = useNavigation();

  return (
    <div className="app">
      <header>
        <Navigation />
      </header>

      <main>
        {navigation.state === 'loading' && <LoadingBar />}
        <Outlet />
      </main>

      <footer>
        <Footer />
      </footer>
    </div>
  );
}

function UsersLayout() {
  return (
    <div className="users-layout">
      <aside>
        <UsersNav />
      </aside>
      <div className="content">
        <Outlet />
      </div>
    </div>
  );
}
```

### Navigation Components

```typescript
import { Link, NavLink, useNavigate } from 'react-router-dom';

function Navigation() {
  return (
    <nav>
      {/* Basic link */}
      <Link to="/">Home</Link>

      {/* NavLink with active styling */}
      <NavLink
        to="/about"
        className={({ isActive }) => (isActive ? 'active' : '')}
      >
        About
      </NavLink>

      {/* NavLink with custom active logic */}
      <NavLink
        to="/users"
        className={({ isActive, isPending }) => {
          return isActive ? 'active' : isPending ? 'pending' : '';
        }}
      >
        Users
      </NavLink>
    </nav>
  );
}

function UserActions() {
  const navigate = useNavigate();

  const handleDelete = async () => {
    await deleteUser();
    navigate('/users'); // Programmatic navigation
  };

  const handleCancel = () => {
    navigate(-1); // Go back
  };

  return (
    <div>
      <button onClick={handleDelete}>Delete</button>
      <button onClick={handleCancel}>Cancel</button>
    </div>
  );
}
```

## Next.js App Router

### File-Based Routing

```
app/
├── page.tsx                    # /
├── about/
│   └── page.tsx                # /about
├── blog/
│   ├── page.tsx                # /blog
│   └── [slug]/
│       └── page.tsx            # /blog/:slug
├── dashboard/
│   ├── layout.tsx              # Shared layout
│   ├── page.tsx                # /dashboard
│   ├── settings/
│   │   └── page.tsx            # /dashboard/settings
│   └── profile/
│       └── page.tsx            # /dashboard/profile
└── (auth)/                     # Route group (no URL segment)
    ├── login/
    │   └── page.tsx            # /login
    └── register/
        └── page.tsx            # /register
```

### Pages

```typescript
// app/page.tsx - Home page
export default function HomePage() {
  return (
    <div>
      <h1>Welcome</h1>
    </div>
  );
}

// app/blog/[slug]/page.tsx - Dynamic route
interface PageProps {
  params: { slug: string };
  searchParams: { [key: string]: string | string[] | undefined };
}

export default function BlogPost({ params, searchParams }: PageProps) {
  return (
    <div>
      <h1>Post: {params.slug}</h1>
      {searchParams.view && <p>View: {searchParams.view}</p>}
    </div>
  );
}

// Generate static params for SSG
export async function generateStaticParams() {
  const posts = await fetch('https://api.example.com/posts').then(r => r.json());

  return posts.map((post: { slug: string }) => ({
    slug: post.slug,
  }));
}
```

### Layouts

```typescript
// app/layout.tsx - Root layout
export const metadata = {
  title: 'My App',
  description: 'App description',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <header>
          <Navigation />
        </header>
        <main>{children}</main>
        <footer>
          <Footer />
        </footer>
      </body>
    </html>
  );
}

// app/dashboard/layout.tsx - Nested layout
export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="dashboard">
      <aside>
        <DashboardNav />
      </aside>
      <div className="content">{children}</div>
    </div>
  );
}
```

### Server Components & Data Fetching

```typescript
// app/users/page.tsx - Server Component
async function getUsers() {
  const res = await fetch('https://api.example.com/users', {
    next: { revalidate: 3600 }, // Revalidate every hour
  });

  if (!res.ok) {
    throw new Error('Failed to fetch users');
  }

  return res.json();
}

export default async function UsersPage() {
  const users = await getUsers();

  return (
    <div>
      <h1>Users</h1>
      <ul>
        {users.map((user: User) => (
          <li key={user.id}>{user.name}</li>
        ))}
      </ul>
    </div>
  );
}
```

### Loading & Error States

```typescript
// app/users/loading.tsx - Automatic loading UI
export default function Loading() {
  return <UsersSkeleton />;
}

// app/users/error.tsx - Error handling
'use client';

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div>
      <h2>Something went wrong!</h2>
      <p>{error.message}</p>
      <button onClick={reset}>Try again</button>
    </div>
  );
}

// app/users/not-found.tsx - 404 page
export default function NotFound() {
  return (
    <div>
      <h2>User Not Found</h2>
      <p>Could not find the requested user.</p>
    </div>
  );
}
```

### Navigation

```typescript
'use client';

import Link from 'next/link';
import { useRouter, usePathname, useSearchParams } from 'next/navigation';

export function Navigation() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  return (
    <nav>
      {/* Link component */}
      <Link href="/">Home</Link>
      <Link href="/about">About</Link>

      {/* Active link styling */}
      <Link
        href="/blog"
        className={pathname === '/blog' ? 'active' : ''}
      >
        Blog
      </Link>

      {/* Programmatic navigation */}
      <button onClick={() => router.push('/dashboard')}>
        Go to Dashboard
      </button>

      <button onClick={() => router.back()}>
        Go Back
      </button>

      {/* Prefetch */}
      <Link href="/heavy-page" prefetch={true}>
        Heavy Page (Prefetched)
      </Link>
    </nav>
  );
}
```

## Route Protection

### React Router Protected Routes

```typescript
import { Navigate, useLocation } from 'react-router-dom';

function RequireAuth({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  const location = useLocation();

  if (loading) {
    return <LoadingSpinner />;
  }

  if (!user) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
}

// Route configuration
{
  path: 'dashboard',
  element: (
    <RequireAuth>
      <DashboardLayout />
    </RequireAuth>
  ),
  children: [
    {
      index: true,
      element: <Dashboard />,
    },
  ],
}

// Login page with redirect
function LoginPage() {
  const location = useLocation();
  const navigate = useNavigate();
  const { login } = useAuth();

  const from = location.state?.from?.pathname || '/dashboard';

  const handleLogin = async (credentials: Credentials) => {
    await login(credentials);
    navigate(from, { replace: true });
  };

  return <LoginForm onSubmit={handleLogin} />;
}
```

### Next.js Middleware Protection

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const token = request.cookies.get('auth-token');

  // Check if accessing protected route
  if (request.nextUrl.pathname.startsWith('/dashboard')) {
    if (!token) {
      return NextResponse.redirect(new URL('/login', request.url));
    }
  }

  // Redirect authenticated users away from auth pages
  if (request.nextUrl.pathname.startsWith('/login')) {
    if (token) {
      return NextResponse.redirect(new URL('/dashboard', request.url));
    }
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*', '/login', '/register'],
};
```

### Role-Based Access

```typescript
interface RequireRoleProps {
  children: React.ReactNode;
  roles: string[];
}

function RequireRole({ children, roles }: RequireRoleProps) {
  const { user, loading } = useAuth();

  if (loading) {
    return <LoadingSpinner />;
  }

  if (!user) {
    return <Navigate to="/login" />;
  }

  if (!roles.includes(user.role)) {
    return <Forbidden />;
  }

  return <>{children}</>;
}

// Usage
{
  path: 'admin',
  element: (
    <RequireRole roles={['admin']}>
      <AdminPanel />
    </RequireRole>
  ),
}
```

## URL State Management

### Search Params

```typescript
import { useSearchParams } from 'react-router-dom';

function ProductList() {
  const [searchParams, setSearchParams] = useSearchParams();

  const page = parseInt(searchParams.get('page') || '1');
  const category = searchParams.get('category') || 'all';
  const sort = searchParams.get('sort') || 'newest';

  const handleFilterChange = (newCategory: string) => {
    setSearchParams(params => {
      params.set('category', newCategory);
      params.set('page', '1'); // Reset to first page
      return params;
    });
  };

  const handlePageChange = (newPage: number) => {
    setSearchParams(params => {
      params.set('page', newPage.toString());
      return params;
    });
  };

  return (
    <div>
      <CategoryFilter category={category} onChange={handleFilterChange} />
      <ProductGrid category={category} page={page} sort={sort} />
      <Pagination currentPage={page} onPageChange={handlePageChange} />
    </div>
  );
}
```

### Next.js Search Params

```typescript
'use client';

import { useRouter, useSearchParams, usePathname } from 'next/navigation';

export function SearchForm() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const handleSearch = (term: string) => {
    const params = new URLSearchParams(searchParams);

    if (term) {
      params.set('q', term);
    } else {
      params.delete('q');
    }

    router.replace(`${pathname}?${params.toString()}`);
  };

  return (
    <input
      type="search"
      defaultValue={searchParams.get('q') || ''}
      onChange={e => handleSearch(e.target.value)}
    />
  );
}
```

### Syncing State with URL

```typescript
function useQueryState<T>(
  key: string,
  defaultValue: T,
  serialize: (value: T) => string = String,
  deserialize: (value: string) => T = (v) => v as T
): [T, (value: T) => void] {
  const [searchParams, setSearchParams] = useSearchParams();

  const value = searchParams.get(key)
    ? deserialize(searchParams.get(key)!)
    : defaultValue;

  const setValue = useCallback(
    (newValue: T) => {
      setSearchParams(params => {
        if (newValue === defaultValue) {
          params.delete(key);
        } else {
          params.set(key, serialize(newValue));
        }
        return params;
      });
    },
    [key, defaultValue, serialize, setSearchParams]
  );

  return [value, setValue];
}

// Usage
function FilteredList() {
  const [search, setSearch] = useQueryState('search', '');
  const [page, setPage] = useQueryState(
    'page',
    1,
    (v) => v.toString(),
    (v) => parseInt(v)
  );

  return (
    <div>
      <input value={search} onChange={e => setSearch(e.target.value)} />
      <Pagination page={page} onPageChange={setPage} />
    </div>
  );
}
```

## Nested Routes

### React Router Nested Routes

```typescript
const router = createBrowserRouter([
  {
    path: '/',
    element: <RootLayout />,
    children: [
      {
        path: 'settings',
        element: <SettingsLayout />,
        children: [
          {
            index: true,
            element: <Navigate to="profile" replace />,
          },
          {
            path: 'profile',
            element: <ProfileSettings />,
          },
          {
            path: 'account',
            element: <AccountSettings />,
          },
          {
            path: 'security',
            element: <SecuritySettings />,
          },
        ],
      },
    ],
  },
]);

// SettingsLayout.tsx
function SettingsLayout() {
  return (
    <div className="settings">
      <nav>
        <NavLink to="profile">Profile</NavLink>
        <NavLink to="account">Account</NavLink>
        <NavLink to="security">Security</NavLink>
      </nav>
      <div className="settings-content">
        <Outlet />
      </div>
    </div>
  );
}
```

### Next.js Parallel Routes

```
app/dashboard/
├── layout.tsx
├── @team/
│   └── page.tsx
├── @analytics/
│   └── page.tsx
└── page.tsx
```

```typescript
// app/dashboard/layout.tsx
export default function DashboardLayout({
  children,
  team,
  analytics,
}: {
  children: React.ReactNode;
  team: React.ReactNode;
  analytics: React.ReactNode;
}) {
  return (
    <div className="dashboard">
      <div className="main">{children}</div>
      <div className="sidebar">
        <div className="team-section">{team}</div>
        <div className="analytics-section">{analytics}</div>
      </div>
    </div>
  );
}
```

## Best Practices

1. **Use loaders for data fetching**: Fetch before rendering
2. **Handle loading states**: Show feedback during navigation
3. **Protect routes**: Implement authentication guards
4. **Use URL for state**: Searchable, shareable, bookmarkable
5. **Prefetch routes**: Improve perceived performance
6. **Error boundaries**: Handle route-level errors
7. **Lazy load routes**: Code split by route
8. **Typed params**: Use TypeScript for route parameters
9. **Breadcrumbs**: Help users understand location
10. **Back button**: Ensure browser back works correctly
