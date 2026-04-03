import pool from '../../src/db.js'

const PHONE_REGEX = /^\d{10}$/

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0
}

function toNumber(value) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

async function insertSmsTransaction(client, payload) {
  const {
    farmerId,
    buyerName,
    commodityName,
    quantityKg,
    pricePerKg,
    district,
    upiTxid,
    amount,
  } = payload

  return client.query(
    `
      INSERT INTO transactions (
        farmer_id,
        buyer_id,
        buyer_name_offline,
        buyer_type_offline,
        commodity_name,
        quantity_kg,
        price_per_kg,
        fair_price_estimate,
        sale_channel,
        district,
        payment_method,
        payment_status,
        upi_txid,
        total_amount,
        gst_rate,
        is_inter_state,
        cgst,
        sgst,
        igst,
        cgst_amount,
        sgst_amount,
        igst_amount,
        platform_fee,
        platform_fee_gst,
        gnn_flagged,
        kafka_emitted_at,
        listing_id,
        bid_id,
        mandi_id
      )
      VALUES (
        $1,
        NULL,
        $2,
        $3,
        $4,
        $5,
        $6,
        $7,
        $8,
        $9,
        $10,
        $11,
        $12,
        $13,
        $14,
        $15,
        $16,
        $17,
        $18,
        $19,
        $20,
        $21,
        $22,
        $23,
        $24,
        NULL,
        NULL,
        NULL,
        NULL
      )
      RETURNING transaction_id
    `,
    [
      farmerId,
      buyerName,
      'local_trader',
      commodityName,
      quantityKg,
      pricePerKg,
      pricePerKg,
      'local_trader',
      district,
      'upi',
      'released',
      upiTxid,
      amount,
      0,
      false,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      false,
    ],
  )
}

export default async function smsLogHandler(req, res) {
  const {
    farmer_phone,
    buyer_name,
    commodity_name,
    amount,
    price_per_kg,
    upi_txid,
    district,
  } = req.body || {}

  if (
    !isNonEmptyString(farmer_phone) ||
    !PHONE_REGEX.test(farmer_phone.trim()) ||
    !isNonEmptyString(buyer_name) ||
    !isNonEmptyString(commodity_name) ||
    amount === null ||
    amount === undefined
  ) {
    return res.status(400).json({
      success: false,
      message:
        'Missing required fields: farmer_phone (10 digits), buyer_name, commodity_name, amount',
    })
  }

  const parsedAmount = toNumber(amount)
  const parsedPricePerKg = toNumber(price_per_kg)

  if (parsedAmount === null || parsedAmount <= 0) {
    return res.status(400).json({
      success: false,
      message: 'amount must be a valid positive number',
    })
  }

  if (price_per_kg !== undefined && price_per_kg !== null && parsedPricePerKg === null) {
    return res.status(400).json({
      success: false,
      message: 'price_per_kg must be a valid number when provided',
    })
  }

  const normalizedPhone = farmer_phone.trim()
  const hasValidPricePerKg = parsedPricePerKg !== null && parsedPricePerKg > 0
  // DB has strict checks: quantity_kg > 0 and price_per_kg > 0.
  // For SMS records without per-kg price, use quantity=1kg and price=total amount.
  const normalizedPricePerKg = hasValidPricePerKg ? parsedPricePerKg : parsedAmount
  const quantityKg = hasValidPricePerKg ? parsedAmount / parsedPricePerKg : 1

  try {
    let farmerId

    const farmerResult = await pool.query(
      'SELECT farmer_id FROM farmers WHERE phone_number = $1 LIMIT 1',
      [normalizedPhone],
    )

    if (farmerResult.rows.length > 0) {
      farmerId = farmerResult.rows[0].farmer_id
    } else {
      const fallbackDistrict =
        typeof district === 'string' && district.trim().length > 0
          ? district.trim()
          : 'Unknown'

      const insertedFarmer = await pool.query(
        `
          INSERT INTO farmers (phone_number, full_name, district)
          VALUES ($1, $2, $3)
          RETURNING farmer_id
        `,
        [normalizedPhone, 'Auto-created farmer', fallbackDistrict],
      )

      farmerId = insertedFarmer.rows[0].farmer_id
    }

    let insertResult
    const insertPayload = {
      farmerId,
      buyerName: buyer_name.trim(),
      commodityName: commodity_name.trim(),
      quantityKg,
      pricePerKg: normalizedPricePerKg,
      district: district ?? null,
      upiTxid: upi_txid ?? null,
      amount: parsedAmount,
    }

    insertResult = await insertSmsTransaction(pool, insertPayload)

    return res.status(200).json({
      success: true,
      transaction_id: insertResult.rows[0].transaction_id,
      message: 'Transaction logged successfully',
    })
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: 'Failed to log transaction',
      detail: err.message,
    })
  }
}
