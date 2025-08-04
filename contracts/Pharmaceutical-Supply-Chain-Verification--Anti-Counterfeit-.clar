(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-already-registered (err u101))
(define-constant err-not-registered (err u102))
(define-constant err-batch-exists (err u103))
(define-constant err-batch-not-found (err u104))
(define-constant err-invalid-status (err u105))
(define-constant err-week-not-finalized (err u106))
(define-constant err-week-already-finalized (err u107))
(define-constant blocks-per-week u1008)
(define-constant bonus-multiplier u5)

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

;; Weekly leaderboard data structures
(define-map weekly-stats
  {collector: principal, week: uint}
  {
    verifications: uint,
    transfers: uint,
    batches-created: uint,
    total-score: uint
  }
)

(define-map week-leaderboard
  {week: uint, rank: uint}
  {collector: principal, score: uint}
)

(define-map weekly-finalized
  uint
  bool
)

(define-data-var current-week uint u0)

;; Helper functions for leaderboard
(define-private (get-current-week)
  (/ burn-block-height blocks-per-week)
)

(define-private (update-weekly-stats (collector principal) (action (string-ascii 20)))
  (let ((week (get-current-week))
        (current-stats (default-to 
          {verifications: u0, transfers: u0, batches-created: u0, total-score: u0}
          (map-get? weekly-stats {collector: collector, week: week}))))
    (let ((updated-stats (if (is-eq action "verify")
                            (merge current-stats 
                                   {verifications: (+ (get verifications current-stats) u1),
                                    total-score: (+ (get total-score current-stats) u1)})
                            (if (is-eq action "transfer") 
                                (merge current-stats 
                                       {transfers: (+ (get transfers current-stats) u1),
                                        total-score: (+ (get total-score current-stats) u1)})
                                (if (is-eq action "create")
                                    (merge current-stats 
                                           {batches-created: (+ (get batches-created current-stats) u1),
                                            total-score: (+ (get total-score current-stats) u2)})
                                    current-stats)))))
      (map-set weekly-stats {collector: collector, week: week} updated-stats)))
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
      (ok (begin
        (map-set drug-batches {batch-id: batch-id} batch-data)
        (update-weekly-stats tx-sender "create")))))
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
         location: location})
      (update-weekly-stats tx-sender "transfer"))))
)

(define-public (verify-drug-batch (batch-id (string-ascii 32)))
  (match (map-get? drug-batches {batch-id: batch-id})
    batch (ok (begin
      (map-set drug-batches
        {batch-id: batch-id}
        (merge batch {verification-count: (+ (get verification-count batch) u1)}))
      (update-weekly-stats tx-sender "verify")
      batch))
    err-batch-not-found)
)

(define-read-only (get-batch-details (batch-id (string-ascii 32)))
  (map-get? drug-batches {batch-id: batch-id})
)

;; Leaderboard functions
(define-public (finalize-weekly-leaderboard (week uint) (top-collectors (list 3 principal)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
    (asserts! (not (default-to false (map-get? weekly-finalized week))) err-week-already-finalized)
    (map-set weekly-finalized week true)
    (let ((collector-1 (unwrap-panic (element-at top-collectors u0)))
          (collector-2 (unwrap-panic (element-at top-collectors u1)))
          (collector-3 (unwrap-panic (element-at top-collectors u2))))
      (let ((stats-1 (default-to {verifications: u0, transfers: u0, batches-created: u0, total-score: u0}
                                 (map-get? weekly-stats {collector: collector-1, week: week})))
            (stats-2 (default-to {verifications: u0, transfers: u0, batches-created: u0, total-score: u0}
                                 (map-get? weekly-stats {collector: collector-2, week: week})))
            (stats-3 (default-to {verifications: u0, transfers: u0, batches-created: u0, total-score: u0}
                                 (map-get? weekly-stats {collector: collector-3, week: week}))))
        (map-set week-leaderboard {week: week, rank: u1} 
                 {collector: collector-1, score: (* (get total-score stats-1) bonus-multiplier)})
        (map-set week-leaderboard {week: week, rank: u2} 
                 {collector: collector-2, score: (* (get total-score stats-2) bonus-multiplier)})
        (map-set week-leaderboard {week: week, rank: u3} 
                 {collector: collector-3, score: (* (get total-score stats-3) bonus-multiplier)})
        (ok true))))
)

(define-read-only (get-collector-stats (collector principal) (week uint))
  (map-get? weekly-stats {collector: collector, week: week})
)

(define-read-only (get-weekly-leaderboard (week uint))
  (list 
    (map-get? week-leaderboard {week: week, rank: u1})
    (map-get? week-leaderboard {week: week, rank: u2})
    (map-get? week-leaderboard {week: week, rank: u3}))
)

(define-read-only (is-week-finalized (week uint))
  (default-to false (map-get? weekly-finalized week))
)

(define-read-only (get-current-week-number)
  (get-current-week)
)