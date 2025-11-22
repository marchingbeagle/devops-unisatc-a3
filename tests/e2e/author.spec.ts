import { test, expect } from '@playwright/test';

const ADMIN_EMAIL = 'admin@satc.edu.br';
const ADMIN_PASSWORD = 'welcomeToStrapi123';
const BASE_URL = process.env.BASE_URL || 'http://localhost:1337';

test.describe('Author Collection E2E Tests', () => {
  let authToken: string;
  let apiToken: string;
  let authorId: number;

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

    // Try to create an API token for API requests
    // Fallback to admin token if API token creation fails
    try {
      const tokenResponse = await request.post(
        `${BASE_URL}/admin/content-manager/collection-types/admin::api-token`,
        {
          headers: {
            Authorization: `Bearer ${apiToken}`,
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
        apiToken = tokenData.accessKey || authToken;
      } else {
        apiToken = authToken;
      }
    } catch {
      // Fallback to admin token
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
    const response = await request.get(`${BASE_URL}/api/authors`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(Array.isArray(data.data)).toBeTruthy();
    expect(data.data.length).toBeGreaterThan(0);
  });

  test('should read a specific author', async ({ request }) => {
    if (!authorId) {
      // Create an author if we don't have one
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
      const createData = await createResponse.json();
      authorId = createData.data.id;
    }

    const response = await request.get(`${BASE_URL}/api/authors/${authorId}`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.data).toBeDefined();
    expect(data.data.id).toBe(authorId);
  });

  test('should update an author', async ({ request }) => {
    if (!authorId) {
      const createResponse = await request.post(`${BASE_URL}/api/authors`, {
        headers: {
          Authorization: `Bearer ${apiToken}`,
          'Content-Type': 'application/json',
        },
        data: {
          data: {
            name: 'Original Name',
            email: 'original@example.com',
          },
        },
      });
      const createData = await createResponse.json();
      authorId = createData.data.id;
    }

    const updatedData = {
      data: {
        name: 'Updated Author Name',
        email: 'updated@example.com',
      },
    };

    const response = await request.put(`${BASE_URL}/api/authors/${authorId}`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data: updatedData,
    });

    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.data.name).toBe('Updated Author Name');
    expect(data.data.email).toBe('updated@example.com');
  });

  test('should delete an author', async ({ request }) => {
    // Create an author to delete
    const createResponse = await request.post(`${BASE_URL}/api/authors`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data: {
        data: {
          name: 'Author to Delete',
          email: 'delete@example.com',
        },
      },
    });
    const createData = await createResponse.json();
    const deleteAuthorId = createData.data.id;

    const response = await request.delete(`${BASE_URL}/api/authors/${deleteAuthorId}`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });

    expect(response.ok()).toBeTruthy();

    // Verify author is deleted
    const getResponse = await request.get(`${BASE_URL}/api/authors/${deleteAuthorId}`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });
    expect(getResponse.status()).toBe(404);
  });

  test('should test author-article relationship', async ({ request }) => {
    // Create an author
    const authorResponse = await request.post(`${BASE_URL}/api/authors`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data: {
        data: {
          name: 'Relationship Test Author',
          email: 'relationship@example.com',
        },
      },
    });
    const authorData = await authorResponse.json();
    const testAuthorId = authorData.data.id;

    // Create an article with the author
    const articleResponse = await request.post(`${BASE_URL}/api/articles`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      data: {
        data: {
          title: 'Article with Author',
          description: 'Testing author relationship',
          author: testAuthorId,
          publishedAt: new Date().toISOString(),
        },
      },
    });

    expect(articleResponse.ok()).toBeTruthy();
    const articleData = await articleResponse.json();
    expect(articleData.data.author).toBeDefined();
    expect(articleData.data.author.id).toBe(testAuthorId);

    // Verify author has the article in its articles relation
    const authorGetResponse = await request.get(`${BASE_URL}/api/authors/${testAuthorId}?populate=articles`, {
      headers: {
        Authorization: `Bearer ${apiToken}`,
      },
    });
    expect(authorGetResponse.ok()).toBeTruthy();
    const authorWithArticles = await authorGetResponse.json();
    expect(authorWithArticles.data.articles).toBeDefined();
  });
});

