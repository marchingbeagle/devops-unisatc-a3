import { test, expect } from '@playwright/test';
import {
  adminLogin,
  getResourceWithRetry,
} from './helpers';
import { AuthorResponse } from './types';

const ADMIN_EMAIL = 'admin@satc.edu.br';
const ADMIN_PASSWORD = 'welcomeToStrapi123';
const BASE_URL = process.env.BASE_URL || 'http://localhost:1337';

test.describe('Author Collection E2E Tests', () => {
  let authToken: string;
  let apiToken: string;
  let authorId: number;

  test.beforeAll(async ({ request }) => {
    // Add a longer delay to avoid rate limiting issues
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Login to get admin authentication token with exponential backoff retry
    authToken = await adminLogin(request, ADMIN_EMAIL, ADMIN_PASSWORD);

    // Try to create an API token for API requests
    // Fallback to admin token if API token creation fails
    try {
      const tokenResponse = await request.post(
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

      if (tokenResponse.ok()) {
        const tokenData = await tokenResponse.json();
        apiToken = tokenData.data?.accessKey || tokenData.accessKey || authToken;
        console.log('API token created successfully');
      } else {
        const errorText = await tokenResponse.text();
        console.warn(`API token creation failed:`, tokenResponse.status(), errorText);
        apiToken = authToken;
      }
    } catch (e) {
      // Fallback to admin token
      console.warn('API token creation exception:', e);
      apiToken = authToken;
    }
  });

  test('should create a new author', async ({ request }) => {
    const authorData = {
      data: {
        name: 'John Doe',
        email: 'john.doe@example.com',
      },
    };

    const response = await request.post(`${BASE_URL}/api/authors`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data: authorData,
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.data).toBeDefined();
    expect(data.data.name).toBe('John Doe');
    expect(data.data.email).toBe('john.doe@example.com');
    authorId = data.data.id;
  });

  test('should list authors', async ({ request }) => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Create a new author for this test
    const createResponse = await request.post(`${BASE_URL}/api/authors`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data: {
        data: {
          name: 'Jane Smith',
          email: 'jane.smith@example.com',
        },
      },
    });
    
    if (!createResponse.ok()) {
      const errorText = await createResponse.text();
      console.error(`POST /api/authors failed:`, createResponse.status(), errorText);
    }
    expect(createResponse.ok()).toBeTruthy();
    const createData = await createResponse.json();
    const testAuthorId = createData.data.id;
    expect(testAuthorId).toBeDefined();

    // Wait for the author to be available in the database
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Test the list endpoint
    let listResponse = await request.get(`${BASE_URL}/api/authors`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });
    
    // If API token doesn't work, try with admin token
    if (!listResponse.ok() && (listResponse.status() === 401 || listResponse.status() === 403)) {
      listResponse = await request.get(`${BASE_URL}/api/authors`, {
        headers: {
          Authorization: `Bearer ${authToken}`,
        },
      });
    }
    
    expect(listResponse.ok()).toBeTruthy();
    const data = await listResponse.json();
    expect(data.data).toBeDefined();
    expect(Array.isArray(data.data)).toBe(true);
    expect(data.data.length).toBeGreaterThan(0);
    
    // Verify our created author is in the list
    const foundAuthor = data.data.find((author: any) => author.id === testAuthorId);
    expect(foundAuthor).toBeDefined();
    expect(foundAuthor.name).toBe('Jane Smith');
    expect(foundAuthor.email).toBe('jane.smith@example.com');
  });
});

