;; Ticket Allocator - Community Theater Ticket Distribution Contract
;; Manages ticket allocation based on contributions to theater productions

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PRODUCTION-NOT-FOUND (err u201))
(define-constant ERR-INVALID-TICKET-TYPE (err u202))
(define-constant ERR-NO-TICKETS-AVAILABLE (err u203))
(define-constant ERR-INSUFFICIENT-CONTRIBUTION (err u204))
(define-constant ERR-TICKET-ALREADY-USED (err u205))
(define-constant ERR-INVALID-AMOUNT (err u206))
(define-constant ERR-TICKET-NOT-FOUND (err u207))
(define-constant ERR-ALLOCATION-CLOSED (err u208))
(define-constant ERR-PRODUCTION-NOT-FUNDED (err u209))

;; Constants
(define-constant TICKET-TYPE-GENERAL u1)
(define-constant TICKET-TYPE-VIP u2)
(define-constant TICKET-TYPE-PREMIUM u3)

;; Contribution tier thresholds (in microSTX)
(define-constant TIER-BRONZE u500000)   ;; 0.5 STX
(define-constant TIER-SILVER u1000000)  ;; 1 STX
(define-constant TIER-GOLD u2000000)    ;; 2 STX
(define-constant TIER-PLATINUM u5000000) ;; 5 STX

;; Data variables
(define-data-var next-ticket-id uint u1)
(define-data-var total-tickets-allocated uint u0)

;; Ticket allocation configuration per production
(define-map ticket-configs
  { production-id: uint }
  {
    general-tickets: uint,
    vip-tickets: uint,
    premium-tickets: uint,
    general-allocated: uint,
    vip-allocated: uint,
    premium-allocated: uint,
    allocation-active: bool,
    min-contribution-general: uint,
    min-contribution-vip: uint,
    min-contribution-premium: uint
  }
)

;; Individual ticket allocations
(define-map ticket-allocations
  { ticket-id: uint }
  {
    production-id: uint,
    holder: principal,
    ticket-type: uint,
    contribution-amount: uint,
    allocated-at: uint,
    used: bool,
    transferable: bool
  }
)

;; Holder tickets mapping (for easy lookup)
(define-map holder-tickets
  { production-id: uint, holder: principal }
  {
    general-count: uint,
    vip-count: uint,
    premium-count: uint,
    total-contribution: uint
  }
)

;; Production ticket summary
(define-map production-tickets
  { production-id: uint }
  {
    total-tickets: uint,
    allocated-tickets: uint,
    unique-holders: uint
  }
)

;; Ticket transfer history
(define-map ticket-transfers
  { ticket-id: uint, transfer-index: uint }
  {
    from-holder: principal,
    to-holder: principal,
    transferred-at: uint
  }
)

;; Track number of transfers per ticket
(define-map ticket-transfer-counts
  { ticket-id: uint }
  { count: uint }
)

;; Public Functions

;; Initialize ticket allocation for a production
(define-public (initialize-ticket-allocation (production-id uint)
                                           (general-tickets uint)
                                           (vip-tickets uint) 
                                           (premium-tickets uint)
                                           (min-general uint)
                                           (min-vip uint)
                                           (min-premium uint))
  (begin
    ;; Validate ticket counts and minimums
    (asserts! (> (+ general-tickets vip-tickets premium-tickets) u0) ERR-INVALID-AMOUNT)
    (asserts! (and (>= min-vip min-general) (>= min-premium min-vip)) ERR-INVALID-AMOUNT)
    
    ;; Set ticket configuration
    (map-set ticket-configs
      { production-id: production-id }
      {
        general-tickets: general-tickets,
        vip-tickets: vip-tickets,
        premium-tickets: premium-tickets,
        general-allocated: u0,
        vip-allocated: u0,
        premium-allocated: u0,
        allocation-active: true,
        min-contribution-general: min-general,
        min-contribution-vip: min-vip,
        min-contribution-premium: min-premium
      }
    )
    
    ;; Initialize production ticket summary
    (map-set production-tickets
      { production-id: production-id }
      {
        total-tickets: (+ general-tickets vip-tickets premium-tickets),
        allocated-tickets: u0,
        unique-holders: u0
      }
    )
    
    (ok true)
  )
)

