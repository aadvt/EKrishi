import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import { pathToFileURL } from 'url'
import farmersRouter from '../src/routes/farmers.js'
import listingsRouter from '../src/routes/listings.js'

const app = express()

app.use(cors())
app.use(express.json())

app.get('/health', (req, res) => res.json({ status: 'ok' }))
app.use('/farmers', farmersRouter)
app.use('/listings', listingsRouter)

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const port = Number(process.env.PORT) || 3000
  app.listen(port, () => {
    console.log(`API listening on port ${port}`)
  })
}

export default app
