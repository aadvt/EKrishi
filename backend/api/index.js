import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import farmersRouter from '../src/routes/farmers.js'
import listingsRouter from '../src/routes/listings.js'

const app = express()

app.use(cors())
app.use(express.json())

app.get('/health', (req, res) => res.json({ status: 'ok' }))
app.use('/farmers', farmersRouter)
app.use('/listings', listingsRouter)

export default app
