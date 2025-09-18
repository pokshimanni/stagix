;; Production Manager - Community Theater Funding Contract
;; Manages theater production campaigns and funding

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PRODUCTION-EXISTS (err u101))
(define-constant ERR-PRODUCTION-NOT-FOUND (err u102))
(define-constant ERR-CAMPAIGN-CLOSED (err u103))
(define-constant ERR-GOAL-NOT-MET (err u104))
(define-constant ERR-INSUFFICIENT-FUNDS (err u105))
(define-constant ERR-ALREADY-FUNDED (err u106))
(define-constant ERR-CAMPAIGN-EXPIRED (err u107))
(define-constant ERR-INVALID-AMOUNT (err u108))
(define-constant ERR-REFUND-FAILED (err u109))
(define-constant ERR-INVALID-DEADLINE (err u110))

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-FUNDING-GOAL u1000000) ;; 1 STX minimum
(define-constant MAX-DEADLINE-BLOCKS u144000) ;; ~100 days in blocks

;; Production status enum
(define-constant STATUS-ACTIVE u1)
(define-constant STATUS-FUNDED u2)
(define-constant STATUS-COMPLETED u3)
(define-constant STATUS-CANCELLED u4)

;; Data variables
(define-data-var next-production-id uint u1)
(define-data-var total-productions uint u0)
(define-data-var total-funds-raised uint u0)

;; Production data structure
(define-map productions
  { production-id: uint }
  {
    organizer: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    funding-goal: uint,
    current-funding: uint,
    deadline: uint,
    status: uint,
    created-at: uint,
    contributor-count: uint
  }
)

;; Individual contributions mapping
(define-map contributions
  { production-id: uint, contributor: principal }
  { amount: uint, contributed-at: uint }
)

;; Contributor list for each production
(define-map production-contributors
  { production-id: uint, contributor-index: uint }
  { contributor: principal }
)

;; Track contributor count per production
(define-map contributor-counts
  { production-id: uint }
  { count: uint }
)

;; Production organizer verification
(define-map verified-organizers
  { organizer: principal }
  { verified: bool, reputation: uint }
)

;; Public Functions

;; Create a new theater production campaign
(define-public (create-production (title (string-ascii 100)) 
                                (description (string-ascii 500))
                                (funding-goal uint)
                                (deadline uint))
  (let ((production-id (var-get next-production-id))
        (current-block stacks-block-height))
    (asserts! (>= funding-goal MIN-FUNDING-GOAL) ERR-INVALID-AMOUNT)
    (asserts! (> deadline current-block) ERR-INVALID-DEADLINE)
    (asserts! (<= (- deadline current-block) MAX-DEADLINE-BLOCKS) ERR-INVALID-DEADLINE)
    (asserts! (is-none (map-get? productions { production-id: production-id })) ERR-PRODUCTION-EXISTS)
    
    ;; Create production record
    (map-set productions
      { production-id: production-id }
      {
        organizer: tx-sender,
        title: title,
        description: description,
        funding-goal: funding-goal,
        current-funding: u0,
        deadline: deadline,
        status: STATUS-ACTIVE,
        created-at: current-block,
        contributor-count: u0
      }
    )
    
    ;; Initialize contributor count
    (map-set contributor-counts
      { production-id: production-id }
      { count: u0 }
    )
    
    ;; Update counters
    (var-set next-production-id (+ production-id u1))
    (var-set total-productions (+ (var-get total-productions) u1))
    
    (ok production-id)
  )
)

;; Contribute funds to a production
(define-public (contribute-to-production (production-id uint) (amount uint))
  (let ((production-data (unwrap! (map-get? productions { production-id: production-id }) ERR-PRODUCTION-NOT-FOUND))
        (existing-contribution (map-get? contributions { production-id: production-id, contributor: tx-sender }))
        (current-block stacks-block-height))
    
    ;; Validation checks
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (is-eq (get status production-data) STATUS-ACTIVE) ERR-CAMPAIGN-CLOSED)
    (asserts! (< current-block (get deadline production-data)) ERR-CAMPAIGN-EXPIRED)
    (asserts! (< (get current-funding production-data) (get funding-goal production-data)) ERR-ALREADY-FUNDED)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update contribution record
    (let ((previous-amount (match existing-contribution 
                            some-contribution (get amount some-contribution) 
                            u0))
          (new-total-amount (+ previous-amount amount))
          (new-funding (+ (get current-funding production-data) amount))
          (contributor-count-data (unwrap! (map-get? contributor-counts { production-id: production-id }) ERR-PRODUCTION-NOT-FOUND)))
      
      ;; Update or create contribution record
      (map-set contributions
        { production-id: production-id, contributor: tx-sender }
        { amount: new-total-amount, contributed-at: current-block }
      )
      
      ;; Add to contributor list if new contributor
      (if (is-none existing-contribution)
        (let ((current-count (get count contributor-count-data)))
          (map-set production-contributors
            { production-id: production-id, contributor-index: current-count }
            { contributor: tx-sender }
          )
          (map-set contributor-counts
            { production-id: production-id }
            { count: (+ current-count u1) }
          )
        )
        true
      )
      
      ;; Update production funding
      (map-set productions
        { production-id: production-id }
        (merge production-data { 
          current-funding: new-funding,
          contributor-count: (if (is-none existing-contribution) 
                              (+ (get contributor-count production-data) u1)
                              (get contributor-count production-data))
        })
      )
      
      ;; Update global stats
      (var-set total-funds-raised (+ (var-get total-funds-raised) amount))
      
      ;; Check if funding goal is met
      (if (>= new-funding (get funding-goal production-data))
        (begin
          (map-set productions
            { production-id: production-id }
            (merge production-data { 
              current-funding: new-funding,
              status: STATUS-FUNDED,
              contributor-count: (if (is-none existing-contribution) 
                                  (+ (get contributor-count production-data) u1)
                                  (get contributor-count production-data))
            })
          )
          (ok { success: true, funding-completed: true, new-total: new-funding })
        )
        (ok { success: true, funding-completed: false, new-total: new-funding })
      )
    )
  )
)

