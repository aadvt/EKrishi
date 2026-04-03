import pg from 'pg'
import 'dotenv/config'

const { Pool } = pg

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || process.env.NEON_DATABASE_URL,
})

export default pool
