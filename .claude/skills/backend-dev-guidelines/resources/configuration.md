# Configuration Management

## Environment Variables

### Setup

Use `dotenv` for environment variable management:

```bash
npm install dotenv
npm install -D @types/node
```

### .env File Structure

```bash
# .env (never commit this file!)

# Application
NODE_ENV=development
PORT=3000
APP_NAME=MyApp
API_VERSION=v1

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=myapp_dev
DB_USER=postgres
DB_PASSWORD=secret
DB_POOL_MIN=2
DB_POOL_MAX=10

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Authentication
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRY=24h
REFRESH_TOKEN_EXPIRY=7d

# External Services
STRIPE_SECRET_KEY=sk_test_xxxxx
SENDGRID_API_KEY=SG.xxxxx
AWS_ACCESS_KEY_ID=xxxxx
AWS_SECRET_ACCESS_KEY=xxxxx
AWS_REGION=us-east-1
AWS_S3_BUCKET=my-bucket

# Monitoring
SENTRY_DSN=https://xxxxx@sentry.io/xxxxx
LOG_LEVEL=debug

# Feature Flags
FEATURE_NEW_CHECKOUT=false
FEATURE_EMAIL_NOTIFICATIONS=true
```

### .env.example Template

```bash
# .env.example (commit this file!)

# Application
NODE_ENV=development
PORT=3000
APP_NAME=MyApp

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=
DB_USER=
DB_PASSWORD=

# Add all required variables without values
# This serves as documentation for required configuration
```

## Configuration Module

### Type-Safe Configuration

```typescript
// config/app.ts
import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config({
  path: path.resolve(process.cwd(), `.env.${process.env.NODE_ENV || 'development'}`)
});

interface Config {
  env: string;
  port: number;
  appName: string;
  apiVersion: string;

  database: {
    host: string;
    port: number;
    name: string;
    user: string;
    password: string;
    poolMin: number;
    poolMax: number;
  };

  redis: {
    host: string;
    port: number;
    password?: string;
  };

  auth: {
    jwtSecret: string;
    jwtExpiry: string;
    refreshTokenExpiry: string;
  };

  externalServices: {
    stripe: {
      secretKey: string;
    };
    sendgrid: {
      apiKey: string;
    };
    aws: {
      accessKeyId: string;
      secretAccessKey: string;
      region: string;
      s3Bucket: string;
    };
  };

  monitoring: {
    sentryDsn?: string;
    logLevel: string;
  };

  features: {
    newCheckout: boolean;
    emailNotifications: boolean;
  };
}

function getEnvVar(key: string, defaultValue?: string): string {
  const value = process.env[key] || defaultValue;
  if (value === undefined) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value;
}

function getEnvVarAsNumber(key: string, defaultValue?: number): number {
  const value = process.env[key];
  if (value === undefined) {
    if (defaultValue === undefined) {
      throw new Error(`Missing required environment variable: ${key}`);
    }
    return defaultValue;
  }
  const parsed = parseInt(value, 10);
  if (isNaN(parsed)) {
    throw new Error(`Environment variable ${key} must be a number`);
  }
  return parsed;
}

function getEnvVarAsBoolean(key: string, defaultValue = false): boolean {
  const value = process.env[key];
  if (value === undefined) return defaultValue;
  return value.toLowerCase() === 'true';
}

const config: Config = {
  env: getEnvVar('NODE_ENV', 'development'),
  port: getEnvVarAsNumber('PORT', 3000),
  appName: getEnvVar('APP_NAME', 'MyApp'),
  apiVersion: getEnvVar('API_VERSION', 'v1'),

  database: {
    host: getEnvVar('DB_HOST'),
    port: getEnvVarAsNumber('DB_PORT', 5432),
    name: getEnvVar('DB_NAME'),
    user: getEnvVar('DB_USER'),
    password: getEnvVar('DB_PASSWORD'),
    poolMin: getEnvVarAsNumber('DB_POOL_MIN', 2),
    poolMax: getEnvVarAsNumber('DB_POOL_MAX', 10)
  },

  redis: {
    host: getEnvVar('REDIS_HOST', 'localhost'),
    port: getEnvVarAsNumber('REDIS_PORT', 6379),
    password: process.env.REDIS_PASSWORD
  },

  auth: {
    jwtSecret: getEnvVar('JWT_SECRET'),
    jwtExpiry: getEnvVar('JWT_EXPIRY', '24h'),
    refreshTokenExpiry: getEnvVar('REFRESH_TOKEN_EXPIRY', '7d')
  },

  externalServices: {
    stripe: {
      secretKey: getEnvVar('STRIPE_SECRET_KEY')
    },
    sendgrid: {
      apiKey: getEnvVar('SENDGRID_API_KEY')
    },
    aws: {
      accessKeyId: getEnvVar('AWS_ACCESS_KEY_ID'),
      secretAccessKey: getEnvVar('AWS_SECRET_ACCESS_KEY'),
      region: getEnvVar('AWS_REGION', 'us-east-1'),
      s3Bucket: getEnvVar('AWS_S3_BUCKET')
    }
  },

  monitoring: {
    sentryDsn: process.env.SENTRY_DSN,
    logLevel: getEnvVar('LOG_LEVEL', 'info')
  },

  features: {
    newCheckout: getEnvVarAsBoolean('FEATURE_NEW_CHECKOUT'),
    emailNotifications: getEnvVarAsBoolean('FEATURE_EMAIL_NOTIFICATIONS', true)
  }
};

export default config;
```

