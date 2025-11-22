import { test, expect } from '@playwright/test';
import {
  adminLogin,
  getResourceWithRetry,
  updateResourceWithRetry,
  createAndPublishArticle,
} from './helpers';

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
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Always create a new author for this test to ensure isolation
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

    // Wait a bit for the author to be available
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Use retry logic to read the author
    const data = await getResourceWithRetry(
      request,
      `${BASE_URL}/api/authors/${testAuthorId}`,
      apiToken
    );
    
    expect(data.data).toBeDefined();
    expect(data.data.id).toBe(testAuthorId);
    expect(data.data.name).toBe('Jane Smith');
  });

  test('should update an author', async ({ request }) => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Always create a new author for this test to ensure isolation
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
    
    if (!createResponse.ok()) {
      const errorText = await createResponse.text();
      console.error(`POST /api/authors failed:`, createResponse.status(), errorText);
    }
    expect(createResponse.ok()).toBeTruthy();
    const createData = await createResponse.json();
    const testAuthorId = createData.data.id;
    expect(testAuthorId).toBeDefined();

    // Wait a bit for the author to be available before updating
    await new Promise(resolve => setTimeout(resolve, 500));

    const updatedData = {
      data: {
        name: 'Updated Author Name',
        email: 'updated@example.com',
      },
    };

    // Use retry logic to update the author
    const data = await updateResourceWithRetry(
      request,
      `${BASE_URL}/api/authors/${testAuthorId}`,
      apiToken,
      updatedData
    );
    
    expect(data.data).toBeDefined();
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

    // Wait for author to be available
    await new Promise(resolve => setTimeout(resolve, 500));

    // Create and publish an article with the author
    const articleId = await createAndPublishArticle(request, apiToken, {
      title: 'Article with Author',
      description: 'Testing author relationship',
    });

    // Update the article to set the author relationship
    await updateResourceWithRetry(
      request,
      `${BASE_URL}/api/articles/${articleId}`,
      apiToken,
      {
        data: {
          author: testAuthorId,
        },
      }
    );

    // Verify article has the author
    const articleData = await getResourceWithRetry(
      request,
      `${BASE_URL}/api/articles/${articleId}?populate=author`,
      apiToken
    );
    expect(articleData.data.author).toBeDefined();
    expect(articleData.data.author.id).toBe(testAuthorId);

    // Verify author has the article in its articles relation
    const authorWithArticles = await getResourceWithRetry(
      request,
      `${BASE_URL}/api/authors/${testAuthorId}?populate=articles`,
      apiToken
    );
    expect(authorWithArticles.data.articles).toBeDefined();
  });
});

