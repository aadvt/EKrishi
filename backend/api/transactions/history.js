import pool from '../../src/db.js'

const PHONE_REGEX = /^\d{10}$/

export default async function transactionHistoryHandler(req, res) {
  const { farmer_phone, limit, offset } = req.query || {}

  if (typeof farmer_phone !== 'string' || !PHONE_REGEX.test(farmer_phone.trim())) {
    return res.status(400).json({
      success: false,
      message: 'farmer_phone is required and must be exactly 10 digits',
    })
  }

  const parsedLimit = Number.parseInt(limit, 10)
  const parsedOffset = Number.parseInt(offset, 10)
  const safeLimit = Number.isFinite(parsedLimit) && parsedLimit > 0 ? parsedLimit : 50
  const safeOffset = Number.isFinite(parsedOffset) && parsedOffset >= 0 ? parsedOffset : 0

  try {
    const farmerResult = await pool.query(
      'SELECT farmer_id FROM farmers WHERE phone_number = $1 LIMIT 1',
      [farmer_phone.trim()],
    )

    if (farmerResult.rows.length === 0) {
      return res.status(200).json({
        success: true,
        transactions: [],
        total: 0,
        farmer_phone: farmer_phone.trim(),
      })
    }

    const farmerId = farmerResult.rows[0].farmer_id

    const txResult = await pool.query(
      `
        SELECT
          t.transaction_id,
          t.commodity_name,
          t.quantity_kg,
          t.price_per_kg,
          t.total_amount,
          t.sale_channel,
          t.payment_status,
          t.buyer_name_offline,
          t.district,
          t.upi_txid,
          t.created_at,
          t.gnn_flagged,
          t.price_ratio
        FROM transactions t
        WHERE t.farmer_id = $1
          AND t.payment_status IN ('released', 'pending', 'in_escrow')
        ORDER BY t.created_at DESC
        LIMIT $2 OFFSET $3
      `,
      [farmerId, safeLimit, safeOffset],
    )

    return res.status(200).json({
      success: true,
      transactions: txResult.rows,
      total: txResult.rows.length,
      farmer_phone: farmer_phone.trim(),
    })
  } catch (err) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch transaction history',
      detail: err.message,
    })
  }
}
