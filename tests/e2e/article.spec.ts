import { test, expect } from '@playwright/test';

const ADMIN_EMAIL = 'admin@satc.edu.br';
const ADMIN_PASSWORD = 'welcomeToStrapi123';
const BASE_URL = process.env.BASE_URL || 'http://localhost:1337';

test.describe('Article Collection E2E Tests', () => {
  let authToken: string;
  let apiToken: string;
  let articleId: number;

  test.beforeAll(async ({ request }) => {
    // Login to get admin authentication token
    const loginResponse = await request.post(`${BASE_URL}/admin/login`, {
      data: {
        email: ADMIN_EMAIL,
        password: ADMIN_PASSWORD,
      },
    });

    expect(loginResponse.ok()).toBeTruthy();
    const loginData = await loginResponse.json();
    authToken = loginData.data.token;

    // Create an API token for API requests
    // First, get the user ID
    const meResponse = await request.get(`${BASE_URL}/admin/users/me`, {
      headers: {
        Authorization: `Bearer ${authToken}`,
      },
    });
    const meData = await meResponse.json();

    // Create API token via content-manager API
    const tokenResponse = await request.post(
      `${BASE_URL}/admin/content-manager/collection-types/admin::api-token`,
      {
        headers: {
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json',
        },
        data: {
          name: 'E2E Test Token',
          type: 'full-access',
          lifespan: null,
        },
      }
    );

    if (tokenResponse.ok()) {
      const tokenData = await tokenResponse.json();
      apiToken = tokenData.accessKey;
    } else {
      // Fallback: use admin token (may work if permissions are set)
      apiToken = authToken;
    }
  });

  test('should login successfully', async ({ request }) => {
    const response = await request.post(`${BASE_URL}/admin/login`, {
      data: {
        email: ADMIN_EMAIL,
        password: ADMIN_PASSWORD,
      },
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.data.token).toBeDefined();
  });

  test('should create a new article', async ({ request }) => {
    const articleData = {
      data: {
        title: 'Test Article',
        description: 'This is a test article description',
        publishedAt: new Date().toISOString(),
      },
    };

    const response = await request.post(`${BASE_URL}/api/articles`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data: articleData,
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.data).toBeDefined();
    expect(data.data.title).toBe('Test Article');
    expect(data.data.description).toBe('This is a test article description');
    articleId = data.data.id;
  });

  test('should list articles', async ({ request }) => {
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
    if (!articleId) {
      // Create an article if we don't have one
      const createResponse = await request.post(`${BASE_URL}/api/articles`, {
        headers: {
          Authorization: `Bearer ${apiToken}`,
          'Content-Type': 'application/json',
        },
        data: {
          data: {
            title: 'Test Article for Read',
            description: 'Test description',
            publishedAt: new Date().toISOString(),
          },
        },
      });
      const createData = await createResponse.json();
      articleId = createData.data.id;
    }

    const response = await request.get(`${BASE_URL}/api/articles/${articleId}`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.data).toBeDefined();
    expect(data.data.id).toBe(articleId);
  });

  test('should update an article', async ({ request }) => {
    if (!articleId) {
      const createResponse = await request.post(`${BASE_URL}/api/articles`, {
        headers: {
          Authorization: `Bearer ${apiToken}`,
          'Content-Type': 'application/json',
        },
        data: {
          data: {
            title: 'Test Article for Update',
            description: 'Original description',
            publishedAt: new Date().toISOString(),
          },
        },
      });
      const createData = await createResponse.json();
      articleId = createData.data.id;
    }

    const updatedData = {
      data: {
        title: 'Updated Article Title',
        description: 'Updated description',
      },
    };

    const response = await request.put(`${BASE_URL}/api/articles/${articleId}`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data: updatedData,
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.data.title).toBe('Updated Article Title');
    expect(data.data.description).toBe('Updated description');
  });

  test('should delete an article', async ({ request }) => {
    // Create an article to delete
    const createResponse = await request.post(`${BASE_URL}/api/articles`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data: {
        data: {
          title: 'Article to Delete',
          description: 'This article will be deleted',
          publishedAt: new Date().toISOString(),
        },
      },
    });
    const createData = await createResponse.json();
    const deleteArticleId = createData.data.id;

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

  test('should fail intentionally for PR demonstration', async ({ request }) => {
    // This test intentionally fails to demonstrate CI failure detection
    const response = await request.get(`${BASE_URL}/api/articles`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    // Intentionally wrong assertion to make this test fail
    expect(data.data.length).toBe(-1); // This will always fail
  });
});

