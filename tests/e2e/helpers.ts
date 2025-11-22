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
 * Publish an article explicitly
 * In Strapi 5, we can publish by updating the article with publishedAt set
 */
export async function publishArticle(
  request: APIRequestContext,
  articleId: number,
  apiToken: string
): Promise<void> {
  // First try the publish action endpoint (if it exists)
  let publishResponse = await request.post(
    `${BASE_URL}/api/articles/${articleId}/actions/publish`,
    {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
    }
  );

  // If publish endpoint doesn't exist, try updating with publishedAt
  if (!publishResponse.ok() && publishResponse.status() === 404) {
    // Get the current article first
    const getResponse = await request.get(`${BASE_URL}/api/articles/${articleId}`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    if (getResponse.ok()) {
      const articleData = await getResponse.json();
      // Update with publishedAt if not already set
      if (!articleData.data.publishedAt) {
        publishResponse = await request.put(
          `${BASE_URL}/api/articles/${articleId}`,
          {
            headers: {
              Authorization: `Bearer ${apiToken}`,
              'Content-Type': 'application/json',
            },
            data: {
              data: {
                publishedAt: new Date().toISOString(),
              },
            },
          }
        );
      }
    }
  }

  if (!publishResponse.ok()) {
    const errorText = await publishResponse.text();
    // If article is already published or endpoint doesn't exist, that's okay
    if (publishResponse.status() !== 404 && publishResponse.status() !== 400) {
      console.warn(`Publish article ${articleId} failed:`, publishResponse.status(), errorText);
    }
  }
}

/**
 * Create and publish an article
 */
export async function createAndPublishArticle(
  request: APIRequestContext,
  apiToken: string,
  articleData: {
    title: string;
    description: string;
    publishedAt?: string;
  }
): Promise<number> {
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

  // Wait a bit for the article to be created in the database
  await new Promise(resolve => setTimeout(resolve, 500));

  // Explicitly publish the article (this ensures it's published even if publishedAt didn't work)
  await publishArticle(request, articleId, apiToken);

  // Wait a bit longer for the article to be available after publishing
  await new Promise(resolve => setTimeout(resolve, 500));

  return articleId;
}

/**
 * Get a resource with retry logic
 */
export async function getResourceWithRetry<T>(
  request: APIRequestContext,
  url: string,
  apiToken: string,
  maxRetries: number = 5
): Promise<T> {
  let delay = 500;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    if (attempt > 0) {
      await new Promise(resolve => setTimeout(resolve, delay));
      delay *= 2; // Exponential backoff
    }

    const response = await request.get(url, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
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
      throw new Error(`GET ${url} failed after ${maxRetries} attempts: ${status} ${errorText}`);
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

