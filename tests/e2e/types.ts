/**
 * Type definitions for Strapi API responses
 */

export interface StrapiResponse<T> {
  data: T;
  meta?: {
    pagination?: {
      page: number;
      pageSize: number;
      pageCount: number;
      total: number;
    };
  };
}

export interface Article {
  id: number;
  title: string;
  description: string;
  publishedAt?: string;
  createdAt?: string;
  updatedAt?: string;
  author?: Author | number;
}

export interface Author {
  id: number;
  name: string;
  email: string;
  createdAt?: string;
  updatedAt?: string;
  articles?: Article[];
}

export type ArticleResponse = StrapiResponse<Article>;
export type AuthorResponse = StrapiResponse<Author>;
export type ArticleListResponse = StrapiResponse<Article[]>;
export type AuthorListResponse = StrapiResponse<Author[]>;

