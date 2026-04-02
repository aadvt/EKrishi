import express from 'express'
import pool from '../db.js'

const router = express.Router()
const PHONE_REGEX = /^\d{10}$/

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0
}

function isValidNumber(value) {
  return typeof value === 'number' && Number.isFinite(value)
}

router.post('/upsert', async (req, res) => {
  const {
    phone_number,
    full_name,
    district,
    taluk,
    village,
    latitude,
    longitude,
  } = req.body || {}

  if (typeof phone_number !== 'string' || !PHONE_REGEX.test(phone_number)) {
    return res.status(422).json({ error: 'phone_number must be exactly 10 digits' })
  }

  if (!isNonEmptyString(full_name) || !isNonEmptyString(district)) {
    return res.status(422).json({ error: 'full_name and district are required' })
  }

  try {
    const existing = await pool.query(
      'SELECT farmer_id, phone_number FROM farmers WHERE phone_number = $1 LIMIT 1',
      [phone_number],
    )

    if (existing.rows.length > 0) {
      return res.status(200).json({
        farmer_id: existing.rows[0].farmer_id,
        already_exists: true,
        phone_number: existing.rows[0].phone_number,
      })
    }

    const columns = ['phone_number', 'full_name', 'district']
    const values = [phone_number, full_name.trim(), district.trim()]
    const placeholders = ['$1', '$2', '$3']

    if (taluk !== null && taluk !== undefined) {
      columns.push('taluk')
      values.push(taluk)
      placeholders.push(`$${values.length}`)
    }

    if (village !== null && village !== undefined) {
      columns.push('village')
      values.push(village)
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
      INSERT INTO farmers (${columns.join(', ')})
      VALUES (${placeholders.join(', ')})
      RETURNING farmer_id, phone_number
    `

    const inserted = await pool.query(insertQuery, values)

    return res.status(201).json({
      farmer_id: inserted.rows[0].farmer_id,
      already_exists: false,
      phone_number: inserted.rows[0].phone_number,
    })
  } catch (err) {
    return res.status(500).json({
      error: 'Internal server error',
      detail: err.message,
    })
  }
})

router.get('/:phone_number', async (req, res) => {
  const { phone_number } = req.params

  try {
    const result = await pool.query(
      `
        SELECT farmer_id, phone_number, full_name, district, taluk, village
        FROM farmers
        WHERE phone_number = $1
        LIMIT 1
      `,
      [phone_number],
    )

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Farmer not found' })
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
