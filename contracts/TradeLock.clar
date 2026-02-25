;; TradeLock - Smart Contract Escrow System for Forex Trades
;; Locks funds until specific targets are hit with automated settlement

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-trade-exists (err u104))
(define-constant err-trade-settled (err u105))
(define-constant err-invalid-target (err u106))
(define-constant err-insufficient-funds (err u107))
;; Added new error constants for input validation
(define-constant err-invalid-currency-pair (err u108))
(define-constant err-invalid-trade-id (err u109))
(define-constant err-invalid-price (err u110))

;; Data Variables
(define-data-var next-trade-id uint u1)
(define-data-var platform-fee-rate uint u100) ;; 1% = 100 basis points

;; Added validation helper functions to check input parameters
(define-private (is-valid-currency-pair (currency-pair (string-ascii 6)))
  (and 
    (> (len currency-pair) u0)
    (<= (len currency-pair) u6)
  )
)

(define-private (is-valid-trade-id (trade-id uint))
  (and 
    (> trade-id u0)
    (< trade-id (var-get next-trade-id))
  )
)

(define-private (is-valid-price (price uint))
  (and 
    (> price u0)
    (< price u1000000000) ;; Reasonable upper bound for forex prices
  )
)

(define-private (is-valid-principal (user principal))
  (not (is-eq user 'SP000000000000000000002Q6VF78))
)

;; Data Maps
(define-map trades
  { trade-id: uint }
  {
    trader: principal,
    counterparty: principal,
    currency-pair: (string-ascii 6),
    entry-price: uint,
    target-price: uint,
    stop-loss: uint,
    amount: uint,
    trade-type: (string-ascii 5), ;; "LONG" or "SHORT"
    status: (string-ascii 10), ;; "ACTIVE", "SETTLED", "CANCELLED"
    created-at: uint,
    settled-at: (optional uint)
  }
)

(define-map escrow-balances
  { trade-id: uint }
  { amount: uint }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map price-feeds
  { currency-pair: (string-ascii 6) }
  { 
    price: uint,
    last-updated: uint,
    oracle: principal
  }
)

;; Read-only functions
(define-read-only (get-trade (trade-id uint))
  (map-get? trades { trade-id: trade-id })
)

(define-read-only (get-escrow-balance (trade-id uint))
  (map-get? escrow-balances { trade-id: trade-id })
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances { user: user })))
)

(define-read-only (get-current-price (currency-pair (string-ascii 6)))
  (map-get? price-feeds { currency-pair: currency-pair })
)

(define-read-only (calculate-pip-difference (entry-price uint) (current-price uint) (trade-type (string-ascii 5)))
  (if (is-eq trade-type "LONG")
    (if (>= current-price entry-price)
      (- current-price entry-price)
      (- entry-price current-price))
    (if (>= entry-price current-price)
      (- entry-price current-price)
      (- current-price entry-price))
  )
)

(define-read-only (is-target-reached (trade-id uint))
  (match (get-trade trade-id)
    trade-data
    (match (get-current-price (get currency-pair trade-data))
      price-data
      (let (
        (current-price (get price price-data))
        (entry-price (get entry-price trade-data))
        (target-price (get target-price trade-data))
        (trade-type (get trade-type trade-data))
      )
      (if (is-eq trade-type "LONG")
        (>= current-price target-price)
        (<= current-price target-price)
      ))
      false)
    false)
)

(define-read-only (is-stop-loss-hit (trade-id uint))
  (match (get-trade trade-id)
    trade-data
    (match (get-current-price (get currency-pair trade-data))
      price-data
      (let (
        (current-price (get price price-data))
        (stop-loss (get stop-loss trade-data))
        (trade-type (get trade-type trade-data))
      )
      (if (is-eq trade-type "LONG")
        (<= current-price stop-loss)
        (>= current-price stop-loss)
      ))
      false)
    false)
)

