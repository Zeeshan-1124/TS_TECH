// import { PrismaClient } from '@prisma/client';

// const globalForPrisma = globalThis as unknown as { prisma: PrismaClient | undefined };

// export const prisma =
//   globalForPrisma.prisma ??
//   new PrismaClient({ log: ['error'] });

// if (process.env.NODE_ENV !== 'production') globalForPrisma.prisma = prisma;
import { PrismaClient } from '@prisma/client'
import { PrismaNeon } from '@prisma/adapter-neon'
import { neonConfig } from '@neondatabase/serverless'
import ws from 'ws'

neonConfig.webSocketConstructor = ws

const connectionString = process.env.DATABASE_URL!
const adapter = new PrismaNeon({ connectionString })

export const prisma = new PrismaClient({ adapter })