;; Release funds to production organizer (only when goal is met)
(define-public (release-funds (production-id uint))
  (let ((production-data (unwrap! (map-get? productions { production-id: production-id }) ERR-PRODUCTION-NOT-FOUND)))
    
    ;; Only organizer can release funds
    (asserts! (is-eq tx-sender (get organizer production-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status production-data) STATUS-FUNDED) ERR-GOAL-NOT-MET)
    
    ;; Transfer funds to organizer
    (try! (as-contract (stx-transfer? (get current-funding production-data) tx-sender (get organizer production-data))))
    
    ;; Mark production as completed
    (map-set productions
      { production-id: production-id }
      (merge production-data { status: STATUS-COMPLETED })
    )
    
    (ok (get current-funding production-data))
  )
)

;; Request refund if campaign failed or expired
(define-public (request-refund (production-id uint))
  (let ((production-data (unwrap! (map-get? productions { production-id: production-id }) ERR-PRODUCTION-NOT-FOUND))
        (contribution-data (unwrap! (map-get? contributions { production-id: production-id, contributor: tx-sender }) ERR-NOT-AUTHORIZED))
        (current-block stacks-block-height))
    
    ;; Check if refund is valid (campaign expired and goal not met, or cancelled)
    (asserts! (or 
                (and (>= current-block (get deadline production-data))
                     (< (get current-funding production-data) (get funding-goal production-data)))
                (is-eq (get status production-data) STATUS-CANCELLED)
              )
              ERR-GOAL-NOT-MET)
    
    ;; Transfer refund to contributor
    (try! (as-contract (stx-transfer? (get amount contribution-data) tx-sender tx-sender)))
    
    ;; Remove contribution record
    (map-delete contributions { production-id: production-id, contributor: tx-sender })
    
    ;; Update production funding
    (map-set productions
      { production-id: production-id }
      (merge production-data { 
        current-funding: (- (get current-funding production-data) (get amount contribution-data)),
        contributor-count: (- (get contributor-count production-data) u1)
      })
    )
    
    (ok (get amount contribution-data))
  )
)

;; Read-only functions

;; Get production details
(define-read-only (get-production (production-id uint))
  (map-get? productions { production-id: production-id })
)

;; Get contribution amount for a specific contributor
(define-read-only (get-contribution (production-id uint) (contributor principal))
  (map-get? contributions { production-id: production-id, contributor: contributor })
)

;; Get total number of productions
(define-read-only (get-total-productions)
  (var-get total-productions)
)

;; Get total funds raised across all productions
(define-read-only (get-total-funds-raised)
  (var-get total-funds-raised)
)

;; Check if production goal is met
(define-read-only (is-goal-met (production-id uint))
  (match (map-get? productions { production-id: production-id })
    some-production (>= (get current-funding some-production) (get funding-goal some-production))
    false
  )
)

;; Check if production is expired
(define-read-only (is-expired (production-id uint))
  (match (map-get? productions { production-id: production-id })
    some-production (>= stacks-block-height (get deadline some-production))
    true
  )
)

;; Get production status
(define-read-only (get-production-status (production-id uint))
  (match (map-get? productions { production-id: production-id })
    some-production (get status some-production)
    u0
  )
)

;; Get contributor at specific index
(define-read-only (get-contributor-at-index (production-id uint) (index uint))
  (map-get? production-contributors { production-id: production-id, contributor-index: index })
)

;; Get total contributor count for production
(define-read-only (get-contributor-count (production-id uint))
  (match (map-get? contributor-counts { production-id: production-id })
    some-count (get count some-count)
    u0
  )
)

