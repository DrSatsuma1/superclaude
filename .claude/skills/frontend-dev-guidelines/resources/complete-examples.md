# Complete Component Examples

Full, production-ready examples demonstrating best practices for common frontend patterns.

## Table of Contents

- [Data Table with Sorting and Filtering](#data-table-with-sorting-and-filtering)
- [Form with Validation](#form-with-validation)
- [Modal Dialog System](#modal-dialog-system)
- [Infinite Scroll List](#infinite-scroll-list)
- [Multi-Step Form Wizard](#multi-step-form-wizard)

## Data Table with Sorting and Filtering

```typescript
// types.ts
export interface User {
  id: string;
  name: string;
  email: string;
  role: 'admin' | 'user' | 'guest';
  createdAt: string;
}

export type SortKey = keyof User;
export type SortDirection = 'asc' | 'desc';

// UserTable.tsx
import { useState, useMemo } from 'react';

interface UserTableProps {
  users: User[];
  onUserSelect?: (user: User) => void;
}

export function UserTable({ users, onUserSelect }: UserTableProps) {
  const [sortKey, setSortKey] = useState<SortKey>('name');
  const [sortDirection, setSortDirection] = useState<SortDirection>('asc');
  const [filterText, setFilterText] = useState('');
  const [roleFilter, setRoleFilter] = useState<User['role'] | 'all'>('all');

  const filteredAndSortedUsers = useMemo(() => {
    let filtered = users;

    // Apply text filter
    if (filterText) {
      filtered = filtered.filter(user =>
        user.name.toLowerCase().includes(filterText.toLowerCase()) ||
        user.email.toLowerCase().includes(filterText.toLowerCase())
      );
    }

    // Apply role filter
    if (roleFilter !== 'all') {
      filtered = filtered.filter(user => user.role === roleFilter);
    }

    // Apply sorting
    return [...filtered].sort((a, b) => {
      const aValue = a[sortKey];
      const bValue = b[sortKey];

      if (aValue < bValue) return sortDirection === 'asc' ? -1 : 1;
      if (aValue > bValue) return sortDirection === 'asc' ? 1 : -1;
      return 0;
    });
  }, [users, sortKey, sortDirection, filterText, roleFilter]);

  const handleSort = (key: SortKey) => {
    if (sortKey === key) {
      setSortDirection(prev => prev === 'asc' ? 'desc' : 'asc');
    } else {
      setSortKey(key);
      setSortDirection('asc');
    }
  };

  return (
    <div className="user-table">
      <div className="filters">
        <input
          type="text"
          placeholder="Search users..."
          value={filterText}
          onChange={e => setFilterText(e.target.value)}
          className="search-input"
        />
        <select
          value={roleFilter}
          onChange={e => setRoleFilter(e.target.value as User['role'] | 'all')}
          className="role-filter"
        >
          <option value="all">All Roles</option>
          <option value="admin">Admin</option>
          <option value="user">User</option>
          <option value="guest">Guest</option>
        </select>
      </div>

      <table>
        <thead>
          <tr>
            <th onClick={() => handleSort('name')}>
              Name {sortKey === 'name' && (sortDirection === 'asc' ? '↑' : '↓')}
            </th>
            <th onClick={() => handleSort('email')}>
              Email {sortKey === 'email' && (sortDirection === 'asc' ? '↑' : '↓')}
            </th>
            <th onClick={() => handleSort('role')}>
              Role {sortKey === 'role' && (sortDirection === 'asc' ? '↑' : '↓')}
            </th>
            <th onClick={() => handleSort('createdAt')}>
              Created {sortKey === 'createdAt' && (sortDirection === 'asc' ? '↑' : '↓')}
            </th>
          </tr>
        </thead>
        <tbody>
          {filteredAndSortedUsers.length === 0 ? (
            <tr>
              <td colSpan={4} className="empty-state">
                No users found
              </td>
            </tr>
          ) : (
            filteredAndSortedUsers.map(user => (
              <tr
                key={user.id}
                onClick={() => onUserSelect?.(user)}
                className="user-row"
              >
                <td>{user.name}</td>
                <td>{user.email}</td>
                <td>
                  <span className={`role-badge role-${user.role}`}>
                    {user.role}
                  </span>
                </td>
                <td>{new Date(user.createdAt).toLocaleDateString()}</td>
              </tr>
            ))
          )}
        </tbody>
      </table>

      <div className="table-footer">
        Showing {filteredAndSortedUsers.length} of {users.length} users
      </div>
    </div>
  );
}
```

## Form with Validation

```typescript
// useForm.ts
import { useState, useCallback } from 'react';

export interface ValidationRule<T> {
  validate: (value: T) => boolean;
  message: string;
}

export interface FieldConfig<T> {
  initialValue: T;
  rules?: ValidationRule<T>[];
}

export interface FormConfig {
  [key: string]: FieldConfig<any>;
}

export function useForm<T extends FormConfig>(config: T) {
  type FormData = {
    [K in keyof T]: T[K]['initialValue'];
  };

  const [values, setValues] = useState<FormData>(() => {
    const initial = {} as FormData;
    Object.keys(config).forEach(key => {
      initial[key as keyof T] = config[key].initialValue;
    });
    return initial;
  });

  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({});
  const [touched, setTouched] = useState<Partial<Record<keyof T, boolean>>>({});

  const validateField = useCallback((name: keyof T, value: any): string | null => {
    const rules = config[name].rules;
    if (!rules) return null;

    for (const rule of rules) {
      if (!rule.validate(value)) {
        return rule.message;
      }
    }
    return null;
  }, [config]);

  const handleChange = useCallback((name: keyof T, value: any) => {
    setValues(prev => ({ ...prev, [name]: value }));

    if (touched[name]) {
      const error = validateField(name, value);
      setErrors(prev => ({ ...prev, [name]: error || undefined }));
    }
  }, [touched, validateField]);

  const handleBlur = useCallback((name: keyof T) => {
    setTouched(prev => ({ ...prev, [name]: true }));
    const error = validateField(name, values[name]);
    setErrors(prev => ({ ...prev, [name]: error || undefined }));
  }, [values, validateField]);

  const validate = useCallback(() => {
    const newErrors: Partial<Record<keyof T, string>> = {};
    let isValid = true;

    Object.keys(config).forEach(key => {
      const error = validateField(key as keyof T, values[key as keyof T]);
      if (error) {
        newErrors[key as keyof T] = error;
        isValid = false;
      }
    });

    setErrors(newErrors);
    setTouched(
      Object.keys(config).reduce((acc, key) => ({ ...acc, [key]: true }), {})
    );

    return isValid;
  }, [config, values, validateField]);

  const reset = useCallback(() => {
    const initial = {} as FormData;
    Object.keys(config).forEach(key => {
      initial[key as keyof T] = config[key].initialValue;
    });
    setValues(initial);
    setErrors({});
    setTouched({});
  }, [config]);

  return {
    values,
    errors,
    touched,
    handleChange,
    handleBlur,
    validate,
    reset,
  };
}

// SignupForm.tsx
interface SignupFormData {
  username: string;
  email: string;
  password: string;
  confirmPassword: string;
}

const formConfig = {
  username: {
    initialValue: '',
    rules: [
      {
        validate: (value: string) => value.length >= 3,
        message: 'Username must be at least 3 characters',
      },
      {
        validate: (value: string) => /^[a-zA-Z0-9_]+$/.test(value),
        message: 'Username can only contain letters, numbers, and underscores',
      },
    ],
  },
  email: {
    initialValue: '',
    rules: [
      {
        validate: (value: string) => value.length > 0,
        message: 'Email is required',
      },
      {
        validate: (value: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value),
        message: 'Please enter a valid email',
      },
    ],
  },
  password: {
    initialValue: '',
    rules: [
      {
        validate: (value: string) => value.length >= 8,
        message: 'Password must be at least 8 characters',
      },
      {
        validate: (value: string) => /[A-Z]/.test(value),
        message: 'Password must contain at least one uppercase letter',
      },
      {
        validate: (value: string) => /[0-9]/.test(value),
        message: 'Password must contain at least one number',
      },
    ],
  },
  confirmPassword: {
    initialValue: '',
    rules: [
      {
        validate: (value: string) => value.length > 0,
        message: 'Please confirm your password',
      },
    ],
  },
};

export function SignupForm() {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const { values, errors, touched, handleChange, handleBlur, validate, reset } =
    useForm(formConfig);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    // Custom validation for password match
    if (values.password !== values.confirmPassword) {
      alert('Passwords do not match');
      return;
    }

    if (!validate()) {
      return;
    }

    setIsSubmitting(true);

    try {
      await signup({
        username: values.username,
        email: values.email,
        password: values.password,
      });
      alert('Signup successful!');
      reset();
    } catch (error) {
      alert('Signup failed. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="signup-form">
      <div className="form-field">
        <label htmlFor="username">Username</label>
        <input
          id="username"
          type="text"
          value={values.username}
          onChange={e => handleChange('username', e.target.value)}
          onBlur={() => handleBlur('username')}
          className={errors.username && touched.username ? 'error' : ''}
        />
        {touched.username && errors.username && (
          <span className="error-message">{errors.username}</span>
        )}
      </div>

      <div className="form-field">
        <label htmlFor="email">Email</label>
        <input
          id="email"
          type="email"
          value={values.email}
          onChange={e => handleChange('email', e.target.value)}
          onBlur={() => handleBlur('email')}
          className={errors.email && touched.email ? 'error' : ''}
        />
        {touched.email && errors.email && (
          <span className="error-message">{errors.email}</span>
        )}
      </div>

      <div className="form-field">
        <label htmlFor="password">Password</label>
        <input
          id="password"
          type="password"
          value={values.password}
          onChange={e => handleChange('password', e.target.value)}
          onBlur={() => handleBlur('password')}
          className={errors.password && touched.password ? 'error' : ''}
        />
        {touched.password && errors.password && (
          <span className="error-message">{errors.password}</span>
        )}
      </div>

      <div className="form-field">
        <label htmlFor="confirmPassword">Confirm Password</label>
        <input
          id="confirmPassword"
          type="password"
          value={values.confirmPassword}
          onChange={e => handleChange('confirmPassword', e.target.value)}
          onBlur={() => handleBlur('confirmPassword')}
          className={errors.confirmPassword && touched.confirmPassword ? 'error' : ''}
        />
        {touched.confirmPassword && errors.confirmPassword && (
          <span className="error-message">{errors.confirmPassword}</span>
        )}
      </div>

      <button type="submit" disabled={isSubmitting}>
        {isSubmitting ? 'Signing up...' : 'Sign Up'}
      </button>
    </form>
  );
}

// Mock signup function
async function signup(data: SignupFormData) {
  return new Promise(resolve => setTimeout(resolve, 1000));
}
```

## Modal Dialog System

```typescript
// ModalContext.tsx
import { createContext, useContext, useState, useCallback } from 'react';
import { createPortal } from 'react-dom';

interface ModalContextValue {
  openModal: (content: React.ReactNode, options?: ModalOptions) => void;
  closeModal: () => void;
}

interface ModalOptions {
  title?: string;
  size?: 'small' | 'medium' | 'large';
  closeOnOverlayClick?: boolean;
  showCloseButton?: boolean;
}

const ModalContext = createContext<ModalContextValue | null>(null);

export function ModalProvider({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const [content, setContent] = useState<React.ReactNode>(null);
  const [options, setOptions] = useState<ModalOptions>({});

  const openModal = useCallback((
    content: React.ReactNode,
    options: ModalOptions = {}
  ) => {
    setContent(content);
    setOptions({
      closeOnOverlayClick: true,
      showCloseButton: true,
      size: 'medium',
      ...options,
    });
    setIsOpen(true);
  }, []);

  const closeModal = useCallback(() => {
    setIsOpen(false);
    setTimeout(() => {
      setContent(null);
      setOptions({});
    }, 300); // Wait for animation
  }, []);

  return (
    <ModalContext.Provider value={{ openModal, closeModal }}>
      {children}
      {isOpen &&
        createPortal(
          <ModalOverlay
            content={content}
            options={options}
            onClose={closeModal}
          />,
          document.body
        )}
    </ModalContext.Provider>
  );
}

export function useModal() {
  const context = useContext(ModalContext);
  if (!context) {
    throw new Error('useModal must be used within ModalProvider');
  }
  return context;
}

interface ModalOverlayProps {
  content: React.ReactNode;
  options: ModalOptions;
  onClose: () => void;
}

function ModalOverlay({ content, options, onClose }: ModalOverlayProps) {
  const handleOverlayClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget && options.closeOnOverlayClick) {
      onClose();
    }
  };

  return (
    <div className="modal-overlay" onClick={handleOverlayClick}>
      <div className={`modal modal-${options.size}`}>
        {options.title && (
          <div className="modal-header">
            <h2>{options.title}</h2>
            {options.showCloseButton && (
              <button onClick={onClose} className="close-button">
                ×
              </button>
            )}
          </div>
        )}
        <div className="modal-content">{content}</div>
      </div>
    </div>
  );
}

// Usage Example
function App() {
  const { openModal, closeModal } = useModal();

  const handleOpenConfirmation = () => {
    openModal(
      <ConfirmationDialog
        title="Delete User"
        message="Are you sure you want to delete this user?"
        onConfirm={() => {
          console.log('User deleted');
          closeModal();
        }}
        onCancel={closeModal}
      />,
      { size: 'small' }
    );
  };

  return (
    <div>
      <button onClick={handleOpenConfirmation}>Delete User</button>
    </div>
  );
}

function ConfirmationDialog({
  title,
  message,
  onConfirm,
  onCancel,
}: {
  title: string;
  message: string;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <div className="confirmation-dialog">
      <h3>{title}</h3>
      <p>{message}</p>
      <div className="actions">
        <button onClick={onCancel}>Cancel</button>
        <button onClick={onConfirm} className="danger">
          Delete
        </button>
      </div>
    </div>
  );
}
```

## Infinite Scroll List

```typescript
// useInfiniteScroll.ts
import { useEffect, useRef, useCallback } from 'react';

interface UseInfiniteScrollOptions {
  onLoadMore: () => void;
  hasMore: boolean;
  loading: boolean;
  threshold?: number;
}

export function useInfiniteScroll({
  onLoadMore,
  hasMore,
  loading,
  threshold = 100,
}: UseInfiniteScrollOptions) {
  const observerRef = useRef<IntersectionObserver | null>(null);
  const loadMoreRef = useRef<HTMLDivElement | null>(null);

  const handleObserver = useCallback(
    (entries: IntersectionObserverEntry[]) => {
      const [entry] = entries;
      if (entry.isIntersecting && hasMore && !loading) {
        onLoadMore();
      }
    },
    [hasMore, loading, onLoadMore]
  );

  useEffect(() => {
    observerRef.current = new IntersectionObserver(handleObserver, {
      rootMargin: `${threshold}px`,
    });

    const currentRef = loadMoreRef.current;
    if (currentRef) {
      observerRef.current.observe(currentRef);
    }

    return () => {
      if (currentRef && observerRef.current) {
        observerRef.current.unobserve(currentRef);
      }
    };
  }, [handleObserver, threshold]);

  return loadMoreRef;
}

// InfiniteList.tsx
interface Post {
  id: string;
  title: string;
  body: string;
}

export function InfinitePostList() {
  const [posts, setPosts] = useState<Post[]>([]);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);
  const [hasMore, setHasMore] = useState(true);

  const loadMore = useCallback(async () => {
    if (loading) return;

    setLoading(true);
    try {
      const response = await fetch(
        `https://jsonplaceholder.typicode.com/posts?_page=${page}&_limit=10`
      );
      const newPosts = await response.json();

      if (newPosts.length === 0) {
        setHasMore(false);
      } else {
        setPosts(prev => [...prev, ...newPosts]);
        setPage(prev => prev + 1);
      }
    } catch (error) {
      console.error('Failed to load posts:', error);
    } finally {
      setLoading(false);
    }
  }, [page, loading]);

  // Initial load
  useEffect(() => {
    loadMore();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const loadMoreRef = useInfiniteScroll({
    onLoadMore: loadMore,
    hasMore,
    loading,
  });

  return (
    <div className="infinite-list">
      <h1>Posts</h1>
      <div className="posts">
        {posts.map(post => (
          <article key={post.id} className="post">
            <h2>{post.title}</h2>
            <p>{post.body}</p>
          </article>
        ))}
      </div>

      {loading && (
        <div className="loading-indicator">
          <span>Loading more posts...</span>
        </div>
      )}

      {!hasMore && posts.length > 0 && (
        <div className="end-message">No more posts to load</div>
      )}

      <div ref={loadMoreRef} style={{ height: 1 }} />
    </div>
  );
}
```

## Multi-Step Form Wizard

```typescript
// FormWizard.tsx
import { createContext, useContext, useState, useCallback } from 'react';

interface WizardContextValue {
  currentStep: number;
  totalSteps: number;
  goToStep: (step: number) => void;
  nextStep: () => void;
  prevStep: () => void;
  isFirstStep: boolean;
  isLastStep: boolean;
}

const WizardContext = createContext<WizardContextValue | null>(null);

export function useWizard() {
  const context = useContext(WizardContext);
  if (!context) {
    throw new Error('useWizard must be used within FormWizard');
  }
  return context;
}

interface FormWizardProps {
  children: React.ReactNode;
  onComplete: (data: any) => void;
}

export function FormWizard({ children, onComplete }: FormWizardProps) {
  const [currentStep, setCurrentStep] = useState(0);
  const [formData, setFormData] = useState<any>({});

  const steps = React.Children.toArray(children);
  const totalSteps = steps.length;

  const goToStep = useCallback((step: number) => {
    if (step >= 0 && step < totalSteps) {
      setCurrentStep(step);
    }
  }, [totalSteps]);

  const nextStep = useCallback(() => {
    if (currentStep < totalSteps - 1) {
      setCurrentStep(prev => prev + 1);
    } else {
      onComplete(formData);
    }
  }, [currentStep, totalSteps, formData, onComplete]);

  const prevStep = useCallback(() => {
    if (currentStep > 0) {
      setCurrentStep(prev => prev - 1);
    }
  }, [currentStep]);

  const value = {
    currentStep,
    totalSteps,
    goToStep,
    nextStep,
    prevStep,
    isFirstStep: currentStep === 0,
    isLastStep: currentStep === totalSteps - 1,
  };

  return (
    <WizardContext.Provider value={value}>
      <div className="form-wizard">
        <WizardProgress />
        <div className="wizard-content">
          {React.cloneElement(steps[currentStep] as React.ReactElement, {
            data: formData,
            setData: setFormData,
          })}
        </div>
        <WizardNavigation />
      </div>
    </WizardContext.Provider>
  );
}

function WizardProgress() {
  const { currentStep, totalSteps } = useWizard();

  return (
    <div className="wizard-progress">
      {Array.from({ length: totalSteps }, (_, i) => (
        <div
          key={i}
          className={`progress-step ${i === currentStep ? 'active' : ''} ${
            i < currentStep ? 'completed' : ''
          }`}
        >
          <div className="step-number">{i + 1}</div>
        </div>
      ))}
    </div>
  );
}

function WizardNavigation() {
  const { prevStep, nextStep, isFirstStep, isLastStep } = useWizard();

  return (
    <div className="wizard-navigation">
      <button onClick={prevStep} disabled={isFirstStep}>
        Previous
      </button>
      <button onClick={nextStep}>
        {isLastStep ? 'Complete' : 'Next'}
      </button>
    </div>
  );
}

// Step components
interface StepProps {
  data?: any;
  setData?: (data: any) => void;
}

function PersonalInfoStep({ data = {}, setData }: StepProps) {
  return (
    <div className="wizard-step">
      <h2>Personal Information</h2>
      <div className="form-field">
        <label>First Name</label>
        <input
          value={data.firstName || ''}
          onChange={e => setData?.({ ...data, firstName: e.target.value })}
        />
      </div>
      <div className="form-field">
        <label>Last Name</label>
        <input
          value={data.lastName || ''}
          onChange={e => setData?.({ ...data, lastName: e.target.value })}
        />
      </div>
    </div>
  );
}

function ContactInfoStep({ data = {}, setData }: StepProps) {
  return (
    <div className="wizard-step">
      <h2>Contact Information</h2>
      <div className="form-field">
        <label>Email</label>
        <input
          type="email"
          value={data.email || ''}
          onChange={e => setData?.({ ...data, email: e.target.value })}
        />
      </div>
      <div className="form-field">
        <label>Phone</label>
        <input
          type="tel"
          value={data.phone || ''}
          onChange={e => setData?.({ ...data, phone: e.target.value })}
        />
      </div>
    </div>
  );
}

function ReviewStep({ data = {} }: StepProps) {
  return (
    <div className="wizard-step">
      <h2>Review</h2>
      <dl>
        <dt>Name</dt>
        <dd>{data.firstName} {data.lastName}</dd>
        <dt>Email</dt>
        <dd>{data.email}</dd>
        <dt>Phone</dt>
        <dd>{data.phone}</dd>
      </dl>
    </div>
  );
}

// Usage
function RegistrationWizard() {
  const handleComplete = (data: any) => {
    console.log('Form completed:', data);
  };

  return (
    <FormWizard onComplete={handleComplete}>
      <PersonalInfoStep />
      <ContactInfoStep />
      <ReviewStep />
    </FormWizard>
  );
}
```

These examples demonstrate production-ready patterns with proper TypeScript typing, error handling, and user experience considerations.
