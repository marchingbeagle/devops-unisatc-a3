#!/usr/bin/env node

/**
 * Script to generate Strapi secrets
 * Usage: node scripts/generate-secrets.js
 */

const crypto = require('crypto');

function generateSecret(length = 32) {
  return crypto.randomBytes(length).toString('base64');
}

console.log('\n🔐 Strapi Secrets Generator\n');
console.log('Copy these values to your .env file and GitHub Secrets:\n');
console.log('─'.repeat(60));

// Generate APP_KEYS (4 keys, comma-separated)
const appKeys = Array.from({ length: 4 }, () => generateSecret(32));
console.log('\nAPP_KEYS=' + appKeys.join(','));

// Generate other secrets
console.log('\nADMIN_JWT_SECRET=' + generateSecret(32));
console.log('\nJWT_SECRET=' + generateSecret(32));
console.log('\nAPI_TOKEN_SALT=' + generateSecret(32));
console.log('\nTRANSFER_TOKEN_SALT=' + generateSecret(32));

console.log('\n' + '─'.repeat(60));
console.log('\n✅ Secrets generated successfully!');
console.log('\n📝 Next steps:');
console.log('   1. Copy these values to your .env file');
console.log('   2. Add them as GitHub Secrets in your repository');
console.log('   3. Keep them secure - never commit them to Git!\n');

