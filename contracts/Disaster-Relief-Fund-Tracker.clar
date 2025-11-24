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
(define-constant err-withdrawal-not-found (err u109))
(define-constant err-withdrawal-already-executed (err u110))
(define-constant err-withdrawal-period-not-ended (err u111))
(define-constant err-insufficient-campaign-funds (err u112))
(define-constant err-withdrawal-amount-invalid (err u113))
(define-constant err-not-eligible-refund (err u114))
(define-constant err-no-donation (err u115))
(define-constant err-campaign-paused (err u116))
(define-constant err-campaign-not-paused (err u117))

(define-data-var next-campaign-id uint u1)
(define-data-var total-campaigns uint u0)
(define-data-var total-donated uint u0)
(define-data-var next-withdrawal-id uint u1)
(define-data-var emergency-withdrawal-delay uint u144)

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
        paused: bool,
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

(define-map emergency-withdrawals
    { withdrawal-id: uint }
    {
        campaign-id: uint,
        requester: principal,
        amount: uint,
        reason: (string-ascii 200),
        requested-at: uint,
        executable-at: uint,
        executed: bool,
    }
)

(define-map withdrawal-objections
    {
        withdrawal-id: uint,
        objector: principal,
    }
    {
        objected-at: uint,
        reason: (string-ascii 200),
    }
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
            paused: false,
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
        (asserts! (not (get paused campaign-data)) err-campaign-paused)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
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
        (asserts! (not (get paused campaign-data)) err-campaign-paused)
        (asserts! (> additional-duration u0) err-invalid-duration)
        (map-set campaigns { campaign-id: campaign-id }
            (merge campaign-data { deadline: (+ (get deadline campaign-data) additional-duration) })
        )
        (ok true)
    )
)

(define-public (pause-campaign (campaign-id uint))
    (let ((campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found)))
        (asserts! (is-eq (get creator campaign-data) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status campaign-data) "active")
            err-campaign-completed
        )
        (asserts! (not (get paused campaign-data)) err-campaign-paused)
        (map-set campaigns { campaign-id: campaign-id }
            (merge campaign-data { paused: true })
        )
        (ok true)
    )
)

(define-public (resume-campaign (campaign-id uint))
    (let ((campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found)))
        (asserts! (is-eq (get creator campaign-data) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status campaign-data) "active")
            err-campaign-completed
        )
        (asserts! (get paused campaign-data) err-campaign-not-paused)
        (map-set campaigns { campaign-id: campaign-id }
            (merge campaign-data { paused: false })
        )
        (ok true)
    )
)

(define-public (request-emergency-withdrawal
        (campaign-id uint)
        (amount uint)
        (reason (string-ascii 200))
    )
    (let (
            (campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id })
                err-not-found
            ))
            (withdrawal-id (var-get next-withdrawal-id))
            (current-height stacks-block-height)
            (executable-at (+ current-height (var-get emergency-withdrawal-delay)))
        )
        (asserts! (is-eq (get creator campaign-data) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status campaign-data) "active")
            err-campaign-completed
        )
        (asserts! (> amount u0) err-withdrawal-amount-invalid)
        (asserts! (<= amount (get raised-amount campaign-data))
            err-insufficient-campaign-funds
        )
        (map-set emergency-withdrawals { withdrawal-id: withdrawal-id } {
            campaign-id: campaign-id,
            requester: tx-sender,
            amount: amount,
            reason: reason,
            requested-at: current-height,
            executable-at: executable-at,
            executed: false,
        })
        (var-set next-withdrawal-id (+ withdrawal-id u1))
        (ok withdrawal-id)
    )
)

(define-public (object-to-withdrawal
        (withdrawal-id uint)
        (objection-reason (string-ascii 200))
    )
    (let (
            (withdrawal-data (unwrap!
                (map-get? emergency-withdrawals { withdrawal-id: withdrawal-id })
                err-withdrawal-not-found
            ))
            (campaign-data (unwrap!
                (map-get? campaigns { campaign-id: (get campaign-id withdrawal-data) })
                err-not-found
            ))
            (donation-data (map-get? donations {
                campaign-id: (get campaign-id withdrawal-data),
                donor: tx-sender,
            }))
            (current-height stacks-block-height)
        )
        (asserts! (is-some donation-data) err-unauthorized)
        (asserts! (not (get executed withdrawal-data))
            err-withdrawal-already-executed
        )
        (asserts! (< current-height (get executable-at withdrawal-data))
            err-withdrawal-period-not-ended
        )
        (map-set withdrawal-objections {
            withdrawal-id: withdrawal-id,
            objector: tx-sender,
        } {
            objected-at: current-height,
            reason: objection-reason,
        })
        (ok true)
    )
)

