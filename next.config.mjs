/** @type {import('next').NextConfig} */
const nextConfig = {
  devIndicators: false,
  experimental: {
    agentUpgrade: 'security',
  },
  images: {
    unoptimized: true,
  },
}

export default nextConfig
