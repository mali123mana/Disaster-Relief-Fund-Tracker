(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-campaign-expired (err u104))
(define-constant err-campaign-completed (err u105))
(define-constant err-insufficient-funds (err u106))
(define-constant err-invalid-target (err u107))
(define-constant err-invalid-duration (err u108))

(define-data-var next-campaign-id uint u1)
(define-data-var total-campaigns uint u0)
(define-data-var total-donated uint u0)

(define-map campaigns
    { campaign-id: uint }
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        target-amount: uint,
        raised-amount: uint,
        deadline: uint,
        status: (string-ascii 20),
        created-at: uint,
    }
)

(define-map donations
    {
        campaign-id: uint,
        donor: principal,
    }
    {
        amount: uint,
        timestamp: uint,
    }
)

(define-map donor-totals
    { donor: principal }
    {
        total-donated: uint,
        campaigns-supported: uint,
    }
)

(define-map campaign-donors
    { campaign-id: uint }
    { donor-count: uint }
)

(define-public (create-campaign
        (title (string-ascii 100))
        (description (string-ascii 500))
        (target-amount uint)
        (duration uint)
    )
    (let (
            (campaign-id (var-get next-campaign-id))
            (current-height stacks-block-height)
            (deadline (+ current-height duration))
        )
        (asserts! (> target-amount u0) err-invalid-target)
        (asserts! (> duration u0) err-invalid-duration)
        (map-set campaigns { campaign-id: campaign-id } {
            creator: tx-sender,
            title: title,
            description: description,
            target-amount: target-amount,
            raised-amount: u0,
            deadline: deadline,
            status: "active",
            created-at: current-height,
        })
        (map-set campaign-donors { campaign-id: campaign-id } { donor-count: u0 })
        (var-set next-campaign-id (+ campaign-id u1))
        (var-set total-campaigns (+ (var-get total-campaigns) u1))
        (ok campaign-id)
    )
)

(define-public (donate
        (campaign-id uint)
        (amount uint)
    )
    (let (
            (campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id })
                err-not-found
            ))
            (current-height stacks-block-height)
            (existing-donation (map-get? donations {
                campaign-id: campaign-id,
                donor: tx-sender,
            }))
            (donor-data (default-to {
                total-donated: u0,
                campaigns-supported: u0,
            }
                (map-get? donor-totals { donor: tx-sender })
            ))
            (campaign-donor-data (unwrap! (map-get? campaign-donors { campaign-id: campaign-id })
                err-not-found
            ))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (asserts! (< current-height (get deadline campaign-data))
            err-campaign-expired
        )
        (asserts! (is-eq (get status campaign-data) "active")
            err-campaign-completed
        )
        (try! (stx-transfer? amount tx-sender (get creator campaign-data)))
        (let (
                (new-raised (+ (get raised-amount campaign-data) amount))
                (new-status (if (>= new-raised (get target-amount campaign-data))
                    "completed"
                    "active"
                ))
            )
            (map-set campaigns { campaign-id: campaign-id }
                (merge campaign-data {
                    raised-amount: new-raised,
                    status: new-status,
                })
            )
            (match existing-donation
                some-donation (map-set donations {
                    campaign-id: campaign-id,
                    donor: tx-sender,
                } {
                    amount: (+ (get amount some-donation) amount),
                    timestamp: current-height,
                })
                (begin
                    (map-set donations {
                        campaign-id: campaign-id,
                        donor: tx-sender,
                    } {
                        amount: amount,
                        timestamp: current-height,
                    })
                    (map-set donor-totals { donor: tx-sender } {
                        total-donated: (+ (get total-donated donor-data) amount),
                        campaigns-supported: (+ (get campaigns-supported donor-data) u1),
                    })
                    (map-set campaign-donors { campaign-id: campaign-id } { donor-count: (+ (get donor-count campaign-donor-data) u1) })
                )
            )
            (var-set total-donated (+ (var-get total-donated) amount))
            (ok true)
        )
    )
)

(define-public (update-campaign-status (campaign-id uint))
    (let (
            (campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id })
                err-not-found
            ))
            (current-height stacks-block-height)
        )
        (if (and (< current-height (get deadline campaign-data)) (is-eq (get status campaign-data) "active"))
            (if (>= (get raised-amount campaign-data)
                    (get target-amount campaign-data)
                )
                (begin
                    (map-set campaigns { campaign-id: campaign-id }
                        (merge campaign-data { status: "completed" })
                    )
                    (ok "completed")
                )
                (ok "active")
            )
            (if (and (>= current-height (get deadline campaign-data)) (is-eq (get status campaign-data) "active"))
                (begin
                    (map-set campaigns { campaign-id: campaign-id }
                        (merge campaign-data { status: "expired" })
                    )
                    (ok "expired")
                )
                (ok (get status campaign-data))
            )
        )
    )
)

(define-public (extend-campaign
        (campaign-id uint)
        (additional-duration uint)
    )
    (let ((campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found)))
        (asserts! (is-eq (get creator campaign-data) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status campaign-data) "active")
            err-campaign-completed
        )
        (asserts! (> additional-duration u0) err-invalid-duration)
        (map-set campaigns { campaign-id: campaign-id }
            (merge campaign-data { deadline: (+ (get deadline campaign-data) additional-duration) })
        )
        (ok true)
    )
)

(define-read-only (get-campaign (campaign-id uint))
    (map-get? campaigns { campaign-id: campaign-id })
)

(define-read-only (get-donation
        (campaign-id uint)
        (donor principal)
    )
    (map-get? donations {
        campaign-id: campaign-id,
        donor: donor,
    })
)

(define-read-only (get-donor-stats (donor principal))
    (map-get? donor-totals { donor: donor })
)

(define-read-only (get-campaign-donor-count (campaign-id uint))
    (map-get? campaign-donors { campaign-id: campaign-id })
)

(define-read-only (get-total-campaigns)
    (var-get total-campaigns)
)

(define-read-only (get-total-donated)
    (var-get total-donated)
)

(define-read-only (get-next-campaign-id)
    (var-get next-campaign-id)
)

(define-read-only (get-campaign-progress (campaign-id uint))
    (match (map-get? campaigns { campaign-id: campaign-id })
        campaign-data (let ((progress (if (> (get target-amount campaign-data) u0)
                (/ (* (get raised-amount campaign-data) u100)
                    (get target-amount campaign-data)
                )
                u0
            )))
            (some {
                progress-percentage: progress,
                raised: (get raised-amount campaign-data),
                target: (get target-amount campaign-data),
            })
        )
        none
    )
)

(define-read-only (is-campaign-active (campaign-id uint))
    (match (map-get? campaigns { campaign-id: campaign-id })
        campaign-data (and (is-eq (get status campaign-data) "active") (< stacks-block-height (get deadline campaign-data)))
        false
    )
)

(define-read-only (get-campaigns-by-status (status (string-ascii 20)))
    (ok status)
)

(define-read-only (get-contract-stats)
    {
        total-campaigns: (var-get total-campaigns),
        total-donated: (var-get total-donated),
        next-campaign-id: (var-get next-campaign-id),
    }
)