;; Allocate tickets based on contribution amount
(define-public (allocate-tickets (production-id uint) (contribution-amount uint) (holder principal))
  (let ((config (unwrap! (map-get? ticket-configs { production-id: production-id }) ERR-PRODUCTION-NOT-FOUND))
        (existing-holder (map-get? holder-tickets { production-id: production-id, holder: holder }))
        (production-summary (unwrap! (map-get? production-tickets { production-id: production-id }) ERR-PRODUCTION-NOT-FOUND)))
    
    ;; Check if allocation is active
    (asserts! (get allocation-active config) ERR-ALLOCATION-CLOSED)
    (asserts! (> contribution-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Determine ticket eligibility based on contribution
    (let ((can-get-premium (>= contribution-amount (get min-contribution-premium config)))
          (can-get-vip (>= contribution-amount (get min-contribution-vip config)))
          (can-get-general (>= contribution-amount (get min-contribution-general config)))
          (current-holder-data (match existing-holder
                                some-data some-data
                                {
                                  general-count: u0,
                                  vip-count: u0,
                                  premium-count: u0,
                                  total-contribution: u0
                                })))
      
      ;; Allocate tickets based on contribution and availability
      (let ((tickets-to-allocate (calculate-ticket-allocation contribution-amount config))
            (general-to-allocate (get general tickets-to-allocate))
            (vip-to-allocate (get vip tickets-to-allocate))
            (premium-to-allocate (get premium tickets-to-allocate)))
        
        ;; Check availability
        (asserts! (<= (+ (get general-allocated config) general-to-allocate) (get general-tickets config)) ERR-NO-TICKETS-AVAILABLE)
        (asserts! (<= (+ (get vip-allocated config) vip-to-allocate) (get vip-tickets config)) ERR-NO-TICKETS-AVAILABLE)
        (asserts! (<= (+ (get premium-allocated config) premium-to-allocate) (get premium-tickets config)) ERR-NO-TICKETS-AVAILABLE)
        
        ;; Create ticket records
        (let ((tickets-created (create-ticket-records production-id holder contribution-amount general-to-allocate vip-to-allocate premium-to-allocate)))
          
          ;; Update ticket configuration
          (map-set ticket-configs
            { production-id: production-id }
            (merge config {
              general-allocated: (+ (get general-allocated config) general-to-allocate),
              vip-allocated: (+ (get vip-allocated config) vip-to-allocate),
              premium-allocated: (+ (get premium-allocated config) premium-to-allocate)
            })
          )
          
          ;; Update holder tickets
          (map-set holder-tickets
            { production-id: production-id, holder: holder }
            {
              general-count: (+ (get general-count current-holder-data) general-to-allocate),
              vip-count: (+ (get vip-count current-holder-data) vip-to-allocate),
              premium-count: (+ (get premium-count current-holder-data) premium-to-allocate),
              total-contribution: (+ (get total-contribution current-holder-data) contribution-amount)
            }
          )
          
          ;; Update production summary
          (map-set production-tickets
            { production-id: production-id }
            (merge production-summary {
              allocated-tickets: (+ (get allocated-tickets production-summary) 
                                   general-to-allocate vip-to-allocate premium-to-allocate),
              unique-holders: (if (is-none existing-holder) 
                                (+ (get unique-holders production-summary) u1)
                                (get unique-holders production-summary))
            })
          )
          
          ;; Update global counter
          (var-set total-tickets-allocated (+ (var-get total-tickets-allocated) 
                                             general-to-allocate vip-to-allocate premium-to-allocate))
          
          (ok {
            general-allocated: general-to-allocate,
            vip-allocated: vip-to-allocate,
            premium-allocated: premium-to-allocate,
            total-allocated: (+ general-to-allocate vip-to-allocate premium-to-allocate)
          })
        )
      )
    )
  )
)

;; Use/redeem a ticket
(define-public (use-ticket (ticket-id uint))
  (let ((ticket-data (unwrap! (map-get? ticket-allocations { ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND)))
    ;; Only ticket holder can use the ticket
    (asserts! (is-eq tx-sender (get holder ticket-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get used ticket-data)) ERR-TICKET-ALREADY-USED)
    
    ;; Mark ticket as used
    (map-set ticket-allocations
      { ticket-id: ticket-id }
      (merge ticket-data { used: true })
    )
    
    (ok ticket-id)
  )
)

;; Transfer ticket to another holder (if transferable)
(define-public (transfer-ticket (ticket-id uint) (new-holder principal))
  (let ((ticket-data (unwrap! (map-get? ticket-allocations { ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
        (transfer-count-data (map-get? ticket-transfer-counts { ticket-id: ticket-id })))
    
    ;; Validate transfer
    (asserts! (is-eq tx-sender (get holder ticket-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get used ticket-data)) ERR-TICKET-ALREADY-USED)
    (asserts! (get transferable ticket-data) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq tx-sender new-holder)) ERR-INVALID-AMOUNT)
    
    ;; Update ticket holder
    (map-set ticket-allocations
      { ticket-id: ticket-id }
      (merge ticket-data { holder: new-holder })
    )
    
    ;; Record transfer
    (let ((current-transfers (match transfer-count-data
                              some-count (get count some-count)
                              u0)))
      (map-set ticket-transfers
        { ticket-id: ticket-id, transfer-index: current-transfers }
        {
          from-holder: tx-sender,
          to-holder: new-holder,
          transferred-at: stacks-block-height
        }
      )
      
      (map-set ticket-transfer-counts
        { ticket-id: ticket-id }
        { count: (+ current-transfers u1) }
      )
    )
    
    (ok ticket-id)
  )
)

;; Private helper functions

;; Calculate ticket allocation based on contribution amount
(define-private (calculate-ticket-allocation (contribution uint) (config (tuple (general-tickets uint) (vip-tickets uint) (premium-tickets uint) (general-allocated uint) (vip-allocated uint) (premium-allocated uint) (allocation-active bool) (min-contribution-general uint) (min-contribution-vip uint) (min-contribution-premium uint))))
  (if (>= contribution (get min-contribution-premium config))
    { general: u1, vip: u1, premium: u1 }  ;; Premium tier gets all ticket types
    (if (>= contribution (get min-contribution-vip config))
      { general: u1, vip: u1, premium: u0 }  ;; VIP tier gets general + vip
      (if (>= contribution (get min-contribution-general config))
        { general: u1, vip: u0, premium: u0 }  ;; General tier gets general only
        { general: u0, vip: u0, premium: u0 }  ;; No tickets if below minimum
      )
    )
  )
)

;; Create individual ticket records (simplified to avoid recursion)
(define-private (create-ticket-records (production-id uint) (holder principal) (contribution uint) (general uint) (vip uint) (premium uint))
  (begin
    ;; Create general tickets (max 1 per contribution)
    (if (> general u0)
      (create-single-ticket production-id holder contribution TICKET-TYPE-GENERAL)
      u0
    )
    
    ;; Create VIP tickets (max 1 per contribution)
    (if (> vip u0)
      (create-single-ticket production-id holder contribution TICKET-TYPE-VIP)
      u0
    )
    
    ;; Create premium tickets (max 1 per contribution)
    (if (> premium u0)
      (create-single-ticket production-id holder contribution TICKET-TYPE-PREMIUM)
      u0
    )
    
    true
  )
)

;; Create a single ticket record
(define-private (create-single-ticket (production-id uint) (holder principal) (contribution uint) (ticket-type uint))
  (let ((ticket-id (var-get next-ticket-id)))
    (map-set ticket-allocations
      { ticket-id: ticket-id }
      {
        production-id: production-id,
        holder: holder,
        ticket-type: ticket-type,
        contribution-amount: contribution,
        allocated-at: stacks-block-height,
        used: false,
        transferable: true
      }
    )
    
    (var-set next-ticket-id (+ ticket-id u1))
    ticket-id
  )
)

;; Read-only functions

;; Get ticket allocation configuration for a production
(define-read-only (get-ticket-config (production-id uint))
  (map-get? ticket-configs { production-id: production-id })
)

;; Get ticket details
(define-read-only (get-ticket (ticket-id uint))
  (map-get? ticket-allocations { ticket-id: ticket-id })
)

;; Get holder's tickets for a production
(define-read-only (get-holder-tickets (production-id uint) (holder principal))
  (map-get? holder-tickets { production-id: production-id, holder: holder })
)

;; Get production ticket summary
(define-read-only (get-production-summary (production-id uint))
  (map-get? production-tickets { production-id: production-id })
)

;; Check ticket availability for a production
(define-read-only (get-available-tickets (production-id uint))
  (match (map-get? ticket-configs { production-id: production-id })
    some-config {
      general-available: (- (get general-tickets some-config) (get general-allocated some-config)),
      vip-available: (- (get vip-tickets some-config) (get vip-allocated some-config)),
      premium-available: (- (get premium-tickets some-config) (get premium-allocated some-config))
    }
    {
      general-available: u0,
      vip-available: u0,
      premium-available: u0
    }
  )
)

;; Get total tickets allocated across all productions
(define-read-only (get-total-tickets-allocated)
  (var-get total-tickets-allocated)
)

;; Get ticket transfer history
(define-read-only (get-ticket-transfer (ticket-id uint) (transfer-index uint))
  (map-get? ticket-transfers { ticket-id: ticket-id, transfer-index: transfer-index })
)

;; Get number of transfers for a ticket
(define-read-only (get-ticket-transfer-count (ticket-id uint))
  (match (map-get? ticket-transfer-counts { ticket-id: ticket-id })
    some-count (get count some-count)
    u0
  )
)

;; Calculate what tickets a contribution would earn
(define-read-only (preview-ticket-allocation (production-id uint) (contribution uint))
  (match (map-get? ticket-configs { production-id: production-id })
    some-config (calculate-ticket-allocation contribution some-config)
    { general: u0, vip: u0, premium: u0 }
  )
)