(define-public (execute-emergency-withdrawal (withdrawal-id uint))
    (let (
            (withdrawal-data (unwrap!
                (map-get? emergency-withdrawals { withdrawal-id: withdrawal-id })
                err-withdrawal-not-found
            ))
            (campaign-data (unwrap!
                (map-get? campaigns { campaign-id: (get campaign-id withdrawal-data) })
                err-not-found
            ))
            (current-height stacks-block-height)
        )
        (asserts! (is-eq (get requester withdrawal-data) tx-sender)
            err-unauthorized
        )
        (asserts! (not (get executed withdrawal-data))
            err-withdrawal-already-executed
        )
        (asserts! (>= current-height (get executable-at withdrawal-data))
            err-withdrawal-period-not-ended
        )
        (asserts!
            (<= (get amount withdrawal-data) (get raised-amount campaign-data))
            err-insufficient-campaign-funds
        )
        (try! (as-contract (stx-transfer? (get amount withdrawal-data) (as-contract tx-sender)
            tx-sender
        )))
        (let ((new-raised (- (get raised-amount campaign-data) (get amount withdrawal-data))))
            (map-set campaigns { campaign-id: (get campaign-id withdrawal-data) }
                (merge campaign-data { raised-amount: new-raised })
            )
            (map-set emergency-withdrawals { withdrawal-id: withdrawal-id }
                (merge withdrawal-data { executed: true })
            )
            (ok true)
        )
    )
)

(define-public (withdraw-completed-funds (campaign-id uint))
    (let ((campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id }) err-not-found)))
        (asserts! (is-eq (get creator campaign-data) tx-sender) err-unauthorized)
        (asserts! (is-eq (get status campaign-data) "completed")
            err-campaign-completed
        )
        (asserts! (> (get raised-amount campaign-data) u0)
            err-insufficient-campaign-funds
        )
        (try! (as-contract (stx-transfer? (get raised-amount campaign-data) (as-contract tx-sender)
            tx-sender
        )))
        (map-set campaigns { campaign-id: campaign-id }
            (merge campaign-data { raised-amount: u0 })
        )
        (ok true)
    )
)

(define-public (claim-refund (campaign-id uint))
    (let (
            (campaign-data (unwrap! (map-get? campaigns { campaign-id: campaign-id })
                err-not-found
            ))
            (donation-opt (map-get? donations {
                campaign-id: campaign-id,
                donor: tx-sender,
            }))
            (current-height stacks-block-height)
        )
        (asserts! (not (is-eq (get status campaign-data) "completed"))
            err-not-eligible-refund
        )
        (asserts!
            (or
                (is-eq (get status campaign-data) "expired")
                (and (>= current-height (get deadline campaign-data)) (< (get raised-amount campaign-data)
                    (get target-amount campaign-data)
                ))
            )
            err-not-eligible-refund
        )
        (asserts! (is-some donation-opt) err-no-donation)
        (let (
                (donation (unwrap! donation-opt err-no-donation))
                (amount (get amount donation))
            )
            (asserts! (> amount u0) err-not-eligible-refund)
            (asserts! (<= amount (get raised-amount campaign-data))
                err-insufficient-campaign-funds
            )
            (try! (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender)))
            (map-set campaigns { campaign-id: campaign-id }
                (merge campaign-data { raised-amount: (- (get raised-amount campaign-data) amount) })
            )
            (map-set donations {
                campaign-id: campaign-id,
                donor: tx-sender,
            } {
                amount: u0,
                timestamp: current-height,
            })
            (ok true)
        )
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
        campaign-data (and
            (is-eq (get status campaign-data) "active")
            (not (get paused campaign-data))
            (< stacks-block-height (get deadline campaign-data))
        )
        false
    )
)

(define-read-only (is-campaign-paused (campaign-id uint))
    (match (map-get? campaigns { campaign-id: campaign-id })
        campaign-data (get paused campaign-data)
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

(define-read-only (get-withdrawal-request (withdrawal-id uint))
    (map-get? emergency-withdrawals { withdrawal-id: withdrawal-id })
)

(define-read-only (get-withdrawal-objection
        (withdrawal-id uint)
        (objector principal)
    )
    (map-get? withdrawal-objections {
        withdrawal-id: withdrawal-id,
        objector: objector,
    })
)

(define-read-only (get-emergency-withdrawal-delay)
    (var-get emergency-withdrawal-delay)
)

(define-read-only (is-withdrawal-executable (withdrawal-id uint))
    (match (map-get? emergency-withdrawals { withdrawal-id: withdrawal-id })
        withdrawal-data (and
            (not (get executed withdrawal-data))
            (>= stacks-block-height (get executable-at withdrawal-data))
        )
        false
    )
)
