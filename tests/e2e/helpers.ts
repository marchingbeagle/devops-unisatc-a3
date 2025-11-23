import { APIRequestContext } from '@playwright/test';

const BASE_URL = process.env.BASE_URL || 'http://localhost:1337';

/**
 * Retry a request with exponential backoff
 */
export async function retryWithBackoff<T>(
  fn: () => Promise<T>,
  maxRetries: number = 5,
  initialDelay: number = 500,
  shouldRetry: (result: T) => boolean = () => false
): Promise<T> {
  let lastError: Error | null = null;
  let delay = initialDelay;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const result = await fn();
      if (!shouldRetry(result)) {
        return result;
      }
      // If shouldRetry returns true, treat as error and retry
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, delay));
        delay *= 2; // Exponential backoff
      }
    } catch (error) {
      lastError = error as Error;
      if (attempt < maxRetries) {
        await new Promise(resolve => setTimeout(resolve, delay));
        delay *= 2; // Exponential backoff
      }
    }
  }

  throw lastError || new Error('Max retries exceeded');
}

/**
 * Admin login with exponential backoff retry
 */
export async function adminLogin(
  request: APIRequestContext,
  email: string,
  password: string,
  maxRetries: number = 5
): Promise<string> {
  let delay = 1000; // Start with 1 second delay

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    if (attempt > 0) {
      await new Promise(resolve => setTimeout(resolve, delay));
      delay *= 2; // Exponential backoff
    }

    const loginResponse = await request.post(`${BASE_URL}/admin/login`, {
      data: {
        email,
        password,
      },
    });

    if (loginResponse.ok()) {
      const loginData = await loginResponse.json();
      return loginData.data.token;
    }

    const status = loginResponse.status();
    if (status === 429 && attempt < maxRetries) {
      // Rate limited, wait longer and retry
      continue;
    }

    const errorText = await loginResponse.text();
    if (attempt === maxRetries) {
      throw new Error(`Admin login failed after ${maxRetries} attempts: ${status} ${errorText}`);
    }
  }

  throw new Error('Admin login failed: Max retries exceeded');
}

/**
 * Create and publish an article
 * Sets publishedAt directly when creating to avoid needing a separate publish endpoint
 */
export async function createAndPublishArticle(
  request: APIRequestContext,
  apiToken: string,
  adminToken: string,
  articleData: {
    title: string;
    description: string;
    publishedAt?: string;
  }
): Promise<number> {
  // Set publishedAt directly to publish the article immediately
  // This is more reliable than using a separate publish endpoint
  const createResponse = await request.post(`${BASE_URL}/api/articles`, {
    headers: {
      Authorization: `Bearer ${apiToken}`,
      'Content-Type': 'application/json',
    },
    data: {
      data: {
        ...articleData,
        publishedAt: articleData.publishedAt || new Date().toISOString(),
      },
    },
  });

  if (!createResponse.ok()) {
    const errorText = await createResponse.text();
    throw new Error(`Failed to create article: ${createResponse.status()} ${errorText}`);
  }

  const createData = await createResponse.json();
  const articleId = createData.data.id;

  // Wait a bit for the article to be created and available in the database
  await new Promise(resolve => setTimeout(resolve, 1000));

  return articleId;
}

/**
 * Get a resource with retry logic
 * Supports fallback to admin token if API token doesn't have proper permissions
 */
export async function getResourceWithRetry<T>(
  request: APIRequestContext,
  url: string,
  apiToken: string,
  maxRetries: number = 5,
  adminToken?: string
): Promise<T> {
  let delay = 500;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    if (attempt > 0) {
      await new Promise(resolve => setTimeout(resolve, delay));
      delay *= 2; // Exponential backoff
    }

    // Try with API token first
    let response = await request.get(url, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    // If API token fails with 401/403 and we have an admin token, try with admin token
    const status = response.status();
    if ((status === 401 || status === 403) && adminToken && attempt === 0) {
      response = await request.get(url, {
        headers: {
          Authorization: `Bearer ${adminToken}`,
        },
      });
    }

    if (response.ok()) {
      return await response.json();
    }

    const finalStatus = response.status();
    if (finalStatus === 404 && attempt < maxRetries) {
      // Resource not found yet, retry
      continue;
    }

    const errorText = await response.text();
    if (attempt === maxRetries) {
      throw new Error(`GET ${url} failed after ${maxRetries} attempts: ${finalStatus} ${errorText}`);
    }
  }

  throw new Error(`GET ${url} failed: Max retries exceeded`);
}

/**
 * Update a resource with retry logic
 */
export async function updateResourceWithRetry<T>(
  request: APIRequestContext,
  url: string,
  apiToken: string,
  data: any,
  maxRetries: number = 5
): Promise<T> {
  let delay = 500;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    if (attempt > 0) {
      await new Promise(resolve => setTimeout(resolve, delay));
      delay *= 2; // Exponential backoff
    }

    const response = await request.put(url, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data,
    });

    if (response.ok()) {
      return await response.json();
    }

    const status = response.status();
    if (status === 404 && attempt < maxRetries) {
      // Resource not found yet, retry
      continue;
    }

    const errorText = await response.text();
    if (attempt === maxRetries) {
      throw new Error(`PUT ${url} failed after ${maxRetries} attempts: ${status} ${errorText}`);
    }
  }

  throw new Error(`PUT ${url} failed: Max retries exceeded`);
}

