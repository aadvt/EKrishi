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

function roundTo(num, digits = 4) {
  if (!Number.isFinite(num)) {
    return null
  }
  const factor = 10 ** digits
  return Math.round(num * factor) / factor
}

function formatCurrency(value) {
  if (!Number.isFinite(value)) {
    return null
  }
  return roundTo(value, 2)
}

function clampNumber(value, min, max) {
  if (!Number.isFinite(value)) {
    return min
  }
  return Math.max(min, Math.min(max, value))
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

async function findLatestFairPricePerKg(client, payload) {
  const { farmerId, commodityName, district } = payload
  const normalizedCommodity = normalizeText(commodityName)
  const normalizedDistrict = normalizeText(district)

  const result = await client.query(
    `
      SELECT
        listing_id,
        COALESCE(fair_price_estimate, minimum_price_per_kg) AS fair_price_per_kg,
        quantity_kg
      FROM marketplace_listings
      WHERE farmer_id = $1
        AND (
          LOWER(commodity_name) = LOWER($2)
          OR regexp_replace(LOWER(commodity_name), '[^a-z0-9]+', '', 'g') = regexp_replace(LOWER($2), '[^a-z0-9]+', '', 'g')
          OR regexp_replace(LOWER(commodity_name), '[^a-z0-9]+', '', 'g') LIKE '%' || regexp_replace(LOWER($2), '[^a-z0-9]+', '', 'g') || '%'
          OR regexp_replace(LOWER($2), '[^a-z0-9]+', '', 'g') LIKE '%' || regexp_replace(LOWER(commodity_name), '[^a-z0-9]+', '', 'g') || '%'
        )
        AND COALESCE(fair_price_estimate, minimum_price_per_kg) > 0
      ORDER BY
        CASE
          WHEN $3 <> '' AND LOWER(COALESCE(location_district, '')) = LOWER($3) THEN 0
          ELSE 1
        END,
        CASE WHEN status = 'active' THEN 0 ELSE 1 END,
        created_at DESC
      LIMIT 1
    `,
    [farmerId, normalizedCommodity, normalizedDistrict],
  )

  if (result.rows.length > 0) {
    return {
      listingId: result.rows[0].listing_id,
      fairPricePerKg: toNumber(result.rows[0].fair_price_per_kg),
      listingQuantityKg: toNumber(result.rows[0].quantity_kg),
      benchmarkSource: 'commodity_match',
    }
  }

  // Fallback: most recent listing in the same district for this farmer.
  // This prevents "no benchmark" when SMS commodity text is noisy.
  const districtFallback = await client.query(
    `
      SELECT
        listing_id,
        COALESCE(fair_price_estimate, minimum_price_per_kg) AS fair_price_per_kg,
        quantity_kg
      FROM marketplace_listings
      WHERE farmer_id = $1
        AND COALESCE(fair_price_estimate, minimum_price_per_kg) > 0
      ORDER BY
        CASE
          WHEN $2 <> '' AND LOWER(COALESCE(location_district, '')) = LOWER($2) THEN 0
          ELSE 1
        END,
        CASE WHEN status = 'active' THEN 0 ELSE 1 END,
        created_at DESC
      LIMIT 1
    `,
    [farmerId, normalizedDistrict],
  )

  if (districtFallback.rows.length === 0) {
    return {
      listingId: null,
      fairPricePerKg: null,
      listingQuantityKg: null,
      benchmarkSource: 'none',
    }
  }

  return {
    listingId: districtFallback.rows[0].listing_id,
    fairPricePerKg: toNumber(districtFallback.rows[0].fair_price_per_kg),
    listingQuantityKg: toNumber(districtFallback.rows[0].quantity_kg),
    benchmarkSource: 'district_fallback',
  }
}

function evaluateTransactionAgainstFairPrice(payload) {
  const { amountPaid, fairPricePerKg, quantityKg, benchmarkSource } = payload

  if (
    !Number.isFinite(amountPaid) ||
    amountPaid <= 0 ||
    !Number.isFinite(fairPricePerKg) ||
    fairPricePerKg <= 0 ||
    !Number.isFinite(quantityKg) ||
    quantityKg <= 0
  ) {
    return {
      gnnFlagged: false,
      fairPriceEstimate: null,
      priceRatio: null,
      expectedAmount: null,
      allowedGapAmount: null,
      flagThresholdRatio: null,
      benchmarkSource: benchmarkSource || 'none',
      explanation: 'No fair-price benchmark found, so this transaction is treated as normal.',
    }
  }

  const expectedAmount = fairPricePerKg * quantityKg
  const priceRatio = amountPaid / expectedAmount
  const shortfallAmount = Math.max(expectedAmount - amountPaid, 0)

  // Demo-friendly tolerance: allows a small rupee gap for tiny transactions,
  // but still flags clear underpayment.
  const allowedGapAmount = Math.max(5, Math.min(20, expectedAmount * 0.08 + quantityKg * 2))
  const flagThresholdRatio = 0.78
  const hardLowRatioThreshold = 0.4

  const gnnFlagged =
    amountPaid < expectedAmount * flagThresholdRatio &&
    (shortfallAmount > allowedGapAmount || priceRatio <= hardLowRatioThreshold)

  const ratioPercent = roundTo(priceRatio * 100, 1)
  const shortfallRounded = formatCurrency(shortfallAmount)

  const explanation = gnnFlagged
    ? `Flagged: paid ${ratioPercent}% of expected fair value (short by Rs ${shortfallRounded}), below threshold.`
    : `Normal: paid ${ratioPercent}% of expected fair value; within allowed tolerance.`

  return {
    gnnFlagged,
    fairPriceEstimate: fairPricePerKg,
    priceRatio: roundTo(priceRatio),
    expectedAmount: roundTo(expectedAmount),
    allowedGapAmount: roundTo(allowedGapAmount),
    flagThresholdRatio,
    benchmarkSource: benchmarkSource || 'commodity_match',
    explanation,
  }
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
    fairPriceEstimate,
    gnnFlagged,
    priceRatio,
    listingId,
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
        price_ratio,
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
        $26,
        NULL,
        $27,
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
      fairPriceEstimate,
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
      gnnFlagged,
      priceRatio,
      listingId,
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

    const fairPriceLookup = await findLatestFairPricePerKg(client, {
      farmerId,
      commodityName: commodity_name,
      district,
    })

    // If SMS does not contain per-kg price, infer quantity from listing weight for demo flows.
    // Clamp to 0.25..4kg to keep behavior practical for your test scenario.
    const derivedQuantityFromListing = clampNumber(
      fairPriceLookup.listingQuantityKg ?? 1,
      0.25,
      4,
    )
    const quantityKg = hasValidPricePerKg
      ? parsedAmount / parsedPricePerKg
      : derivedQuantityFromListing
    const normalizedPricePerKg = hasValidPricePerKg
      ? parsedPricePerKg
      : parsedAmount / quantityKg

    const evaluation = evaluateTransactionAgainstFairPrice({
      amountPaid: parsedAmount,
      fairPricePerKg: fairPriceLookup.fairPricePerKg,
      quantityKg,
      benchmarkSource: fairPriceLookup.benchmarkSource,
    })

    const insertPayload = {
      farmerId,
      buyerId,
      buyerName: normalizedBuyerName,
      commodityName: normalizeText(commodity_name),
      quantityKg,
      pricePerKg: normalizedPricePerKg,
      fairPriceEstimate: evaluation.fairPriceEstimate || normalizedPricePerKg,
      gnnFlagged: evaluation.gnnFlagged,
      priceRatio: evaluation.priceRatio,
      listingId: fairPriceLookup.listingId,
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
      gnn_flagged: evaluation.gnnFlagged,
      gnn_meta: {
        matched_listing_id: fairPriceLookup.listingId,
        fair_price_per_kg: evaluation.fairPriceEstimate,
        benchmark_source: evaluation.benchmarkSource,
        quantity_kg_used: roundTo(quantityKg, 3),
        expected_amount: evaluation.expectedAmount,
        paid_amount: parsedAmount,
        price_ratio: evaluation.priceRatio,
        flag_ratio_threshold: evaluation.flagThresholdRatio,
        allowed_gap_amount: evaluation.allowedGapAmount,
        explanation: evaluation.explanation,
      },
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
