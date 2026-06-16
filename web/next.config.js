/** @type {import('next').NextConfig} */
const nextConfig = {
  // Allow large clip uploads to the route handler if proxying through the API.
  // (Default flow uses presigned PUT straight to R2, so this is a safety margin.)
  experimental: {
    serverActions: { bodySizeLimit: "10mb" },
  },
};
module.exports = nextConfig;