### Usage

```typescript
// Anywhere in your app
import config from './config/app';

// Type-safe access
const dbHost = config.database.host;
const port = config.port;

if (config.features.newCheckout) {
  // Use new checkout flow
}
```

## Database Configuration

```typescript
// config/database.ts
import { Sequelize } from 'sequelize';
import config from './app';
import logger from './logger';

export const sequelize = new Sequelize({
  dialect: 'postgres',
  host: config.database.host,
  port: config.database.port,
  database: config.database.name,
  username: config.database.user,
  password: config.database.password,

  pool: {
    min: config.database.poolMin,
    max: config.database.poolMax,
    acquire: 30000,
    idle: 10000
  },

  logging: config.env === 'development'
    ? (msg) => logger.debug(msg)
    : false,

  define: {
    timestamps: true,
    underscored: true,
    freezeTableName: true
  }
});

// Test connection
export async function testConnection(): Promise<void> {
  try {
    await sequelize.authenticate();
    logger.info('Database connection established successfully');
  } catch (error) {
    logger.error('Unable to connect to database:', error);
    throw error;
  }
}
```

## Logger Configuration

```typescript
// config/logger.ts
import winston from 'winston';
import config from './app';

const levels = {
  error: 0,
  warn: 1,
  info: 2,
  http: 3,
  debug: 4
};

const level = () => {
  return config.monitoring.logLevel || 'info';
};

const colors = {
  error: 'red',
  warn: 'yellow',
  info: 'green',
  http: 'magenta',
  debug: 'white'
};

winston.addColors(colors);

const format = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss:ms' }),
  winston.format.colorize({ all: true }),
  winston.format.printf(
    (info) => `${info.timestamp} ${info.level}: ${info.message}`
  )
);

const transports = [
  new winston.transports.Console(),
  new winston.transports.File({
    filename: 'logs/error.log',
    level: 'error'
  }),
  new winston.transports.File({ filename: 'logs/all.log' })
];

const logger = winston.createLogger({
  level: level(),
  levels,
  format,
  transports
});

export default logger;
```

## Multiple Environment Support

### Environment-Specific Files

```
.env.development
.env.test
.env.staging
.env.production
```

### Loading Strategy

```typescript
// config/env.ts
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

export function loadEnv(): void {
  const env = process.env.NODE_ENV || 'development';
  const envPath = path.resolve(process.cwd(), `.env.${env}`);

  // Check if env file exists
  if (!fs.existsSync(envPath)) {
    console.warn(`Warning: ${envPath} not found, using .env`);
    dotenv.config();
  } else {
    dotenv.config({ path: envPath });
  }

  // Optionally load .env.local for local overrides (never commit this)
  const localPath = path.resolve(process.cwd(), '.env.local');
  if (fs.existsSync(localPath)) {
    dotenv.config({ path: localPath, override: true });
  }
}
```

## Feature Flags

### Simple Feature Flag Service

