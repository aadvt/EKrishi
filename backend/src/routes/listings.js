import express from 'express'
import pool from '../db.js'

const router = express.Router()
const PHONE_REGEX = /^\d{10}$/

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0
}

function isPositiveNumber(value) {
  return typeof value === 'number' && Number.isFinite(value) && value > 0
}

function isValidNumber(value) {
  return typeof value === 'number' && Number.isFinite(value)
}

function normalizeSourceChannel(value) {
  if (!isNonEmptyString(value)) {
    return 'api'
  }

  const normalized = value.trim().toLowerCase()
  if (normalized === 'mobile_app') {
    return 'api'
  }

  if (['web', 'sms', 'ivr', 'api'].includes(normalized)) {
    return normalized
  }

  return 'api'
}

router.post('/', async (req, res) => {
  const {
    farmer_phone,
    produce_name,
    produce_name_local,
    quantity_kg = 1.0,
    price_per_kg,
    price_min_per_kg,
    price_max_per_kg,
    grade,
    location_district,
    location_taluk,
    latitude,
    longitude,
    source_channel = 'mobile_app',
  } = req.body || {}

  if (typeof farmer_phone !== 'string' || !PHONE_REGEX.test(farmer_phone)) {
    return res.status(422).json({ error: 'farmer_phone must be exactly 10 digits' })
  }

  if (!isNonEmptyString(produce_name)) {
    return res.status(422).json({ error: 'produce_name is required' })
  }

  if (!isPositiveNumber(quantity_kg)) {
    return res.status(422).json({ error: 'quantity_kg must be greater than 0' })
  }

  if (!isPositiveNumber(price_per_kg)) {
    return res.status(422).json({ error: 'price_per_kg must be greater than 0' })
  }

  const client = await pool.connect()
  let inTransaction = false

  try {
    const farmerResult = await client.query(
      'SELECT farmer_id FROM farmers WHERE phone_number = $1 LIMIT 1',
      [farmer_phone],
    )

    if (farmerResult.rows.length === 0) {
      return res
        .status(404)
        .json({ error: 'Farmer not registered. Please register first.' })
    }

    const farmerId = farmerResult.rows[0].farmer_id

    const columns = [
      'farmer_id',
      'commodity_name',
      'quantity_kg',
      'quantity_remaining_kg',
      'minimum_price_per_kg',
      'delivery_terms',
      'status',
      'source_channel',
    ]

    const values = [
      farmerId,
      produce_name.trim(),
      quantity_kg,
      quantity_kg,
      price_per_kg,
      'farm_pickup',
      'active',
      normalizeSourceChannel(source_channel),
    ]

    const placeholders = values.map((_, idx) => `$${idx + 1}`)

    if (price_min_per_kg !== null && price_min_per_kg !== undefined) {
      columns.push('fair_price_estimate')
      values.push(price_min_per_kg)
      placeholders.push(`$${values.length}`)
    }

    if (price_max_per_kg !== null && price_max_per_kg !== undefined) {
      columns.push('msp_at_listing')
      values.push(price_max_per_kg)
      placeholders.push(`$${values.length}`)
    }

    if (produce_name_local !== null && produce_name_local !== undefined) {
      columns.push('produce_description')
      values.push(produce_name_local)
      placeholders.push(`$${values.length}`)
    }

    if (grade !== null && grade !== undefined) {
      columns.push('grade')
      values.push(grade)
      placeholders.push(`$${values.length}`)

      columns.push('grade_source')
      values.push('cv_model')
      placeholders.push(`$${values.length}`)
    }

    if (location_district !== null && location_district !== undefined) {
      columns.push('location_district')
      values.push(location_district)
      placeholders.push(`$${values.length}`)
    }

    if (location_taluk !== null && location_taluk !== undefined) {
      columns.push('location_taluk')
      values.push(location_taluk)
      placeholders.push(`$${values.length}`)
    }

    if (isValidNumber(latitude) && isValidNumber(longitude)) {
      columns.push('geom')
      values.push(longitude)
      const lonIndex = values.length
      values.push(latitude)
      const latIndex = values.length
      placeholders.push(`ST_MakePoint($${lonIndex}, $${latIndex})::geography`)
    }

    const insertQuery = `
      INSERT INTO marketplace_listings (${columns.join(', ')})
      VALUES (${placeholders.join(', ')})
      RETURNING listing_id, farmer_id, status, created_at
    `

    await client.query('BEGIN')
    inTransaction = true
    const insertResult = await client.query(insertQuery, values)

    await client.query(
      `
        UPDATE farmers
        SET total_listings = total_listings + 1,
            updated_at = now()
        WHERE farmer_id = $1
      `,
      [farmerId],
    )

    await client.query('COMMIT')
    inTransaction = false

    return res.status(201).json(insertResult.rows[0])
  } catch (err) {
    if (inTransaction) {
      await client.query('ROLLBACK')
    }
    return res.status(500).json({
      error: 'Internal server error',
      detail: err.message,
    })
  } finally {
    client.release()
  }
})

router.get('/:listing_id', async (req, res) => {
  const { listing_id } = req.params

  try {
    const result = await pool.query(
      `
       SELECT listing_id, farmer_id,
         commodity_name AS produce_name,
         produce_description AS produce_name_local,
         minimum_price_per_kg AS price_per_kg,
         fair_price_estimate AS price_min_per_kg,
         msp_at_listing AS price_max_per_kg,
               grade, location_district, location_taluk,
               source_channel, status, created_at
        FROM marketplace_listings
        WHERE listing_id = $1
        LIMIT 1
      `,
      [listing_id],
    )

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Listing not found' })
    }

    return res.status(200).json(result.rows[0])
  } catch (err) {
    return res.status(500).json({
      error: 'Internal server error',
      detail: err.message,
    })
  }
})

export default router
