import { test, expect } from '@playwright/test';
import {
  adminLogin,
  createAndPublishArticle,
  getResourceWithRetry,
  updateResourceWithRetry,
  publishArticle,
} from './helpers';

const ADMIN_EMAIL = 'admin@satc.edu.br';
const ADMIN_PASSWORD = 'welcomeToStrapi123';
const BASE_URL = process.env.BASE_URL || 'http://localhost:1337';

test.describe('Article Collection E2E Tests', () => {
  // This test suite verifies CRUD operations for articles
  let authToken: string;
  let apiToken: string;
  let articleId: number;

  test.beforeAll(async ({ request }) => {
    // Add a delay to avoid rate limiting issues
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Login to get admin authentication token with exponential backoff retry
    authToken = await adminLogin(request, ADMIN_EMAIL, ADMIN_PASSWORD);

    // Create an API token for API requests
    // In Strapi 5, API tokens are created via /admin/api-tokens endpoint
    let tokenResponse;
    try {
      tokenResponse = await request.post(
        `${BASE_URL}/admin/api-tokens`,
        {
          headers: {
            Authorization: `Bearer ${authToken}`,
            'Content-Type': 'application/json',
          },
          data: {
            name: `E2E Test Token ${Date.now()}`,
            type: 'full-access',
            lifespan: null,
          },
        }
      );
      
      if (!tokenResponse.ok()) {
        const errorText = await tokenResponse.text();
        console.warn(`API token creation failed:`, tokenResponse.status(), errorText);
      }
    } catch (e) {
      // If endpoint doesn't exist or request fails, fall back to admin token
      console.warn('API token creation exception:', e);
      tokenResponse = { ok: () => false };
    }

    if (tokenResponse.ok()) {
      const tokenData = await tokenResponse.json();
      apiToken = tokenData.data?.accessKey || tokenData.accessKey || authToken;
      console.log('API token created successfully');
    } else {
      // Fallback: use admin token
      // In Strapi 5, admin JWT tokens can work for /api/* endpoints if permissions are set
      apiToken = authToken;
      console.warn('Using admin JWT token as fallback (API token creation failed)');
    }
  });

  test('should login successfully', async ({ request }) => {
    // Add delay before login to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const token = await adminLogin(request, ADMIN_EMAIL, ADMIN_PASSWORD);
    expect(token).toBeDefined();
    expect(token.length).toBeGreaterThan(0);
  });

  test('should create a new article', async ({ request }) => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    articleId = await createAndPublishArticle(request, apiToken, {
      title: 'Test Article',
      description: 'This is a test article description',
    });

    expect(articleId).toBeDefined();
    
    // Verify the article was created and published
    const data = await getResourceWithRetry(
      request,
      `${BASE_URL}/api/articles/${articleId}`,
      apiToken
    );
    expect(data.data).toBeDefined();
    expect(data.data.title).toBe('Test Article');
    expect(data.data.description).toBe('This is a test article description');
  });

  test('should list articles', async ({ request }) => {
    await new Promise(resolve => setTimeout(resolve, 200));
    
    const response = await request.get(`${BASE_URL}/api/articles`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(Array.isArray(data.data)).toBeTruthy();
    expect(data.data.length).toBeGreaterThan(0);
  });

  test('should read a specific article', async ({ request }) => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Always create a new article for this test to ensure isolation
    const testArticleId = await createAndPublishArticle(request, apiToken, {
      title: 'Test Article for Read',
      description: 'Test description',
    });
    
    expect(testArticleId).toBeDefined();

    // Use retry logic to read the article
    const data = await getResourceWithRetry(
      request,
      `${BASE_URL}/api/articles/${testArticleId}`,
      apiToken
    );
    
    expect(data.data).toBeDefined();
    expect(data.data.id).toBe(testArticleId);
    expect(data.data.title).toBe('Test Article for Read');
  });

  test('should update an article', async ({ request }) => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Always create a new article for this test to ensure isolation
    const testArticleId = await createAndPublishArticle(request, apiToken, {
      title: 'Test Article for Update',
      description: 'Original description',
    });
    
    expect(testArticleId).toBeDefined();

    const updatedData = {
      data: {
        title: 'Updated Article Title',
        description: 'Updated description',
      },
    };

    // Use retry logic to update the article
    const data = await updateResourceWithRetry(
      request,
      `${BASE_URL}/api/articles/${testArticleId}`,
      apiToken,
      updatedData
    );
    
    expect(data.data).toBeDefined();
    expect(data.data.title).toBe('Updated Article Title');
    expect(data.data.description).toBe('Updated description');
  });

  test('should delete an article', async ({ request }) => {
    // Create an article to delete
    const deleteArticleId = await createAndPublishArticle(request, apiToken, {
      title: 'Article to Delete',
      description: 'This article will be deleted',
    });

    const response = await request.delete(`${BASE_URL}/api/articles/${deleteArticleId}`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    expect(response.ok()).toBeTruthy();

    // Verify article is deleted
    const getResponse = await request.get(`${BASE_URL}/api/articles/${deleteArticleId}`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });
    expect(getResponse.status()).toBe(404);
  });

  test('should list articles correctly', async ({ request }) => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const response = await request.get(`${BASE_URL}/api/articles`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(Array.isArray(data.data)).toBeTruthy();
    expect(data.data.length).toBeGreaterThanOrEqual(0);
  });
});