```typescript
// services/featureFlagService.ts
import config from '../config/app';

export class FeatureFlagService {
  isEnabled(featureName: keyof typeof config.features): boolean {
    return config.features[featureName] === true;
  }

  // Can be extended to support user-specific flags
  isEnabledForUser(featureName: string, userId: string): boolean {
    // Check database or external service for user-specific flags
    return this.isEnabled(featureName as any);
  }
}

export const featureFlagService = new FeatureFlagService();
```

### Usage

```typescript
import { featureFlagService } from '../services/featureFlagService';

// In controller or service
if (featureFlagService.isEnabled('newCheckout')) {
  return await newCheckoutService.process(order);
} else {
  return await oldCheckoutService.process(order);
}
```

## Secrets Management

### For Production

**Don't use .env files in production!** Use proper secrets management:

1. **AWS Secrets Manager**
2. **HashiCorp Vault**
3. **Azure Key Vault**
4. **Google Secret Manager**
5. **Kubernetes Secrets**

### Example with AWS Secrets Manager

```typescript
// config/secrets.ts
import { SecretsManager } from 'aws-sdk';

const secretsManager = new SecretsManager({ region: 'us-east-1' });

export async function loadSecrets(): Promise<void> {
  if (process.env.NODE_ENV === 'production') {
    const secretName = process.env.AWS_SECRET_NAME;

    try {
      const data = await secretsManager
        .getSecretValue({ SecretId: secretName })
        .promise();

      const secrets = JSON.parse(data.SecretString || '{}');

      // Merge secrets into process.env
      Object.assign(process.env, secrets);
    } catch (error) {
      console.error('Failed to load secrets:', error);
      throw error;
    }
  }
}
```

## Validation on Startup

```typescript
// config/validation.ts
import config from './app';
import logger from './logger';

export function validateConfig(): void {
  const required = [
    'database.host',
    'database.name',
    'database.user',
    'database.password',
    'auth.jwtSecret'
  ];

  const missing: string[] = [];

  for (const path of required) {
    const value = path.split('.').reduce((obj, key) => obj?.[key], config as any);
    if (!value) {
      missing.push(path);
    }
  }

  if (missing.length > 0) {
    logger.error('Missing required configuration:', missing);
    throw new Error(`Missing required configuration: ${missing.join(', ')}`);
  }

  // Validate specific values
  if (config.env === 'production' && config.auth.jwtSecret.length < 32) {
    throw new Error('JWT secret must be at least 32 characters in production');
  }

  logger.info('Configuration validated successfully');
}
```

### Use in App Startup

```typescript
// app.ts
import { loadEnv } from './config/env';
import { validateConfig } from './config/validation';
import { testConnection } from './config/database';

async function bootstrap() {
  // 1. Load environment variables
  loadEnv();

  // 2. Validate configuration
  validateConfig();

  // 3. Test database connection
  await testConnection();

  // 4. Start server
  app.listen(config.port, () => {
    logger.info(`Server running on port ${config.port}`);
  });
}

bootstrap().catch(error => {
  logger.error('Failed to start application:', error);
  process.exit(1);
});
```

## Best Practices

1. **Never commit secrets** - Use .gitignore for .env files
2. **Provide .env.example** - Document all required variables
3. **Validate on startup** - Fail fast if configuration is invalid
4. **Use type-safe config** - Single source of truth for configuration
5. **Different configs per environment** - .env.development, .env.production, etc.
6. **Use secrets management in production** - Not .env files
7. **Document all variables** - What they do and valid values
8. **Use sensible defaults** - Where appropriate
9. **Fail early** - Don't start app with invalid config
10. **Keep secrets out of logs** - Never log passwords, API keys, etc.

## Common Pitfalls

1. **Committing .env to git** - Add to .gitignore!
2. **No validation** - App crashes at runtime instead of startup
3. **String instead of number** - Parse PORT to number
4. **No defaults for optional config** - App breaks unnecessarily
5. **Hardcoded values** - Use environment variables instead
6. **Logging secrets** - Filter sensitive data from logs
7. **Using .env in production** - Use proper secrets management
8. **No .env.example** - New developers don't know what's needed

## Summary

- Use environment variables for all configuration
- Create type-safe configuration module
- Validate configuration on startup
- Use different .env files per environment
- Never commit secrets to git
- Use proper secrets management in production
- Provide .env.example for documentation
- Implement feature flags for gradual rollouts
