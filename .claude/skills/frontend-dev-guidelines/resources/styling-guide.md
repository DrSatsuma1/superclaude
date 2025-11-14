# Styling Guide

Best practices for styling React applications using various CSS methodologies.

## Table of Contents

- [CSS Modules](#css-modules)
- [Tailwind CSS](#tailwind-css)
- [CSS-in-JS](#css-in-js)
- [Sass/SCSS](#sassscss)
- [Design Tokens](#design-tokens)
- [Responsive Design](#responsive-design)

## CSS Modules

### Basic Usage

```typescript
// Button.module.css
.button {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.button:hover {
  opacity: 0.9;
}

.primary {
  background-color: #007bff;
  color: white;
}

.secondary {
  background-color: #6c757d;
  color: white;
}

.small {
  padding: 0.25rem 0.5rem;
  font-size: 0.875rem;
}

.large {
  padding: 0.75rem 1.5rem;
  font-size: 1.125rem;
}

// Button.tsx
import styles from './Button.module.css';
import { ButtonHTMLAttributes } from 'react';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary';
  size?: 'small' | 'medium' | 'large';
}

export function Button({
  variant = 'primary',
  size = 'medium',
  className = '',
  children,
  ...props
}: ButtonProps) {
  const classes = [
    styles.button,
    styles[variant],
    size !== 'medium' && styles[size],
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <button className={classes} {...props}>
      {children}
    </button>
  );
}
```

### Composition

```css
/* Card.module.css */
.card {
  border: 1px solid #ddd;
  border-radius: 8px;
  padding: 1rem;
  background: white;
}

.elevated {
  composes: card;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.interactive {
  composes: card;
  cursor: pointer;
  transition: transform 0.2s;
}

.interactive:hover {
  transform: translateY(-2px);
}
```

### Global Styles

```css
/* globals.css */
:root {
  --color-primary: #007bff;
  --color-secondary: #6c757d;
  --color-success: #28a745;
  --color-danger: #dc3545;
  --spacing-unit: 0.5rem;
  --border-radius: 4px;
}

* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen,
    Ubuntu, Cantarell, sans-serif;
  line-height: 1.6;
  color: #333;
}
```

## Tailwind CSS

### Component Styling

```typescript
// Button with Tailwind
interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
}

export function Button({
  variant = 'primary',
  size = 'md',
  className = '',
  children,
  ...props
}: ButtonProps) {
  const baseClasses = 'font-medium rounded transition-colors focus:outline-none focus:ring-2';

  const variantClasses = {
    primary: 'bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500',
    secondary: 'bg-gray-600 text-white hover:bg-gray-700 focus:ring-gray-500',
    danger: 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500',
  };

  const sizeClasses = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-base',
    lg: 'px-6 py-3 text-lg',
  };

  const classes = [
    baseClasses,
    variantClasses[variant],
    sizeClasses[size],
    className,
  ].join(' ');

  return (
    <button className={classes} {...props}>
      {children}
    </button>
  );
}
```

### Using clsx/classnames

```typescript
import clsx from 'clsx';

interface CardProps {
  elevated?: boolean;
  interactive?: boolean;
  selected?: boolean;
  className?: string;
  children: React.ReactNode;
}

export function Card({
  elevated,
  interactive,
  selected,
  className,
  children,
}: CardProps) {
  return (
    <div
      className={clsx(
        'rounded-lg border border-gray-200 bg-white p-4',
        {
          'shadow-lg': elevated,
          'cursor-pointer transition-transform hover:-translate-y-1': interactive,
          'ring-2 ring-blue-500': selected,
        },
        className
      )}
    >
      {children}
    </div>
  );
}
```

### Custom Tailwind Configuration

```javascript
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#f0f9ff',
          100: '#e0f2fe',
          500: '#0ea5e9',
          600: '#0284c7',
          700: '#0369a1',
          900: '#0c4a6e',
        },
      },
      spacing: {
        128: '32rem',
        144: '36rem',
      },
      borderRadius: {
        '4xl': '2rem',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['Fira Code', 'monospace'],
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
};
```

### Responsive Design

```typescript
export function ResponsiveCard() {
  return (
    <div className="
      w-full
      p-4
      sm:w-1/2 sm:p-6
      md:w-1/3
      lg:w-1/4 lg:p-8
      xl:w-1/5
    ">
      <h3 className="text-lg sm:text-xl md:text-2xl">
        Responsive Heading
      </h3>
      <p className="text-sm sm:text-base">
        Responsive text
      </p>
    </div>
  );
}
```

## CSS-in-JS

### Styled Components

```typescript
import styled from 'styled-components';

interface ButtonProps {
  variant?: 'primary' | 'secondary';
  size?: 'small' | 'medium' | 'large';
}

const StyledButton = styled.button<ButtonProps>`
  padding: ${props => {
    switch (props.size) {
      case 'small': return '0.25rem 0.5rem';
      case 'large': return '0.75rem 1.5rem';
      default: return '0.5rem 1rem';
    }
  }};

  background-color: ${props =>
    props.variant === 'secondary' ? '#6c757d' : '#007bff'};

  color: white;
  border: none;
  border-radius: 4px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;

  &:hover {
    opacity: 0.9;
  }

  &:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
`;

export function Button({ children, ...props }: ButtonProps & { children: React.ReactNode }) {
  return <StyledButton {...props}>{children}</StyledButton>;
}
```

### Emotion

```typescript
/** @jsxImportSource @emotion/react */
import { css } from '@emotion/react';

interface CardProps {
  elevated?: boolean;
  children: React.ReactNode;
}

export function Card({ elevated, children }: CardProps) {
  const cardStyles = css`
    padding: 1rem;
    border-radius: 8px;
    background: white;
    border: 1px solid #ddd;

    ${elevated && css`
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    `}
  `;

  return <div css={cardStyles}>{children}</div>;
}

// Using styled
import styled from '@emotion/styled';

const Container = styled.div<{ maxWidth?: string }>`
  width: 100%;
  max-width: ${props => props.maxWidth || '1200px'};
  margin: 0 auto;
  padding: 0 1rem;
`;

export function Layout({ children }: { children: React.ReactNode }) {
  return <Container maxWidth="1400px">{children}</Container>;
}
```

### Theme Support

```typescript
import { ThemeProvider, createTheme } from '@mui/material/styles';
import { css, Global } from '@emotion/react';

const theme = createTheme({
  palette: {
    primary: {
      main: '#007bff',
    },
    secondary: {
      main: '#6c757d',
    },
  },
  typography: {
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
  },
  spacing: 8,
});

function App() {
  return (
    <ThemeProvider theme={theme}>
      <Global
        styles={css`
          * {
            box-sizing: border-box;
          }
          body {
            margin: 0;
            font-family: ${theme.typography.fontFamily};
          }
        `}
      />
      <YourApp />
    </ThemeProvider>
  );
}
```

## Sass/SCSS

### Variables and Mixins

```scss
// _variables.scss
$color-primary: #007bff;
$color-secondary: #6c757d;
$color-success: #28a745;
$color-danger: #dc3545;

$spacing-unit: 0.5rem;
$border-radius: 4px;

$breakpoint-sm: 576px;
$breakpoint-md: 768px;
$breakpoint-lg: 992px;
$breakpoint-xl: 1200px;

// _mixins.scss
@mixin flex-center {
  display: flex;
  align-items: center;
  justify-content: center;
}

@mixin respond-to($breakpoint) {
  @if $breakpoint == 'sm' {
    @media (min-width: $breakpoint-sm) { @content; }
  } @else if $breakpoint == 'md' {
    @media (min-width: $breakpoint-md) { @content; }
  } @else if $breakpoint == 'lg' {
    @media (min-width: $breakpoint-lg) { @content; }
  } @else if $breakpoint == 'xl' {
    @media (min-width: $breakpoint-xl) { @content; }
  }
}

@mixin button-variant($bg-color, $text-color: white) {
  background-color: $bg-color;
  color: $text-color;

  &:hover {
    background-color: darken($bg-color, 10%);
  }

  &:active {
    background-color: darken($bg-color, 15%);
  }
}

// Button.scss
@import './variables';
@import './mixins';

.button {
  padding: $spacing-unit * 2 $spacing-unit * 4;
  border: none;
  border-radius: $border-radius;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;

  &--primary {
    @include button-variant($color-primary);
  }

  &--secondary {
    @include button-variant($color-secondary);
  }

  &--small {
    padding: $spacing-unit $spacing-unit * 2;
    font-size: 0.875rem;
  }

  &--large {
    padding: $spacing-unit * 3 $spacing-unit * 6;
    font-size: 1.125rem;
  }
}
```

### BEM Methodology

```scss
// Card.scss
.card {
  padding: 1rem;
  border-radius: 8px;
  background: white;
  border: 1px solid #ddd;

  &__header {
    margin-bottom: 1rem;
    padding-bottom: 0.5rem;
    border-bottom: 1px solid #eee;
  }

  &__title {
    font-size: 1.25rem;
    font-weight: 600;
    margin: 0;
  }

  &__subtitle {
    font-size: 0.875rem;
    color: #666;
    margin: 0.25rem 0 0;
  }

  &__body {
    margin-bottom: 1rem;
  }

  &__footer {
    display: flex;
    justify-content: flex-end;
    gap: 0.5rem;
  }

  &--elevated {
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  }

  &--interactive {
    cursor: pointer;
    transition: transform 0.2s;

    &:hover {
      transform: translateY(-2px);
    }
  }
}
```

## Design Tokens

### CSS Custom Properties

```css
/* tokens.css */
:root {
  /* Colors */
  --color-primary-50: #f0f9ff;
  --color-primary-100: #e0f2fe;
  --color-primary-500: #0ea5e9;
  --color-primary-600: #0284c7;
  --color-primary-700: #0369a1;

  /* Spacing */
  --space-1: 0.25rem;
  --space-2: 0.5rem;
  --space-3: 0.75rem;
  --space-4: 1rem;
  --space-6: 1.5rem;
  --space-8: 2rem;

  /* Typography */
  --font-size-xs: 0.75rem;
  --font-size-sm: 0.875rem;
  --font-size-base: 1rem;
  --font-size-lg: 1.125rem;
  --font-size-xl: 1.25rem;
  --font-size-2xl: 1.5rem;

  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;

  /* Shadows */
  --shadow-sm: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1);

  /* Border Radius */
  --radius-sm: 0.125rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;
  --radius-full: 9999px;

  /* Transitions */
  --transition-fast: 150ms ease;
  --transition-base: 200ms ease;
  --transition-slow: 300ms ease;
}

[data-theme='dark'] {
  --color-primary-50: #0c4a6e;
  --color-primary-100: #075985;
  /* ... other dark theme values */
}
```

### TypeScript Token Types

```typescript
// tokens.ts
export const tokens = {
  colors: {
    primary: {
      50: '#f0f9ff',
      100: '#e0f2fe',
      500: '#0ea5e9',
      600: '#0284c7',
      700: '#0369a1',
    },
    gray: {
      50: '#f9fafb',
      100: '#f3f4f6',
      500: '#6b7280',
      600: '#4b5563',
      900: '#111827',
    },
  },
  spacing: {
    1: '0.25rem',
    2: '0.5rem',
    3: '0.75rem',
    4: '1rem',
    6: '1.5rem',
    8: '2rem',
  },
  fontSize: {
    xs: '0.75rem',
    sm: '0.875rem',
    base: '1rem',
    lg: '1.125rem',
    xl: '1.25rem',
    '2xl': '1.5rem',
  },
} as const;

export type Color = keyof typeof tokens.colors;
export type ColorShade = keyof typeof tokens.colors.primary;
export type Spacing = keyof typeof tokens.spacing;
export type FontSize = keyof typeof tokens.fontSize;
```

## Responsive Design

### Mobile-First Approach

```css
/* Base styles (mobile) */
.container {
  padding: 1rem;
  width: 100%;
}

.grid {
  display: grid;
  gap: 1rem;
  grid-template-columns: 1fr;
}

/* Tablet and up */
@media (min-width: 768px) {
  .container {
    padding: 2rem;
  }

  .grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

/* Desktop and up */
@media (min-width: 1024px) {
  .container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 3rem;
  }

  .grid {
    grid-template-columns: repeat(3, 1fr);
    gap: 2rem;
  }
}
```

### Container Queries

```css
.card-container {
  container-type: inline-size;
  container-name: card;
}

.card {
  padding: 1rem;
}

.card__title {
  font-size: 1rem;
}

/* When container is wider than 400px */
@container card (min-width: 400px) {
  .card {
    display: flex;
    gap: 1rem;
  }

  .card__title {
    font-size: 1.25rem;
  }
}
```

## Best Practices

1. **Consistent naming**: Use BEM or similar convention
2. **CSS variables**: For themeable properties
3. **Mobile-first**: Start with mobile styles, add breakpoints up
4. **Avoid deep nesting**: Keep specificity low (max 3 levels)
5. **Composition over duplication**: Reuse styles via composition
6. **Performance**: Minimize CSS bundle size, use critical CSS
7. **Accessibility**: Ensure sufficient color contrast, focus styles
8. **Dark mode**: Support system preference and manual toggle
9. **Type safety**: Use TypeScript for dynamic styles
10. **Documentation**: Document color systems and spacing scales
