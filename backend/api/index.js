import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import farmersRouter from '../src/routes/farmers.js'
import listingsRouter from '../src/routes/listings.js'
import smsLogHandler from './transactions/sms-log.js'
import transactionHistoryHandler from './transactions/history.js'

const app = express()

app.use(cors())
app.use(express.json())

app.get('/health', (req, res) => res.json({ status: 'ok' }))
app.use('/farmers', farmersRouter)
app.use('/listings', listingsRouter)
app.post('/api/transactions/sms-log', smsLogHandler)
app.get('/api/transactions/history', transactionHistoryHandler)

export default app
