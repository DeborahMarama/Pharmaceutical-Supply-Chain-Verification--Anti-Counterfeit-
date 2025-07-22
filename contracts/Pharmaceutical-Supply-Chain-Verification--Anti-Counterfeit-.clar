(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-already-registered (err u101))
(define-constant err-not-registered (err u102))
(define-constant err-batch-exists (err u103))
(define-constant err-batch-not-found (err u104))
(define-constant err-invalid-status (err u105))

(define-map manufacturers 
  principal 
  {name: (string-ascii 50), license-id: (string-ascii 20), verified: bool}
)

(define-map distributors
  principal
  {name: (string-ascii 50), license-id: (string-ascii 20), verified: bool}
)

(define-map drug-batches
  {batch-id: (string-ascii 32)}
  {
    manufacturer: principal,
    name: (string-ascii 50),
    expiry-date: uint,
    current-holder: principal,
    status: (string-ascii 20),
    verification-count: uint
  }
)

(define-map supply-chain-events
  {batch-id: (string-ascii 32), timestamp: uint}
  {
    actor: principal,
    action: (string-ascii 20),
    location: (string-ascii 50)
  }
)

(define-public (register-manufacturer (name (string-ascii 50)) (license-id (string-ascii 20)))
  (let ((manufacturer-data {name: name, license-id: license-id, verified: false}))

    (if (is-some (map-get? manufacturers tx-sender))
      err-already-registered
      (ok (map-set manufacturers tx-sender manufacturer-data))))
)

(define-public (register-distributor (name (string-ascii 50)) (license-id (string-ascii 20)))
  (let ((distributor-data {name: name, license-id: license-id, verified: false}))

    (if (is-some (map-get? distributors tx-sender))
      err-already-registered
      (ok (map-set distributors tx-sender distributor-data))))
)

(define-public (verify-entity (entity-address principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (match (map-get? manufacturers entity-address)
      manufacturer-data (ok (map-set manufacturers 
                                    entity-address 
                                    (merge manufacturer-data {verified: true})))
      (match (map-get? distributors entity-address)
        distributor-data (ok (map-set distributors 
                                     entity-address 
                                     (merge distributor-data {verified: true})))
        err-not-registered)))
)

(define-public (create-drug-batch 
    (batch-id (string-ascii 32))
    (name (string-ascii 50))
    (expiry-date uint))
  (let ((batch-data {
    manufacturer: tx-sender,
    name: name,
    expiry-date: expiry-date,
    current-holder: tx-sender,
    status: "manufactured",
    verification-count: u0
  }))
    (asserts! (is-some (map-get? manufacturers tx-sender)) err-not-registered)

    (if (is-some (map-get? drug-batches {batch-id: batch-id}))
      err-batch-exists
      (ok (map-set drug-batches {batch-id: batch-id} batch-data))))
)

(define-public (transfer-batch 
    (batch-id (string-ascii 32))
    (recipient principal)
    (location (string-ascii 50)))
  (let ((batch (map-get? drug-batches {batch-id: batch-id})))
    (asserts! (is-some batch) err-batch-not-found)
    (asserts! (is-eq (get current-holder (unwrap! batch err-batch-not-found)) tx-sender) err-not-authorized)
    (asserts! (or
      (is-some (map-get? distributors recipient))
      (is-some (map-get? manufacturers recipient))) err-not-registered)
    (ok (begin
      (map-set drug-batches 
        {batch-id: batch-id}
        (merge (unwrap! batch err-batch-not-found) 
               {current-holder: recipient, status: "in-transit"}))
      (map-set supply-chain-events

        {batch-id: batch-id, timestamp: burn-block-height}
        {actor: tx-sender,
         action: "transfer",
         location: location}))))
)

(define-public (verify-drug-batch (batch-id (string-ascii 32)))
  (match (map-get? drug-batches {batch-id: batch-id})
    batch (ok (begin
      (map-set drug-batches
        {batch-id: batch-id}
        (merge batch {verification-count: (+ (get verification-count batch) u1)}))
      batch))
    err-batch-not-found)
)

(define-read-only (get-batch-details (batch-id (string-ascii 32)))
  (map-get? drug-batches {batch-id: batch-id})
)