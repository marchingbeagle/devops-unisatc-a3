export default ({ env }) => ({
  'users-permissions': {
    jwtSecret: env('JWT_SECRET'),
  },
});
