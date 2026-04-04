import pool from '../../src/db.js'

const PHONE_REGEX = /^\d{10}$/

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim().length > 0
}

function toNumber(value) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? parsed : null
}

function normalizeText(value) {
  return typeof value === 'string' ? value.trim() : ''
}

function toSlug(value) {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40)
}

function makeSyntheticBuyerPhone(buyerName) {
  let hash = 0
  for (let i = 0; i < buyerName.length; i += 1) {
    hash = (hash * 31 + buyerName.charCodeAt(i)) >>> 0
  }
  const suffix = String(hash % 1000000000).padStart(9, '0')
  return `9${suffix}`
}

async function findOrCreateBuyer(client, payload) {
  const { buyerName, district, state } = payload
  const normalizedName = normalizeText(buyerName)

  const buyerByName = await client.query(
    `
      SELECT buyer_id, business_name
      FROM buyers
      WHERE LOWER(business_name) = LOWER($1)
      LIMIT 1
    `,
    [normalizedName],
  )

  if (buyerByName.rows.length > 0) {
    return buyerByName.rows[0].buyer_id
  }

  let syntheticPhone = makeSyntheticBuyerPhone(normalizedName)
  for (let attempt = 0; attempt < 5; attempt += 1) {
    const insertResult = await client.query(
      `
        INSERT INTO buyers (phone_number, business_name, buyer_type, district, state)
        VALUES ($1, $2, 'other', $3, $4)
        ON CONFLICT (phone_number) DO NOTHING
        RETURNING buyer_id
      `,
      [syntheticPhone, normalizedName, district ?? null, state ?? 'Karnataka'],
    )

    if (insertResult.rows.length > 0) {
      return insertResult.rows[0].buyer_id
    }

    const existing = await client.query(
      `
        SELECT buyer_id
        FROM buyers
        WHERE phone_number = $1 AND LOWER(business_name) = LOWER($2)
        LIMIT 1
      `,
      [syntheticPhone, normalizedName],
    )
    if (existing.rows.length > 0) {
      return existing.rows[0].buyer_id
    }

    const base = Number(syntheticPhone.slice(1))
    syntheticPhone = `9${String((base + attempt + 1) % 1000000000).padStart(9, '0')}`
  }

  throw new Error('Unable to create buyer record for SMS transaction')
}

async function resolveOrCreateNetworkNode(client, payload) {
  const { preferredId, name, nodeGroup, district, commodity } = payload

  const existing = await client.query(
    `
      SELECT id
      FROM network_nodes
      WHERE LOWER(name) = LOWER($1) AND node_group = $2
      LIMIT 1
    `,
    [name, nodeGroup],
  )

  if (existing.rows.length > 0) {
    return existing.rows[0].id
  }

  const nodeId = preferredId || `${nodeGroup.toLowerCase()}_${toSlug(name)}`
  const inserted = await client.query(
    `
      INSERT INTO network_nodes (id, name, node_group, district, commodity)
      VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT (id)
      DO UPDATE SET
        name = EXCLUDED.name,
        node_group = EXCLUDED.node_group,
        district = COALESCE(EXCLUDED.district, network_nodes.district),
        commodity = COALESCE(EXCLUDED.commodity, network_nodes.commodity)
      RETURNING id
    `,
    [nodeId, name, nodeGroup, district ?? null, commodity ?? null],
  )

  return inserted.rows[0].id
}

async function createTransactionNetworkLink(client, payload) {
  const {
    sourceNodeId,
    targetNodeId,
    commodityName,
    pricePerKg,
    quantityKg,
  } = payload

  await client.query(
    `
      INSERT INTO network_links (
        source,
        target,
        value,
        link_type,
        has_anomaly,
        commodity,
        price_actual,
        price_fair,
        quantity_kg,
        transaction_date
      )
      VALUES ($1, $2, 1, 'Transaction', false, $3, $4, $4, $5, CURRENT_DATE)
    `,
    [sourceNodeId, targetNodeId, commodityName, pricePerKg, quantityKg],
  )
}

async function insertSmsTransaction(client, payload) {
  const {
    farmerId,
    buyerId,
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
        $25,
        NULL,
        NULL,
        NULL,
        NULL
      )
      RETURNING transaction_id
    `,
    [
      farmerId,
      buyerId,
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
    state,
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

  const client = await pool.connect()
  let inTransaction = false
  try {
    await client.query('BEGIN')
    inTransaction = true

    let farmerId
    let farmerName = 'Farmer'

    const farmerResult = await client.query(
      'SELECT farmer_id, full_name FROM farmers WHERE phone_number = $1 LIMIT 1',
      [normalizedPhone],
    )

    if (farmerResult.rows.length > 0) {
      farmerId = farmerResult.rows[0].farmer_id
      farmerName = normalizeText(farmerResult.rows[0].full_name) || farmerName
    } else {
      const fallbackDistrict =
        typeof district === 'string' && district.trim().length > 0
          ? district.trim()
          : 'Unknown'

      const insertedFarmer = await client.query(
        `
          INSERT INTO farmers (phone_number, full_name, district)
          VALUES ($1, $2, $3)
          RETURNING farmer_id, full_name
        `,
        [normalizedPhone, 'Auto-created farmer', fallbackDistrict],
      )

      farmerId = insertedFarmer.rows[0].farmer_id
      farmerName = normalizeText(insertedFarmer.rows[0].full_name) || farmerName
    }

    const normalizedBuyerName = normalizeText(buyer_name)
    const buyerId = await findOrCreateBuyer(client, {
      buyerName: normalizedBuyerName,
      district: normalizeText(district) || null,
      state: normalizeText(state) || 'Karnataka',
    })

    const insertPayload = {
      farmerId,
      buyerId,
      buyerName: normalizedBuyerName,
      commodityName: normalizeText(commodity_name),
      quantityKg,
      pricePerKg: normalizedPricePerKg,
      district: normalizeText(district) || null,
      upiTxid: normalizeText(upi_txid) || null,
      amount: parsedAmount,
    }

    const insertResult = await insertSmsTransaction(client, insertPayload)

    try {
      const farmerNodeId = await resolveOrCreateNetworkNode(client, {
        preferredId: `farmer_${farmerId}`,
        name: farmerName,
        nodeGroup: 'Farmer',
        district: normalizeText(district) || null,
        commodity: normalizeText(commodity_name),
      })

      const buyerNodeId = await resolveOrCreateNetworkNode(client, {
        preferredId: `buyer_${buyerId}`,
        name: normalizedBuyerName,
        nodeGroup: 'Buyer',
        district: normalizeText(district) || null,
        commodity: normalizeText(commodity_name),
      })

      await createTransactionNetworkLink(client, {
        sourceNodeId: farmerNodeId,
        targetNodeId: buyerNodeId,
        commodityName: normalizeText(commodity_name),
        pricePerKg: normalizedPricePerKg,
        quantityKg,
      })
    } catch (graphErr) {
      // Keep transaction logging resilient even if graph cache sync fails.
      console.warn('GNN sync warning in sms-log:', graphErr.message)
    }

    await client.query('COMMIT')
    inTransaction = false

    return res.status(200).json({
      success: true,
      transaction_id: insertResult.rows[0].transaction_id,
      buyer_id: buyerId,
      message: 'Transaction logged successfully',
    })
  } catch (err) {
    if (inTransaction) {
      await client.query('ROLLBACK')
    }
    return res.status(500).json({
      success: false,
      message: 'Failed to log transaction',
      detail: err.message,
    })
  } finally {
    client.release()
  }
}
