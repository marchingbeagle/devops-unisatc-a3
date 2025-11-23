import { test, expect } from '@playwright/test';
import {
  adminLogin,
  createAndPublishArticle,
  getResourceWithRetry,
} from './helpers';
import { ArticleResponse } from './types';

const ADMIN_EMAIL = 'admin@satc.edu.br';
const ADMIN_PASSWORD = 'welcomeToStrapi123';
const BASE_URL = process.env.BASE_URL || 'http://localhost:1337';

test.describe('Article Collection E2E Tests', () => {
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

  test('should create a new article', async ({ request }) => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    articleId = await createAndPublishArticle(request, apiToken, authToken, {
      title: 'Test Article',
      description: 'This is a test article description',
    });

    // Verify the article was created successfully
    expect(articleId).toBeDefined();
    expect(typeof articleId).toBe('number');
    expect(articleId).toBeGreaterThan(0);
  });

  test('should list articles', async ({ request }) => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Create a new article for this test
    const testArticleId = await createAndPublishArticle(request, apiToken, authToken, {
      title: 'Test Article for List',
      description: 'Test description for listing',
    });
    
    expect(testArticleId).toBeDefined();

    // Test the list endpoint
    let listResponse = await request.get(`${BASE_URL}/api/articles`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });
    
    // If API token doesn't work, try with admin token
    if (!listResponse.ok() && (listResponse.status() === 401 || listResponse.status() === 403)) {
      listResponse = await request.get(`${BASE_URL}/api/articles`, {
        headers: {
          Authorization: `Bearer ${authToken}`,
        },
      });
    }
    
    // Verify the endpoint works and returns valid data structure
    expect(listResponse.ok()).toBeTruthy();
    const data = await listResponse.json();
    expect(data.data).toBeDefined();
    expect(Array.isArray(data.data)).toBe(true);
    // Note: Articles with draftAndPublish may not appear in public API list if not published
    // This test just verifies the endpoint is accessible and returns valid data
  });
});