;; Public functions
(define-public (deposit (amount uint))
  (let (
    (current-balance (get-user-balance tx-sender))
  )
  (if (> amount u0)
    (begin
      (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
      (map-set user-balances 
        { user: tx-sender }
        { balance: (+ current-balance amount) }
      )
      (ok amount)
    )
    err-invalid-amount
  ))
)

(define-public (withdraw (amount uint))
  (let (
    (current-balance (get-user-balance tx-sender))
  )
  (if (and (> amount u0) (>= current-balance amount))
    (begin
      (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
      (map-set user-balances 
        { user: tx-sender }
        { balance: (- current-balance amount) }
      )
      (ok amount)
    )
    err-insufficient-funds
  ))
)

(define-public (create-trade 
  (counterparty principal)
  (currency-pair (string-ascii 6))
  (entry-price uint)
  (target-price uint)
  (stop-loss uint)
  (amount uint)
  (trade-type (string-ascii 5))
)
  (let (
    (trade-id (var-get next-trade-id))
    (user-balance (get-user-balance tx-sender))
  )
  ;; Added input validation to prevent unchecked data warnings
  (asserts! (is-valid-currency-pair currency-pair) err-invalid-currency-pair)
  (asserts! (is-valid-price entry-price) err-invalid-price)
  (asserts! (is-valid-price target-price) err-invalid-price)
  (asserts! (is-valid-price stop-loss) err-invalid-price)
  (asserts! (is-valid-principal counterparty) err-unauthorized)
  (asserts! (> amount u0) err-invalid-amount)
  (asserts! (>= user-balance amount) err-insufficient-funds)
  (asserts! (or (is-eq trade-type "LONG") (is-eq trade-type "SHORT")) err-invalid-target)
  (asserts! (not (is-eq tx-sender counterparty)) err-unauthorized)

  ;; Validate price targets
  (if (is-eq trade-type "LONG")
    (asserts! (> target-price entry-price) err-invalid-target)
    (asserts! (< target-price entry-price) err-invalid-target)
  )

  ;; Lock funds in escrow
  (map-set user-balances 
    { user: tx-sender }
    { balance: (- user-balance amount) }
  )

  (map-set escrow-balances
    { trade-id: trade-id }
    { amount: amount }
  )

  (map-set trades
    { trade-id: trade-id }
    {
      trader: tx-sender,
      counterparty: counterparty,
      currency-pair: currency-pair,
      entry-price: entry-price,
      target-price: target-price,
      stop-loss: stop-loss,
      amount: amount,
      trade-type: trade-type,
      status: "ACTIVE",
      created-at: block-height,
      settled-at: none
    }
  )

  (var-set next-trade-id (+ trade-id u1))
  (ok trade-id)
  ))

(define-public (settle-trade (trade-id uint))
  (match (get-trade trade-id)
    trade-data
    (let (
      (escrow-amount (default-to u0 (get amount (get-escrow-balance trade-id))))
      (platform-fee (/ (* escrow-amount (var-get platform-fee-rate)) u10000))
      (settlement-amount (- escrow-amount platform-fee))
      (trader (get trader trade-data))
      (counterparty (get counterparty trade-data))
    )
    (asserts! (is-eq (get status trade-data) "ACTIVE") err-trade-settled)
    (asserts! (or (is-eq tx-sender trader) (is-eq tx-sender counterparty)) err-unauthorized)

    (if (is-target-reached trade-id)
      ;; Target reached - trader wins
      (begin
        (map-set user-balances 
          { user: trader }
          { balance: (+ (get-user-balance trader) settlement-amount) }
        )
        (map-set trades
          { trade-id: trade-id }
          (merge trade-data { 
            status: "SETTLED",
            settled-at: (some block-height)
          })
        )
        (map-delete escrow-balances { trade-id: trade-id })
        (ok "TARGET_REACHED")
      )
      (if (is-stop-loss-hit trade-id)
        ;; Stop loss hit - counterparty wins
        (begin
          (map-set user-balances 
            { user: counterparty }
            { balance: (+ (get-user-balance counterparty) settlement-amount) }
          )
          (map-set trades
            { trade-id: trade-id }
            (merge trade-data { 
              status: "SETTLED",
              settled-at: (some block-height)
            })
          )
          (map-delete escrow-balances { trade-id: trade-id })
          (ok "STOP_LOSS_HIT")
        )
        err-unauthorized ;; Neither condition met
      )
    ))
    err-not-found)
)

(define-public (cancel-trade (trade-id uint))
  (begin
    ;; Added trade-id validation to prevent unchecked data warning
    (asserts! (is-valid-trade-id trade-id) err-invalid-trade-id)
    (match (get-trade trade-id)
      trade-data
      (let (
        (escrow-amount (default-to u0 (get amount (get-escrow-balance trade-id))))
        (trader (get trader trade-data))
      )
      (asserts! (is-eq tx-sender trader) err-unauthorized)
      (asserts! (is-eq (get status trade-data) "ACTIVE") err-trade-settled)

      ;; Return funds to trader
      (map-set user-balances 
        { user: trader }
        { balance: (+ (get-user-balance trader) escrow-amount) }
      )

      (map-set trades
        { trade-id: trade-id }
        (merge trade-data { 
          status: "CANCELLED",
          settled-at: (some block-height)
        })
      )

      (map-delete escrow-balances { trade-id: trade-id })
      (ok true)
      )
      err-not-found)
  )
)

;; Oracle functions (only contract owner)
(define-public (update-price (currency-pair (string-ascii 6)) (new-price uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; Added input validation for currency-pair and price to prevent unchecked data warnings
    (asserts! (is-valid-currency-pair currency-pair) err-invalid-currency-pair)
    (asserts! (is-valid-price new-price) err-invalid-price)
    (map-set price-feeds
      { currency-pair: currency-pair }
      {
        price: new-price,
        last-updated: block-height,
        oracle: tx-sender
      }
    )
    (ok true)
  )
)

(define-public (set-platform-fee (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-rate u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee-rate new-rate)
    (ok true)
  )
)

;; Emergency functions
(define-public (emergency-settle (trade-id uint) (winner principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    ;; Added input validation for trade-id and winner to prevent unchecked data warnings
    (asserts! (is-valid-trade-id trade-id) err-invalid-trade-id)
    (asserts! (is-valid-principal winner) err-unauthorized)
    (match (get-trade trade-id)
      trade-data
      (let (
        (escrow-amount (default-to u0 (get amount (get-escrow-balance trade-id))))
      )
      (asserts! (is-eq (get status trade-data) "ACTIVE") err-trade-settled)

      (map-set user-balances 
        { user: winner }
        { balance: (+ (get-user-balance winner) escrow-amount) }
      )

      (map-set trades
        { trade-id: trade-id }
        (merge trade-data { 
          status: "SETTLED",
          settled-at: (some block-height)
        })
      )

      (map-delete escrow-balances { trade-id: trade-id })
      (ok true)
      )
      err-not-found)
  )
)
