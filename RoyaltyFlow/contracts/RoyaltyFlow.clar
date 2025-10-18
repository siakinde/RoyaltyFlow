;; Automated Royalty Distribution for Music and Digital Content
;; This smart contract enables transparent and automated distribution of royalties
;; to multiple stakeholders (artists, producers, labels, etc.) based on predefined
;; split percentages. It ensures fair, immutable, and instant payment distribution.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-content-not-found (err u102))
(define-constant err-invalid-percentage (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-insufficient-balance (err u105))
(define-constant err-no-stakeholders (err u106))
(define-constant err-invalid-stakeholder (err u107))
(define-constant err-content-locked (err u108))
(define-constant err-zero-amount (err u109))
(define-constant percentage-precision u10000) ;; 100.00% = 10000 (allows 2 decimal precision)

;; data maps and vars
;; Track content metadata and owner
(define-map content-registry
  { content-id: (string-ascii 64) }
  {
    owner: principal,
    title: (string-utf8 256),
    total-revenue: uint,
    is-locked: bool,
    created-at: uint
  }
)

;; Track stakeholder splits for each content (supports multiple stakeholders per content)
(define-map royalty-splits
  { content-id: (string-ascii 64), stakeholder: principal }
  {
    percentage: uint, ;; Basis points (e.g., 2500 = 25.00%)
    total-earned: uint,
    pending-balance: uint
  }
)

;; Track all stakeholders for a given content (for iteration purposes)
(define-map content-stakeholders
  { content-id: (string-ascii 64), index: uint }
  { stakeholder: principal }
)

;; Count of stakeholders per content
(define-map stakeholder-count
  { content-id: (string-ascii 64) }
  { count: uint }
)

;; Global statistics
(define-data-var total-contents uint u0)
(define-data-var total-revenue-distributed uint u0)

;; private functions
;; Verify that percentage splits add up to 100%
(define-private (verify-total-percentage (content-id (string-ascii 64)))
  (let
    (
      (count (default-to u0 (get count (map-get? stakeholder-count { content-id: content-id }))))
      (total (fold calculate-total-percentage (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) { content-id: content-id, total: u0, max: count }))
    )
    (is-eq (get total total) percentage-precision)
  )
)

;; Helper for fold operation to calculate total percentage
(define-private (calculate-total-percentage 
  (index uint) 
  (context { content-id: (string-ascii 64), total: uint, max: uint }))
  (if (< index (get max context))
    (match (map-get? content-stakeholders { content-id: (get content-id context), index: index })
      stakeholder-data
        (match (map-get? royalty-splits { content-id: (get content-id context), stakeholder: (get stakeholder stakeholder-data) })
          split-data
            (merge context { total: (+ (get total context) (get percentage split-data)) })
          context
        )
      context
    )
    context
  )
)

;; Distribute revenue to a specific stakeholder
(define-private (distribute-to-stakeholder 
  (content-id (string-ascii 64)) 
  (stakeholder principal) 
  (amount uint))
  (let
    (
      (split-data (unwrap! (map-get? royalty-splits { content-id: content-id, stakeholder: stakeholder }) false))
      (share (/ (* amount (get percentage split-data)) percentage-precision))
    )
    (map-set royalty-splits
      { content-id: content-id, stakeholder: stakeholder }
      (merge split-data {
        total-earned: (+ (get total-earned split-data) share),
        pending-balance: (+ (get pending-balance split-data) share)
      })
    )
    true
  )
)

;; public functions
;; Register new content with initial stakeholder (content owner)
(define-public (register-content 
  (content-id (string-ascii 64)) 
  (title (string-utf8 256)))
  (let
    (
      (existing-content (map-get? content-registry { content-id: content-id }))
    )
    (asserts! (is-none existing-content) err-already-exists)
    
    ;; Create content entry
    (map-set content-registry
      { content-id: content-id }
      {
        owner: tx-sender,
        title: title,
        total-revenue: u0,
        is-locked: false,
        created-at: block-height
      }
    )
    
    ;; Initialize stakeholder count
    (map-set stakeholder-count
      { content-id: content-id }
      { count: u0 }
    )
    
    ;; Update global counter
    (var-set total-contents (+ (var-get total-contents) u1))
    
    (ok true)
  )
)

;; Add stakeholder with their royalty percentage
(define-public (add-stakeholder 
  (content-id (string-ascii 64)) 
  (stakeholder principal) 
  (percentage uint))
  (let
    (
      (content (unwrap! (map-get? content-registry { content-id: content-id }) err-content-not-found))
      (count-data (unwrap! (map-get? stakeholder-count { content-id: content-id }) err-content-not-found))
      (current-count (get count count-data))
      (existing-split (map-get? royalty-splits { content-id: content-id, stakeholder: stakeholder }))
    )
    ;; Only content owner can add stakeholders
    (asserts! (is-eq tx-sender (get owner content)) err-not-authorized)
    ;; Content must not be locked
    (asserts! (not (get is-locked content)) err-content-locked)
    ;; Stakeholder shouldn't already exist
    (asserts! (is-none existing-split) err-already-exists)
    ;; Percentage must be valid (1-10000)
    (asserts! (and (> percentage u0) (<= percentage percentage-precision)) err-invalid-percentage)
    ;; Max 10 stakeholders to prevent gas issues
    (asserts! (< current-count u10) err-no-stakeholders)
    
    ;; Add stakeholder to splits map
    (map-set royalty-splits
      { content-id: content-id, stakeholder: stakeholder }
      {
        percentage: percentage,
        total-earned: u0,
        pending-balance: u0
      }
    )
    
    ;; Add stakeholder to list for iteration
    (map-set content-stakeholders
      { content-id: content-id, index: current-count }
      { stakeholder: stakeholder }
    )
    
    ;; Increment stakeholder count
    (map-set stakeholder-count
      { content-id: content-id }
      { count: (+ current-count u1) }
    )
    
    (ok true)
  )
)

;; Lock content to prevent further stakeholder changes
(define-public (lock-content (content-id (string-ascii 64)))
  (let
    (
      (content (unwrap! (map-get? content-registry { content-id: content-id }) err-content-not-found))
    )
    ;; Only content owner can lock
    (asserts! (is-eq tx-sender (get owner content)) err-not-authorized)
    ;; Verify percentages add up to 100%
    (asserts! (verify-total-percentage content-id) err-invalid-percentage)
    
    ;; Lock the content
    (map-set content-registry
      { content-id: content-id }
      (merge content { is-locked: true })
    )
    
    (ok true)
  )
)

;; Distribute revenue for specific content (automated split calculation and distribution)
(define-public (distribute-revenue 
  (content-id (string-ascii 64)) 
  (amount uint))
  (let
    (
      (content (unwrap! (map-get? content-registry { content-id: content-id }) err-content-not-found))
      (count-data (unwrap! (map-get? stakeholder-count { content-id: content-id }) err-content-not-found))
      (stakeholder-total (get count count-data))
    )
    ;; Content must be locked before distributing revenue
    (asserts! (get is-locked content) err-content-locked)
    ;; Amount must be greater than zero
    (asserts! (> amount u0) err-zero-amount)
    ;; Must have stakeholders
    (asserts! (> stakeholder-total u0) err-no-stakeholders)
    
    ;; Distribute to all stakeholders
    (asserts! (get success (fold distribute-revenue-to-stakeholder 
      (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9) 
      { content-id: content-id, amount: amount, max: stakeholder-total, success: true }))
      err-invalid-stakeholder)
    
    ;; Update content total revenue
    (map-set content-registry
      { content-id: content-id }
      (merge content { total-revenue: (+ (get total-revenue content) amount) })
    )
    
    ;; Update global statistics
    (var-set total-revenue-distributed (+ (var-get total-revenue-distributed) amount))
    
    (ok true)
  )
)

;; Helper function for revenue distribution fold operation
(define-private (distribute-revenue-to-stakeholder 
  (index uint) 
  (context { content-id: (string-ascii 64), amount: uint, max: uint, success: bool }))
  (if (and (< index (get max context)) (get success context))
    (match (map-get? content-stakeholders { content-id: (get content-id context), index: index })
      stakeholder-data
        (merge context { success: (distribute-to-stakeholder (get content-id context) (get stakeholder stakeholder-data) (get amount context)) })
      (merge context { success: false })
    )
    context
  )
)

;; Withdraw accumulated royalties (stakeholders claim their earnings)
(define-public (withdraw-royalties (content-id (string-ascii 64)))
  (let
    (
      (split-data (unwrap! (map-get? royalty-splits { content-id: content-id, stakeholder: tx-sender }) err-invalid-stakeholder))
      (pending (get pending-balance split-data))
    )
    ;; Must have pending balance
    (asserts! (> pending u0) err-insufficient-balance)
    
    ;; Reset pending balance
    (map-set royalty-splits
      { content-id: content-id, stakeholder: tx-sender }
      (merge split-data { pending-balance: u0 })
    )
    
    ;; Transfer STX to stakeholder (in production, this would transfer actual STX)
    ;; Note: Actual STX transfer would use (stx-transfer? pending tx-sender contract)
    ;; For this example, we're tracking balances in the contract state
    
    (ok pending)
  )
)

;; Helper function to sum revenue amounts from multiple sources
(define-private (sum-revenue-amounts 
  (revenue-source { source: (string-ascii 32), amount: uint, timestamp: uint })
  (accumulated uint))
  (+ accumulated (get amount revenue-source))
)

;; Read-only functions for querying contract state
(define-read-only (get-content-info (content-id (string-ascii 64)))
  (ok (map-get? content-registry { content-id: content-id }))
)

(define-read-only (get-stakeholder-split (content-id (string-ascii 64)) (stakeholder principal))
  (ok (map-get? royalty-splits { content-id: content-id, stakeholder: stakeholder }))
)

(define-read-only (get-global-stats)
  (ok {
    total-contents: (var-get total-contents),
    total-revenue-distributed: (var-get total-revenue-distributed)
  })
)


